`timescale 1ns / 1ps
module tcp_benchmark_tb;
    reg clk = 0;
    always #4 clk = ~clk;
    reg rst = 1;
    reg [7:0] gmii_rxd = 0;
    reg gmii_rx_dv = 0, gmii_rx_er = 0;
    wire [7:0] gmii_txd;
    wire gmii_tx_en, gmii_tx_er;

    wire rx_valid, rx_consume;
    wire [10:0] rx_len, rx_addr;
    wire [7:0] rx_data;
    wire tx_request, tx_done;
    wire [10:0] tx_len, tx_addr;
    wire [7:0] tx_data;
    wire [31:0] tcp_connections, tcp_segments;

    gmii_rx_frame u_rx (
        .clk(clk), .rst(rst), .gmii_rxd(gmii_rxd), .gmii_rx_dv(gmii_rx_dv),
        .gmii_rx_er(gmii_rx_er), .frame_valid(rx_valid), .frame_len(rx_len),
        .frame_consume(rx_consume), .frame_rd_addr(rx_addr), .frame_rd_data(rx_data),
        .good_frames(), .bad_frames(), .dropped_frames()
    );
    arp_icmp_server u_server (
        .rx_clk(clk), .rst(rst), .rx_frame_valid(rx_valid), .rx_frame_len(rx_len),
        .rx_frame_consume(rx_consume), .rx_frame_rd_addr(rx_addr),
        .rx_frame_rd_data(rx_data), .tx_request_toggle(tx_request),
        .tx_done_toggle(tx_done), .tx_frame_len(tx_len),
        .tx_frame_rd_addr(tx_addr), .tx_frame_rd_data(tx_data),
        .arp_replies(), .icmp_replies(), .unsupported_frames(), .response_drops(),
        .tcp_connections(tcp_connections), .tcp_segments(tcp_segments)
    );
    gmii_tx_frame u_tx (
        .clk(clk), .rst(rst), .request_toggle(tx_request), .done_toggle(tx_done),
        .frame_len(tx_len), .frame_rd_addr(tx_addr), .frame_rd_data(tx_data),
        .gmii_txd(gmii_txd), .gmii_tx_en(gmii_tx_en),
        .gmii_tx_er(gmii_tx_er), .busy()
    );

    reg [7:0] tcp_syn [0:63];
    reg [7:0] tcp_synack [0:63];
    reg [7:0] tcp_ack [0:63];
    reg [7:0] tcp_data0 [0:1517];
    reg [7:0] tcp_ack0 [0:63];
    reg [7:0] tcp_data1 [0:1517];
    reg [7:0] captured [0:2047];
    integer i, captured_len;

    task automatic send_host_frame(input integer kind);
        reg [7:0] value;
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
                case (kind)
                    0: value = tcp_syn[i];
                    1: value = tcp_ack[i];
                    default: value = tcp_ack0[i];
                endcase
                gmii_rxd = value;
                @(negedge clk);
            end
            gmii_rx_dv = 0;
            gmii_rxd = 0;
        end
    endtask

    task automatic receive_and_compare(input integer kind);
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
                $fatal(1, "TCP wire length %0d, expected %0d",
                    captured_len, expected_len + 8);
            for (i = 0; i < 7; i = i + 1)
                if (captured[i] != 8'h55) $fatal(1, "Bad TCP preamble");
            if (captured[7] != 8'hD5) $fatal(1, "Bad TCP SFD");
            for (i = 0; i < expected_len; i = i + 1) begin
                case (kind)
                    0: expected = tcp_synack[i];
                    1: expected = tcp_data0[i];
                    default: expected = tcp_data1[i];
                endcase
                if (captured[i+8] !== expected)
                    $fatal(1, "TCP reply %0d mismatch at %0d: got %02x expected %02x",
                        kind, i, captured[i+8], expected);
            end
        end
    endtask

    initial begin
        $readmemh("tcp_syn.hex", tcp_syn);
        $readmemh("tcp_synack.hex", tcp_synack);
        $readmemh("tcp_ack.hex", tcp_ack);
        $readmemh("tcp_data0.hex", tcp_data0);
        $readmemh("tcp_ack0.hex", tcp_ack0);
        $readmemh("tcp_data1.hex", tcp_data1);
        repeat (8) @(negedge clk);
        rst = 0;

        send_host_frame(0);
        receive_and_compare(0);
        send_host_frame(1);
        receive_and_compare(1);
        send_host_frame(2);
        receive_and_compare(2);
        if (tcp_connections != 1 || tcp_segments < 3)
            $fatal(1, "TCP state counters wrong");
        $display("PASS: TCP handshake, checksums, sequence numbers, ACK window and two 1460-byte counter segments");
        $finish;
    end

    initial begin
        #500000;
        $fatal(1, "TCP simulation timeout");
    end
endmodule
