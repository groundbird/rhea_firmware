`timescale 1ns / 1ps

// Standalone AXKU042 throughput test for axku042_open_net_core.
// The producer emits the same little-endian 32-bit counter stream used by the
// SiTCP baseline firmware.
module axku042_open_net_test_top (
    input  wire       PL_CLK0_P,
    input  wire       PL_CLK0_N,
    input  wire       FPGA_RSETN,
    output wire       PHY_GTXC,
    output wire [3:0] PHY_TXD,
    output wire       PHY_TXEN,
    input  wire       PHY_RXC,
    input  wire [3:0] PHY_RXD,
    input  wire       PHY_RXDV,
    output wire       PHY_MDC,
    inout  wire       PHY_MDIO,
    output wire       PHY_RESET
);
    wire clk200_ibuf, clk200;
    IBUFDS #(
        .DIFF_TERM("FALSE"), .IBUF_LOW_PWR("FALSE"), .IOSTANDARD("LVDS")
    ) u_ibufds_clk200 (
        .I(PL_CLK0_P), .IB(PL_CLK0_N), .O(clk200_ibuf)
    );
    BUFG u_bufg_clk200 (.I(clk200_ibuf), .O(clk200));

    wire tcp_open_ack, tcp_tx_full;
    wire tcp_tx_wr;
    wire [7:0] tcp_txd;
    wire [31:0] rbcp_addr;
    wire [7:0] rbcp_wd, rbcp_rd;
    wire rbcp_we, rbcp_re, rbcp_ack;

    sitcp_benchmark u_benchmark (
        .clk(clk200), .rst(~FPGA_RSETN), .tcp_open_ack(tcp_open_ack),
        .tcp_close_req(1'b0), .tcp_error(1'b0),
        .tcp_tx_full(tcp_tx_full), .tcp_tx_wr(tcp_tx_wr),
        .tcp_tx_data(tcp_txd), .rbcp_addr(rbcp_addr), .rbcp_wd(rbcp_wd),
        .rbcp_we(rbcp_we), .rbcp_re(rbcp_re), .rbcp_ack(rbcp_ack),
        .rbcp_rd(rbcp_rd)
    );

    axku042_open_net_core u_open_net (
        .clk_200(clk200), .rst(~FPGA_RSETN), .force_defaultn(1'b0),
        .sitcp_rst(), .status(), .phy_rstn(PHY_RESET),
        .phy_gtxc(PHY_GTXC), .phy_txd(PHY_TXD), .phy_txen(PHY_TXEN),
        .phy_rxc(PHY_RXC), .phy_rxd(PHY_RXD), .phy_rxdv(PHY_RXDV),
        .phy_mdc(PHY_MDC), .phy_mdio(PHY_MDIO),
        .tcp_open_ack(tcp_open_ack), .tcp_tx_full(tcp_tx_full),
        .tcp_tx_wr(tcp_tx_wr), .tcp_txd(tcp_txd),
        .rbcp_act(), .rbcp_addr(rbcp_addr), .rbcp_wd(rbcp_wd),
        .rbcp_we(rbcp_we), .rbcp_re(rbcp_re),
        .rbcp_ack(rbcp_ack), .rbcp_rd(rbcp_rd),
        .iic_main_sda(), .iic_main_scl()
    );
endmodule
