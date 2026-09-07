`timescale 1ns / 1ps

// Transfer one RBCP byte access from the PHY receive clock to the 200 MHz
// RHEA register bus. Request and response payloads remain stable until the
// corresponding toggle has crossed two synchronizer stages.
module rbcp_cdc_bridge #(
    parameter integer TIMEOUT_CYCLES = 20_000_000
) (
    input  wire        src_clk,
    input  wire        src_rst,
    input  wire        src_start,
    input  wire [31:0] src_addr,
    input  wire [7:0]  src_wd,
    input  wire        src_we,
    output reg         src_busy,
    output reg         src_done,
    output reg         src_error,
    output reg  [7:0]  src_rd,

    input  wire        dst_clk,
    input  wire        dst_rst,
    output reg         rbcp_act,
    output reg  [31:0] rbcp_addr,
    output reg  [7:0]  rbcp_wd,
    output reg         rbcp_we,
    output reg         rbcp_re,
    input  wire        rbcp_ack,
    input  wire [7:0]  rbcp_rd
);
    reg req_toggle;
    reg [31:0] req_addr_hold;
    reg [7:0] req_wd_hold;
    reg req_we_hold;

    reg response_toggle;
    reg response_error_hold;
    reg [7:0] response_rd_hold;

    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *)
    reg response_meta, response_sync;
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *)
    reg response_error_meta, response_error_sync;
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *)
    reg [7:0] response_rd_meta, response_rd_sync;
    reg response_seen;

    always @(posedge src_clk) begin
        if (src_rst) begin
            req_toggle <= 1'b0;
            req_addr_hold <= 32'd0;
            req_wd_hold <= 8'd0;
            req_we_hold <= 1'b0;
            response_meta <= 1'b0;
            response_sync <= 1'b0;
            response_error_meta <= 1'b0;
            response_error_sync <= 1'b0;
            response_rd_meta <= 8'd0;
            response_rd_sync <= 8'd0;
            response_seen <= 1'b0;
            src_busy <= 1'b0;
            src_done <= 1'b0;
            src_error <= 1'b0;
            src_rd <= 8'd0;
        end else begin
            response_meta <= response_toggle;
            response_sync <= response_meta;
            response_error_meta <= response_error_hold;
            response_error_sync <= response_error_meta;
            response_rd_meta <= response_rd_hold;
            response_rd_sync <= response_rd_meta;
            src_done <= 1'b0;
            if (src_busy && response_sync != response_seen) begin
                response_seen <= response_sync;
                src_error <= response_error_sync;
                src_rd <= response_rd_sync;
                src_busy <= 1'b0;
                src_done <= 1'b1;
            end else if (src_start && !src_busy) begin
                req_addr_hold <= src_addr;
                req_wd_hold <= src_wd;
                req_we_hold <= src_we;
                req_toggle <= ~req_toggle;
                src_busy <= 1'b1;
            end
        end
    end

    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *)
    reg req_meta, req_sync;
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *)
    reg [31:0] req_addr_meta, req_addr_sync;
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *)
    reg [7:0] req_wd_meta, req_wd_sync;
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *)
    reg req_we_meta, req_we_sync;
    reg req_seen;
    reg access_active;
    reg timeout_quarantine;
    reg [31:0] timeout_count;

    always @(posedge dst_clk) begin
        if (dst_rst) begin
            req_meta <= 1'b0;
            req_sync <= 1'b0;
            req_addr_meta <= 32'd0;
            req_addr_sync <= 32'd0;
            req_wd_meta <= 8'd0;
            req_wd_sync <= 8'd0;
            req_we_meta <= 1'b0;
            req_we_sync <= 1'b0;
            req_seen <= 1'b0;
            response_toggle <= 1'b0;
            response_error_hold <= 1'b0;
            response_rd_hold <= 8'd0;
            access_active <= 1'b0;
            timeout_quarantine <= 1'b0;
            timeout_count <= 32'd0;
            rbcp_act <= 1'b0;
            rbcp_addr <= 32'd0;
            rbcp_wd <= 8'd0;
            rbcp_we <= 1'b0;
            rbcp_re <= 1'b0;
        end else begin
            req_meta <= req_toggle;
            req_sync <= req_meta;
            req_addr_meta <= req_addr_hold;
            req_addr_sync <= req_addr_meta;
            req_wd_meta <= req_wd_hold;
            req_wd_sync <= req_wd_meta;
            req_we_meta <= req_we_hold;
            req_we_sync <= req_we_meta;
            rbcp_we <= 1'b0;
            rbcp_re <= 1'b0;

            if (access_active) begin
                if (rbcp_ack) begin
                    response_rd_hold <= rbcp_rd;
                    response_error_hold <= 1'b0;
                    response_toggle <= req_sync;
                    req_seen <= req_sync;
                    access_active <= 1'b0;
                    rbcp_act <= 1'b0;
                    timeout_count <= 32'd0;
                end else if (timeout_count >= TIMEOUT_CYCLES - 1) begin
                    response_rd_hold <= 8'd0;
                    response_error_hold <= 1'b1;
                    response_toggle <= req_sync;
                    req_seen <= req_sync;
                    access_active <= 1'b0;
                    rbcp_act <= 1'b0;
                    timeout_quarantine <= 1'b1;
                    timeout_count <= 32'd0;
                end else begin
                    timeout_count <= timeout_count + 1'b1;
                end
            end else if (timeout_quarantine) begin
                // A late ACK from the timed-out byte cannot complete the next
                // byte. Require a full timeout interval with ACK inactive.
                if (rbcp_ack) begin
                    timeout_count <= 32'd0;
                end else if (timeout_count >= TIMEOUT_CYCLES - 1) begin
                    timeout_quarantine <= 1'b0;
                    timeout_count <= 32'd0;
                end else begin
                    timeout_count <= timeout_count + 1'b1;
                end
            end else if (req_sync != req_seen) begin
                rbcp_addr <= req_addr_sync;
                rbcp_wd <= req_wd_sync;
                rbcp_we <= req_we_sync;
                rbcp_re <= ~req_we_sync;
                rbcp_act <= 1'b1;
                timeout_count <= 32'd0;
                access_active <= 1'b1;
            end
        end
    end
endmodule
