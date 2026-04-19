// rhea_debug_top.v
// Debug top-level for AXKU042 / rhea FMC board.
// Verifies:
//   1. clk_ab_p/n (200 MHz differential FMC clock) via MMCM lock + frequency counter
//   2. SPI communication with DAC3283 and ADS4249 via bit-bang GPIO
//
// MicroBlaze (with MDM JTAG-UART) is instantiated in the block design wrapper.
//
// GPIO channel 1 – OUTPUT (8-bit), driven by MicroBlaze:
//   [0] SCLK     → spi_sclk18
//   [1] MOSI     → spi_sdata18
//   [2] ADC_CS_N → adc_n_en18  (active-low)
//   [3] DAC_CS_N → dac_n_en18  (active-low)
//   [7:4] LEDs   → user_led[3:0]
//
// GPIO channel 2 – INPUT (24-bit), read by MicroBlaze:
//   [0]     ADC_SDO      ← adc_sdo18
//   [1]     DAC_SDO      ← dac_sdo18
//   [2]     CLK_LOCKED   ← MMCM locked on clk_ab
//   [23:3]  FREQ_COUNT   ← clk_freq_counter count_out[20:0] (21 bits)

`default_nettype none

module rhea_debug_top (
    // 200 MHz board clock (PL_CLK0)
    input  wire       sysclk_200MHz_p,
    input  wire       sysclk_200MHz_n,
    // Reset (active-low push button)
    input  wire       cpu_reset,
    // FMC 200 MHz differential clock from ADC board
    input  wire       clk_ab_p,
    input  wire       clk_ab_n,
    // SPI lines to DAC3283 and ADS4249
    output wire       spi_sclk18,
    output wire       spi_sdata18,
    input  wire       adc_sdo18,
    input  wire       dac_sdo18,
    output wire       adc_n_en18,   // ADC SPI CS (active-low)
    output wire       dac_n_en18,   // DAC SPI CS (active-low)
    // ADC hard-reset (deassert = run)
    output wire       adc_reset18,
    // DAC TX enable
    output wire       txenable18,
    // User LEDs
    output wire [3:0] user_led
);

    // -----------------------------------------------------------------------
    // clk_ab: differential → single-ended
    // -----------------------------------------------------------------------
    wire clk_ab_se;
    IBUFDS #(.DIFF_TERM("TRUE"), .IBUF_LOW_PWR("FALSE")) u_ibufds_ab (
        .I  (clk_ab_p),
        .IB (clk_ab_n),
        .O  (clk_ab_se)
    );

    // -----------------------------------------------------------------------
    // MMCM on clk_ab to check lock (200 MHz in → 200 MHz out, just for lock)
    // -----------------------------------------------------------------------
    wire clk_ab_locked;
    wire clk_ab_mmcm_out;  // unused, just need locked
    wire clk_ab_mmcm_fb;
    wire clk_ab_mmcm_fb_buf;
    wire clk_ab_mmcm_rst;

    assign clk_ab_mmcm_rst = ~cpu_reset;

    MMCME3_BASE #(
        .BANDWIDTH          ("OPTIMIZED"),
        .CLKFBOUT_MULT_F    (5.0),    // VCO = 200*5 = 1000 MHz
        .DIVCLK_DIVIDE      (1),
        .CLKOUT0_DIVIDE_F   (5.0),    // 1000/5 = 200 MHz
        .CLKIN1_PERIOD      (5.0),    // 200 MHz = 5 ns
        .STARTUP_WAIT       ("FALSE")
    ) u_mmcm_ab (
        .CLKIN1   (clk_ab_se),
        .CLKFBIN  (clk_ab_mmcm_fb_buf),
        .CLKOUT0  (clk_ab_mmcm_out),
        .CLKFBOUT (clk_ab_mmcm_fb),
        .LOCKED   (clk_ab_locked),
        .PWRDWN   (1'b0),
        .RST      (clk_ab_mmcm_rst)
    );
    BUFG u_bufg_mmcm_fb (
        .I(clk_ab_mmcm_fb),
        .O(clk_ab_mmcm_fb_buf)
    );

    // -----------------------------------------------------------------------
    // Frequency counter: clk_ab_se counted vs mb_clk (from BD)
    // -----------------------------------------------------------------------
    wire        mb_clk;      // 100 MHz from block design clk_wiz
    wire        mb_rst;      // active-high reset from proc_sys_reset in BD
    wire [19:0] freq_count;
    wire        freq_done;   // unused at top-level

    clk_freq_counter u_freq_ctr (
        .clk_ref   (mb_clk),
        .clk_meas  (clk_ab_se),
        .rst       (mb_rst),
        .count_out (freq_count),
        .done      (freq_done)
    );

    // -----------------------------------------------------------------------
    // GPIO: output bits (channel 1) and input bits (channel 2)
    // -----------------------------------------------------------------------
    wire [7:0]  gpio1_o;   // MicroBlaze → peripherals
    wire [23:0] gpio2_i;   // peripherals → MicroBlaze

    // Channel 1 outputs
    assign spi_sclk18  = gpio1_o[0];
    assign spi_sdata18 = gpio1_o[1];
    assign adc_n_en18  = gpio1_o[2];
    assign dac_n_en18  = gpio1_o[3];
    assign user_led    = gpio1_o[7:4];

    // Channel 2 inputs
    assign gpio2_i[0]    = adc_sdo18;
    assign gpio2_i[1]    = dac_sdo18;
    assign gpio2_i[2]    = clk_ab_locked;
    assign gpio2_i[22:3] = freq_count[19:0];  // 20 bits of freq count
    assign gpio2_i[23]   = 1'b0;             // unused

    // Static outputs
    assign adc_reset18 = 1'b0;   // keep ADC out of reset
    assign txenable18  = 1'b0;   // DAC TX disable (not needed for SPI config test)

    // -----------------------------------------------------------------------
    // Block design wrapper (MicroBlaze + MDM + clk_wiz + GPIO + proc_sys_reset)
    // -----------------------------------------------------------------------
    rhea_debug_bd_wrapper u_bd (
        // Differential sysclk in
        .CLK_IN1_D_clk_p   (sysclk_200MHz_p),
        .CLK_IN1_D_clk_n   (sysclk_200MHz_n),
        // Reset (active-low from board, BD wrapper inverts internally)
        .reset              (~cpu_reset),
        // Clocks out to top-level logic
        .mb_clk             (mb_clk),
        .mb_rst             (mb_rst),
        // GPIO
        .gpio1_tri_o        (gpio1_o),
        .gpio2_tri_i        (gpio2_i)
    );

endmodule

`default_nettype wire
