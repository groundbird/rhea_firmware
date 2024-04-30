`timescale 1ns / 1ps

module delayed_reset #(
    parameter DELAY_C_WIDTH = 30,
    parameter RST_C_WIDTH = 5 )(

    input      clk,
    input      rst_orig,
    output     rst_delay
    );

    reg [DELAY_C_WIDTH-1:0] counter;
    reg [RST_C_WIDTH-1:0] rst_counter;
    wire c_max = & counter;
    wire r_max = & rst_counter;
    wire r_0 = rst_counter == {{(RST_C_WIDTH){1'b0}}};

    always @(posedge clk) begin
        if (rst_orig) begin
            counter <= {{(DELAY_C_WIDTH){1'b0}}};
        end else begin
            if (~c_max) begin
                counter <= counter + 1;
            end else begin
                counter <= counter;
            end
        end
    end

    always @(posedge clk) begin
        if (rst_orig) begin
            rst_counter <= {{(RST_C_WIDTH){1'b0}}};
        end else if (c_max) begin
            if (~r_max) begin
                rst_counter <= rst_counter + 1;
            end else begin
                rst_counter <= rst_counter;
            end
        end else begin
            rst_counter <= rst_counter;
        end
    end

    assign rst_delay = (~r_0) & (~r_max);

endmodule