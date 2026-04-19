// clk_freq_counter.v
//
// Measures the frequency of clk_meas by counting its rising edges during a
// fixed gate window generated in the clk_ref domain.
//
// Architecture
// ------------
//   clk_ref domain  : generates a periodic gate signal (2^17 cycles ≈ 1.31 ms)
//   clk_meas domain : counter increments every cycle while gate is high;
//                     latches result when gate falls
//   CDC (ref→meas)  : 2-FF synchronizer on gate signal
//   CDC (meas→ref)  : toggle-handshake on latch_valid pulse;
//                     meas_latch is stable >> 2 clk_ref cycles before being read
//
// Expected result at 200 MHz: ~262 144 counts per window.

module clk_freq_counter (
    input  wire        clk_ref,     // reference clock (100 MHz mb_clk)
    input  wire        clk_meas,    // clock to measure (clk_ab, single-ended)
    input  wire        rst,         // synchronous reset, clk_ref domain
    output reg  [19:0] count_out,   // measured count (clk_ref domain)
    output reg         done         // 1-cycle pulse when count_out is updated
);

    // -------------------------------------------------------------------------
    // clk_ref domain: measurement gate
    // Gate toggles every 2^17 clk_ref cycles → each high phase = 1.31 ms window
    // -------------------------------------------------------------------------
    localparam WINDOW_BITS = 17;

    reg [WINDOW_BITS-1:0] win_cnt;
    reg                   win_gate;

    always @(posedge clk_ref) begin
        if (rst) begin
            win_cnt  <= 0;
            win_gate <= 0;
        end else begin
            if (win_cnt == {WINDOW_BITS{1'b1}}) begin
                win_cnt  <= 0;
                win_gate <= ~win_gate;   // toggle: alternate active / idle
            end else begin
                win_cnt <= win_cnt + 1;
            end
        end
    end

    // -------------------------------------------------------------------------
    // CDC ref → meas: synchronize win_gate into clk_meas domain (2-FF + edge)
    // -------------------------------------------------------------------------
    (* ASYNC_REG = "TRUE" *) reg gate_s0, gate_s1;
    reg gate_s2;

    always @(posedge clk_meas) begin
        gate_s0 <= win_gate;
        gate_s1 <= gate_s0;
        gate_s2 <= gate_s1;
    end

    wire gate_rise = ( gate_s1) & (~gate_s2);   // window opened
    wire gate_fall = (~gate_s1) & ( gate_s2);   // window closed

    // -------------------------------------------------------------------------
    // clk_meas domain: counter and latch
    // -------------------------------------------------------------------------
    reg [19:0] meas_cnt;
    reg [19:0] meas_latch;
    reg        latch_valid;   // single-cycle pulse in clk_meas domain

    always @(posedge clk_meas) begin
        latch_valid <= 0;

        if (gate_rise) begin
            meas_cnt <= 0;
        end else if (gate_s1) begin
            meas_cnt <= meas_cnt + 1;
        end

        if (gate_fall) begin
            meas_latch  <= meas_cnt;
            latch_valid <= 1;
        end
    end

    // -------------------------------------------------------------------------
    // CDC meas → ref: toggle handshake
    // latch_valid is a 1-cycle pulse → toggle a flag → synchronize to clk_ref
    // meas_latch is stable for the entire idle phase (2^17 clk_meas cycles)
    // so reading it in clk_ref after the synchronizer delay is safe.
    // -------------------------------------------------------------------------
    reg latch_toggle;  // clk_meas domain

    always @(posedge clk_meas)
        if (latch_valid) latch_toggle <= ~latch_toggle;

    (* ASYNC_REG = "TRUE" *) reg tog_s0, tog_s1;
    reg tog_s2;

    always @(posedge clk_ref) begin
        tog_s0 <= latch_toggle;
        tog_s1 <= tog_s0;
        tog_s2 <= tog_s1;
    end

    wire new_data = tog_s1 ^ tog_s2;   // edge = new latch available

    always @(posedge clk_ref) begin
        done <= 0;
        if (rst) begin
            count_out <= 0;
        end else if (new_data) begin
            count_out <= meas_latch;   // stable: won't change for >> 2 ref cycles
            done      <= 1;
        end
    end

endmodule
