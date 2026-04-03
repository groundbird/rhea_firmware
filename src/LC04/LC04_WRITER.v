`timescale 1ns / 1ps
//-------------------------------------------------------------------//
//  Module      : LC04_WRITER
//  Description : 24LC04 multi-entry writer.
//                Buffers (addr[8:0], data[7:0]) pairs and issues
//                single-byte I2C write transactions to 24LC04.
//                Open-drain model: SCL_DRIVE_LOW / SDA_DRIVE_LOW.
//
//  24LC04 write sequence per byte:
//    START -> ctrl_write (0xA0 | block<<1) -> word_addr[7:0]
//          -> data -> STOP -> ACK poll
//
//  Parameters:
//    CLK_DIVIDER  : SYSCLK cycles per I2C bit quarter-period
//                   e.g. 250MHz / 250 = 1MHz quarter -> 400kHz I2C
//    ACK_POLL_MAX : max ACK-polling retries after each write
//-------------------------------------------------------------------//

module LC04_WRITER #(
    parameter integer CLK_DIVIDER  = 250,
    parameter integer ACK_POLL_MAX = 500
) (
    input  wire        SYSCLK_IN,
    input  wire        RESET_IN,

    // --- write interface ---
    // Assert ROM_WE_IN for one SYSCLK cycle to push one entry.
    input  wire        ROM_WE_IN,
    input  wire [8:0]  ROM_ADDR_IN,   // bit[8]: block select, [7:0]: word address
    input  wire [7:0]  ROM_DATA_IN,

    // --- I2C open-drain ---
    // Connect to IOBUF: .I(1'b0), .T(~DRIVE_LOW)
    output wire        SCL_DRIVE_LOW,
    output wire        SDA_DRIVE_LOW,
    input  wire        SDA_IN,

    output reg         DONE_OUT,      // high when all buffered entries written
    output reg         ERROR_OUT      // high if any entry had an I2C error
);

    // ----------------------------------------------------------------
    // Entry buffer: 128 × 17-bit distributed RAM (async read)
    // ----------------------------------------------------------------
    (* ram_style = "distributed" *) reg [16:0] buf_mem [0:127];
    reg [6:0] wr_ptr = 7'd0;
    reg [6:0] rd_ptr = 7'd0;

    always @(posedge SYSCLK_IN) begin
        if (RESET_IN)
            wr_ptr <= 7'd0;
        else if (ROM_WE_IN) begin
            buf_mem[wr_ptr] <= {ROM_ADDR_IN, ROM_DATA_IN};
            wr_ptr <= wr_ptr + 7'd1;
        end
    end

    wire buf_empty = (wr_ptr == rd_ptr);

    // ----------------------------------------------------------------
    // Tick generator: one tick per I2C quarter-period
    // ----------------------------------------------------------------
    reg [15:0] div_cnt = 16'd0;
    reg        tick    = 1'b0;

    always @(posedge SYSCLK_IN) begin
        if (RESET_IN) begin
            div_cnt <= 16'd0;
            tick    <= 1'b0;
        end else if (div_cnt == (CLK_DIVIDER - 1)) begin
            div_cnt <= 16'd0;
            tick    <= 1'b1;
        end else begin
            div_cnt <= div_cnt + 16'd1;
            tick    <= 1'b0;
        end
    end

    // ----------------------------------------------------------------
    // Bit-level I2C engine
    // (identical to verified i2c_eeprom_master bit engine)
    // ----------------------------------------------------------------
    localparam [4:0]
        BS_IDLE      = 5'd0,
        BS_STA_A     = 5'd1,
        BS_STA_HOLD  = 5'd19,   // extra tick: SCL=1,SDA=1 for tSU;STA/tBUF
        BS_STA_B     = 5'd2,
        BS_STA_C     = 5'd3,
        BS_STO_A     = 5'd4,
        BS_STO_B     = 5'd5,
        BS_STO_C     = 5'd6,
        BS_TX_SETUP  = 5'd7,
        BS_TX_HIGH   = 5'd8,
        BS_TX_HOLD   = 5'd9,
        BS_ACK_SETUP = 5'd10,
        BS_ACK_HIGH  = 5'd11,
        BS_ACK_HOLD  = 5'd12;

    localparam [1:0]
        CMD_NONE  = 2'd0,
        CMD_START = 2'd1,
        CMD_STOP  = 2'd2,
        CMD_SEND  = 2'd3;

    reg [4:0] bs      = BS_IDLE;
    reg [1:0] bcmd    = CMD_NONE;
    reg       breq    = 1'b0;
    reg       bbusy   = 1'b0;
    reg       bdone   = 1'b0;
    reg       back_ok = 1'b0;
    reg [7:0] btx     = 8'h00;
    reg [7:0] bshift  = 8'h00;
    reg [2:0] bcnt    = 3'd0;
    reg       scl_low = 1'b0;
    reg       sda_low = 1'b0;

    assign SCL_DRIVE_LOW = scl_low;
    assign SDA_DRIVE_LOW = sda_low;

    always @(posedge SYSCLK_IN) begin
        if (RESET_IN) begin
            bs      <= BS_IDLE;
            bbusy   <= 1'b0;
            bdone   <= 1'b0;
            back_ok <= 1'b0;
            scl_low <= 1'b0;
            sda_low <= 1'b0;
        end else begin
            bdone <= 1'b0;

            if (!bbusy && breq) begin
                bbusy <= 1'b1;
                case (bcmd)
                    CMD_START: bs <= BS_STA_A;
                    CMD_STOP:  bs <= BS_STO_A;
                    CMD_SEND: begin
                        bshift <= btx;
                        bcnt   <= 3'd7;
                        bs     <= BS_TX_SETUP;
                    end
                    default: begin bbusy <= 1'b0; bs <= BS_IDLE; end
                endcase
            end else if (bbusy && tick) begin
                case (bs)
                    BS_STA_A:    begin scl_low<=1'b0; sda_low<=1'b0; bs<=BS_STA_HOLD; end
                    BS_STA_HOLD: bs <= BS_STA_B;
                    BS_STA_B:    begin scl_low<=1'b0; sda_low<=1'b1; bs<=BS_STA_C; end
                    BS_STA_C:    begin scl_low<=1'b1; sda_low<=1'b1; bs<=BS_IDLE; bbusy<=1'b0; bdone<=1'b1; end
                    BS_STO_A:    begin scl_low<=1'b1; sda_low<=1'b1; bs<=BS_STO_B; end
                    BS_STO_B:    begin scl_low<=1'b0; sda_low<=1'b1; bs<=BS_STO_C; end
                    BS_STO_C:    begin scl_low<=1'b0; sda_low<=1'b0; bs<=BS_IDLE; bbusy<=1'b0; bdone<=1'b1; end
                    BS_TX_SETUP: begin scl_low<=1'b1; sda_low<=~bshift[7]; bs<=BS_TX_HIGH; end
                    BS_TX_HIGH:  begin scl_low<=1'b0; bs<=BS_TX_HOLD; end
                    BS_TX_HOLD:  begin
                        scl_low <= 1'b1;
                        bshift  <= {bshift[6:0], 1'b0};
                        if (bcnt == 3'd0)
                            bs <= BS_ACK_SETUP;
                        else begin
                            bcnt <= bcnt - 3'd1;
                            bs   <= BS_TX_SETUP;
                        end
                    end
                    BS_ACK_SETUP: begin scl_low<=1'b1; sda_low<=1'b0; bs<=BS_ACK_HIGH; end
                    BS_ACK_HIGH:  begin scl_low<=1'b0; bs<=BS_ACK_HOLD; end
                    BS_ACK_HOLD:  begin
                        back_ok <= (SDA_IN == 1'b0);
                        scl_low <= 1'b1;
                        bs      <= BS_IDLE;
                        bbusy   <= 1'b0;
                        bdone   <= 1'b1;
                    end
                    default: begin bs <= BS_IDLE; bbusy <= 1'b0; end
                endcase
            end
        end
    end

    // ----------------------------------------------------------------
    // High-level FSM
    // ----------------------------------------------------------------
    localparam [4:0]
        HL_IDLE        = 5'd0,
        HL_STA         = 5'd1,  HL_STA_W        = 5'd2,
        HL_CTRL        = 5'd3,  HL_CTRL_W       = 5'd4,
        HL_WADDR       = 5'd5,  HL_WADDR_W      = 5'd6,
        HL_DATA        = 5'd7,  HL_DATA_W       = 5'd8,
        HL_STO         = 5'd9,  HL_STO_W        = 5'd10,
        HL_POLL_STA    = 5'd11, HL_POLL_STA_W   = 5'd12,
        HL_POLL_CTRL   = 5'd13, HL_POLL_CTRL_W  = 5'd14,
        HL_POLL_STO    = 5'd15, HL_POLL_STO_W   = 5'd16,
        HL_NEXT        = 5'd17,
        HL_ERR         = 5'd18;

    reg [4:0]  hl       = HL_IDLE;
    reg [15:0] poll_cnt = 16'd0;
    reg [7:0]  l_ctrl   = 8'h00;
    reg [7:0]  l_addr   = 8'h00;
    reg [7:0]  l_data   = 8'h00;
    reg        started  = 1'b0;   // at least one entry has been processed
    reg        err_latch = 1'b0;

    always @(posedge SYSCLK_IN) begin
        if (RESET_IN) begin
            hl        <= HL_IDLE;
            rd_ptr    <= 7'd0;
            started   <= 1'b0;
            err_latch <= 1'b0;
            DONE_OUT  <= 1'b0;
            ERROR_OUT <= 1'b0;
            breq      <= 1'b0;
            bcmd      <= CMD_NONE;
            btx       <= 8'h00;
        end else begin
            breq <= 1'b0;

            case (hl)
                HL_IDLE: begin
                    if (!buf_empty) begin
                        // latch current entry (distributed RAM: combinatorial read)
                        l_ctrl    <= 8'hA0 | {6'd0, buf_mem[rd_ptr][16], 1'b0};
                        l_addr    <= buf_mem[rd_ptr][15:8];
                        l_data    <= buf_mem[rd_ptr][7:0];
                        started   <= 1'b1;
                        err_latch <= 1'b0;
                        DONE_OUT  <= 1'b0;
                        hl        <= HL_STA;
                    end else if (started) begin
                        DONE_OUT <= 1'b1;
                    end
                end

                // START
                HL_STA:   if (!bbusy) begin bcmd<=CMD_START; breq<=1'b1; hl<=HL_STA_W; end
                HL_STA_W: if (bdone) hl <= HL_CTRL;

                // Send control byte (write direction)
                HL_CTRL:   if (!bbusy) begin bcmd<=CMD_SEND; btx<=l_ctrl; breq<=1'b1; hl<=HL_CTRL_W; end
                HL_CTRL_W: if (bdone) begin
                    if (!back_ok) begin err_latch<=1'b1; hl<=HL_STO; end
                    else hl <= HL_WADDR;
                end

                // Send word address
                HL_WADDR:   if (!bbusy) begin bcmd<=CMD_SEND; btx<=l_addr; breq<=1'b1; hl<=HL_WADDR_W; end
                HL_WADDR_W: if (bdone) begin
                    if (!back_ok) begin err_latch<=1'b1; hl<=HL_STO; end
                    else hl <= HL_DATA;
                end

                // Send data
                HL_DATA:   if (!bbusy) begin bcmd<=CMD_SEND; btx<=l_data; breq<=1'b1; hl<=HL_DATA_W; end
                HL_DATA_W: if (bdone) begin
                    if (!back_ok) err_latch <= 1'b1;
                    hl <= HL_STO;
                end

                // STOP
                HL_STO:   if (!bbusy) begin bcmd<=CMD_STOP; breq<=1'b1; hl<=HL_STO_W; end
                HL_STO_W: if (bdone) begin
                    if (err_latch) hl <= HL_ERR;
                    else begin poll_cnt <= 16'd0; hl <= HL_POLL_STA; end
                end

                // ACK polling: wait for EEPROM internal write cycle (~5ms max)
                HL_POLL_STA: if (!bbusy) begin
                    if (poll_cnt >= ACK_POLL_MAX[15:0]) begin
                        err_latch <= 1'b1;
                        hl <= HL_ERR;
                    end else begin
                        poll_cnt <= poll_cnt + 16'd1;
                        bcmd <= CMD_START; breq <= 1'b1;
                        hl <= HL_POLL_STA_W;
                    end
                end
                HL_POLL_STA_W:  if (bdone) hl <= HL_POLL_CTRL;
                HL_POLL_CTRL:   if (!bbusy) begin bcmd<=CMD_SEND; btx<=l_ctrl; breq<=1'b1; hl<=HL_POLL_CTRL_W; end
                HL_POLL_CTRL_W: if (bdone) hl <= HL_POLL_STO;
                HL_POLL_STO:    if (!bbusy) begin bcmd<=CMD_STOP; breq<=1'b1; hl<=HL_POLL_STO_W; end
                HL_POLL_STO_W:  if (bdone) begin
                    if (back_ok) hl <= HL_NEXT;   // EEPROM ACKed: write done
                    else         hl <= HL_POLL_STA; // still busy: retry
                end

                HL_NEXT: begin
                    rd_ptr <= rd_ptr + 7'd1;
                    hl     <= HL_IDLE;
                end

                HL_ERR: begin
                    ERROR_OUT <= 1'b1;
                    rd_ptr    <= rd_ptr + 7'd1;   // skip bad entry, continue
                    hl        <= HL_IDLE;
                end

                default: hl <= HL_IDLE;
            endcase
        end
    end

endmodule
