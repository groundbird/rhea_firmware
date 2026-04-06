`timescale 1ns / 1ps

// AXKU042 SiTCP core:
// - RGMII PHY interface based on the validated AXKU042 test design
// - 24LC04-backed EEPROM bridge through AT93C46_LC04
// - Exposes the original TCP/RBCP streaming interface to rhea.vhd

module axku042_sitcp_core (
    input  wire        clk_200,
    input  wire        rst,
    input  wire        force_defaultn,
    output wire        sitcp_rst,
    output wire [15:0] status,
    output wire        phy_rstn,
    output wire        phy_gtxc,
    output wire [3:0]  phy_txd,
    output wire        phy_txen,
    input  wire        phy_rxc,
    input  wire [3:0]  phy_rxd,
    input  wire        phy_rxdv,
    output wire        phy_mdc,
    inout  wire        phy_mdio,
    output wire        tcp_open_ack,
    output wire        tcp_tx_full,
    input  wire        tcp_tx_wr,
    input  wire [7:0]  tcp_txd,
    output wire        rbcp_act,
    output wire [31:0] rbcp_addr,
    output wire [7:0]  rbcp_wd,
    output wire        rbcp_we,
    output wire        rbcp_re,
    input  wire        rbcp_ack,
    input  wire [7:0]  rbcp_rd,
    inout  wire        iic_main_sda,
    output wire        iic_main_scl
);

    localparam [4:0] PHY_ADDR_PARAM = 5'd3;

    wire mmcm_fb_out, mmcm_fb_in;
    wire clk125_raw, clk125_90_raw;
    wire mmcm_locked;
    wire clk125, clk125_90;

    MMCME3_ADV #(
        .BANDWIDTH          ("OPTIMIZED"),
        .COMPENSATION       ("ZHOLD"),
        .STARTUP_WAIT       ("FALSE"),
        .CLKIN1_PERIOD      (5.000),
        .DIVCLK_DIVIDE      (1),
        .CLKFBOUT_MULT_F    (5.0),
        .CLKFBOUT_PHASE     (0.0),
        .CLKOUT0_DIVIDE_F   (8.000),
        .CLKOUT0_PHASE      (0.000),
        .CLKOUT0_DUTY_CYCLE (0.5),
        .CLKOUT1_DIVIDE     (8),
        .CLKOUT1_PHASE      (90.000),
        .CLKOUT1_DUTY_CYCLE (0.5)
    ) u_mmcm (
        .CLKIN1   (clk_200),
        .CLKIN2   (1'b0),
        .CLKINSEL (1'b1),
        .CLKFBIN  (mmcm_fb_in),
        .CLKFBOUT (mmcm_fb_out),
        .CLKFBOUTB(),
        .CLKOUT0  (clk125_raw),
        .CLKOUT0B (),
        .CLKOUT1  (clk125_90_raw),
        .CLKOUT1B (),
        .CLKOUT2  (),
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

    BUFG u_bufg_mmcm_fb   (.I(mmcm_fb_out),  .O(mmcm_fb_in));
    BUFG u_bufg_clk125    (.I(clk125_raw),   .O(clk125));
    BUFG u_bufg_clk125_90 (.I(clk125_90_raw), .O(clk125_90));

    wire rxc_ibuf, rxc;
    IBUF u_ibuf_rxc (.I(phy_rxc), .O(rxc_ibuf));
    BUFG u_bufg_rxc (.I(rxc_ibuf), .O(rxc));

    reg rst_p0 = 1'b1, rst_p1 = 1'b1;
    always @(posedge clk_200 or posedge rst) begin
        if (rst) begin
            rst_p0 <= 1'b1;
            rst_p1 <= 1'b1;
        end else begin
            rst_p0 <= 1'b0;
            rst_p1 <= rst_p0;
        end
    end
    wire btn_rst = rst_p1;

    localparam integer POWERUP_CYCLES = 2_000_000;
    reg [20:0] phy_rst_cnt = 0;
    reg        phy_reset_nr = 1'b0;

    always @(posedge clk_200) begin
        if (btn_rst || !mmcm_locked) begin
            phy_rst_cnt  <= 0;
            phy_reset_nr <= 1'b0;
        end else if (!phy_reset_nr) begin
            if (phy_rst_cnt == POWERUP_CYCLES - 1)
                phy_reset_nr <= 1'b1;
            else
                phy_rst_cnt <= phy_rst_cnt + 1'b1;
        end
    end

    assign phy_rstn = phy_reset_nr;

    wire [7:0] gmii_txd;
    wire       gmii_tx_en;
    wire       gmii_tx_er;
    wire [7:0] gmii_rxd;
    wire       gmii_rx_dv;
    wire       gmii_rx_er;

    wire gtxc_pre;
    ODDRE1 #(.SRVAL(1'b0)) u_oddr_gtxc (
        .C (clk125_90),
        .D1(1'b1),
        .D2(1'b0),
        .SR(1'b0),
        .Q (gtxc_pre)
    );
    OBUF u_obuf_gtxc (.I(gtxc_pre), .O(phy_gtxc));

    genvar gi;
    wire [3:0] txd_pre;
    generate
        for (gi = 0; gi < 4; gi = gi + 1) begin : gen_txd
            ODDRE1 #(.SRVAL(1'b0)) u_oddr_txd (
                .C (clk125),
                .D1(gmii_txd[gi]),
                .D2(gmii_txd[gi+4]),
                .SR(1'b0),
                .Q (txd_pre[gi])
            );
            OBUF u_obuf_txd (.I(txd_pre[gi]), .O(phy_txd[gi]));
        end
    endgenerate

    wire txen_pre;
    ODDRE1 #(.SRVAL(1'b0)) u_oddr_txen (
        .C (clk125),
        .D1(gmii_tx_en),
        .D2(gmii_tx_en ^ gmii_tx_er),
        .SR(1'b0),
        .Q (txen_pre)
    );
    OBUF u_obuf_txen (.I(txen_pre), .O(phy_txen));

    wire [3:0] rxd_ibuf_w;
    generate
        for (gi = 0; gi < 4; gi = gi + 1) begin : gen_rxd
            IBUF u_ibuf_rxd (.I(phy_rxd[gi]), .O(rxd_ibuf_w[gi]));
            IDDRE1 #(
                .DDR_CLK_EDGE  ("SAME_EDGE_PIPELINED"),
                .IS_CB_INVERTED(1'b1),
                .IS_C_INVERTED (1'b0)
            ) u_iddr_rxd (
                .C (rxc),
                .CB(rxc),
                .D (rxd_ibuf_w[gi]),
                .R (1'b0),
                .Q1(gmii_rxd[gi]),
                .Q2(gmii_rxd[gi+4])
            );
        end
    endgenerate

    wire rxdv_ibuf_w;
    wire rxdv_rise, rxdv_fall;
    IBUF u_ibuf_rxdv (.I(phy_rxdv), .O(rxdv_ibuf_w));
    IDDRE1 #(
        .DDR_CLK_EDGE  ("SAME_EDGE_PIPELINED"),
        .IS_CB_INVERTED(1'b1),
        .IS_C_INVERTED (1'b0)
    ) u_iddr_rxdv (
        .C (rxc),
        .CB(rxc),
        .D (rxdv_ibuf_w),
        .R (1'b0),
        .Q1(rxdv_rise),
        .Q2(rxdv_fall)
    );

    assign gmii_rx_dv = rxdv_rise;
    assign gmii_rx_er = rxdv_rise ^ rxdv_fall;

    wire mdio_in, mdio_out, mdio_oe;
    IOBUF u_iobuf_mdio (
        .I (mdio_out),
        .O (mdio_in),
        .T (~mdio_oe),
        .IO(phy_mdio)
    );

    wire eeprom_cs;
    wire eeprom_sk;
    wire eeprom_di;
    wire eeprom_do;
    wire tcp_close_req;
    wire sda_drive;
    wire sda_in;
    wire sda_out_unused;
    wire sitcp_eeprom_rst;

    IOBUF u_iobuf_sda (
        .I (1'b0),
        .O (sda_in),
        .T (sda_drive),
        .IO(iic_main_sda)
    );

    wire sitcp_core_rst = btn_rst | ~mmcm_locked | ~phy_reset_nr | sitcp_eeprom_rst;
    assign sitcp_rst = sitcp_core_rst;
    assign status = {12'd0, tcp_open_ack, tcp_tx_full, rbcp_act, mmcm_locked};

    WRAP_SiTCP_GMII_XCKU_32K #(
        .TIM_PERIOD(8'd200)
    ) u_sitcp (
        .CLK            (clk_200),
        .RST            (sitcp_core_rst),
        .FORCE_DEFAULTn (force_defaultn),
        .EXT_IP_ADDR    (32'd0),
        .EXT_TCP_PORT   (16'd0),
        .EXT_RBCP_PORT  (16'd0),
        .PHY_ADDR       (PHY_ADDR_PARAM),
        .EEPROM_CS      (eeprom_cs),
        .EEPROM_SK      (eeprom_sk),
        .EEPROM_DI      (eeprom_di),
        .EEPROM_DO      (eeprom_do),
        .USR_REG_X3C    (),
        .USR_REG_X3D    (),
        .USR_REG_X3E    (),
        .USR_REG_X3F    (),
        .GMII_RSTn      (),
        .GMII_1000M     (1'b1),
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
        .GMII_MDC       (phy_mdc),
        .GMII_MDIO_IN   (mdio_in),
        .GMII_MDIO_OUT  (mdio_out),
        .GMII_MDIO_OE   (mdio_oe),
        .SiTCP_RST      (),
        .TCP_OPEN_REQ   (1'b0),
        .TCP_OPEN_ACK   (tcp_open_ack),
        .TCP_ERROR      (),
        .TCP_CLOSE_REQ  (tcp_close_req),
        .TCP_CLOSE_ACK  (tcp_close_req),
        .TCP_RX_WC      (16'd0),
        .TCP_RX_WR      (),
        .TCP_RX_DATA    (),
        .TCP_TX_FULL    (tcp_tx_full),
        .TCP_TX_WR      (tcp_tx_wr),
        .TCP_TX_DATA    (tcp_txd),
        .RBCP_ACT       (rbcp_act),
        .RBCP_ADDR      (rbcp_addr),
        .RBCP_WD        (rbcp_wd),
        .RBCP_WE        (rbcp_we),
        .RBCP_RE        (rbcp_re),
        .RBCP_ACK       (rbcp_ack),
        .RBCP_RD        (rbcp_rd)
    );

    AT93C46_LC04 #(
        .SYSCLK_FREQ_IN_MHz(200)
    ) u_at93c46_lc04 (
        .AT93C46_CS_IN   (eeprom_cs),
        .AT93C46_SK_IN   (eeprom_sk),
        .AT93C46_DI_IN   (eeprom_di),
        .AT93C46_DO_OUT  (eeprom_do),
        .M24C08_SCL_OUT  (iic_main_scl),
        .M24C08_SDA_OUT  (sda_out_unused),
        .M24C08_SDA_IN   (sda_in),
        .M24C08_SDAT_OUT (sda_drive),
        .RESET_IN        (rst),
        .SiTCP_RESET_OUT (sitcp_eeprom_rst),
        .SYSCLK_IN       (clk_200)
    );

endmodule
