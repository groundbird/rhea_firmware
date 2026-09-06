`timescale 1ns / 1ps
module arp_icmp_tb;
    reg clk = 0;
    always #4 clk = ~clk; // GMII 125 MHz
    reg rst = 1;
    reg [7:0] gmii_rxd = 0;
    reg gmii_rx_dv = 0, gmii_rx_er = 0;
    wire [7:0] gmii_txd;
    wire gmii_tx_en, gmii_tx_er;

    wire rx_valid, rx_consume;
    wire [10:0] rx_len, rx_addr;
    wire [7:0] rx_data;
    wire [31:0] good_frames, bad_frames, dropped_frames;
    wire tx_request, tx_done;
    wire [10:0] tx_len, tx_addr;
    wire [7:0] tx_data;
    wire [31:0] arp_replies, icmp_replies, unsupported_frames, response_drops;

    gmii_rx_frame u_rx (
        .clk(clk), .rst(rst), .gmii_rxd(gmii_rxd), .gmii_rx_dv(gmii_rx_dv),
        .gmii_rx_er(gmii_rx_er), .frame_valid(rx_valid), .frame_len(rx_len),
        .frame_consume(rx_consume), .frame_rd_addr(rx_addr), .frame_rd_data(rx_data),
        .good_frames(good_frames), .bad_frames(bad_frames), .dropped_frames(dropped_frames)
    );
    arp_icmp_server u_server (
        .rx_clk(clk), .rst(rst), .rx_frame_valid(rx_valid), .rx_frame_len(rx_len),
        .rx_frame_consume(rx_consume), .rx_frame_rd_addr(rx_addr),
        .rx_frame_rd_data(rx_data), .tx_request_toggle(tx_request),
        .tx_done_toggle(tx_done), .tx_frame_len(tx_len),
        .tx_frame_rd_addr(tx_addr), .tx_frame_rd_data(tx_data),
        .arp_replies(arp_replies), .icmp_replies(icmp_replies),
        .unsupported_frames(unsupported_frames), .response_drops(response_drops),
        .tcp_connections(), .tcp_segments()
    );
    gmii_tx_frame u_tx (
        .clk(clk), .rst(rst), .request_toggle(tx_request), .done_toggle(tx_done),
        .frame_len(tx_len), .frame_rd_addr(tx_addr), .frame_rd_data(tx_data),
        .gmii_txd(gmii_txd), .gmii_tx_en(gmii_tx_en), .gmii_tx_er(gmii_tx_er), .busy()
    );

    reg [7:0] arp_request [0:63];
    reg [7:0] arp_reply [0:63];
    reg [7:0] icmp_request [0:73];
    reg [7:0] icmp_reply [0:73];
    reg [7:0] wrong_ip_request [0:73];
    reg [7:0] captured [0:2047];
    integer captured_len = 0;
    integer i;

    task automatic send_arp(input bit corrupt_fcs);
        begin
            @(negedge clk); gmii_rx_dv = 1;
            for (i = 0; i < 7; i++) begin gmii_rxd = 8'h55; @(negedge clk); end
            gmii_rxd = 8'hD5; @(negedge clk);
            for (i = 0; i < 64; i++) begin
                gmii_rxd = arp_request[i] ^ ((corrupt_fcs && i == 63) ? 8'h01 : 0);
                @(negedge clk);
            end
            gmii_rx_dv = 0; gmii_rxd = 0;
        end
    endtask

    task automatic send_icmp(input bit wrong_ip);
        begin
            @(negedge clk); gmii_rx_dv = 1;
            for (i = 0; i < 7; i++) begin gmii_rxd = 8'h55; @(negedge clk); end
            gmii_rxd = 8'hD5; @(negedge clk);
            for (i = 0; i < 74; i++) begin
                gmii_rxd = wrong_ip ? wrong_ip_request[i] : icmp_request[i];
                @(negedge clk);
            end
            gmii_rx_dv = 0; gmii_rxd = 0;
        end
    endtask

    task automatic receive_and_compare(input bit arp);
        integer expected_len;
        begin
            expected_len = arp ? 64 : 74;
            captured_len = 0;
            while (!gmii_tx_en) @(negedge clk);
            while (gmii_tx_en) begin
                captured[captured_len] = gmii_txd;
                captured_len++;
                @(negedge clk);
            end
            if (captured_len != expected_len + 8)
                $fatal(1, "Wire length %0d, expected %0d", captured_len, expected_len + 8);
            for (i = 0; i < 7; i++)
                if (captured[i] != 8'h55) $fatal(1, "Bad preamble byte %0d", i);
            if (captured[7] != 8'hD5) $fatal(1, "Bad SFD");
            for (i = 0; i < expected_len; i++) begin
                if (captured[i+8] !== (arp ? arp_reply[i] : icmp_reply[i]))
                    $fatal(1, "Reply mismatch at %0d: got %02x", i, captured[i+8]);
            end
        end
    endtask

    initial begin
        $readmemh("arp_request.hex", arp_request);
        $readmemh("arp_reply.hex", arp_reply);
        $readmemh("icmp_request.hex", icmp_request);
        $readmemh("icmp_reply.hex", icmp_reply);
        $readmemh("wrong_ip_request.hex", wrong_ip_request);
        repeat (8) @(negedge clk);
        rst = 0;

        send_arp(0);
        receive_and_compare(1);
        repeat (20) @(negedge clk);
        if (arp_replies != 1 || good_frames != 1 || bad_frames != 0)
            $fatal(1, "ARP counters wrong");

        send_icmp(0);
        receive_and_compare(0);
        repeat (20) @(negedge clk);
        if (icmp_replies != 1 || good_frames != 2)
            $fatal(1, "ICMP counters wrong");

        send_arp(1);
        repeat (300) @(negedge clk);
        if (bad_frames != 1 || arp_replies != 1)
            $fatal(1, "Bad FCS was not rejected");

        send_icmp(1);
        repeat (300) @(negedge clk);
        $display("wrong-IP counters: unsupported=%0d icmp=%0d good=%0d bad=%0d dropped=%0d response_drops=%0d",
            unsupported_frames, icmp_replies, good_frames, bad_frames,
            dropped_frames, response_drops);
        if (unsupported_frames != 1 || icmp_replies != 1 || good_frames != 3)
            $fatal(1, "Wrong destination IP was not rejected");
        if (response_drops != 0 || dropped_frames != 0)
            $fatal(1, "Unexpected buffer drop");

        $display("PASS: Ethernet FCS, padding/IFG, ARP reply, ICMP echo, bad FCS and wrong-IP rejection");
        $finish;
    end
    initial begin
        #200000;
        $fatal(1, "Simulation timeout");
    end
endmodule
