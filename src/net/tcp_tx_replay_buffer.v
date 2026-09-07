`timescale 1ns / 1ps

// Byte-addressed TCP replay ring. TCP sequence numbers are used directly as
// ring addresses, so wrap at 2^32 does not require special address handling.
// ACK updates must already be limited to data actually transmitted by the TCB.
module tcp_tx_replay_buffer #(
    parameter ADDR_WIDTH = 15,
    parameter DEPTH_BYTES = (1 << ADDR_WIDTH),
    parameter FULL_GUARD_BYTES = 8
) (
    input  wire                  clk,
    input  wire                  rst,
    input  wire                  session_start,
    input  wire [31:0]           session_first_seq,

    input  wire                  tx_wr,
    input  wire [7:0]            tx_data,
    output wire                  tcp_tx_full,
    output reg  [31:0]           overflow_count,

    input  wire                  ack_valid,
    input  wire [31:0]           ack_seq,
    output reg  [31:0]           invalid_ack_count,

    input  wire [31:0]           read_seq,
    output reg  [7:0]            read_data,

    output reg  [31:0]           first_stored_seq,
    output reg  [31:0]           write_seq,
    output wire [ADDR_WIDTH:0]   buffered_bytes
);
    (* ram_style = "block" *) reg [7:0] memory [0:DEPTH_BYTES-1];

    wire [31:0] stored_distance = write_seq - first_stored_seq;
    wire [31:0] ack_distance = ack_seq - first_stored_seq;
    wire can_write = stored_distance < DEPTH_BYTES;

    assign buffered_bytes = stored_distance[ADDR_WIDTH:0];
    // SiTCP permits up to eight writes after FULL rises. Assert early while
    // retaining physical space for those already-pipelined bytes.
    assign tcp_tx_full = stored_distance >= DEPTH_BYTES - FULL_GUARD_BYTES;

    always @(posedge clk) begin
        read_data <= memory[read_seq[ADDR_WIDTH-1:0]];
        if (rst) begin
            first_stored_seq <= 0;
            write_seq <= 0;
            overflow_count <= 0;
            invalid_ack_count <= 0;
            read_data <= 0;
        end else if (session_start) begin
            first_stored_seq <= session_first_seq;
            write_seq <= session_first_seq;
        end else begin
            if (tx_wr) begin
                if (can_write) begin
                    memory[write_seq[ADDR_WIDTH-1:0]] <= tx_data;
                    write_seq <= write_seq + 1'b1;
                end else begin
                    overflow_count <= overflow_count + 1'b1;
                end
            end

            if (ack_valid) begin
                // Distances are unambiguous because the ring is much smaller
                // than half of the 32-bit TCP sequence space.
                if (ack_distance <= stored_distance)
                    first_stored_seq <= ack_seq;
                else
                    invalid_ack_count <= invalid_ack_count + 1'b1;
            end
        end
    end
endmodule
