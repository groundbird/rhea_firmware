`timescale 1ns / 1ps
// All signals synchronous to clk (200 MHz). Each connection sends little-endian
// uint32 values 0,1,2,... . FULL/disable preserves the exact byte position.
module sitcp_benchmark (
    input wire clk, rst,
    input wire tcp_open_ack, tcp_close_req, tcp_error, tcp_tx_full,
    output wire tcp_tx_wr,
    output reg [7:0] tcp_tx_data,
    input wire [31:0] rbcp_addr,
    input wire [7:0] rbcp_wd,
    input wire rbcp_we, rbcp_re,
    output reg rbcp_ack,
    output reg [7:0] rbcp_rd
);
    reg enabled;
    reg [31:0] word_count;
    reg [1:0] byte_index;
    reg open_d, error_d;
    reg [63:0] sent_bytes, open_cycles, full_cycles;
    reg [31:0] connections, errors;
    reg [255:0] snapshot;
    localparam [31:0] CLOCK_HZ = 200000000;

    assign tcp_tx_wr = !rst && enabled && tcp_open_ack &&
                       !tcp_close_req && !tcp_tx_full;
    always @* begin
        case (byte_index)
            0: tcp_tx_data = word_count[7:0];
            1: tcp_tx_data = word_count[15:8];
            2: tcp_tx_data = word_count[23:16];
            3: tcp_tx_data = word_count[31:24];
        endcase
    end

    always @(posedge clk) begin
        if (rst) begin
            enabled <= 1;
            word_count <= 0;
            byte_index <= 0;
            open_d <= 0;
            error_d <= 0;
            sent_bytes <= 0;
            open_cycles <= 0;
            full_cycles <= 0;
            connections <= 0;
            errors <= 0;
            snapshot <= 0;
            rbcp_ack <= 0;
            rbcp_rd <= 0;
        end else begin
            open_d <= tcp_open_ack;
            error_d <= tcp_error;
            if (tcp_open_ack && !open_d) connections <= connections + 1'b1;
            if (tcp_error && !error_d) errors <= errors + 1'b1;
            if (tcp_open_ack) open_cycles <= open_cycles + 1'b1;
            if (tcp_open_ack && tcp_tx_full) full_cycles <= full_cycles + 1'b1;
            if (!tcp_open_ack) begin
                word_count <= 0;
                byte_index <= 0;
            end else if (tcp_tx_wr) begin
                byte_index <= byte_index + 1'b1;
                if (byte_index == 3) word_count <= word_count + 1'b1;
            end
            if (tcp_tx_wr) sent_bytes <= sent_bytes + 1'b1;
            // One-cycle response to each byte request from SiTCP.
            rbcp_ack <= rbcp_we | rbcp_re;
            rbcp_rd <= 0;
            if (rbcp_we) begin
                if (rbcp_addr == 32'h09) enabled <= rbcp_wd[0];
                if (rbcp_addr == 32'h10)
                    snapshot <= {errors, connections, full_cycles, open_cycles, sent_bytes};
            end
            if (rbcp_re) begin
                case (rbcp_addr)
                    0: rbcp_rd <= "S";
                    1: rbcp_rd <= "T";
                    2: rbcp_rd <= "B";
                    3: rbcp_rd <= "1";
                    4: rbcp_rd <= CLOCK_HZ[7:0];
                    5: rbcp_rd <= CLOCK_HZ[15:8];
                    6: rbcp_rd <= CLOCK_HZ[23:16];
                    7: rbcp_rd <= CLOCK_HZ[31:24];
                    8: rbcp_rd <= {4'd0, tcp_error, tcp_close_req, tcp_tx_full, tcp_open_ack};
                    9: rbcp_rd <= {7'd0, enabled};
                    default: begin
                        if (rbcp_addr >= 32'h20 && rbcp_addr < 32'h40)
                            rbcp_rd <= snapshot[8*rbcp_addr[4:0] +: 8];
                    end
                endcase
            end
        end
    end
endmodule
