// clk_freq_counter.v
// Measures the frequency of clk_meas by counting its rising edges over a
// fixed window of 2^17 cycles of clk_ref (100 MHz → ~1.31 ms window).
// At 200 MHz input the count saturates near 262144 (18'h40000).
// Result is latched into count_out when done=1 (one clk_ref pulse).
//
// Usage: clk_ref = mb_clk (100 MHz), clk_meas = clk_ab (single-ended from IBUFDS)

module clk_freq_counter (
    input  wire        clk_ref,     // reference clock (100 MHz mb_clk)
    input  wire        clk_meas,    // clock to measure (clk_ab single-ended)
    input  wire        rst,         // synchronous reset (active-high, clk_ref domain)
    output reg  [19:0] count_out,   // measured count, stable between 'done' pulses
    output reg         done         // 1-cycle pulse when count_out is updated
);

    // -----------------------------------------------------------------------
    // Window counter in clk_ref domain: 2^17 = 131072 cycles @ 100 MHz ≈ 1.31 ms
    // -----------------------------------------------------------------------
    localparam WINDOW_BITS = 17;
    reg [WINDOW_BITS-1:0] window_cnt;
    reg                   window_done;

    always @(posedge clk_ref) begin
        if (rst) begin
            window_cnt  <= 0;
            window_done <= 0;
        end else begin
            window_done <= (window_cnt == {WINDOW_BITS{1'b1}});
            window_cnt  <= window_cnt + 1;
        end
    end

    // -----------------------------------------------------------------------
    // Edge detector for clk_meas, synchronised into clk_ref domain
    // (two-FF synchroniser on a toggle signal)
    // -----------------------------------------------------------------------
    reg toggle_meas;  // clk_meas domain
    always @(posedge clk_meas) toggle_meas <= ~toggle_meas;

    reg sync0, sync1, sync2;
    always @(posedge clk_ref) begin
        sync0 <= toggle_meas;
        sync1 <= sync0;
        sync2 <= sync1;
    end
    wire meas_edge = sync1 ^ sync2;  // 1 each time clk_meas had a rising edge

    // -----------------------------------------------------------------------
    // Count edges during window
    // -----------------------------------------------------------------------
    reg [19:0] accum;

    always @(posedge clk_ref) begin
        if (rst) begin
            accum     <= 0;
            count_out <= 0;
            done      <= 0;
        end else begin
            done <= 0;
            if (window_done) begin
                count_out <= accum;
                done      <= 1;
                accum     <= meas_edge ? 1 : 0;
            end else begin
                if (meas_edge)
                    accum <= accum + 1;
            end
        end
    end

endmodule
