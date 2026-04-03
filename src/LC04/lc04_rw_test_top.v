`timescale 1ns / 1ps
//-------------------------------------------------------------------//
//  Module      : lc04_rw_test_top
//  Description : Standalone write/read verification for LC04_WRITER
//                and LC04_READER on AXKU042.
//
//  Test sequence:
//    1. Startup delay (2 ms) for 24LC04 power-up
//    2. Write 64 bytes to addresses 0x00-0x3F
//         pattern: data[i] = i ^ 0xA5
//    3. Wait for LC04_WRITER DONE
//    4. Release LC04_READER reset; reader reads 64 bytes sequentially
//    5. Compare each byte with expected pattern
//    6. Display result on LEDs and ILA
//
//  LEDs:
//    [0] : Startup / write phase in progress (1=busy, 0=done)
//    [1] : Write complete (latched)
//    [2] : Read complete (latched)
//    [3] : PASS (1=all bytes match, 0=error or mismatch)
//
//  I2C clock: ~100 kHz  (CLK_DIVIDER=500 at 200 MHz)
//  Total test time: ~10 ms (write 64x + read 64x at 100 kHz I2C)
//-------------------------------------------------------------------//

module lc04_rw_test_top (
    input  wire       PL_CLK0_P,
    input  wire       PL_CLK0_N,
    input  wire       ext_resetn,   // active-low push-button reset
    inout  wire       iic_sda,
    inout  wire       iic_scl,
    output wire [3:0] user_led
);

    // ----------------------------------------------------------------
    // System clock: 200 MHz differential input
    // ----------------------------------------------------------------
    wire clk;

    IBUFDS #(
        .DIFF_TERM   ("FALSE"),
        .IBUF_LOW_PWR("FALSE"),
        .IOSTANDARD  ("LVDS" )
    ) u_ibufds (
        .I (PL_CLK0_P),
        .IB(PL_CLK0_N),
        .O (clk       )
    );

    // ----------------------------------------------------------------
    // Reset synchronizer (active-high internal reset)
    // ----------------------------------------------------------------
    reg rst_p0 = 1'b1, rst_p1 = 1'b1;
    always @(posedge clk or negedge ext_resetn) begin
        if (!ext_resetn) begin
            rst_p0 <= 1'b1;
            rst_p1 <= 1'b1;
        end else begin
            rst_p0 <= 1'b0;
            rst_p1 <= rst_p0;
        end
    end
    wire rst = rst_p1;

    // ----------------------------------------------------------------
    // Startup delay: 2 ms at 200 MHz = 400 000 cycles
    // ----------------------------------------------------------------
    localparam integer STARTUP_CYCLES = 400_000;

    reg [19:0] startup_cnt  = 20'd0;
    reg        startup_done = 1'b0;

    always @(posedge clk) begin
        if (rst) begin
            startup_cnt  <= 20'd0;
            startup_done <= 1'b0;
        end else if (!startup_done) begin
            if (startup_cnt == STARTUP_CYCLES - 1)
                startup_done <= 1'b1;
            else
                startup_cnt <= startup_cnt + 20'd1;
        end
    end

    // lc04_rst: held high during system reset AND startup delay
    wire lc04_rst = rst | ~startup_done;

    // ----------------------------------------------------------------
    // I2C open-drain IOBUF
    //   IOBUF: I=0 (always drive 0), T=1→high-Z, T=0→drive low
    // ----------------------------------------------------------------
    wire scl_drive_low, sda_drive_low;
    wire scl_in, sda_in;

    wire scl_r_low, sda_r_low;   // from LC04_READER
    wire scl_w_low, sda_w_low;   // from LC04_WRITER

    assign scl_drive_low = scl_r_low | scl_w_low;
    assign sda_drive_low = sda_r_low | sda_w_low;

    IOBUF u_iobuf_scl (
        .I (1'b0            ),
        .IO(iic_scl         ),
        .O (scl_in          ),
        .T (~scl_drive_low  )
    );
    IOBUF u_iobuf_sda (
        .I (1'b0            ),
        .IO(iic_sda         ),
        .O (sda_in          ),
        .T (~sda_drive_low  )
    );

    // ----------------------------------------------------------------
    // Test parameters
    // ----------------------------------------------------------------
    localparam integer TEST_BYTES   = 64;       // bytes to write and read
    localparam integer CLK_DIV      = 500;      // 200 MHz / (4 * 500) = 100 kHz I2C
    localparam integer ACK_POLL_MAX = 500;

    // ----------------------------------------------------------------
    // Test FSM
    // ----------------------------------------------------------------
    localparam [2:0]
        TS_RESET   = 3'd0,
        TS_STARTUP = 3'd1,
        TS_WR_PUSH = 3'd2,    // push TEST_BYTES entries to writer buffer
        TS_WR_WAIT = 3'd3,    // wait for WRITER DONE
        TS_RD_WAIT = 3'd4,    // wait for READER DONE
        TS_DONE    = 3'd5;

    (* mark_debug = "true" *) reg [2:0] ts = TS_RESET;
    (* mark_debug = "true" *) reg [6:0] wr_idx = 7'd0;     // current push index

    reg       wr_push        = 1'b0;   // single-cycle ROM_WE_IN pulse
    reg       reader_release = 1'b0;   // 1 = release reader from reset

    wire writer_done, writer_error;
    wire reader_done, reader_error;

    always @(posedge clk) begin
        if (rst) begin
            ts             <= TS_RESET;
            wr_idx         <= 7'd0;
            wr_push        <= 1'b0;
            reader_release <= 1'b0;
        end else begin
            wr_push <= 1'b0;   // default: no push

            case (ts)
                TS_RESET: begin
                    ts <= TS_STARTUP;
                end

                TS_STARTUP: begin
                    if (startup_done) ts <= TS_WR_PUSH;
                end

                // Push one entry per clock cycle into LC04_WRITER buffer.
                // TEST_BYTES = 64 < buffer depth 128, so no wrap-around.
                TS_WR_PUSH: begin
                    wr_push <= 1'b1;
                    if (wr_idx == TEST_BYTES[6:0] - 7'd1) begin
                        ts <= TS_WR_WAIT;   // last entry pushed this cycle
                    end else begin
                        wr_idx <= wr_idx + 7'd1;
                    end
                end

                TS_WR_WAIT: begin
                    if (writer_done) begin
                        reader_release <= 1'b1;
                        ts <= TS_RD_WAIT;
                    end
                end

                TS_RD_WAIT: begin
                    if (reader_done) ts <= TS_DONE;
                end

                TS_DONE: begin
                    // Remain here; LEDs show final result
                end

                default: ts <= TS_RESET;
            endcase
        end
    end

    // ----------------------------------------------------------------
    // LC04_WRITER
    //   ROM_WE_IN   : single-cycle pulse from test FSM
    //   ROM_ADDR_IN : {2'b00, wr_idx}  (block 0, word address 0-63)
    //   ROM_DATA_IN : wr_idx ^ 0xA5
    // ----------------------------------------------------------------
    LC04_WRITER #(
        .CLK_DIVIDER  (CLK_DIV      ),
        .ACK_POLL_MAX (ACK_POLL_MAX )
    ) u_writer (
        .SYSCLK_IN     (clk                     ),
        .RESET_IN      (lc04_rst                ),
        .ROM_WE_IN     (wr_push                 ),
        .ROM_ADDR_IN   ({2'b00, wr_idx}         ),
        .ROM_DATA_IN   ({1'b0, wr_idx} ^ 8'hA5 ),
        .SCL_DRIVE_LOW (scl_w_low               ),
        .SDA_DRIVE_LOW (sda_w_low               ),
        .SDA_IN        (sda_in                  ),
        .DONE_OUT      (writer_done             ),
        .ERROR_OUT     (writer_error            )
    );

    // ----------------------------------------------------------------
    // LC04_READER
    //   Held in reset until writer completes (reader_rst deasserts
    //   only when lc04_rst=0 AND reader_release=1).
    // ----------------------------------------------------------------
    wire reader_rst = lc04_rst | ~reader_release;

    wire       rd_we;
    wire [8:0] rd_addr;
    wire [7:0] rd_din;

    LC04_READER #(
        .CLK_DIVIDER (CLK_DIV   ),
        .NUM_BYTES   (TEST_BYTES),
        .START_ADDR  (0         )
    ) u_reader (
        .SYSCLK_IN      (clk         ),
        .RESET_IN       (reader_rst  ),
        .SCL_DRIVE_LOW  (scl_r_low   ),
        .SDA_DRIVE_LOW  (sda_r_low   ),
        .SDA_IN         (sda_in      ),
        .MEM_WE_OUT     (rd_we       ),
        .MEM_ADDR_OUT   (rd_addr     ),
        .MEM_DIN_OUT    (rd_din      ),
        .SITCP_RESET_OUT(            ),
        .DONE_OUT       (reader_done ),
        .ERROR_OUT      (reader_error)
    );

    // ----------------------------------------------------------------
    // Verification
    //   On each MEM_WE_OUT from reader, compare rd_din with expected.
    //   expected[i] = i ^ 0xA5  (same pattern as written above)
    // ----------------------------------------------------------------
    (* mark_debug = "true" *) reg        mismatch     = 1'b0;
    (* mark_debug = "true" *) reg [6:0]  match_count  = 7'd0;  // counts 0..64

    wire [7:0] rd_expected = rd_addr[7:0] ^ 8'hA5;

    always @(posedge clk) begin
        if (reader_rst) begin
            mismatch    <= 1'b0;
            match_count <= 7'd0;
        end else if (rd_we) begin
            if (rd_din != rd_expected)
                mismatch <= 1'b1;
            match_count <= match_count + 7'd1;
        end
    end

    // ----------------------------------------------------------------
    // LED output
    // ----------------------------------------------------------------
    // Latch "write complete" and "read complete" for stable LED display
    reg wr_done_latch = 1'b0;
    reg rd_done_latch = 1'b0;
    always @(posedge clk) begin
        if (rst) begin wr_done_latch<=0; rd_done_latch<=0; end
        else begin
            if (writer_done) wr_done_latch <= 1'b1;
            if (reader_done) rd_done_latch <= 1'b1;
        end
    end

    wire pass = rd_done_latch & ~mismatch & ~writer_error & ~reader_error;

    assign user_led[0] = ~wr_done_latch;   // 1=write in progress, 0=done
    assign user_led[1] = wr_done_latch;    // 1=write complete
    assign user_led[2] = rd_done_latch;    // 1=read complete
    assign user_led[3] = pass;             // 1=PASS, 0=FAIL (or not yet done)

    // ----------------------------------------------------------------
    // ILA debug signals (mark_debug)
    // ----------------------------------------------------------------
    (* mark_debug = "true" *) wire dbg_scl     = scl_in;
    (* mark_debug = "true" *) wire dbg_sda     = sda_in;
    (* mark_debug = "true" *) wire dbg_scl_low = scl_drive_low;
    (* mark_debug = "true" *) wire dbg_sda_low = sda_drive_low;
    (* mark_debug = "true" *) wire dbg_wr_done = writer_done;
    (* mark_debug = "true" *) wire dbg_wr_err  = writer_error;
    (* mark_debug = "true" *) wire dbg_rd_done = reader_done;
    (* mark_debug = "true" *) wire dbg_rd_err  = reader_error;
    (* mark_debug = "true" *) wire        dbg_rd_we   = rd_we;
    (* mark_debug = "true" *) wire [8:0]  dbg_rd_addr = rd_addr;
    (* mark_debug = "true" *) wire [7:0]  dbg_rd_din  = rd_din;
    (* mark_debug = "true" *) wire [7:0]  dbg_rd_exp  = rd_expected;

endmodule
