`timescale 1ns / 1ps

// Clock-domain adapter for the SiTCP-style byte transmit interface.
// The user side is normally clk_int_200; the replay-buffer side runs from
// the PHY receive clock. FULL asserts with eight FIFO locations reserved for
// writes already in the upstream pipeline.
module tcp_tx_async_adapter #(
    parameter ADDR_WIDTH = 6,
    parameter DEPTH_BYTES = (1 << ADDR_WIDTH),
    parameter FULL_GUARD_BYTES = 8
) (
    input  wire       wr_clk,
    input  wire       wr_rst,
    input  wire       tcp_open_rx,
    output wire       tcp_open_ack,
    input  wire       tcp_tx_wr,
    input  wire [7:0] tcp_tx_data,
    output wire       tcp_tx_full,
    output reg [31:0] overflow_count,
    output reg [31:0] closed_write_count,

    input  wire       rd_clk,
    input  wire       rd_rst,
    input  wire       session_start_rx,
    input  wire       replay_full,
    output reg        replay_wr,
    output reg  [7:0] replay_data
);
    localparam PTR_WIDTH = ADDR_WIDTH + 1;
    (* ram_style = "distributed" *) reg [7:0] memory [0:DEPTH_BYTES-1];

    reg [PTR_WIDTH-1:0] wr_bin, wr_gray;
    reg [PTR_WIDTH-1:0] rd_bin, rd_gray;
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *)
    reg [PTR_WIDTH-1:0] rd_gray_meta, rd_gray_sync;
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *)
    reg [PTR_WIDTH-1:0] wr_gray_meta, wr_gray_sync;
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg open_meta, open_sync;
    reg session_toggle;
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *)
    reg session_meta, session_sync;
    reg session_seen;
    reg session_ack;
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *)
    reg session_ack_meta, session_ack_sync;

    function [PTR_WIDTH-1:0] gray_to_bin;
        input [PTR_WIDTH-1:0] gray;
        integer bit_index;
        begin
            gray_to_bin[PTR_WIDTH-1] = gray[PTR_WIDTH-1];
            for (bit_index = PTR_WIDTH-2; bit_index >= 0;
                    bit_index = bit_index - 1)
                gray_to_bin[bit_index] = gray_to_bin[bit_index+1] ^
                    gray[bit_index];
        end
    endfunction

    wire [PTR_WIDTH-1:0] rd_bin_sync = gray_to_bin(rd_gray_sync);
    wire [PTR_WIDTH-1:0] wr_used = wr_bin - rd_bin_sync;
    wire fifo_physical_full = wr_used == DEPTH_BYTES;
    wire fifo_empty = rd_gray == wr_gray_sync;
    wire read_session_ready = session_ack_sync == session_toggle;
    assign tcp_open_ack = open_sync;
    assign tcp_tx_full = !open_sync ||
        wr_used >= DEPTH_BYTES - FULL_GUARD_BYTES;

    always @(posedge rd_clk or posedge rd_rst) begin
        if (rd_rst) begin
            session_toggle <= 0;
        end else if (session_start_rx) begin
            session_toggle <= ~session_toggle;
        end
    end

    always @(posedge wr_clk) begin
        if (wr_rst) begin
            open_meta <= 0;
            open_sync <= 0;
            session_meta <= 0;
            session_sync <= 0;
            session_seen <= 0;
            session_ack <= 0;
            rd_gray_meta <= 0;
            rd_gray_sync <= 0;
            wr_bin <= 0;
            wr_gray <= 0;
            overflow_count <= 0;
            closed_write_count <= 0;
        end else begin
            open_meta <= tcp_open_rx;
            open_sync <= open_meta;
            session_meta <= session_toggle;
            session_sync <= session_meta;
            rd_gray_meta <= rd_gray;
            rd_gray_sync <= rd_gray_meta;

            if (session_sync != session_seen) begin
                session_seen <= session_sync;
                session_ack <= session_sync;
                rd_gray_meta <= 0;
                rd_gray_sync <= 0;
                wr_bin <= 0;
                wr_gray <= 0;
            end else if (tcp_tx_wr) begin
                if (!open_sync) begin
                    closed_write_count <= closed_write_count + 1'b1;
                end else if (!fifo_physical_full) begin
                    memory[wr_bin[ADDR_WIDTH-1:0]] <= tcp_tx_data;
                    wr_bin <= wr_bin + 1'b1;
                    wr_gray <= ((wr_bin + 1'b1) >> 1) ^ (wr_bin + 1'b1);
                end else begin
                    overflow_count <= overflow_count + 1'b1;
                end
            end
        end
    end

    always @(posedge rd_clk) begin
        if (rd_rst) begin
            wr_gray_meta <= 0;
            wr_gray_sync <= 0;
            rd_bin <= 0;
            rd_gray <= 0;
            session_ack_meta <= 0;
            session_ack_sync <= 0;
            replay_wr <= 0;
            replay_data <= 0;
        end else begin
            session_ack_meta <= session_ack;
            session_ack_sync <= session_ack_meta;
            replay_wr <= 0;
            if (session_start_rx) begin
                wr_gray_meta <= 0;
                wr_gray_sync <= 0;
                rd_bin <= 0;
                rd_gray <= 0;
            end else begin
                wr_gray_meta <= wr_gray;
                wr_gray_sync <= wr_gray_meta;
                if (read_session_ready && !replay_full && !fifo_empty) begin
                    replay_data <= memory[rd_bin[ADDR_WIDTH-1:0]];
                    replay_wr <= 1;
                    rd_bin <= rd_bin + 1'b1;
                    rd_gray <= ((rd_bin + 1'b1) >> 1) ^ (rd_bin + 1'b1);
                end
            end
        end
    end
endmodule
