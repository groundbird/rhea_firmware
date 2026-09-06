`timescale 1ns / 1ps
// Receive one Ethernet frame from GMII, remove preamble/SFD and FCS, and hold
// the frame in a single buffer until frame_consume. Bad/runt/oversize frames
// never become visible to the protocol engine.
module gmii_rx_frame #(
    parameter MAX_FRAME_BYTES = 1536,
    parameter ADDR_WIDTH = 11
) (
    input  wire                  clk,
    input  wire                  rst,
    input  wire [7:0]            gmii_rxd,
    input  wire                  gmii_rx_dv,
    input  wire                  gmii_rx_er,
    output reg                   frame_valid,
    output reg  [ADDR_WIDTH-1:0] frame_len,
    input  wire                  frame_consume,
    input  wire [ADDR_WIDTH-1:0] frame_rd_addr,
    output wire [7:0]            frame_rd_data,
    output reg  [31:0]           good_frames,
    output reg  [31:0]           bad_frames,
    output reg  [31:0]           dropped_frames
);
    localparam ST_IDLE = 2'd0, ST_PREAMBLE = 2'd1, ST_FRAME = 2'd2, ST_DROP = 2'd3;
    reg [1:0] state;
    reg [2:0] preamble_count;
    reg [ADDR_WIDTH:0] byte_count;
    reg [31:0] crc;
    reg [31:0] fcs_shift;
    reg saw_error;
    reg overflow;
    reg [7:0] frame_mem [0:MAX_FRAME_BYTES-1];

    assign frame_rd_data = frame_mem[frame_rd_addr];

    function [31:0] crc32_byte;
        input [31:0] crc_in;
        input [7:0] data;
        integer i;
        reg [31:0] c;
        begin
            c = crc_in ^ data;
            for (i = 0; i < 8; i = i + 1)
                c = c[0] ? ((c >> 1) ^ 32'hEDB88320) : (c >> 1);
            crc32_byte = c;
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            state <= ST_IDLE;
            preamble_count <= 0;
            byte_count <= 0;
            crc <= 32'hFFFFFFFF;
            fcs_shift <= 0;
            saw_error <= 0;
            overflow <= 0;
            frame_valid <= 0;
            frame_len <= 0;
            good_frames <= 0;
            bad_frames <= 0;
            dropped_frames <= 0;
        end else begin
            if (frame_consume)
                frame_valid <= 0;
            case (state)
                ST_IDLE: begin
                    if (gmii_rx_dv) begin
                        if (frame_valid) begin
                            state <= ST_DROP;
                            dropped_frames <= dropped_frames + 1'b1;
                        end else if (gmii_rxd == 8'h55) begin
                            state <= ST_PREAMBLE;
                            preamble_count <= 1;
                        end else begin
                            state <= ST_DROP;
                            bad_frames <= bad_frames + 1'b1;
                        end
                    end
                end
                ST_PREAMBLE: begin
                    if (!gmii_rx_dv) begin
                        state <= ST_IDLE;
                        bad_frames <= bad_frames + 1'b1;
                    end else if (gmii_rxd == 8'h55 && preamble_count < 7) begin
                        preamble_count <= preamble_count + 1'b1;
                    end else if (gmii_rxd == 8'hD5 && preamble_count == 7) begin
                        state <= ST_FRAME;
                        byte_count <= 0;
                        crc <= 32'hFFFFFFFF;
                        fcs_shift <= 0;
                        saw_error <= gmii_rx_er;
                        overflow <= 0;
                    end else begin
                        state <= ST_DROP;
                        bad_frames <= bad_frames + 1'b1;
                    end
                end
                ST_FRAME: begin
                    if (gmii_rx_dv) begin
                        saw_error <= saw_error | gmii_rx_er;
                        if (byte_count >= 4) begin
                            if ((byte_count - 4) < MAX_FRAME_BYTES)
                                frame_mem[byte_count - 4] <= fcs_shift[7:0];
                            else
                                overflow <= 1;
                            crc <= crc32_byte(crc, fcs_shift[7:0]);
                        end
                        fcs_shift <= {gmii_rxd, fcs_shift[31:8]};
                        byte_count <= byte_count + 1'b1;
                        if (byte_count >= MAX_FRAME_BYTES + 4)
                            overflow <= 1;
                    end else begin
                        state <= ST_IDLE;
                        // byte_count includes the four FCS bytes. Ethernet frames
                        // excluding preamble/FCS must be at least 60 bytes.
                        if (!saw_error && !overflow && byte_count >= 64 &&
                            fcs_shift == ~crc) begin
                            frame_len <= byte_count - 4;
                            frame_valid <= 1;
                            good_frames <= good_frames + 1'b1;
                        end else begin
                            bad_frames <= bad_frames + 1'b1;
                        end
                    end
                end
                ST_DROP: begin
                    if (!gmii_rx_dv)
                        state <= ST_IDLE;
                end
            endcase
        end
    end
endmodule
