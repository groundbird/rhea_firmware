`timescale 1ns / 1ps
// Transmit a stable frame buffer over GMII. The request and completion toggles
// cross clock domains; frame_len/data must remain stable until done_toggle.
module gmii_tx_frame #(
    parameter ADDR_WIDTH = 11
) (
    input  wire                  clk,
    input  wire                  rst,
    input  wire                  request_toggle,
    output reg                   done_toggle,
    input  wire [ADDR_WIDTH-1:0] frame_len,
    output reg  [ADDR_WIDTH-1:0] frame_rd_addr,
    input  wire [7:0]            frame_rd_data,
    output reg  [7:0]            gmii_txd,
    output reg                   gmii_tx_en,
    output wire                  gmii_tx_er,
    output wire                  busy
);
    localparam ST_IDLE = 3'd0, ST_PREAMBLE = 3'd1, ST_FRAME = 3'd2,
               ST_FCS = 3'd3, ST_IFG = 3'd4;
    reg [2:0] state;
    reg request_meta, request_sync, request_seen;
    reg [2:0] preamble_count;
    reg [1:0] fcs_index;
    reg [3:0] ifg_count;
    reg [ADDR_WIDTH-1:0] latched_len;
    reg [ADDR_WIDTH-1:0] wire_len;
    reg [31:0] crc;
    reg [31:0] fcs;
    wire [7:0] current_data = frame_rd_addr < latched_len ? frame_rd_data : 8'h00;

    assign gmii_tx_er = 1'b0;
    assign busy = state != ST_IDLE || request_sync != request_seen;

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
            request_meta <= 0;
            request_sync <= 0;
            request_seen <= 0;
            done_toggle <= 0;
            state <= ST_IDLE;
            preamble_count <= 0;
            fcs_index <= 0;
            ifg_count <= 0;
            latched_len <= 0;
            wire_len <= 0;
            frame_rd_addr <= 0;
            crc <= 32'hFFFFFFFF;
            fcs <= 0;
            gmii_txd <= 0;
            gmii_tx_en <= 0;
        end else begin
            request_meta <= request_toggle;
            request_sync <= request_meta;
            case (state)
                ST_IDLE: begin
                    gmii_tx_en <= 0;
                    if (request_sync != request_seen) begin
                        latched_len <= frame_len;
                        wire_len <= frame_len < 60 ? 60 : frame_len;
                        frame_rd_addr <= 0;
                        preamble_count <= 0;
                        crc <= 32'hFFFFFFFF;
                        state <= ST_PREAMBLE;
                    end
                end
                ST_PREAMBLE: begin
                    gmii_tx_en <= 1;
                    if (preamble_count < 7) begin
                        gmii_txd <= 8'h55;
                        preamble_count <= preamble_count + 1'b1;
                    end else begin
                        gmii_txd <= 8'hD5;
                        state <= ST_FRAME;
                    end
                end
                ST_FRAME: begin
                    gmii_tx_en <= 1;
                    gmii_txd <= current_data;
                    crc <= crc32_byte(crc, current_data);
                    if (frame_rd_addr == wire_len - 1'b1) begin
                        fcs <= ~crc32_byte(crc, current_data);
                        fcs_index <= 0;
                        state <= ST_FCS;
                    end else begin
                        frame_rd_addr <= frame_rd_addr + 1'b1;
                    end
                end
                ST_FCS: begin
                    gmii_tx_en <= 1;
                    case (fcs_index)
                        0: gmii_txd <= fcs[7:0];
                        1: gmii_txd <= fcs[15:8];
                        2: gmii_txd <= fcs[23:16];
                        3: gmii_txd <= fcs[31:24];
                    endcase
                    if (fcs_index == 3) begin
                        ifg_count <= 0;
                        state <= ST_IFG;
                    end else begin
                        fcs_index <= fcs_index + 1'b1;
                    end
                end
                ST_IFG: begin
                    gmii_tx_en <= 0;
                    gmii_txd <= 0;
                    if (ifg_count == 11) begin
                        request_seen <= request_sync;
                        done_toggle <= request_sync;
                        state <= ST_IDLE;
                    end else begin
                        ifg_count <= ifg_count + 1'b1;
                    end
                end
            endcase
        end
    end
endmodule
