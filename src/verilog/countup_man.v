`timescale 1ns / 1ps

module countup_man #(
    parameter DATA_WIDTH = 14,// 8 < DW <= 16 
    parameter RBCP_OFFSET = 32'h1400_0000
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        [DATA_WIDTH-1:0] data,
    output wire        irq,

    input  wire        rbcp_we,
    input  wire        rbcp_re,
    output wire        rbcp_ack,
    input  wire [31:0] rbcp_addr,
    input  wire [ 7:0] rbcp_wd,
    output wire [ 7:0] rbcp_rd);

    // Internal signal
    reg [DATA_WIDTH-1:0] counter;
    reg [DATA_WIDTH-1:0] data_reg;
    reg irq_reg;

    // Communication buffer
    reg       rbcp_ack_reg;
    reg [7:0] rbcp_rd_reg;
    assign rbcp_ack = rbcp_ack_reg;
    assign rbcp_rd = rbcp_rd_reg;

    // Alias
    wire [7:0] addr = rbcp_addr[7:0];

    // Flags
    wire selected = (rbcp_addr[31:8] == RBCP_OFFSET[31:8]);

    wire soft_reset = selected & rbcp_we & (addr == 8'b0) 
                      & (rbcp_wd & 8'b0000_0001);

    wire wrong = (data != counter);
    assign irq = irq_reg | wrong;
    wire trg = ~irq_reg & wrong;


    // counter
    always @(posedge clk) begin
        if (rst) begin
            counter <= {(DATA_WIDTH){1'b0}};
        end else if (soft_reset) begin
            counter <= data + 1;
        end else begin
            if (irq) begin
                counter <= counter;
            end else begin
                counter <= counter + 1;
            end
        end
    end

    // data_reg
    always @(posedge clk) begin
        if (rst) begin
            data_reg <= {(DATA_WIDTH){1'b0}};
        end else begin
            if (trg) begin
                data_reg <= data;
            end
        end
    end

    // irq
    always @(posedge clk) begin
        if (rst | soft_reset) begin
            irq_reg <= 1'b0;
        end else if (wrong) begin
            irq_reg <= 1'b1;
        end
    end

    // RBCP communication
    // ack generation
    always @(posedge clk) begin
        if (selected & (rbcp_we | rbcp_re)) begin
            rbcp_ack_reg <= 1'b1;
        end else begin
            rbcp_ack_reg <= 1'b0;
        end
    end

    // read response
    always @(posedge clk) begin
        if (rst) begin
            rbcp_rd_reg <= 8'b0;
        end else if (selected & rbcp_re) begin
            if (addr == 8'b0) begin
                rbcp_rd_reg <= {6'b0, irq, 1'b0};
            end else begin
                if (addr == 8'b1) begin
                    rbcp_rd_reg <= counter[7:0];
                end else if (addr == 8'h2) begin
                    rbcp_rd_reg <= counter[DATA_WIDTH-1:8];
                end else if (addr == 8'h3) begin
                    rbcp_rd_reg <= data_reg[7:0];
                end else if (addr == 8'h4) begin
                    rbcp_rd_reg <= data_reg[DATA_WIDTH-1:8];
                end else begin
                    rbcp_rd_reg <= 8'b0;
                end
            end
        end else begin
            rbcp_rd_reg <= 8'b0;
        end
    end

endmodule