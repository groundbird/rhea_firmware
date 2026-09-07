`timescale 1ns / 1ps
module tcp_retransmit_tb;
    reg clk = 0;
    always #4 clk = ~clk;
    reg app_clk = 0;
    always #2.5 app_clk = ~app_clk;
    reg rst = 1;
    reg [7:0] gmii_rxd = 0;
    reg gmii_rx_dv = 0, gmii_rx_er = 0;
    wire [7:0] gmii_txd;
    wire gmii_tx_en;
    wire rx_valid, rx_consume;
    wire [10:0] rx_len, rx_addr, tx_len, tx_addr;
    wire [7:0] rx_data, tx_data;
    wire tx_request, tx_done;
    wire [31:0] tcp_retransmissions;
    wire replay_tcp_tx_full, protocol_tcp_open, protocol_session_start;
    wire tcp_tx_full, tcp_open_ack, replay_tx_wr;
    wire [7:0] replay_tx_data;
    reg app_tx_wr = 0;
    reg [29:0] app_word_index = 0;
    reg [1:0] app_byte_select = 0;
    wire [7:0] app_tx_data = app_byte_select == 0
        ? app_word_index[7:0] : app_byte_select == 1
        ? app_word_index[15:8] : app_byte_select == 2
        ? app_word_index[23:16] : {2'b00, app_word_index[29:24]};
    always @(posedge app_clk) begin
        if (rst || !tcp_open_ack) begin
            app_tx_wr <= 0;
            app_word_index <= 0;
            app_byte_select <= 0;
        end else begin
            app_tx_wr <= ~tcp_tx_full;
            if (app_tx_wr) begin
                if (app_byte_select == 3)
                    app_word_index <= app_word_index + 1'b1;
                app_byte_select <= app_byte_select + 1'b1;
            end
        end
    end

    tcp_tx_async_adapter u_tx_cdc (
        .wr_clk(app_clk), .wr_rst(rst),
        .tcp_open_rx(protocol_tcp_open), .tcp_open_ack(tcp_open_ack),
        .tcp_tx_wr(app_tx_wr), .tcp_tx_data(app_tx_data),
        .tcp_tx_full(tcp_tx_full), .overflow_count(),
        .closed_write_count(), .rd_clk(clk), .rd_rst(rst),
        .session_start_rx(protocol_session_start),
        .replay_full(replay_tcp_tx_full), .replay_wr(replay_tx_wr),
        .replay_data(replay_tx_data)
    );

    gmii_rx_frame u_rx (
        .clk(clk), .rst(rst), .gmii_rxd(gmii_rxd), .gmii_rx_dv(gmii_rx_dv),
        .gmii_rx_er(gmii_rx_er), .frame_valid(rx_valid), .frame_len(rx_len),
        .frame_consume(rx_consume), .frame_rd_addr(rx_addr), .frame_rd_data(rx_data),
        .good_frames(), .bad_frames(), .dropped_frames()
    );
    arp_icmp_server #(
        .TCP_CWND_BYTES(32'd1460), .RTO_CYCLES(10000),
        .USE_REPLAY_BUFFER(1)
    ) u_server (
        .rx_clk(clk), .rst(rst), .rx_frame_valid(rx_valid), .rx_frame_len(rx_len),
        .rx_frame_consume(rx_consume), .rx_frame_rd_addr(rx_addr),
        .rx_frame_rd_data(rx_data), .tx_request_toggle(tx_request),
        .tx_done_toggle(tx_done), .tx_frame_len(tx_len),
        .tx_frame_rd_addr(tx_addr), .tx_frame_rd_data(tx_data),
        .arp_replies(), .icmp_replies(), .unsupported_frames(), .response_drops(),
        .tcp_connections(), .tcp_segments(),
        .tcp_retransmissions(tcp_retransmissions),
        .app_tx_wr(replay_tx_wr), .app_tx_data(replay_tx_data),
        .app_tcp_tx_full(replay_tcp_tx_full),
        .app_tcp_open(protocol_tcp_open),
        .app_session_start(protocol_session_start)
    );
    gmii_tx_frame u_tx (
        .clk(clk), .rst(rst), .request_toggle(tx_request), .done_toggle(tx_done),
        .frame_len(tx_len), .frame_rd_addr(tx_addr), .frame_rd_data(tx_data),
        .gmii_txd(gmii_txd), .gmii_tx_en(gmii_tx_en), .gmii_tx_er(), .busy()
    );

    reg [7:0] tcp_syn [0:63];
    reg [7:0] tcp_synack [0:63];
    reg [7:0] tcp_ack [0:63];
    reg [7:0] tcp_data0 [0:1517];
    reg [7:0] tcp_data0_retx [0:1517];
    integer i, captured_len;
    reg [7:0] captured [0:2047];

    task automatic send_frame(input integer kind);
        begin
            @(negedge clk);
            gmii_rx_dv = 1;
            for (i = 0; i < 7; i = i + 1) begin
                gmii_rxd = 8'h55;
                @(negedge clk);
            end
            gmii_rxd = 8'hD5;
            @(negedge clk);
            for (i = 0; i < 64; i = i + 1) begin
                gmii_rxd = kind == 0 ? tcp_syn[i] : tcp_ack[i];
                @(negedge clk);
            end
            gmii_rx_dv = 0;
            gmii_rxd = 0;
        end
    endtask

    task automatic receive_compare(input integer kind);
        integer expected_len;
        reg [7:0] expected;
        begin
            expected_len = kind == 0 ? 64 : 1518;
            captured_len = 0;
            while (!gmii_tx_en) @(negedge clk);
            while (gmii_tx_en) begin
                captured[captured_len] = gmii_txd;
                captured_len = captured_len + 1;
                @(negedge clk);
            end
            if (captured_len != expected_len + 8)
                $fatal(1, "Retransmit wire length mismatch");
            for (i = 0; i < expected_len; i = i + 1) begin
                case (kind)
                    0: expected = tcp_synack[i];
                    1: expected = tcp_data0[i];
                    default: expected = tcp_data0_retx[i];
                endcase
                if (captured[i+8] !== expected)
                    $fatal(1, "Retransmit frame %0d mismatch at %0d", kind, i);
            end
        end
    endtask

    initial begin
        $readmemh("tcp_syn.hex", tcp_syn);
        $readmemh("tcp_synack.hex", tcp_synack);
        $readmemh("tcp_ack.hex", tcp_ack);
        $readmemh("tcp_data0.hex", tcp_data0);
        $readmemh("tcp_data0_retx.hex", tcp_data0_retx);
        repeat (8) @(negedge clk);
        rst = 0;
        send_frame(0);
        receive_compare(0);
        send_frame(1);
        receive_compare(1);
        // Deliberately omit the ACK for data0. The oldest unacknowledged
        // sequence must be regenerated after RTO with a fresh IPv4 ID.
        receive_compare(2);
        if (tcp_retransmissions != 1)
            $fatal(1, "Expected exactly one timeout retransmission");
        $display("PASS: missing ACK triggers retransmission from snd_una");
        $finish;
    end

    initial begin
        #500000;
        $fatal(1, "Retransmission simulation timeout");
    end
endmodule
