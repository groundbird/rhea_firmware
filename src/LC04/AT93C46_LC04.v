`timescale 1ns / 1ps
//-------------------------------------------------------------------//
//  Module      : AT93C46_LC04
//  Description : Bridge between SiTCP's AT93C46 interface and 24LC04.
//
//  This module replaces AT93C46_M24C08 for boards equipped with a
//  24LC04 EEPROM instead of M24C08.  The external port names and
//  semantics are kept identical to AT93C46_M24C08 so that sitcp.vhd
//  requires only a component-declaration / instance-name change.
//
//  Architecture (same as AT93C46_M24C08):
//    SiTCP -> AT93C46 decoder -> Shadow RAM <-> LC04_READER/WRITER -> 24LC04
//
//  Differences from AT93C46_M24C08:
//    - TCA9544 I2C mux initialization removed (not present on AXKU042)
//    - M24_READER / M24_WRITER replaced with LC04_READER / LC04_WRITER
//    - Open-drain I2C model:
//        M24C08_SCL_OUT  = ~(scl_r | scl_w)   (direct push-pull drive)
//        M24C08_SDA_OUT  = 1'b0                (IOBUF.I is always 0)
//        M24C08_SDAT_OUT = ~(sda_r | sda_w)   (0=drive, 1=tristate)
//      sitcp.vhd IOBUF: iobuf_t = SDAT_OUT OR SDA_OUT
//        -> drive SDA low  when SDAT_OUT=0 AND SDA_OUT=0  (sda_r|sda_w=1)
//        -> release SDA    when SDAT_OUT=1                 (sda_r|sda_w=0)
//
//  Parameter:
//    SYSCLK_FREQ_IN_MHz : System clock frequency.
//                         I2C is generated internally at ~100 kHz.
//-------------------------------------------------------------------//

module AT93C46_LC04 #(
    parameter integer SYSCLK_FREQ_IN_MHz = 100
) (
    // AT93C46 serial interface (driven by SiTCP)
    input  wire  AT93C46_CS_IN,
    input  wire  AT93C46_SK_IN,
    input  wire  AT93C46_DI_IN,
    output wire  AT93C46_DO_OUT,

    // I2C interface to 24LC04
    // Port names preserved from AT93C46_M24C08 for drop-in sitcp.vhd compatibility.
    output wire  M24C08_SCL_OUT,    // SCL direct drive  (0=low, 1=high)
    output wire  M24C08_SDA_OUT,    // Always 1'b0       (IOBUF.I=0 open-drain)
    input  wire  M24C08_SDA_IN,     // SDA read-back     (from IOBUF.O)
    output wire  M24C08_SDAT_OUT,   // SDA tristate ctrl (0=drive low, 1=release)

    input  wire  RESET_IN,
    output wire  SiTCP_RESET_OUT,

    input  wire  SYSCLK_IN
);

    // ------------------------------------------------------------------
    // I2C quarter-period: target 100 kHz
    //   CLK_DIV = SYSCLK_MHz / (4 * 100kHz) = SYSCLK_MHz * 2.5
    // ------------------------------------------------------------------
    localparam integer CLK_DIV = SYSCLK_FREQ_IN_MHz * 5 / 2;

    // ------------------------------------------------------------------
    // Startup delay: hold internal reset for ~2 ms after RESET_IN
    // deasserts to allow 24LC04 power-up (tPU <= 1 ms per datasheet).
    //   STARTUP_DELAY = SYSCLK_MHz * 2000 (cycles for 2 ms)
    // ------------------------------------------------------------------
    localparam integer STARTUP_DELAY = SYSCLK_FREQ_IN_MHz * 2000;
    localparam integer DELAY_CNT_W   = 22; // ceil(log2(200*2000)) = 22

    reg [DELAY_CNT_W-1:0] startup_cnt = 0;
    reg                   lc04_reset  = 1'b1;  // internal reset for LC04 blocks

    always @(posedge SYSCLK_IN or posedge RESET_IN) begin
        if (RESET_IN) begin
            startup_cnt <= 0;
            lc04_reset  <= 1'b1;
        end else begin
            if (startup_cnt < STARTUP_DELAY[DELAY_CNT_W-1:0]) begin
                startup_cnt <= startup_cnt + 1;
                lc04_reset  <= 1'b1;
            end else begin
                lc04_reset <= 1'b0;
            end
        end
    end

    // ------------------------------------------------------------------
    // I2C bus: combine drive signals from Reader and Writer (open-drain OR)
    // ------------------------------------------------------------------
    wire scl_r_low, sda_r_low;  // from LC04_READER
    wire scl_w_low, sda_w_low;  // from LC04_WRITER
    wire sda_in = M24C08_SDA_IN;

    // SCL: direct push-pull (24LC04 does not clock-stretch)
    assign M24C08_SCL_OUT  = ~(scl_r_low | scl_w_low);
    // SDA: open-drain via IOBUF in sitcp.vhd
    //   iobuf_t = SDAT_OUT OR SDA_OUT  →  T=0 (drive) only when both=0
    assign M24C08_SDA_OUT  = 1'b0;
    assign M24C08_SDAT_OUT = ~(sda_r_low | sda_w_low);

    // ------------------------------------------------------------------
    // Shadow RAM: blk_mem_gen_v7_3 (128 × 8-bit, true dual-port)
    //   Port A (r/w) : AT93C46 protocol decoder (SiTCP read/write)
    //   Port B (w)   : LC04_READER (fill on startup)
    // ------------------------------------------------------------------
    reg        MEM_WEA;
    wire [6:0] MEM_ADDRA;
    wire [7:0] MEM_DINA;
    wire [7:0] MEM_DOUTA;

    wire       MEM_WEB;
    wire [6:0] MEM_ADDRB;
    wire [7:0] MEM_DINB;

    blk_mem_gen_v7_3 SHADOW_RAM (
        .clka   (SYSCLK_IN  ),
        .wea    (MEM_WEA    ),
        .addra  (MEM_ADDRA  ),
        .dina   (MEM_DINA   ),
        .douta  (MEM_DOUTA  ),
        .clkb   (SYSCLK_IN  ),
        .web    (MEM_WEB    ),
        .addrb  (MEM_ADDRB  ),
        .dinb   (MEM_DINB   ),
        .doutb  (           )
    );

    // ------------------------------------------------------------------
    // LC04_READER: reads 128 bytes from 24LC04 at startup → Shadow RAM
    //   START_ADDR=0 : 24LC04 addresses 0x00-0x7F (block 0)
    // ------------------------------------------------------------------
    wire       rd_we;
    wire [8:0] rd_addr;   // 9-bit from LC04_READER; [6:0] used for shadow RAM
    wire [7:0] rd_din;

    assign MEM_WEB  = rd_we;
    assign MEM_ADDRB = rd_addr[6:0];
    assign MEM_DINB  = rd_din;

    LC04_READER #(
        .CLK_DIVIDER (CLK_DIV),
        .NUM_BYTES   (128    ),
        .START_ADDR  (0      )
    ) u_reader (
        .SYSCLK_IN      (SYSCLK_IN      ),
        .RESET_IN       (lc04_reset     ),
        .SCL_DRIVE_LOW  (scl_r_low      ),
        .SDA_DRIVE_LOW  (sda_r_low      ),
        .SDA_IN         (sda_in         ),
        .MEM_WE_OUT     (rd_we          ),
        .MEM_ADDR_OUT   (rd_addr        ),
        .MEM_DIN_OUT    (rd_din         ),
        .SITCP_RESET_OUT(SiTCP_RESET_OUT),
        .DONE_OUT       (               ),
        .ERROR_OUT      (               )
    );

    // ------------------------------------------------------------------
    // LC04_WRITER: writes shadow RAM entries to 24LC04 when SiTCP writes
    // ------------------------------------------------------------------
    LC04_WRITER #(
        .CLK_DIVIDER  (CLK_DIV),
        .ACK_POLL_MAX (500    )
    ) u_writer (
        .SYSCLK_IN      (SYSCLK_IN              ),
        .RESET_IN       (lc04_reset             ),
        .ROM_WE_IN      (MEM_WEA                ),
        .ROM_ADDR_IN    ({2'b00, MEM_ADDRA[6:0]}),  // block 0, addresses 0-127
        .ROM_DATA_IN    (MEM_DINA               ),
        .SCL_DRIVE_LOW  (scl_w_low              ),
        .SDA_DRIVE_LOW  (sda_w_low              ),
        .SDA_IN         (sda_in                 ),
        .DONE_OUT       (                       ),
        .ERROR_OUT      (                       )
    );

    // ------------------------------------------------------------------
    // AT93C46 protocol decoder (unchanged from AT93C46_M24C08)
    //
    // AT93C46 command format (8-bit data, 128-word):
    //   SB  OP1 OP0  A6..A0  D7..D0
    //   1   1   0    xxxxxx  xxxxxxxx  READ
    //   1   0   1    xxxxxx  xxxxxxxx  WRITE
    //   1   0   0    xxxxxx            ERASE / extended
    // ------------------------------------------------------------------
    reg  [5:0] BIT_COUNT;
    reg  [7:0] OUT_BUFFER;
    reg  [7:0] IN_BUFFER;
    reg  [2:0] OPCODE;
    reg  [6:0] ADDRESS;

    // Shadow RAM port A address / data
    assign MEM_ADDRA[6:0] = (OPCODE == 3'b110) ? {IN_BUFFER[5:0], AT93C46_DI_IN}
                                                 : ADDRESS[6:0];
    assign MEM_DINA[7:0]  = IN_BUFFER[7:0];
    assign AT93C46_DO_OUT = OUT_BUFFER[7];

    reg [7:0] MEM_DOUTA_REG;

    wire AT93C46_SK_RISE;
    wire AT93C46_SK_FALL;
    reg  AT93C46_SK_P0;
    reg  AT93C46_SK_P1;
    assign AT93C46_SK_RISE = ~AT93C46_SK_P1 &  AT93C46_SK_P0;
    assign AT93C46_SK_FALL =  AT93C46_SK_P1 & ~AT93C46_SK_P0;

    always @(posedge SYSCLK_IN or posedge lc04_reset) begin
        if (lc04_reset) begin
            MEM_WEA         <= 1'b0;
            MEM_DOUTA_REG   <= 8'd0;
            BIT_COUNT       <= 6'd0;
            AT93C46_SK_P0   <= 1'b0;
            AT93C46_SK_P1   <= 1'b0;
            OUT_BUFFER      <= 8'hff;
            IN_BUFFER       <= 8'd0;
            OPCODE          <= 3'd0;
            ADDRESS         <= 7'd0;
        end else begin
            AT93C46_SK_P0 <= AT93C46_SK_IN;
            AT93C46_SK_P1 <= AT93C46_SK_P0;

            BIT_COUNT  <= ~AT93C46_CS_IN    ? 6'd0
                        : ~AT93C46_SK_RISE  ? BIT_COUNT
                        : BIT_COUNT + 6'd1;

            IN_BUFFER  <= ~AT93C46_SK_RISE  ? IN_BUFFER
                        : {IN_BUFFER[6:0], AT93C46_DI_IN};

            OPCODE     <= ~AT93C46_SK_RISE  ? OPCODE
                        : (BIT_COUNT == 6'd3) ? IN_BUFFER[2:0] : OPCODE;

            ADDRESS    <= ~AT93C46_SK_RISE  ? ADDRESS
                        : (BIT_COUNT == 6'd10) ? IN_BUFFER[6:0] : ADDRESS;

            MEM_WEA    <= ~AT93C46_SK_RISE  ? 1'b0
                        : (BIT_COUNT == 6'd17) & (OPCODE == 3'b101);

            MEM_DOUTA_REG <= ~AT93C46_SK_RISE ? MEM_DOUTA_REG : MEM_DOUTA;

            OUT_BUFFER <= ~AT93C46_SK_FALL  ? OUT_BUFFER
                        : (BIT_COUNT == 6'd9)  & (OPCODE == 3'b110) ? 8'd0
                        : (BIT_COUNT == 6'd10) & (OPCODE == 3'b110) ? MEM_DOUTA_REG
                        : {OUT_BUFFER[6:0], 1'b1};
        end
    end

endmodule
