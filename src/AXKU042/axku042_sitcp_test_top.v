`timescale 1ns / 1ps
//------------------------------------------------------------------------------
// axku042_sitcp_test_top.v
//
// AXKU042 SiTCP RGMII basic connectivity test
//
// Configuration (hardcoded):
//   IP   : 192.168.10.16  (change EXT_IP_ADDR below as needed)
//   TCP  : port 24
//   RBCP : port 4660
//
// Test method with Wireshark:
//   1. Connect PC directly (or via switch) to AXKU042 GbE port
//   2. Set PC IP to 192.168.10.x/24
//   3. Start Wireshark on the Ethernet interface
//   4. You should see ARP broadcast from the FPGA IP after ~10ms
//   5. ping 192.168.10.16  â†? ICMP echo reply visible in Wireshark
//   6. nc 192.168.10.16 24  â†? TCP echo (anything typed is echoed back)
//   7. rbcp (if zturn-rbcp or rbcp-tool available): read/write registers
//
// MDIO/MDC are driven by SiTCP; KSZ9031 auto-negotiates with default settings.
// PHY_RESET is held low for ~10 ms at startup then released.
//
// Clock plan:
//   PL_CLK0 (200 MHz diff) â†? IBUFDS â†? MMCME3_ADV
//     CLKOUT0 (125 MHz, 0Â°)   â†? u_bufg_clk125   â†? clk125   (GMII TX)
//     CLKOUT1 (125 MHz, +90Â°) â†? u_bufg_clk125_90 â†? clk125_90 (PHY_GTXC)
//     CLKOUT2 (200 MHz, 0Â°)   â†? u_bufg_clk200    â†? clk200  (SiTCP CLK)
//   PHY_RXC (125 MHz from PHY) â†? IBUF â†? u_bufg_rxc â†? rxc    (GMII RX)
//
// RGMII:
//   TX : GMII 8-bit @ clk125 â†? ODDRE1 â†? 4-bit DDR @ clk125
//        GTX_CLK driven with ODDRE1 @ clk125_90 (+90Â° â‰? 2 ns delay vs data)
//   RX : 4-bit DDR @ rxc â†? IDDRE1 (SAME_EDGE_PIPELINED) â†? GMII 8-bit @ rxc
//------------------------------------------------------------------------------

module axku042_sitcp_test_top #(
    parameter BENCHMARK = 0  // 0: echo, 1: counter stream + statistics
) (
    // 200 MHz differential system clock
    input  wire       PL_CLK0_P,
    input  wire       PL_CLK0_N,
    // Reset (active-low push button)
    input  wire       FPGA_RSETN,
    // RGMII TX
    output wire       PHY_GTXC,
    output wire [3:0] PHY_TXD,
    output wire       PHY_TXEN,
    // RGMII RX
    input  wire       PHY_RXC,
    input  wire [3:0] PHY_RXD,
    input  wire       PHY_RXDV,
    // MDIO / MDC / PHY reset
    output wire       PHY_MDC,
    inout  wire       PHY_MDIO,
    output wire       PHY_RESET
);

    // -------------------------------------------------------------------------
    // Parameters â€? edit here to change IP / ports
    // -------------------------------------------------------------------------
    localparam [31:0] MY_IP   = {8'd192, 8'd168, 8'd10, 8'd16}; // 192.168.10.16
    localparam [15:0] MY_TCP  = 16'd24;
    localparam [15:0] MY_RBCP = 16'd4660;
    localparam [4:0]  PHY_ADDR_PARAM = 5'd3; // KSZ9031 default PHY addr strapped to 0

    // =========================================================================
    // Clock section
    // =========================================================================

    wire clk200_ibuf;

    IBUFDS #(
        .DIFF_TERM   ("FALSE"),
        .IBUF_LOW_PWR("FALSE"),
        .IOSTANDARD  ("LVDS")
    ) u_ibufds_clk200 (
        .I (PL_CLK0_P),
        .IB(PL_CLK0_N),
        .O (clk200_ibuf)
    );

    wire mmcm_fb_out, mmcm_fb_in;
    wire clk125_raw, clk125_90_raw, clk200_raw;
    wire mmcm_locked;

    // MMCME3_ADV: 200 MHz â†? 125 MHz (0Â°), 125 MHz (+90Â°), 200 MHz (0Â°)
    // VCO = 200 Ã? 5 = 1000 MHz  (within 600â€?1200 MHz for xcku040 speed-2)
    MMCME3_ADV #(
        .BANDWIDTH          ("OPTIMIZED"),
        .COMPENSATION       ("ZHOLD"),
        .STARTUP_WAIT       ("FALSE"),
        .CLKIN1_PERIOD      (5.000),     // 200 MHz
        .DIVCLK_DIVIDE      (1),
        .CLKFBOUT_MULT_F    (5.0),       // VCO = 1000 MHz
        .CLKFBOUT_PHASE     (0.0),
        // CLKOUT0: 125 MHz, 0Â° â€? TX data clock
        .CLKOUT0_DIVIDE_F   (8.000),
        .CLKOUT0_PHASE      (0.000),
        .CLKOUT0_DUTY_CYCLE (0.5),
        // CLKOUT1: 125 MHz, +90Â° â€? GTX_CLK output (data-stable before clock edge)
        .CLKOUT1_DIVIDE     (8),
        .CLKOUT1_PHASE      (90.000),
        .CLKOUT1_DUTY_CYCLE (0.5),
        // CLKOUT2: 200 MHz, 0Â° â€? SiTCP system clock
        .CLKOUT2_DIVIDE     (5),
        .CLKOUT2_PHASE      (0.000),
        .CLKOUT2_DUTY_CYCLE (0.5)
    ) u_mmcm (
        .CLKIN1   (clk200_ibuf),
        .CLKIN2   (1'b0),
        .CLKINSEL (1'b1),
        .CLKFBIN  (mmcm_fb_in),
        .CLKFBOUT (mmcm_fb_out),
        .CLKFBOUTB(),
        .CLKOUT0  (clk125_raw),
        .CLKOUT0B (),
        .CLKOUT1  (clk125_90_raw),
        .CLKOUT1B (),
        .CLKOUT2  (clk200_raw),
        .CLKOUT2B (),
        .CLKOUT3  (),
        .CLKOUT3B (),
        .CLKOUT4  (),
        .CLKOUT5  (),
        .CLKOUT6  (),
        .LOCKED   (mmcm_locked),
        .DADDR    (7'd0),
        .DCLK     (1'b0),
        .DEN      (1'b0),
        .DI       (16'd0),
        .DO       (),
        .DRDY     (),
        .DWE      (1'b0),
        .CDDCREQ  (1'b0),
        .CDDCDONE (),
        .PSCLK    (1'b0),
        .PSEN     (1'b0),
        .PSINCDEC (1'b0),
        .PSDONE   (),
        .PWRDWN   (1'b0),
        .RST      (1'b0)
    );

    BUFG u_bufg_mmcm_fb  (.I(mmcm_fb_out),     .O(mmcm_fb_in));
    BUFG u_bufg_clk125   (.I(clk125_raw),       .O(clk125));
    BUFG u_bufg_clk125_90(.I(clk125_90_raw),    .O(clk125_90));
    BUFG u_bufg_clk200   (.I(clk200_raw),       .O(clk200));

    wire clk125, clk125_90, clk200;

    // RX clock from PHY
    wire rxc_ibuf, rxc;
    IBUF u_ibuf_rxc (.I(PHY_RXC), .O(rxc_ibuf));
    BUFG u_bufg_rxc (.I(rxc_ibuf), .O(rxc));

    // =========================================================================
    // Reset section
    // =========================================================================

    // Two-stage synchroniser for external reset button (active-low input)
    reg rst_p0 = 1'b1, rst_p1 = 1'b1;
    always @(posedge clk200 or negedge FPGA_RSETN) begin
        if (!FPGA_RSETN) begin
            rst_p0 <= 1'b1;
            rst_p1 <= 1'b1;
        end else begin
            rst_p0 <= 1'b0;
            rst_p1 <= rst_p0;
        end
    end
    wire btn_rst = rst_p1;  // active-high, synced to clk200

    // Power-up delay: hold PHY reset low for ~10 ms (200 MHz Ã? 2 000 000 = 10 ms)
    // Then allow SiTCP to start.
    localparam integer POWERUP_CYCLES = 2_000_000;  // 10 ms @ 200 MHz

    reg [20:0] phy_rst_cnt  = 0;
    reg        phy_reset_nr = 0;  // active-low PHY reset, registered

    always @(posedge clk200) begin
        if (btn_rst || !mmcm_locked) begin
            phy_rst_cnt  <= 0;
            phy_reset_nr <= 0;
        end else if (!phy_reset_nr) begin
            if (phy_rst_cnt == POWERUP_CYCLES - 1)
                phy_reset_nr <= 1'b1;
            else
                phy_rst_cnt <= phy_rst_cnt + 1;
        end
    end

    assign PHY_RESET = phy_reset_nr;

    // SiTCP active-high reset: hold until MMCM locked AND PHY released
    wire sitcp_rst = btn_rst | ~mmcm_locked | ~phy_reset_nr;

    // =========================================================================
    // RGMII TX â€? GMII 8-bit (clk125) â†? 4-bit DDR
    // =========================================================================

    // SiTCP GMII TX outputs (clk125 domain)
    wire        gmii_tx_en;
    wire [7:0]  gmii_txd;
    wire        gmii_tx_er;

    // PHY_GTXC: forward clk125_90 (+90Â°) so the PHY sees data-stable before clock
    wire gtxc_pre;
    ODDRE1 #(.SRVAL(1'b0)) u_oddr_gtxc (
        .C (clk125_90),
        .D1(1'b1),
        .D2(1'b0),
        .SR(1'b0),
        .Q (gtxc_pre)
    );
    OBUF u_obuf_gtxc (.I(gtxc_pre), .O(PHY_GTXC));

    // PHY_TXD[3:0]: lower nibble on rising, upper nibble on falling
    genvar gi;
    wire [3:0] txd_pre;
    generate
        for (gi = 0; gi < 4; gi = gi + 1) begin : gen_txd
            ODDRE1 #(.SRVAL(1'b0)) u_oddr (
                .C (clk125),
                .D1(gmii_txd[gi]),
                .D2(gmii_txd[gi+4]),
                .SR(1'b0),
                .Q (txd_pre[gi])
            );
            OBUF u_obuf (.I(txd_pre[gi]), .O(PHY_TXD[gi]));
        end
    endgenerate

    // PHY_TXEN: rising=TX_EN, falling=TX_EN XOR TX_ER  (RGMII encoding)
    wire txen_pre;
    ODDRE1 #(.SRVAL(1'b0)) u_oddr_txen (
        .C (clk125),
        .D1(gmii_tx_en),
        .D2(gmii_tx_en ^ gmii_tx_er),
        .SR(1'b0),
        .Q (txen_pre)
    );
    OBUF u_obuf_txen (.I(txen_pre), .O(PHY_TXEN));

    // =========================================================================
    // RGMII RX â€? 4-bit DDR â†? GMII 8-bit (rxc domain)
    // =========================================================================

    // SiTCP GMII RX inputs (rxc domain)
    wire [7:0]  gmii_rxd;
    wire        gmii_rx_dv;
    wire        gmii_rx_er;

    // IDDRE1 SAME_EDGE_PIPELINED with IS_CB_INVERTED=1:
    //   Q1 = data captured on rising edge of C  (available after next rising edge)
    //   Q2 = data captured on falling edge of C (available after next rising edge)
    wire [3:0] rxd_ibuf_w;
    generate
        for (gi = 0; gi < 4; gi = gi + 1) begin : gen_rxd
            IBUF u_ibuf (.I(PHY_RXD[gi]), .O(rxd_ibuf_w[gi]));
            IDDRE1 #(
                .DDR_CLK_EDGE  ("SAME_EDGE_PIPELINED"),
                .IS_CB_INVERTED(1'b1),
                .IS_C_INVERTED (1'b0)
            ) u_iddr (
                .C (rxc),
                .CB(rxc),           // logically inverted by IS_CB_INVERTED
                .D (rxd_ibuf_w[gi]),
                .R (1'b0),
                .Q1(gmii_rxd[gi]),  // lower nibble (rising edge)
                .Q2(gmii_rxd[gi+4]) // upper nibble (falling edge)
            );
        end
    endgenerate

    wire        rxdv_ibuf_w;
    wire        rxdv_rise, rxdv_fall;
    IBUF u_ibuf_rxdv (.I(PHY_RXDV), .O(rxdv_ibuf_w));
    IDDRE1 #(
        .DDR_CLK_EDGE  ("SAME_EDGE_PIPELINED"),
        .IS_CB_INVERTED(1'b1),
        .IS_C_INVERTED (1'b0)
    ) u_iddr_rxdv (
        .C (rxc),
        .CB(rxc),
        .D (rxdv_ibuf_w),
        .R (1'b0),
        .Q1(rxdv_rise),  // RX_DV
        .Q2(rxdv_fall)   // RX_DV XOR RX_ER
    );
    assign gmii_rx_dv = rxdv_rise;
    assign gmii_rx_er = rxdv_rise ^ rxdv_fall;

    // =========================================================================
    // MDIO IOBUF
    // =========================================================================

    wire mdio_in, mdio_out, mdio_oe;
    IOBUF u_iobuf_mdio (
        .I (mdio_out),
        .O (mdio_in),
        .T (~mdio_oe),  // T=1 â†? tri-state (input), T=0 â†? drive
        .IO(PHY_MDIO)
    );

    // =========================================================================
    // SiTCP (WRAP_SiTCP_GMII_XCKU_32K)
    // TIM_PERIOD must equal system clock frequency in MHz = 200
    // =========================================================================

    wire        tcp_open_ack;
    wire        tcp_error;
    wire        tcp_close_req;
    wire        tcp_rx_wr;
    wire [7:0]  tcp_rx_data;
    wire        tcp_tx_full;

    wire        tcp_tx_wr;
    wire [7:0]  tcp_tx_data;
    wire        sitcp_user_rst;

    wire        rbcp_act;
    wire [31:0] rbcp_addr;
    wire [7:0]  rbcp_wd;
    wire        rbcp_we;
    wire        rbcp_re;

    wire       rbcp_ack_r;
    wire [7:0] rbcp_rd_r;
    generate
        if (BENCHMARK) begin : gen_benchmark
            sitcp_benchmark u_benchmark (
                .clk(clk200), .rst(sitcp_rst | sitcp_user_rst),
                .tcp_open_ack(tcp_open_ack), .tcp_close_req(tcp_close_req),
                .tcp_error(tcp_error), .tcp_tx_full(tcp_tx_full),
                .tcp_tx_wr(tcp_tx_wr), .tcp_tx_data(tcp_tx_data),
                .rbcp_addr(rbcp_addr), .rbcp_wd(rbcp_wd),
                .rbcp_we(rbcp_we), .rbcp_re(rbcp_re),
                .rbcp_ack(rbcp_ack_r), .rbcp_rd(rbcp_rd_r)
            );
        end else begin : gen_echo
            assign tcp_tx_wr = tcp_rx_wr & ~tcp_tx_full;
            assign tcp_tx_data = tcp_rx_data;
            reg ack = 0;
            reg [7:0] rd = 0;
            always @(posedge clk200) begin
                ack <= rbcp_we | rbcp_re;
                if (rbcp_re) rd <= 8'hAB;
            end
            assign rbcp_ack_r = ack;
            assign rbcp_rd_r = rd;
        end
    endgenerate

    WRAP_SiTCP_GMII_XCKU_32K #(
        .TIM_PERIOD(8'd200)  // system clock = 200 MHz
    ) u_sitcp (
        .CLK            (clk200),
        .RST            (sitcp_rst),
        // Force built-in defaults: wrapper ignores EXT_* when FORCE_DEFAULTn=0.
        // 192.168.10.16, TCP 24, RBCP 4660. No EEPROM dependency.
        .FORCE_DEFAULTn (1'b0),
        .EXT_IP_ADDR    (MY_IP),
        .EXT_TCP_PORT   (MY_TCP),
        .EXT_RBCP_PORT  (MY_RBCP),
        .PHY_ADDR       (PHY_ADDR_PARAM),
        // EEPROM: tie to unprogrammed state (all-1s)
        .EEPROM_CS      (),
        .EEPROM_SK      (),
        .EEPROM_DI      (),
        .EEPROM_DO      (1'b1),
        .USR_REG_X3C    (),
        .USR_REG_X3D    (),
        .USR_REG_X3E    (),
        .USR_REG_X3F    (),
        // GMII interface
        .GMII_RSTn      (),          // PHY_RESET handled by phy_reset_nr above
        .GMII_1000M     (1'b1),      // 1 = GMII (1 GbE)
        .GMII_TX_CLK    (clk125),
        .GMII_TX_EN     (gmii_tx_en),
        .GMII_TXD       (gmii_txd),
        .GMII_TX_ER     (gmii_tx_er),
        .GMII_RX_CLK    (rxc),
        .GMII_RX_DV     (gmii_rx_dv),
        .GMII_RXD       (gmii_rxd),
        .GMII_RX_ER     (gmii_rx_er),
        .GMII_CRS       (1'b0),
        .GMII_COL       (1'b0),
        .GMII_MDC       (PHY_MDC),
        .GMII_MDIO_IN   (mdio_in),
        .GMII_MDIO_OUT  (mdio_out),
        .GMII_MDIO_OE   (mdio_oe),
        // User interface
        .SiTCP_RST      (sitcp_user_rst),
        .TCP_OPEN_REQ   (1'b0),
        .TCP_OPEN_ACK   (tcp_open_ack),
        .TCP_ERROR      (tcp_error),
        .TCP_CLOSE_REQ  (tcp_close_req),
        .TCP_CLOSE_ACK  (tcp_close_req),  // auto-close: echo back close request
        // TCP FIFO
        .TCP_RX_WC      (BENCHMARK ? 16'd0 : 16'hFFFF),
        .TCP_RX_WR      (tcp_rx_wr),
        .TCP_RX_DATA    (tcp_rx_data),
        .TCP_TX_FULL    (tcp_tx_full),
        .TCP_TX_WR      (tcp_tx_wr),
        .TCP_TX_DATA    (tcp_tx_data),
        // RBCP
        .RBCP_ACT       (rbcp_act),
        .RBCP_ADDR      (rbcp_addr),
        .RBCP_WD        (rbcp_wd),
        .RBCP_WE        (rbcp_we),
        .RBCP_RE        (rbcp_re),
        .RBCP_ACK       (rbcp_ack_r),
        .RBCP_RD        (rbcp_rd_r)
    );

endmodule
