`timescale 1ns / 1ps
module rbcp_udp_tb;
    reg rx_clk = 0;
    reg bus_clk = 0;
    always #4 rx_clk = ~rx_clk;      // 125 MHz PHY receive clock
    always #2.5 bus_clk = ~bus_clk;  // 200 MHz RHEA register clock
    reg rst = 1;
    reg [7:0] gmii_rxd = 0;
    reg gmii_rx_dv = 0, gmii_rx_er = 0;
    wire [7:0] gmii_txd;
    wire gmii_tx_en;

    wire rx_valid, rx_consume;
    wire [10:0] rx_len, rx_addr;
    wire [7:0] rx_data;
    wire [31:0] rx_good_frames, rx_bad_frames, rx_dropped_frames;
    wire tx_request, tx_done;
    wire [10:0] tx_len, tx_addr;
    wire [7:0] tx_data;

    wire rbcp_start, rbcp_busy, rbcp_done, rbcp_error;
    wire [31:0] rbcp_req_addr;
    wire [7:0] rbcp_req_wd, rbcp_read_data;
    wire rbcp_req_we;
    wire rbcp_act;
    wire [31:0] rbcp_addr;
    wire [7:0] rbcp_wd;
    wire rbcp_we, rbcp_re;
    reg rbcp_ack = 0;
    reg [7:0] rbcp_rd = 0;

    gmii_rx_frame u_rx (
        .clk(rx_clk), .rst(rst), .gmii_rxd(gmii_rxd),
        .gmii_rx_dv(gmii_rx_dv), .gmii_rx_er(gmii_rx_er),
        .frame_valid(rx_valid), .frame_len(rx_len),
        .frame_consume(rx_consume), .frame_rd_addr(rx_addr),
        .frame_rd_data(rx_data), .good_frames(rx_good_frames),
        .bad_frames(rx_bad_frames), .dropped_frames(rx_dropped_frames)
    );

    arp_icmp_server u_server (
        .rx_clk(rx_clk), .rst(rst), .rx_frame_valid(rx_valid),
        .rx_frame_len(rx_len), .rx_frame_consume(rx_consume),
        .rx_frame_rd_addr(rx_addr), .rx_frame_rd_data(rx_data),
        .tx_request_toggle(tx_request), .tx_done_toggle(tx_done),
        .tx_frame_len(tx_len), .tx_frame_rd_addr(tx_addr),
        .tx_frame_rd_data(tx_data), .arp_replies(), .icmp_replies(),
        .unsupported_frames(), .response_drops(), .tcp_connections(),
        .tcp_segments(), .tcp_retransmissions(), .app_tx_wr(1'b0),
        .rx_good_frames(rx_good_frames), .rx_bad_frames(rx_bad_frames),
        .rx_dropped_frames(rx_dropped_frames),
        .app_tx_data(8'd0), .app_tcp_tx_full(), .app_tcp_open(),
        .app_session_start(), .rbcp_start(rbcp_start),
        .rbcp_req_addr(rbcp_req_addr), .rbcp_req_wd(rbcp_req_wd),
        .rbcp_req_we(rbcp_req_we), .rbcp_busy(rbcp_busy),
        .rbcp_done(rbcp_done), .rbcp_error(rbcp_error),
        .rbcp_read_data(rbcp_read_data)
    );

    rbcp_cdc_bridge #(.TIMEOUT_CYCLES(32)) u_cdc (
        .src_clk(rx_clk), .src_rst(rst), .src_start(rbcp_start),
        .src_addr(rbcp_req_addr), .src_wd(rbcp_req_wd),
        .src_we(rbcp_req_we), .src_busy(rbcp_busy), .src_done(rbcp_done),
        .src_error(rbcp_error), .src_rd(rbcp_read_data),
        .dst_clk(bus_clk), .dst_rst(rst), .rbcp_act(rbcp_act),
        .rbcp_addr(rbcp_addr), .rbcp_wd(rbcp_wd), .rbcp_we(rbcp_we),
        .rbcp_re(rbcp_re), .rbcp_ack(rbcp_ack), .rbcp_rd(rbcp_rd)
    );

    gmii_tx_frame u_tx (
        .clk(rx_clk), .rst(rst), .request_toggle(tx_request),
        .done_toggle(tx_done), .frame_len(tx_len), .frame_rd_addr(tx_addr),
        .frame_rd_data(tx_data), .gmii_txd(gmii_txd),
        .gmii_tx_en(gmii_tx_en), .gmii_tx_er(), .busy()
    );

    reg [7:0] scratch [0:255];
    integer bus_accesses = 0;
    always @(posedge bus_clk) begin
        rbcp_ack <= 1'b0;
        if (rst) begin
            rbcp_rd <= 0;
        end else if (rbcp_we) begin
            scratch[rbcp_addr[7:0]] <= rbcp_wd;
            rbcp_ack <= 1'b1;
            bus_accesses <= bus_accesses + 1;
        end else if (rbcp_re) begin
            rbcp_rd <= scratch[rbcp_addr[7:0]];
            rbcp_ack <= 1'b1;
            bus_accesses <= bus_accesses + 1;
        end
    end

    reg [7:0] write_request [0:63];
    reg [7:0] write_reply [0:63];
    reg [7:0] read_request [0:63];
    reg [7:0] read_reply [0:63];
    reg [7:0] captured [0:127];
    integer captured_len;
    integer i;

    task automatic send_request(input bit is_read);
        begin
            @(negedge rx_clk);
            gmii_rx_dv = 1'b1;
            for (i = 0; i < 7; i = i + 1) begin
                gmii_rxd = 8'h55;
                @(negedge rx_clk);
            end
            gmii_rxd = 8'hd5;
            @(negedge rx_clk);
            for (i = 0; i < 64; i = i + 1) begin
                gmii_rxd = is_read ? read_request[i] : write_request[i];
                @(negedge rx_clk);
            end
            gmii_rx_dv = 1'b0;
            gmii_rxd = 0;
        end
    endtask

    task automatic receive_and_compare(input bit is_read);
        begin
            captured_len = 0;
            while (!gmii_tx_en) @(negedge rx_clk);
            while (gmii_tx_en) begin
                captured[captured_len] = gmii_txd;
                captured_len = captured_len + 1;
                @(negedge rx_clk);
            end
            if (captured_len != 72)
                $fatal(1, "RBCP wire length %0d, expected 72", captured_len);
            for (i = 0; i < 7; i = i + 1)
                if (captured[i] != 8'h55)
                    $fatal(1, "Bad RBCP preamble byte %0d", i);
            if (captured[7] != 8'hd5)
                $fatal(1, "Bad RBCP SFD");
            for (i = 0; i < 64; i = i + 1)
                if (captured[i+8] !==
                        (is_read ? read_reply[i] : write_reply[i]))
                    $fatal(1, "RBCP reply mismatch at %0d: got %02x expected %02x",
                        i, captured[i+8],
                        is_read ? read_reply[i] : write_reply[i]);
        end
    endtask

    initial begin
        $readmemh("rbcp_write_request.hex", write_request);
        $readmemh("rbcp_write_reply.hex", write_reply);
        $readmemh("rbcp_read_request.hex", read_request);
        $readmemh("rbcp_read_reply.hex", read_reply);
        for (i = 0; i < 256; i = i + 1)
            scratch[i] = 0;
        repeat (10) @(negedge rx_clk);
        rst = 0;

        send_request(0);
        receive_and_compare(0);
        if (scratch[8'h10] != 8'h12 || scratch[8'h11] != 8'h34 ||
                scratch[8'h12] != 8'h56)
            $fatal(1, "RBCP write did not reach sequential bus addresses");

        repeat (20) @(negedge rx_clk);
        send_request(1);
        receive_and_compare(1);
        if (bus_accesses != 6)
            $fatal(1, "Expected 6 byte bus accesses, got %0d", bus_accesses);
        if (rbcp_act || rbcp_we || rbcp_re)
            $fatal(1, "RBCP bus did not return inactive");

        $display("PASS: RBCP UDP write/read, sequential addresses, CDC and replies");
        $finish;
    end

    initial begin
        #200000;
        $fatal(1, "Simulation timeout");
    end
endmodule
