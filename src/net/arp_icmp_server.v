`timescale 1ns / 1ps
// Single-buffer ARP and IPv4 ICMP Echo responder. The receive buffer and this
// engine share rx_clk. The transmit buffer is held stable across the toggle
// handshake with gmii_tx_frame.
module arp_icmp_server #(
    parameter [47:0] LOCAL_MAC = 48'h02_52_48_45_41_01,
    parameter [31:0] LOCAL_IP  = {8'd192, 8'd168, 8'd10, 8'd16},
    parameter MAX_FRAME_BYTES = 1536,
    parameter ADDR_WIDTH = 11,
    parameter [31:0] TCP_CWND_BYTES = 32'd14600,
    parameter integer RTO_CYCLES = 125_000_000
) (
    input  wire                  rx_clk,
    input  wire                  rst,
    input  wire                  rx_frame_valid,
    input  wire [ADDR_WIDTH-1:0] rx_frame_len,
    output reg                   rx_frame_consume,
    output reg  [ADDR_WIDTH-1:0] rx_frame_rd_addr,
    input  wire [7:0]            rx_frame_rd_data,
    output reg                   tx_request_toggle,
    input  wire                  tx_done_toggle,
    output reg  [ADDR_WIDTH-1:0] tx_frame_len,
    input  wire [ADDR_WIDTH-1:0] tx_frame_rd_addr,
    output wire [7:0]            tx_frame_rd_data,
    output reg  [31:0]           arp_replies,
    output reg  [31:0]           icmp_replies,
    output reg  [31:0]           unsupported_frames,
    output reg  [31:0]           response_drops,
    output reg  [31:0]           tcp_connections,
    output reg  [31:0]           tcp_segments,
    output reg  [31:0]           tcp_retransmissions
);
    localparam ST_IDLE = 4'd0, ST_PARSE = 4'd1, ST_CHECK = 4'd2,
               ST_BUILD_ARP = 4'd3, ST_BUILD_ICMP = 4'd4,
               ST_WAIT_RX_RELEASE = 4'd5, ST_TCP_CHECKSUM = 4'd6,
               ST_BUILD_TCP = 4'd7, ST_TCP_RX_INIT = 4'd8,
               ST_TCP_RX_PSEUDO = 4'd9, ST_TCP_IP_CHECKSUM = 4'd10,
               ST_TCP_TX_PSEUDO = 4'd11;
    localparam TCP_LISTEN = 2'd0, TCP_SYN_RCVD = 2'd1,
               TCP_ESTABLISHED = 2'd2, TCP_LAST_ACK = 2'd3;
    localparam [15:0] TCP_PORT = 16'd24;
    localparam [31:0] TCP_ISN = 32'h5248_4541;
    localparam [15:0] TCP_PAYLOAD_BYTES = 16'd1460;
    reg [3:0] state;
    reg [1:0] tcp_state;
    reg [ADDR_WIDTH-1:0] index;
    reg [ADDR_WIDTH-1:0] build_len;
    reg [7:0] tx_mem [0:MAX_FRAME_BYTES-1];

    reg tx_done_meta, tx_done_sync;
    wire tx_buffer_busy = tx_done_sync != tx_request_toggle;
    assign tx_frame_rd_data = tx_mem[tx_frame_rd_addr];

    reg [47:0] src_mac;
    reg [31:0] src_ip;
    reg [15:0] eth_type;
    reg [15:0] arp_htype, arp_ptype, arp_oper;
    reg [7:0] arp_hlen, arp_plen;
    reg [31:0] arp_target_ip;
    reg [7:0] ip_vihl, ip_protocol;
    reg [15:0] ip_total_len, ip_fragment;
    reg [31:0] ip_target;
    reg [7:0] icmp_type, icmp_code;
    reg [15:0] icmp_old_checksum;
    reg [15:0] ip_sum, icmp_sum, tcp_rx_sum;
    reg [7:0] ip_high, icmp_high, tcp_rx_high;
    reg [15:0] icmp_reply_checksum;
    reg [7:0] build_data;

    reg [15:0] tcp_src_port, tcp_dst_port, tcp_window;
    reg [31:0] tcp_rx_seq, tcp_rx_ack;
    reg [7:0] tcp_rx_offset, tcp_rx_flags;
    reg [47:0] peer_mac;
    reg [31:0] peer_ip;
    reg [15:0] peer_port, peer_window;
    reg [31:0] rcv_nxt, snd_una, snd_nxt;
    reg [31:0] tcp_build_seq, tcp_build_ack;
    reg [7:0] tcp_build_flags;
    reg [15:0] tcp_build_payload_len;
    reg [15:0] tcp_build_checksum, tcp_build_ip_checksum;
    reg [15:0] tcp_build_ip_id;
    reg [15:0] tcp_calc_sum;
    reg [7:0] tcp_calc_high;
    reg tcp_build_from_rx;
    reg [15:0] tcp_validate_sum;
    reg tcp_checksum_ok;
    reg [15:0] checksum_word;
    reg [31:0] rto_counter;
    reg rto_expired;

    function [15:0] csum_add16;
        input [15:0] sum;
        input [15:0] word;
        reg [16:0] tmp;
        begin
            tmp = {1'b0, sum} + {1'b0, word};
            csum_add16 = tmp[15:0] + tmp[16];
        end
    endfunction

    function [15:0] echo_reply_checksum;
        input [15:0] old_checksum;
        reg [16:0] tmp;
        reg [15:0] folded;
        begin
            // RFC 1624 incremental update: type/code 0x0800 -> 0x0000.
            tmp = {1'b0, ~old_checksum} + 17'h0F7FF;
            folded = tmp[15:0] + tmp[16];
            echo_reply_checksum = ~folded;
        end
    endfunction

    function [7:0] benchmark_payload_byte;
        input [31:0] seq_value;
        input [15:0] offset;
        reg [31:0] byte_offset;
        reg [29:0] word_index;
        begin
            byte_offset = seq_value - (TCP_ISN + 1'b1) + offset;
            word_index = byte_offset[31:2];
            case (byte_offset[1:0])
                2'd0: benchmark_payload_byte = word_index[7:0];
                2'd1: benchmark_payload_byte = word_index[15:8];
                2'd2: benchmark_payload_byte = word_index[23:16];
                default: benchmark_payload_byte = {2'b00, word_index[29:24]};
            endcase
        end
    endfunction

    function [7:0] tcp_segment_byte;
        input [15:0] offset;
        begin
            case (offset)
                0: tcp_segment_byte = TCP_PORT[15:8];
                1: tcp_segment_byte = TCP_PORT[7:0];
                2: tcp_segment_byte = peer_port[15:8];
                3: tcp_segment_byte = peer_port[7:0];
                4: tcp_segment_byte = tcp_build_seq[31:24];
                5: tcp_segment_byte = tcp_build_seq[23:16];
                6: tcp_segment_byte = tcp_build_seq[15:8];
                7: tcp_segment_byte = tcp_build_seq[7:0];
                8: tcp_segment_byte = tcp_build_ack[31:24];
                9: tcp_segment_byte = tcp_build_ack[23:16];
                10: tcp_segment_byte = tcp_build_ack[15:8];
                11: tcp_segment_byte = tcp_build_ack[7:0];
                12: tcp_segment_byte = 8'h50;
                13: tcp_segment_byte = tcp_build_flags;
                14: tcp_segment_byte = 8'h80;
                15: tcp_segment_byte = 8'h00;
                16, 17, 18, 19: tcp_segment_byte = 8'h00;
                default: tcp_segment_byte = benchmark_payload_byte(
                    tcp_build_seq, offset - 16'd20);
            endcase
        end
    endfunction

    wire [15:0] icmp_sum_final = ip_total_len[0]
        ? csum_add16(icmp_sum, {icmp_high, 8'h00}) : icmp_sum;
    wire [15:0] tcp_rx_len = ip_total_len - 16'd20;
    wire [15:0] tcp_rx_payload_len = tcp_rx_len -
        {10'd0, tcp_rx_offset[7:4], 2'b00};
    wire [15:0] tcp_rx_body_sum = tcp_rx_len[0]
        ? csum_add16(tcp_rx_sum, {tcp_rx_high, 8'h00}) : tcp_rx_sum;
    wire valid_arp = eth_type == 16'h0806 && rx_frame_len >= 42 &&
        arp_htype == 16'h0001 && arp_ptype == 16'h0800 &&
        arp_hlen == 8'd6 && arp_plen == 8'd4 && arp_oper == 16'h0001 &&
        arp_target_ip == LOCAL_IP;
    wire valid_icmp = eth_type == 16'h0800 && rx_frame_len >= 42 &&
        ip_vihl == 8'h45 && ip_total_len >= 16'd28 &&
        ip_total_len <= rx_frame_len - 14 && ip_fragment[13:0] == 0 &&
        ip_protocol == 8'd1 && ip_target == LOCAL_IP &&
        ip_sum == 16'hFFFF && icmp_type == 8'd8 && icmp_code == 0 &&
        icmp_sum_final == 16'hFFFF;
    wire valid_tcp = eth_type == 16'h0800 && rx_frame_len >= 54 &&
        ip_vihl == 8'h45 && ip_total_len >= 16'd40 &&
        ip_total_len <= rx_frame_len - 14 && ip_fragment[13:0] == 0 &&
        ip_protocol == 8'd6 && ip_target == LOCAL_IP && ip_sum == 16'hFFFF &&
        tcp_dst_port == TCP_PORT && tcp_rx_offset[7:4] >= 5 &&
        {10'd0, tcp_rx_offset[7:4], 2'b00} <= tcp_rx_len &&
        tcp_checksum_ok;
    wire tcp_peer_match = src_mac == peer_mac && src_ip == peer_ip &&
        tcp_src_port == peer_port;
    wire [31:0] tcp_flight_bytes = snd_nxt - snd_una;
    wire [31:0] tcp_send_limit = ({16'd0, peer_window} < TCP_CWND_BYTES)
        ? {16'd0, peer_window} : TCP_CWND_BYTES;

    always @* begin
        build_data = rx_frame_rd_data;
        checksum_word = 16'd0;
        if (state == ST_TCP_RX_PSEUDO) begin
            case (index)
                0: checksum_word = src_ip[31:16];
                1: checksum_word = src_ip[15:0];
                2: checksum_word = LOCAL_IP[31:16];
                3: checksum_word = LOCAL_IP[15:0];
                4: checksum_word = 16'h0006;
                default: checksum_word = tcp_rx_len;
            endcase
        end else if (state == ST_TCP_IP_CHECKSUM) begin
            case (index)
                0: checksum_word = 16'h4500;
                1: checksum_word = 16'd40 + tcp_build_payload_len;
                2: checksum_word = tcp_build_ip_id;
                3: checksum_word = 16'h4000;
                4: checksum_word = 16'h4006;
                5: checksum_word = 16'h0000;
                6: checksum_word = LOCAL_IP[31:16];
                7: checksum_word = LOCAL_IP[15:0];
                8: checksum_word = peer_ip[31:16];
                default: checksum_word = peer_ip[15:0];
            endcase
        end else if (state == ST_TCP_TX_PSEUDO) begin
            case (index)
                0: checksum_word = LOCAL_IP[31:16];
                1: checksum_word = LOCAL_IP[15:0];
                2: checksum_word = peer_ip[31:16];
                3: checksum_word = peer_ip[15:0];
                4: checksum_word = 16'h0006;
                default: checksum_word = 16'd20 + tcp_build_payload_len;
            endcase
        end
        if (state == ST_BUILD_ARP) begin
            case (index)
                0: build_data = src_mac[47:40];
                1: build_data = src_mac[39:32];
                2: build_data = src_mac[31:24];
                3: build_data = src_mac[23:16];
                4: build_data = src_mac[15:8];
                5: build_data = src_mac[7:0];
                6: build_data = LOCAL_MAC[47:40];
                7: build_data = LOCAL_MAC[39:32];
                8: build_data = LOCAL_MAC[31:24];
                9: build_data = LOCAL_MAC[23:16];
                10: build_data = LOCAL_MAC[15:8];
                11: build_data = LOCAL_MAC[7:0];
                12: build_data = 8'h08; 13: build_data = 8'h06;
                14: build_data = 8'h00; 15: build_data = 8'h01;
                16: build_data = 8'h08; 17: build_data = 8'h00;
                18: build_data = 8'h06; 19: build_data = 8'h04;
                20: build_data = 8'h00; 21: build_data = 8'h02;
                22: build_data = LOCAL_MAC[47:40];
                23: build_data = LOCAL_MAC[39:32];
                24: build_data = LOCAL_MAC[31:24];
                25: build_data = LOCAL_MAC[23:16];
                26: build_data = LOCAL_MAC[15:8];
                27: build_data = LOCAL_MAC[7:0];
                28: build_data = LOCAL_IP[31:24];
                29: build_data = LOCAL_IP[23:16];
                30: build_data = LOCAL_IP[15:8];
                31: build_data = LOCAL_IP[7:0];
                32: build_data = src_mac[47:40];
                33: build_data = src_mac[39:32];
                34: build_data = src_mac[31:24];
                35: build_data = src_mac[23:16];
                36: build_data = src_mac[15:8];
                37: build_data = src_mac[7:0];
                38: build_data = src_ip[31:24];
                39: build_data = src_ip[23:16];
                40: build_data = src_ip[15:8];
                41: build_data = src_ip[7:0];
                default: build_data = 0;
            endcase
        end else if (state == ST_BUILD_ICMP) begin
            case (index)
                0: build_data = src_mac[47:40];
                1: build_data = src_mac[39:32];
                2: build_data = src_mac[31:24];
                3: build_data = src_mac[23:16];
                4: build_data = src_mac[15:8];
                5: build_data = src_mac[7:0];
                6: build_data = LOCAL_MAC[47:40];
                7: build_data = LOCAL_MAC[39:32];
                8: build_data = LOCAL_MAC[31:24];
                9: build_data = LOCAL_MAC[23:16];
                10: build_data = LOCAL_MAC[15:8];
                11: build_data = LOCAL_MAC[7:0];
                26: build_data = LOCAL_IP[31:24];
                27: build_data = LOCAL_IP[23:16];
                28: build_data = LOCAL_IP[15:8];
                29: build_data = LOCAL_IP[7:0];
                30: build_data = src_ip[31:24];
                31: build_data = src_ip[23:16];
                32: build_data = src_ip[15:8];
                33: build_data = src_ip[7:0];
                34: build_data = 8'h00;
                35: build_data = 8'h00;
                36: build_data = icmp_reply_checksum[15:8];
                37: build_data = icmp_reply_checksum[7:0];
                default: build_data = rx_frame_rd_data;
            endcase
        end else if (state == ST_TCP_CHECKSUM) begin
            build_data = tcp_segment_byte(index);
        end else if (state == ST_BUILD_TCP) begin
            case (index)
                0: build_data = peer_mac[47:40];
                1: build_data = peer_mac[39:32];
                2: build_data = peer_mac[31:24];
                3: build_data = peer_mac[23:16];
                4: build_data = peer_mac[15:8];
                5: build_data = peer_mac[7:0];
                6: build_data = LOCAL_MAC[47:40];
                7: build_data = LOCAL_MAC[39:32];
                8: build_data = LOCAL_MAC[31:24];
                9: build_data = LOCAL_MAC[23:16];
                10: build_data = LOCAL_MAC[15:8];
                11: build_data = LOCAL_MAC[7:0];
                12: build_data = 8'h08;
                13: build_data = 8'h00;
                14: build_data = 8'h45;
                15: build_data = 8'h00;
                16: build_data = (16'd40 + tcp_build_payload_len) >> 8;
                17: build_data = 16'd40 + tcp_build_payload_len;
                18: build_data = tcp_build_ip_id[15:8];
                19: build_data = tcp_build_ip_id[7:0];
                20: build_data = 8'h40;
                21: build_data = 8'h00;
                22: build_data = 8'd64;
                23: build_data = 8'd6;
                24: build_data = tcp_build_ip_checksum[15:8];
                25: build_data = tcp_build_ip_checksum[7:0];
                26: build_data = LOCAL_IP[31:24];
                27: build_data = LOCAL_IP[23:16];
                28: build_data = LOCAL_IP[15:8];
                29: build_data = LOCAL_IP[7:0];
                30: build_data = peer_ip[31:24];
                31: build_data = peer_ip[23:16];
                32: build_data = peer_ip[15:8];
                33: build_data = peer_ip[7:0];
                50: build_data = tcp_build_checksum[15:8];
                51: build_data = tcp_build_checksum[7:0];
                default: build_data = tcp_segment_byte(index - 16'd34);
            endcase
        end
    end

    always @(posedge rx_clk) begin
        if (rst) begin
            state <= ST_IDLE;
            index <= 0;
            build_len <= 0;
            rx_frame_consume <= 0;
            rx_frame_rd_addr <= 0;
            tx_request_toggle <= 0;
            tx_done_meta <= 0;
            tx_done_sync <= 0;
            tx_frame_len <= 0;
            arp_replies <= 0;
            icmp_replies <= 0;
            unsupported_frames <= 0;
            response_drops <= 0;
            tcp_connections <= 0;
            tcp_segments <= 0;
            tcp_retransmissions <= 0;
            tcp_state <= TCP_LISTEN;
            src_mac <= 0; src_ip <= 0; eth_type <= 0;
            arp_htype <= 0; arp_ptype <= 0; arp_oper <= 0;
            arp_hlen <= 0; arp_plen <= 0; arp_target_ip <= 0;
            ip_vihl <= 0; ip_protocol <= 0; ip_total_len <= 0;
            ip_fragment <= 0; ip_target <= 0;
            icmp_type <= 0; icmp_code <= 0; icmp_old_checksum <= 0;
            ip_sum <= 0; icmp_sum <= 0; tcp_rx_sum <= 0;
            ip_high <= 0; icmp_high <= 0; tcp_rx_high <= 0;
            icmp_reply_checksum <= 0;
            tcp_src_port <= 0; tcp_dst_port <= 0; tcp_window <= 0;
            tcp_rx_seq <= 0; tcp_rx_ack <= 0; tcp_rx_offset <= 0;
            tcp_rx_flags <= 0; peer_mac <= 0; peer_ip <= 0; peer_port <= 0;
            peer_window <= 0; rcv_nxt <= 0; snd_una <= 0; snd_nxt <= 0;
            tcp_build_seq <= 0; tcp_build_ack <= 0; tcp_build_flags <= 0;
            tcp_build_payload_len <= 0; tcp_build_checksum <= 0;
            tcp_build_ip_checksum <= 0; tcp_build_ip_id <= 0;
            tcp_calc_sum <= 0; tcp_calc_high <= 0; tcp_build_from_rx <= 0;
            tcp_validate_sum <= 0; tcp_checksum_ok <= 0;
            rto_counter <= 0; rto_expired <= 0;
        end else begin
            tx_done_meta <= tx_done_toggle;
            tx_done_sync <= tx_done_meta;
            rx_frame_consume <= 0;
            if (tcp_state == TCP_LISTEN || snd_una == snd_nxt) begin
                rto_counter <= 0;
                rto_expired <= 0;
            end else if (!rto_expired) begin
                if (rto_counter >= RTO_CYCLES - 1) begin
                    rto_counter <= 0;
                    rto_expired <= 1;
                end else begin
                    rto_counter <= rto_counter + 1'b1;
                end
            end
            case (state)
                ST_IDLE: begin
                    if (rx_frame_valid) begin
                        index <= 0;
                        rx_frame_rd_addr <= 0;
                        src_mac <= 0; src_ip <= 0; eth_type <= 0;
                        arp_htype <= 0; arp_ptype <= 0; arp_oper <= 0;
                        arp_hlen <= 0; arp_plen <= 0; arp_target_ip <= 0;
                        ip_vihl <= 0; ip_protocol <= 0; ip_total_len <= 0;
                        ip_fragment <= 0; ip_target <= 0;
                        icmp_type <= 0; icmp_code <= 0; icmp_old_checksum <= 0;
                        tcp_src_port <= 0; tcp_dst_port <= 0; tcp_window <= 0;
                        tcp_rx_seq <= 0; tcp_rx_ack <= 0; tcp_rx_offset <= 0;
                        tcp_rx_flags <= 0;
                        tcp_checksum_ok <= 0;
                        ip_sum <= 0; icmp_sum <= 0; tcp_rx_sum <= 0;
                        ip_high <= 0; icmp_high <= 0; tcp_rx_high <= 0;
                        state <= ST_PARSE;
                    end else if (rto_expired && tcp_state != TCP_LISTEN &&
                            !tx_buffer_busy) begin
                        tcp_build_seq <= tcp_state == TCP_SYN_RCVD ? TCP_ISN :
                            (tcp_state == TCP_LAST_ACK ? snd_nxt - 1'b1 : snd_una);
                        tcp_build_ack <= rcv_nxt;
                        tcp_build_flags <= tcp_state == TCP_SYN_RCVD ? 8'h12 :
                            (tcp_state == TCP_LAST_ACK ? 8'h11 : 8'h18);
                        tcp_build_payload_len <= tcp_state == TCP_ESTABLISHED
                            ? TCP_PAYLOAD_BYTES : 16'd0;
                        tcp_build_ip_id <= tcp_build_ip_id + 1'b1;
                        tcp_calc_sum <= 0;
                        tcp_calc_high <= 0;
                        index <= 0;
                        tcp_build_from_rx <= 0;
                        tcp_retransmissions <= tcp_retransmissions + 1'b1;
                        rto_counter <= 0;
                        rto_expired <= 0;
                        state <= ST_TCP_IP_CHECKSUM;
                    end else if (tcp_state == TCP_ESTABLISHED && !tx_buffer_busy &&
                            tcp_send_limit >= TCP_PAYLOAD_BYTES &&
                            tcp_flight_bytes <= tcp_send_limit - TCP_PAYLOAD_BYTES) begin
                        tcp_build_seq <= snd_nxt;
                        tcp_build_ack <= rcv_nxt;
                        tcp_build_flags <= 8'h18;
                        tcp_build_payload_len <= TCP_PAYLOAD_BYTES;
                        tcp_build_ip_id <= tcp_build_ip_id + 1'b1;
                        tcp_calc_sum <= 0;
                        tcp_calc_high <= 0;
                        index <= 0;
                        tcp_build_from_rx <= 0;
                        snd_nxt <= snd_nxt + TCP_PAYLOAD_BYTES;
                        state <= ST_TCP_IP_CHECKSUM;
                    end
                end
                ST_PARSE: begin
                    if (index >= 6 && index <= 11)
                        src_mac[47 - 8*(index-6) -: 8] <= rx_frame_rd_data;
                    if (index == 12 || index == 13)
                        eth_type <= {eth_type[7:0], rx_frame_rd_data};
                    if (index == 14 || index == 15)
                        arp_htype <= {arp_htype[7:0], rx_frame_rd_data};
                    if (index == 16 || index == 17)
                        arp_ptype <= {arp_ptype[7:0], rx_frame_rd_data};
                    if (index == 18) arp_hlen <= rx_frame_rd_data;
                    if (index == 19) arp_plen <= rx_frame_rd_data;
                    if (index == 20 || index == 21)
                        arp_oper <= {arp_oper[7:0], rx_frame_rd_data};
                    if (index >= 28 && index <= 31 && eth_type == 16'h0806)
                        src_ip[31 - 8*(index-28) -: 8] <= rx_frame_rd_data;
                    if (index >= 38 && index <= 41)
                        arp_target_ip[31 - 8*(index-38) -: 8] <= rx_frame_rd_data;

                    if (index == 14) ip_vihl <= rx_frame_rd_data;
                    if (index == 16 || index == 17)
                        ip_total_len <= {ip_total_len[7:0], rx_frame_rd_data};
                    if (index == 20 || index == 21)
                        ip_fragment <= {ip_fragment[7:0], rx_frame_rd_data};
                    if (index == 23) ip_protocol <= rx_frame_rd_data;
                    if (index >= 26 && index <= 29 && eth_type == 16'h0800)
                        src_ip[31 - 8*(index-26) -: 8] <= rx_frame_rd_data;
                    if (index >= 30 && index <= 33)
                        ip_target[31 - 8*(index-30) -: 8] <= rx_frame_rd_data;
                    if (index == 34) icmp_type <= rx_frame_rd_data;
                    if (index == 35) icmp_code <= rx_frame_rd_data;
                    if (index == 36 || index == 37)
                        icmp_old_checksum <= {icmp_old_checksum[7:0], rx_frame_rd_data};

                    if (index == 34 || index == 35)
                        tcp_src_port <= {tcp_src_port[7:0], rx_frame_rd_data};
                    if (index == 36 || index == 37)
                        tcp_dst_port <= {tcp_dst_port[7:0], rx_frame_rd_data};
                    if (index >= 38 && index <= 41)
                        tcp_rx_seq <= {tcp_rx_seq[23:0], rx_frame_rd_data};
                    if (index >= 42 && index <= 45)
                        tcp_rx_ack <= {tcp_rx_ack[23:0], rx_frame_rd_data};
                    if (index == 46) tcp_rx_offset <= rx_frame_rd_data;
                    if (index == 47) tcp_rx_flags <= rx_frame_rd_data;
                    if (index == 48 || index == 49)
                        tcp_window <= {tcp_window[7:0], rx_frame_rd_data};

                    if (index >= 14 && index < 34) begin
                        if (!index[0]) ip_high <= rx_frame_rd_data;
                        else ip_sum <= csum_add16(ip_sum, {ip_high, rx_frame_rd_data});
                    end
                    if (index >= 34 && index < 14 + ip_total_len) begin
                        if (!index[0]) icmp_high <= rx_frame_rd_data;
                        else icmp_sum <= csum_add16(icmp_sum, {icmp_high, rx_frame_rd_data});
                        if (!index[0]) tcp_rx_high <= rx_frame_rd_data;
                        else tcp_rx_sum <= csum_add16(tcp_rx_sum,
                            {tcp_rx_high, rx_frame_rd_data});
                    end

                    if (index == rx_frame_len - 1'b1) begin
                        if (eth_type == 16'h0800 && ip_protocol == 8'd6)
                            state <= ST_TCP_RX_INIT;
                        else
                            state <= ST_CHECK;
                    end else begin
                        index <= index + 1'b1;
                        rx_frame_rd_addr <= index + 1'b1;
                    end
                end
                ST_TCP_RX_INIT: begin
                    tcp_validate_sum <= tcp_rx_body_sum;
                    index <= 0;
                    state <= ST_TCP_RX_PSEUDO;
                end
                ST_TCP_RX_PSEUDO: begin
                    if (index == 5) begin
                        tcp_checksum_ok <=
                            csum_add16(tcp_validate_sum, checksum_word) == 16'hFFFF;
                        state <= ST_CHECK;
                    end else begin
                        tcp_validate_sum <= csum_add16(tcp_validate_sum,
                            checksum_word);
                        index <= index + 1'b1;
                    end
                end
                ST_CHECK: begin
                    if (valid_arp || valid_icmp) begin
                        if (tx_buffer_busy) begin
                            response_drops <= response_drops + 1'b1;
                            rx_frame_consume <= 1;
                            state <= ST_WAIT_RX_RELEASE;
                        end else begin
                            index <= 0;
                            rx_frame_rd_addr <= 0;
                            if (valid_arp) begin
                                build_len <= 42;
                                state <= ST_BUILD_ARP;
                            end else begin
                                build_len <= 14 + ip_total_len;
                                icmp_reply_checksum <= echo_reply_checksum(icmp_old_checksum);
                                state <= ST_BUILD_ICMP;
                            end
                        end
                    end else if (valid_tcp) begin
                        rx_frame_consume <= 1;
                        if (tcp_state == TCP_LISTEN && tcp_rx_flags[1] &&
                                !tcp_rx_flags[4] && !tx_buffer_busy) begin
                            peer_mac <= src_mac;
                            peer_ip <= src_ip;
                            peer_port <= tcp_src_port;
                            peer_window <= tcp_window;
                            rcv_nxt <= tcp_rx_seq + 1'b1;
                            snd_una <= TCP_ISN;
                            snd_nxt <= TCP_ISN + 1'b1;
                            tcp_build_seq <= TCP_ISN;
                            tcp_build_ack <= tcp_rx_seq + 1'b1;
                            tcp_build_flags <= 8'h12;
                            tcp_build_payload_len <= 0;
                            tcp_build_ip_id <= tcp_build_ip_id + 1'b1;
                            tcp_calc_sum <= 0;
                            tcp_calc_high <= 0;
                            tcp_build_from_rx <= 1;
                            index <= 0;
                            tcp_state <= TCP_SYN_RCVD;
                            rto_counter <= 0;
                            rto_expired <= 0;
                            state <= ST_TCP_IP_CHECKSUM;
                        end else if (tcp_state != TCP_LISTEN && tcp_peer_match &&
                                tcp_rx_flags[2]) begin
                            tcp_state <= TCP_LISTEN;
                            snd_una <= 0;
                            snd_nxt <= 0;
                            rto_counter <= 0;
                            rto_expired <= 0;
                            state <= ST_WAIT_RX_RELEASE;
                        end else if (tcp_state == TCP_SYN_RCVD && tcp_peer_match &&
                                tcp_rx_flags[1] && !tcp_rx_flags[4] &&
                                tcp_rx_seq + 1'b1 == rcv_nxt && !tx_buffer_busy) begin
                            tcp_build_seq <= TCP_ISN;
                            tcp_build_ack <= rcv_nxt;
                            tcp_build_flags <= 8'h12;
                            tcp_build_payload_len <= 0;
                            tcp_build_ip_id <= tcp_build_ip_id + 1'b1;
                            tcp_calc_sum <= 0;
                            tcp_calc_high <= 0;
                            tcp_build_from_rx <= 1;
                            index <= 0;
                            rto_counter <= 0;
                            rto_expired <= 0;
                            tcp_retransmissions <= tcp_retransmissions + 1'b1;
                            state <= ST_TCP_IP_CHECKSUM;
                        end else if (tcp_state == TCP_SYN_RCVD && tcp_peer_match &&
                                tcp_rx_flags[4] && tcp_rx_ack == TCP_ISN + 1'b1) begin
                            snd_una <= tcp_rx_ack;
                            peer_window <= tcp_window;
                            tcp_state <= TCP_ESTABLISHED;
                            tcp_connections <= tcp_connections + 1'b1;
                            rto_counter <= 0;
                            rto_expired <= 0;
                            state <= ST_WAIT_RX_RELEASE;
                        end else if (tcp_state == TCP_ESTABLISHED && tcp_peer_match &&
                                tcp_rx_flags[4]) begin
                            if (tcp_rx_ack > snd_una && tcp_rx_ack <= snd_nxt) begin
                                snd_una <= tcp_rx_ack;
                                rto_counter <= 0;
                                rto_expired <= 0;
                            end
                            peer_window <= tcp_window;
                            if (tcp_rx_flags[0] && !tx_buffer_busy) begin
                                rcv_nxt <= tcp_rx_seq + tcp_rx_payload_len + 1'b1;
                                tcp_build_seq <= snd_nxt;
                                tcp_build_ack <= tcp_rx_seq + tcp_rx_payload_len + 1'b1;
                                tcp_build_flags <= 8'h11;
                                tcp_build_payload_len <= 0;
                                tcp_build_ip_id <= tcp_build_ip_id + 1'b1;
                                tcp_calc_sum <= 0;
                                tcp_calc_high <= 0;
                                tcp_build_from_rx <= 1;
                                index <= 0;
                                snd_nxt <= snd_nxt + 1'b1;
                                tcp_state <= TCP_LAST_ACK;
                                state <= ST_TCP_IP_CHECKSUM;
                            end else begin
                                state <= ST_WAIT_RX_RELEASE;
                            end
                        end else if (tcp_state == TCP_LAST_ACK && tcp_peer_match &&
                                tcp_rx_flags[4] && tcp_rx_ack == snd_nxt) begin
                            tcp_state <= TCP_LISTEN;
                            rto_counter <= 0;
                            rto_expired <= 0;
                            state <= ST_WAIT_RX_RELEASE;
                        end else begin
                            unsupported_frames <= unsupported_frames + 1'b1;
                            state <= ST_WAIT_RX_RELEASE;
                        end
                    end else begin
                        unsupported_frames <= unsupported_frames + 1'b1;
                        rx_frame_consume <= 1;
                        state <= ST_WAIT_RX_RELEASE;
                    end
                end
                ST_BUILD_ARP, ST_BUILD_ICMP: begin
                    tx_mem[index] <= build_data;
                    if (index == build_len - 1'b1) begin
                        tx_frame_len <= build_len;
                        tx_request_toggle <= ~tx_request_toggle;
                        rx_frame_consume <= 1;
                        if (state == ST_BUILD_ARP)
                            arp_replies <= arp_replies + 1'b1;
                        else
                            icmp_replies <= icmp_replies + 1'b1;
                        state <= ST_WAIT_RX_RELEASE;
                    end else begin
                        index <= index + 1'b1;
                        rx_frame_rd_addr <= index + 1'b1;
                    end
                end
                ST_TCP_IP_CHECKSUM: begin
                    if (index == 9) begin
                        tcp_build_ip_checksum <=
                            ~csum_add16(tcp_calc_sum, checksum_word);
                        tcp_calc_sum <= 0;
                        index <= 0;
                        state <= ST_TCP_TX_PSEUDO;
                    end else begin
                        tcp_calc_sum <= csum_add16(tcp_calc_sum, checksum_word);
                        index <= index + 1'b1;
                    end
                end
                ST_TCP_TX_PSEUDO: begin
                    if (index == 5) begin
                        tcp_calc_sum <= csum_add16(tcp_calc_sum, checksum_word);
                        index <= 0;
                        state <= ST_TCP_CHECKSUM;
                    end else begin
                        tcp_calc_sum <= csum_add16(tcp_calc_sum, checksum_word);
                        index <= index + 1'b1;
                    end
                end
                ST_TCP_CHECKSUM: begin
                    if (!index[0]) begin
                        tcp_calc_high <= build_data;
                    end else begin
                        tcp_calc_sum <= csum_add16(tcp_calc_sum,
                            {tcp_calc_high, build_data});
                    end
                    if (index == 16'd19 + tcp_build_payload_len) begin
                        tcp_build_checksum <= ~csum_add16(tcp_calc_sum,
                            {tcp_calc_high, build_data});
                        build_len <= 16'd54 + tcp_build_payload_len;
                        index <= 0;
                        state <= ST_BUILD_TCP;
                    end else begin
                        index <= index + 1'b1;
                    end
                end
                ST_BUILD_TCP: begin
                    tx_mem[index] <= build_data;
                    if (index == build_len - 1'b1) begin
                        tx_frame_len <= build_len;
                        tx_request_toggle <= ~tx_request_toggle;
                        tcp_segments <= tcp_segments + 1'b1;
                        if (tcp_build_from_rx)
                            state <= ST_WAIT_RX_RELEASE;
                        else
                            state <= ST_IDLE;
                    end else begin
                        index <= index + 1'b1;
                    end
                end
                ST_WAIT_RX_RELEASE: begin
                    if (!rx_frame_valid)
                        state <= ST_IDLE;
                end
            endcase
        end
    end
endmodule
