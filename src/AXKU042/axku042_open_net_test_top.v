`timescale 1ns / 1ps

// SiTCP replacement prototype: independent 1000BASE-T RGMII MAC with
// ARP, ICMP Echo and a single-client TCP counter-stream benchmark.
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
    localparam [47:0] LOCAL_MAC = 48'h02_52_48_45_41_01;
    localparam [31:0] LOCAL_IP  = {8'd192, 8'd168, 8'd10, 8'd16};
    localparam integer POWERUP_CYCLES = 2_000_000;

    wire clk200_ibuf;
    wire mmcm_fb_out, mmcm_fb_in;
    wire clk125_raw, clk125_90_raw, clk200_raw;
    wire clk125, clk125_90, clk200;
    wire mmcm_locked;

    IBUFDS #(
        .DIFF_TERM("FALSE"), .IBUF_LOW_PWR("FALSE"), .IOSTANDARD("LVDS")
    ) u_ibufds_clk200 (
        .I(PL_CLK0_P), .IB(PL_CLK0_N), .O(clk200_ibuf)
    );

    MMCME3_ADV #(
        .BANDWIDTH("OPTIMIZED"), .COMPENSATION("ZHOLD"),
        .STARTUP_WAIT("FALSE"), .CLKIN1_PERIOD(5.000),
        .DIVCLK_DIVIDE(1), .CLKFBOUT_MULT_F(5.0), .CLKFBOUT_PHASE(0.0),
        .CLKOUT0_DIVIDE_F(8.000), .CLKOUT0_PHASE(0.000),
        .CLKOUT0_DUTY_CYCLE(0.5),
        .CLKOUT1_DIVIDE(8), .CLKOUT1_PHASE(90.000),
        .CLKOUT1_DUTY_CYCLE(0.5),
        .CLKOUT2_DIVIDE(5), .CLKOUT2_PHASE(0.000),
        .CLKOUT2_DUTY_CYCLE(0.5)
    ) u_mmcm (
        .CLKIN1(clk200_ibuf), .CLKIN2(1'b0), .CLKINSEL(1'b1),
        .CLKFBIN(mmcm_fb_in), .CLKFBOUT(mmcm_fb_out), .CLKFBOUTB(),
        .CLKOUT0(clk125_raw), .CLKOUT0B(), .CLKOUT1(clk125_90_raw),
        .CLKOUT1B(), .CLKOUT2(clk200_raw), .CLKOUT2B(), .CLKOUT3(),
        .CLKOUT3B(), .CLKOUT4(), .CLKOUT5(), .CLKOUT6(), .LOCKED(mmcm_locked),
        .DADDR(7'd0), .DCLK(1'b0), .DEN(1'b0), .DI(16'd0), .DO(),
        .DRDY(), .DWE(1'b0), .CDDCREQ(1'b0), .CDDCDONE(), .PSCLK(1'b0),
        .PSEN(1'b0), .PSINCDEC(1'b0), .PSDONE(), .PWRDWN(1'b0), .RST(1'b0)
    );

    BUFG u_bufg_mmcm_fb   (.I(mmcm_fb_out),  .O(mmcm_fb_in));
    BUFG u_bufg_clk125    (.I(clk125_raw),    .O(clk125));
    BUFG u_bufg_clk125_90 (.I(clk125_90_raw), .O(clk125_90));
    BUFG u_bufg_clk200    (.I(clk200_raw),    .O(clk200));

    wire rxc_ibuf, rxc;
    IBUF u_ibuf_rxc (.I(PHY_RXC), .O(rxc_ibuf));
    BUFG u_bufg_rxc (.I(rxc_ibuf), .O(rxc));

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

    reg [20:0] phy_rst_cnt = 0;
    reg phy_reset_nr = 1'b0;
    always @(posedge clk200) begin
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
    assign PHY_RESET = phy_reset_nr;

    // The KSZ9031 strap pins select auto-negotiation. MDIO configuration is
    // unnecessary for the fixed 1000BASE-T test and is left idle.
    assign PHY_MDC = 1'b0;
    assign PHY_MDIO = 1'bz;

    wire net_reset_async = rst_p1 | ~mmcm_locked | ~phy_reset_nr;
    (* ASYNC_REG = "TRUE" *) reg [1:0] tx_reset_pipe = 2'b11;
    (* ASYNC_REG = "TRUE" *) reg [1:0] rx_reset_pipe = 2'b11;
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

    wire [7:0] gmii_txd;
    wire gmii_tx_en, gmii_tx_er;
    wire [7:0] gmii_rxd;
    wire gmii_rx_dv, gmii_rx_er;

    wire gtxc_pre;
    ODDRE1 #(.SRVAL(1'b0)) u_oddr_gtxc (
        .C(clk125_90), .D1(1'b1), .D2(1'b0), .SR(1'b0), .Q(gtxc_pre)
    );
    OBUF u_obuf_gtxc (.I(gtxc_pre), .O(PHY_GTXC));

    genvar gi;
    wire [3:0] txd_pre;
    generate
        for (gi = 0; gi < 4; gi = gi + 1) begin : gen_txd
            ODDRE1 #(.SRVAL(1'b0)) u_oddr (
                .C(clk125), .D1(gmii_txd[gi]), .D2(gmii_txd[gi+4]),
                .SR(1'b0), .Q(txd_pre[gi])
            );
            OBUF u_obuf (.I(txd_pre[gi]), .O(PHY_TXD[gi]));
        end
    endgenerate

    wire txen_pre;
    ODDRE1 #(.SRVAL(1'b0)) u_oddr_txen (
        .C(clk125), .D1(gmii_tx_en), .D2(gmii_tx_en ^ gmii_tx_er),
        .SR(1'b0), .Q(txen_pre)
    );
    OBUF u_obuf_txen (.I(txen_pre), .O(PHY_TXEN));

    wire [3:0] rxd_ibuf_w;
    generate
        for (gi = 0; gi < 4; gi = gi + 1) begin : gen_rxd
            IBUF u_ibuf (.I(PHY_RXD[gi]), .O(rxd_ibuf_w[gi]));
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
    IBUF u_ibuf_rxdv (.I(PHY_RXDV), .O(rxdv_ibuf_w));
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
    wire tcp_tx_full, tcp_open_ack;
    wire replay_tx_wr;
    wire [7:0] replay_tx_data;
    reg tcp_tx_wr = 1'b0;
    reg [29:0] app_word_index = 0;
    reg [1:0] app_byte_select = 0;
    wire [7:0] app_tx_data = app_byte_select == 2'd0
        ? app_word_index[7:0] : app_byte_select == 2'd1
        ? app_word_index[15:8] : app_byte_select == 2'd2
        ? app_word_index[23:16] : {2'b00, app_word_index[29:24]};

    // Benchmark producer using the same byte-stream contract as SiTCP's
    // TCP_TX_WR/TCP_TX_FULL interface. The replay ring preserves accepted
    // bytes until the peer acknowledges their TCP sequence numbers.
    always @(posedge clk200) begin
        if (rst_p1 || !tcp_open_ack) begin
            tcp_tx_wr <= 1'b0;
            app_word_index <= 0;
            app_byte_select <= 0;
        end else begin
            tcp_tx_wr <= ~tcp_tx_full;
            // FULL is an early warning. A write already in flight when it
            // rises remains valid and must advance the producer position.
            if (tcp_tx_wr) begin
                if (app_byte_select == 2'd3)
                    app_word_index <= app_word_index + 1'b1;
                app_byte_select <= app_byte_select + 1'b1;
            end
        end
    end

    tcp_tx_async_adapter u_tx_cdc (
        .wr_clk(clk200), .wr_rst(rst_p1),
        .tcp_open_rx(protocol_tcp_open), .tcp_open_ack(tcp_open_ack),
        .tcp_tx_wr(tcp_tx_wr), .tcp_tx_data(app_tx_data),
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

    arp_icmp_server #(
        .LOCAL_MAC(LOCAL_MAC), .LOCAL_IP(LOCAL_IP), .USE_REPLAY_BUFFER(1)
    ) u_protocol (
        .rx_clk(rxc), .rst(rx_reset), .rx_frame_valid(rx_frame_valid),
        .rx_frame_len(rx_frame_len), .rx_frame_consume(rx_frame_consume),
        .rx_frame_rd_addr(rx_frame_rd_addr), .rx_frame_rd_data(rx_frame_rd_data),
        .tx_request_toggle(tx_request_toggle), .tx_done_toggle(tx_done_toggle),
        .tx_frame_len(tx_frame_len), .tx_frame_rd_addr(tx_frame_rd_addr),
        .tx_frame_rd_data(tx_frame_rd_data), .arp_replies(), .icmp_replies(),
        .unsupported_frames(), .response_drops(), .tcp_connections(),
        .tcp_segments(), .tcp_retransmissions(),
        .app_tx_wr(replay_tx_wr), .app_tx_data(replay_tx_data),
        .app_tcp_tx_full(replay_tcp_tx_full),
        .app_tcp_open(protocol_tcp_open),
        .app_session_start(protocol_session_start)
    );

    gmii_tx_frame u_tx_frame (
        .clk(clk125), .rst(tx_reset), .request_toggle(tx_request_toggle),
        .done_toggle(tx_done_toggle), .frame_len(tx_frame_len),
        .frame_rd_addr(tx_frame_rd_addr), .frame_rd_data(tx_frame_rd_data),
        .gmii_txd(gmii_txd), .gmii_tx_en(gmii_tx_en),
        .gmii_tx_er(gmii_tx_er), .busy()
    );
endmodule
