`timescale 1ns / 1ps

// AXKU042 SiTCP-compatible single-client TCP core.
//
// The external interface matches axku042_sitcp_core so that rhea.vhd can
// select either implementation without changing its measurement-data path.
// Network settings are fixed while the EEPROM/configuration path is being
// replaced: 02:52:48:45:41:01, 192.168.10.16, TCP port 24.
module axku042_open_net_core (
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
    localparam [47:0] LOCAL_MAC = 48'h02_52_48_45_41_01;
    localparam [31:0] LOCAL_IP = {8'd192, 8'd168, 8'd10, 8'd16};
    localparam integer POWERUP_CYCLES = 2_000_000;

    wire mmcm_fb_out, mmcm_fb_in;
    wire clk125_raw, clk125_90_raw;
    wire mmcm_locked;
    wire clk125, clk125_90;

    MMCME3_ADV #(
        .BANDWIDTH("OPTIMIZED"), .COMPENSATION("ZHOLD"),
        .STARTUP_WAIT("FALSE"), .CLKIN1_PERIOD(5.000),
        .DIVCLK_DIVIDE(1), .CLKFBOUT_MULT_F(5.0), .CLKFBOUT_PHASE(0.0),
        .CLKOUT0_DIVIDE_F(8.000), .CLKOUT0_PHASE(0.000),
        .CLKOUT0_DUTY_CYCLE(0.5),
        .CLKOUT1_DIVIDE(8), .CLKOUT1_PHASE(90.000),
        .CLKOUT1_DUTY_CYCLE(0.5)
    ) u_mmcm (
        .CLKIN1(clk_200), .CLKIN2(1'b0), .CLKINSEL(1'b1),
        .CLKFBIN(mmcm_fb_in), .CLKFBOUT(mmcm_fb_out), .CLKFBOUTB(),
        .CLKOUT0(clk125_raw), .CLKOUT0B(), .CLKOUT1(clk125_90_raw),
        .CLKOUT1B(), .CLKOUT2(), .CLKOUT2B(), .CLKOUT3(), .CLKOUT3B(),
        .CLKOUT4(), .CLKOUT5(), .CLKOUT6(), .LOCKED(mmcm_locked),
        .DADDR(7'd0), .DCLK(1'b0), .DEN(1'b0), .DI(16'd0), .DO(),
        .DRDY(), .DWE(1'b0), .CDDCREQ(1'b0), .CDDCDONE(), .PSCLK(1'b0),
        .PSEN(1'b0), .PSINCDEC(1'b0), .PSDONE(), .PWRDWN(1'b0), .RST(1'b0)
    );

    BUFG u_bufg_mmcm_fb   (.I(mmcm_fb_out),   .O(mmcm_fb_in));
    BUFG u_bufg_clk125    (.I(clk125_raw),     .O(clk125));
    BUFG u_bufg_clk125_90 (.I(clk125_90_raw),  .O(clk125_90));

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

    reg [20:0] phy_rst_cnt = 0;
    reg phy_reset_nr = 1'b0;
    always @(posedge clk_200) begin
        if (rst_p1 || !mmcm_locked) begin
            phy_rst_cnt <= 0;
            phy_reset_nr <= 1'b0;
        end else if (!phy_reset_nr) begin
            if (phy_rst_cnt == POWERUP_CYCLES-1)
                phy_reset_nr <= 1'b1;
            else
                phy_rst_cnt <= phy_rst_cnt + 1'b1;
        end
    end
    assign phy_rstn = phy_reset_nr;

    // KSZ9031 straps select auto-negotiation for this fixed 1000BASE-T mode.
    assign phy_mdc = 1'b0;
    assign phy_mdio = 1'bz;

    wire net_reset_async = rst_p1 | ~mmcm_locked | ~phy_reset_nr;
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *)
    reg [1:0] tx_reset_pipe = 2'b11;
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *)
    reg [1:0] rx_reset_pipe = 2'b11;
    always @(posedge clk125 or posedge net_reset_async) begin
        if (net_reset_async) tx_reset_pipe <= 2'b11;
        else tx_reset_pipe <= {tx_reset_pipe[0], 1'b0};
    end
    always @(posedge rxc or posedge net_reset_async) begin
        if (net_reset_async) rx_reset_pipe <= 2'b11;
        else rx_reset_pipe <= {rx_reset_pipe[0], 1'b0};
    end
    wire tx_reset = tx_reset_pipe[1];
    wire rx_reset = rx_reset_pipe[1];
    assign sitcp_rst = net_reset_async;

    wire [7:0] gmii_txd;
    wire gmii_tx_en, gmii_tx_er;
    wire [7:0] gmii_rxd;
    wire gmii_rx_dv, gmii_rx_er;

    wire gtxc_pre;
    ODDRE1 #(.SRVAL(1'b0)) u_oddr_gtxc (
        .C(clk125_90), .D1(1'b1), .D2(1'b0), .SR(1'b0), .Q(gtxc_pre)
    );
    OBUF u_obuf_gtxc (.I(gtxc_pre), .O(phy_gtxc));

    genvar gi;
    wire [3:0] txd_pre;
    generate
        for (gi = 0; gi < 4; gi = gi + 1) begin : gen_txd
            ODDRE1 #(.SRVAL(1'b0)) u_oddr (
                .C(clk125), .D1(gmii_txd[gi]), .D2(gmii_txd[gi+4]),
                .SR(1'b0), .Q(txd_pre[gi])
            );
            OBUF u_obuf (.I(txd_pre[gi]), .O(phy_txd[gi]));
        end
    endgenerate

    wire txen_pre;
    ODDRE1 #(.SRVAL(1'b0)) u_oddr_txen (
        .C(clk125), .D1(gmii_tx_en), .D2(gmii_tx_en ^ gmii_tx_er),
        .SR(1'b0), .Q(txen_pre)
    );
    OBUF u_obuf_txen (.I(txen_pre), .O(phy_txen));

    wire [3:0] rxd_ibuf_w;
    generate
        for (gi = 0; gi < 4; gi = gi + 1) begin : gen_rxd
            IBUF u_ibuf (.I(phy_rxd[gi]), .O(rxd_ibuf_w[gi]));
            IDDRE1 #(
                .DDR_CLK_EDGE("SAME_EDGE_PIPELINED"),
                .IS_CB_INVERTED(1'b1), .IS_C_INVERTED(1'b0)
            ) u_iddr (
                .C(rxc), .CB(rxc), .D(rxd_ibuf_w[gi]), .R(1'b0),
                .Q1(gmii_rxd[gi]), .Q2(gmii_rxd[gi+4])
            );
        end
    endgenerate

    wire rxdv_ibuf_w, rxdv_rise, rxdv_fall;
    IBUF u_ibuf_rxdv (.I(phy_rxdv), .O(rxdv_ibuf_w));
    IDDRE1 #(
        .DDR_CLK_EDGE("SAME_EDGE_PIPELINED"),
        .IS_CB_INVERTED(1'b1), .IS_C_INVERTED(1'b0)
    ) u_iddr_rxdv (
        .C(rxc), .CB(rxc), .D(rxdv_ibuf_w), .R(1'b0),
        .Q1(rxdv_rise), .Q2(rxdv_fall)
    );
    assign gmii_rx_dv = rxdv_rise;
    assign gmii_rx_er = rxdv_rise ^ rxdv_fall;

    wire rx_frame_valid, rx_frame_consume;
    wire [10:0] rx_frame_len, rx_frame_rd_addr;
    wire [7:0] rx_frame_rd_data;
    wire tx_request_toggle, tx_done_toggle;
    wire [10:0] tx_frame_len, tx_frame_rd_addr;
    wire [7:0] tx_frame_rd_data;
    wire replay_tcp_tx_full, protocol_tcp_open, protocol_session_start;
    wire replay_tx_wr;
    wire [7:0] replay_tx_data;
    wire rbcp_start, rbcp_busy, rbcp_done, rbcp_error;
    wire [31:0] rbcp_req_addr;
    wire [7:0] rbcp_req_wd, rbcp_read_data;
    wire rbcp_req_we;

    tcp_tx_async_adapter u_tx_cdc (
        .wr_clk(clk_200), .wr_rst(rst_p1),
        .tcp_open_rx(protocol_tcp_open), .tcp_open_ack(tcp_open_ack),
        .tcp_tx_wr(tcp_tx_wr), .tcp_tx_data(tcp_txd),
        .tcp_tx_full(tcp_tx_full), .overflow_count(),
        .closed_write_count(), .rd_clk(rxc), .rd_rst(rx_reset),
        .session_start_rx(protocol_session_start),
        .replay_full(replay_tcp_tx_full), .replay_wr(replay_tx_wr),
        .replay_data(replay_tx_data)
    );

    gmii_rx_frame u_rx_frame (
        .clk(rxc), .rst(rx_reset), .gmii_rxd(gmii_rxd),
        .gmii_rx_dv(gmii_rx_dv), .gmii_rx_er(gmii_rx_er),
        .frame_valid(rx_frame_valid), .frame_len(rx_frame_len),
        .frame_consume(rx_frame_consume), .frame_rd_addr(rx_frame_rd_addr),
        .frame_rd_data(rx_frame_rd_data), .good_frames(), .bad_frames(),
        .dropped_frames()
    );

    rbcp_cdc_bridge u_rbcp_cdc (
        .src_clk(rxc), .src_rst(rx_reset), .src_start(rbcp_start),
        .src_addr(rbcp_req_addr), .src_wd(rbcp_req_wd),
        .src_we(rbcp_req_we), .src_busy(rbcp_busy), .src_done(rbcp_done),
        .src_error(rbcp_error), .src_rd(rbcp_read_data),
        .dst_clk(clk_200), .dst_rst(rst_p1), .rbcp_act(rbcp_act),
        .rbcp_addr(rbcp_addr), .rbcp_wd(rbcp_wd), .rbcp_we(rbcp_we),
        .rbcp_re(rbcp_re), .rbcp_ack(rbcp_ack), .rbcp_rd(rbcp_rd)
    );

    arp_icmp_server #(
        .LOCAL_MAC(LOCAL_MAC), .LOCAL_IP(LOCAL_IP), .USE_REPLAY_BUFFER(1)
    ) u_protocol (
        .rx_clk(rxc), .rst(rx_reset), .rx_frame_valid(rx_frame_valid),
        .rx_frame_len(rx_frame_len), .rx_frame_consume(rx_frame_consume),
        .rx_frame_rd_addr(rx_frame_rd_addr),
        .rx_frame_rd_data(rx_frame_rd_data),
        .tx_request_toggle(tx_request_toggle), .tx_done_toggle(tx_done_toggle),
        .tx_frame_len(tx_frame_len), .tx_frame_rd_addr(tx_frame_rd_addr),
        .tx_frame_rd_data(tx_frame_rd_data), .arp_replies(), .icmp_replies(),
        .unsupported_frames(), .response_drops(), .tcp_connections(),
        .tcp_segments(), .tcp_retransmissions(), .app_tx_wr(replay_tx_wr),
        .app_tx_data(replay_tx_data), .app_tcp_tx_full(replay_tcp_tx_full),
        .app_tcp_open(protocol_tcp_open),
        .app_session_start(protocol_session_start),
        .rbcp_start(rbcp_start), .rbcp_req_addr(rbcp_req_addr),
        .rbcp_req_wd(rbcp_req_wd), .rbcp_req_we(rbcp_req_we),
        .rbcp_busy(rbcp_busy), .rbcp_done(rbcp_done),
        .rbcp_error(rbcp_error), .rbcp_read_data(rbcp_read_data)
    );

    gmii_tx_frame u_tx_frame (
        .clk(clk125), .rst(tx_reset), .request_toggle(tx_request_toggle),
        .done_toggle(tx_done_toggle), .frame_len(tx_frame_len),
        .frame_rd_addr(tx_frame_rd_addr), .frame_rd_data(tx_frame_rd_data),
        .gmii_txd(gmii_txd), .gmii_tx_en(gmii_tx_en),
        .gmii_tx_er(gmii_tx_er), .busy()
    );

    // Persistent configuration is not yet implemented; use static defaults.
    assign iic_main_sda = 1'bz;
    assign iic_main_scl = 1'b1;
    assign status = {12'd0, tcp_open_ack, tcp_tx_full, rbcp_act, mmcm_locked};
endmodule
