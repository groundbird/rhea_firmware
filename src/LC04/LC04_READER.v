`timescale 1ns / 1ps
//-------------------------------------------------------------------//
//  Module      : LC04_READER
//  Description : 24LC04 sequential reader.
//                Reads NUM_BYTES bytes starting from START_ADDR and
//                writes results to an external memory interface.
//                Open-drain model: SCL_DRIVE_LOW / SDA_DRIVE_LOW.
//
//  24LC04 sequential read sequence per block segment:
//    START -> ctrl_write (0xA0|block<<1) -> word_addr[7:0]
//          -> RESTART -> ctrl_read (0xA1|block<<1)
//          -> [read, ACK] x (N-1) -> [read, NACK] -> STOP
//
//  Block boundary (0x00/0x100): a new transaction is started
//  automatically when the address wraps to the next block.
//
//  Parameters:
//    CLK_DIVIDER : SYSCLK cycles per I2C bit quarter-period
//                  e.g. 250 -> 400kHz at 100MHz SYSCLK
//    NUM_BYTES   : total bytes to read (1..512)
//    START_ADDR  : 9-bit start address {block[8], word[7:0]}
//-------------------------------------------------------------------//

module LC04_READER #(
    parameter integer CLK_DIVIDER = 250,
    parameter integer NUM_BYTES   = 128,
    parameter integer START_ADDR  = 0,
    // Transactions to attempt before giving up on an unresponsive EEPROM.
    // Without a bound, a board with no ACK keeps SITCP_RESET_OUT asserted
    // forever, which holds the whole design in reset with no way to tell why.
    parameter integer RETRY_MAX   = 8
) (
    input  wire        SYSCLK_IN,
    input  wire        RESET_IN,

    // --- I2C open-drain ---
    // Connect to IOBUF: .I(1'b0), .T(~DRIVE_LOW)
    output wire        SCL_DRIVE_LOW,
    output wire        SDA_DRIVE_LOW,
    input  wire        SDA_IN,

    // --- memory output (compatible with M24_READER) ---
    output reg         MEM_WE_OUT,
    output reg  [8:0]  MEM_ADDR_OUT,
    output reg  [7:0]  MEM_DIN_OUT,

    // SITCP_RESET_OUT: 1=SiTCP in reset, 0=released (same polarity as M24_READER)
    output wire        SITCP_RESET_OUT,

    output reg         DONE_OUT,
    output reg         ERROR_OUT
);

    // SITCP stays in reset until reading completes
    assign SITCP_RESET_OUT = RESET_IN | ~DONE_OUT;

    // ----------------------------------------------------------------
    // Tick generator: one tick per I2C bit quarter-period
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
        BS_IDLE        = 5'd0,
        BS_STA_A       = 5'd1,
        BS_STA_HOLD    = 5'd19,   // extra tick for tSU;STA / tBUF >= 4.7us
        BS_STA_B       = 5'd2,
        BS_STA_C       = 5'd3,
        BS_STO_A       = 5'd4,
        BS_STO_B       = 5'd5,
        BS_STO_C       = 5'd6,
        BS_TX_SETUP    = 5'd7,
        BS_TX_HIGH     = 5'd8,
        BS_TX_HOLD     = 5'd9,
        BS_ACK_SETUP   = 5'd10,
        BS_ACK_HIGH    = 5'd11,
        BS_ACK_HOLD    = 5'd12,
        BS_RX_SETUP    = 5'd13,
        BS_RX_HIGH     = 5'd14,
        BS_RX_HOLD     = 5'd15,
        BS_RXACK_SETUP = 5'd16,
        BS_RXACK_HIGH  = 5'd17,
        BS_RXACK_HOLD  = 5'd18;

    localparam [2:0]
        CMD_NONE  = 3'd0,
        CMD_START = 3'd1,
        CMD_STOP  = 3'd2,
        CMD_SEND  = 3'd3,
        CMD_READ  = 3'd4;

    reg [4:0] bs        = BS_IDLE;
    reg [2:0] bcmd      = CMD_NONE;
    reg       breq      = 1'b0;
    reg       bbusy     = 1'b0;
    reg       bdone     = 1'b0;
    reg       back_ok   = 1'b0;
    reg [7:0] btx       = 8'h00;
    reg [7:0] bshift    = 8'h00;
    reg [7:0] brx       = 8'h00;
    reg [2:0] bcnt      = 3'd0;
    reg       send_nack = 1'b0;  // 1=NACK (last byte), 0=ACK (more bytes)
    reg       scl_low   = 1'b0;
    reg       sda_low   = 1'b0;

    assign SCL_DRIVE_LOW = scl_low;
    assign SDA_DRIVE_LOW = sda_low;

    always @(posedge SYSCLK_IN) begin
        if (RESET_IN) begin
            bs      <= BS_IDLE;
            bbusy   <= 1'b0;
            bdone   <= 1'b0;
            back_ok <= 1'b0;
            brx     <= 8'h00;
            scl_low <= 1'b0;
            sda_low <= 1'b0;
        end else begin
            bdone <= 1'b0;

            if (!bbusy && breq) begin
                bbusy <= 1'b1;
                case (bcmd)
                    CMD_START: bs <= BS_STA_A;
                    CMD_STOP:  bs <= BS_STO_A;
                    CMD_SEND: begin bshift<=btx; bcnt<=3'd7; bs<=BS_TX_SETUP; end
                    CMD_READ: begin bshift<=8'h00; bcnt<=3'd7; bs<=BS_RX_SETUP; end
                    default:   begin bbusy<=1'b0; bs<=BS_IDLE; end
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
                        if (bcnt == 3'd0) bs <= BS_ACK_SETUP;
                        else begin bcnt<=bcnt-3'd1; bs<=BS_TX_SETUP; end
                    end
                    BS_ACK_SETUP: begin scl_low<=1'b1; sda_low<=1'b0; bs<=BS_ACK_HIGH; end
                    BS_ACK_HIGH:  begin scl_low<=1'b0; bs<=BS_ACK_HOLD; end
                    BS_ACK_HOLD:  begin
                        back_ok <= (SDA_IN == 1'b0);
                        scl_low <= 1'b1;
                        bs <= BS_IDLE; bbusy<=1'b0; bdone<=1'b1;
                    end
                    BS_RX_SETUP:    begin scl_low<=1'b1; sda_low<=1'b0; bs<=BS_RX_HIGH; end
                    BS_RX_HIGH:     begin scl_low<=1'b0; bs<=BS_RX_HOLD; end
                    BS_RX_HOLD:     begin
                        scl_low <= 1'b1;
                        bshift  <= {bshift[6:0], SDA_IN};
                        if (bcnt == 3'd0) bs <= BS_RXACK_SETUP;
                        else begin bcnt<=bcnt-3'd1; bs<=BS_RX_SETUP; end
                    end
                    BS_RXACK_SETUP: begin
                        scl_low <= 1'b1;
                        sda_low <= ~send_nack;  // NACK=release(0), ACK=drive-low(1)
                        bs <= BS_RXACK_HIGH;
                    end
                    BS_RXACK_HIGH:  begin scl_low<=1'b0; bs<=BS_RXACK_HOLD; end
                    BS_RXACK_HOLD:  begin
                        scl_low <= 1'b1;
                        sda_low <= 1'b0;
                        brx     <= bshift;
                        bs <= BS_IDLE; bbusy<=1'b0; bdone<=1'b1;
                    end
                    default: begin bs<=BS_IDLE; bbusy<=1'b0; end
                endcase
            end
        end
    end

    // ----------------------------------------------------------------
    // High-level FSM
    // ----------------------------------------------------------------
    localparam [3:0]
        HL_IDLE      = 4'd0,
        HL_STA       = 4'd1,  HL_STA_W      = 4'd2,
        HL_CTRLW     = 4'd3,  HL_CTRLW_W    = 4'd4,
        HL_WADDR     = 4'd5,  HL_WADDR_W    = 4'd6,
        HL_RESTART   = 4'd7,  HL_RESTART_W  = 4'd8,
        HL_CTRLR     = 4'd9,  HL_CTRLR_W    = 4'd10,
        HL_RXBYTE    = 4'd11, HL_RXBYTE_W   = 4'd12,
        HL_STO       = 4'd13, HL_STO_W      = 4'd14,
        HL_DONE      = 4'd15;

    reg [3:0]  hl         = HL_IDLE;
    reg [8:0]  cur_addr   = START_ADDR[8:0];
    reg [9:0]  bytes_left = NUM_BYTES[9:0];
    reg [7:0]  retry_cnt  = 8'd0;

    // Is this the last byte to read overall?
    wire is_last_overall = (bytes_left == 10'd1);
    // Is this the last address in the current 24LC04 block?
    wire is_block_end    = (cur_addr[7:0] == 8'hFF);

    always @(posedge SYSCLK_IN) begin
        if (RESET_IN) begin
            hl           <= HL_IDLE;
            cur_addr     <= START_ADDR[8:0];
            bytes_left   <= NUM_BYTES[9:0];
            DONE_OUT     <= 1'b0;
            ERROR_OUT    <= 1'b0;
            MEM_WE_OUT   <= 1'b0;
            MEM_ADDR_OUT <= 9'd0;
            MEM_DIN_OUT  <= 8'd0;
            breq         <= 1'b0;
            bcmd         <= CMD_NONE;
            btx          <= 8'h00;
            send_nack    <= 1'b0;
            retry_cnt    <= 8'd0;
        end else begin
            breq       <= 1'b0;
            MEM_WE_OUT <= 1'b0;

            case (hl)
                HL_IDLE: begin
                    // Give up once the EEPROM has failed to answer RETRY_MAX
                    // times: DONE releases SiTCP, ERROR stays latched so the
                    // failure is visible over VIO / RBCP.
                    if (bytes_left == 10'd0)          hl <= HL_DONE;
                    else if (retry_cnt >= RETRY_MAX[7:0]) hl <= HL_DONE;
                    else                              hl <= HL_STA;
                end

                // START
                HL_STA:   if (!bbusy) begin
                    bcmd <= CMD_START; breq <= 1'b1; hl <= HL_STA_W;
                end
                HL_STA_W: if (bdone) hl <= HL_CTRLW;

                // Send control byte (write direction, to set word address)
                HL_CTRLW: if (!bbusy) begin
                    bcmd <= CMD_SEND;
                    btx  <= 8'hA0 | {6'd0, cur_addr[8], 1'b0};
                    breq <= 1'b1;
                    hl   <= HL_CTRLW_W;
                end
                HL_CTRLW_W: if (bdone) begin
                    if (!back_ok) begin ERROR_OUT<=1'b1; retry_cnt<=retry_cnt+8'd1; hl<=HL_STO; end
                    else hl <= HL_WADDR;
                end

                // Send word address
                HL_WADDR: if (!bbusy) begin
                    bcmd <= CMD_SEND;
                    btx  <= cur_addr[7:0];
                    breq <= 1'b1;
                    hl   <= HL_WADDR_W;
                end
                HL_WADDR_W: if (bdone) begin
                    if (!back_ok) begin ERROR_OUT<=1'b1; retry_cnt<=retry_cnt+8'd1; hl<=HL_STO; end
                    else hl <= HL_RESTART;
                end

                // Repeated START (switch to read direction)
                HL_RESTART:   if (!bbusy) begin bcmd<=CMD_START; breq<=1'b1; hl<=HL_RESTART_W; end
                HL_RESTART_W: if (bdone) hl <= HL_CTRLR;

                // Send control byte (read direction)
                HL_CTRLR: if (!bbusy) begin
                    bcmd <= CMD_SEND;
                    btx  <= 8'hA1 | {6'd0, cur_addr[8], 1'b0};
                    breq <= 1'b1;
                    hl   <= HL_CTRLR_W;
                end
                HL_CTRLR_W: if (bdone) begin
                    if (!back_ok) begin ERROR_OUT<=1'b1; retry_cnt<=retry_cnt+8'd1; hl<=HL_STO; end
                    else hl <= HL_RXBYTE;
                end

                // Receive bytes sequentially
                HL_RXBYTE: if (!bbusy) begin
                    // NACK if: last byte overall OR last byte in this block
                    send_nack <= is_last_overall || is_block_end;
                    bcmd      <= CMD_READ;
                    breq      <= 1'b1;
                    hl        <= HL_RXBYTE_W;
                end
                HL_RXBYTE_W: if (bdone) begin
                    retry_cnt    <= 8'd0;   // progress: forgive earlier retries
                    MEM_WE_OUT   <= 1'b1;
                    MEM_ADDR_OUT <= cur_addr;
                    MEM_DIN_OUT  <= brx;
                    bytes_left   <= bytes_left - 10'd1;
                    cur_addr     <= cur_addr + 9'd1;

                    if (is_last_overall) begin
                        // All bytes read: STOP then DONE
                        hl <= HL_STO;
                    end else if (is_block_end) begin
                        // End of block: STOP then start new transaction for next block
                        hl <= HL_STO;
                    end else begin
                        // More bytes in this block: continue reading
                        hl <= HL_RXBYTE;
                    end
                end

                // STOP
                HL_STO:   if (!bbusy) begin bcmd<=CMD_STOP; breq<=1'b1; hl<=HL_STO_W; end
                HL_STO_W: if (bdone) begin
                    // Go back to IDLE; IDLE checks bytes_left to decide done vs next block
                    hl <= HL_IDLE;
                end

                HL_DONE: begin
                    DONE_OUT <= 1'b1;
                    // Stay here forever (re-read requires RESET_IN)
                end

                default: hl <= HL_IDLE;
            endcase
        end
    end

endmodule
