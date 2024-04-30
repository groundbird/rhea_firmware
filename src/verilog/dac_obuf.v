`timescale 1ns / 1ps


module dac_obuf(
    input       clk_div,
    input       clk_2x,
    input       clk,
    input       rst,
    input [3:0] I,

    output [8:0] delay_count_out,
    input [8:0]  delay_count_in,
    input        delay_load,
   
    output      O_p,
    output      O_n );

    wire        ddr_out;
    wire        ddr_out_delayed;
    
    reg [8:0]   dc_out_buf_0;
    reg [8:0]   dc_out_buf_1;
    reg [8:0]   dc_in_buf_0;
    reg [8:0]   dc_in_buf_1;
    wire [8:0]  dc_raw;

    reg         load_buf_0;
    reg         load_buf_1;
   

    always @(posedge clk_div) begin
        dc_in_buf_0 <= delay_count_in;
        dc_in_buf_1 <= dc_in_buf_0;
        
        load_buf_0 <= delay_load;
        load_buf_1 <= load_buf_0;
    end      

    always @(posedge clk) begin
        dc_out_buf_0 <= dc_raw;
        dc_out_buf_1 <= dc_out_buf_0;
    end

    assign delay_count_out = dc_out_buf_1;

    OSERDESE3 #(
       .DATA_WIDTH(4)
    ) OSERDESE3_inst (
      .CLK    (clk_2x),
      .CLKDIV (clk_div),
      .D      ({4'b0000, I}),
      .OQ     (ddr_out),
      .RST    (rst),
      .T_OUT  (),
      .T      (1'b0) );

    ODELAYE3 #(
      .CASCADE("NONE"),
      .DELAY_FORMAT("COUNT"),
      .DELAY_TYPE("VAR_LOAD"),
      .DELAY_VALUE(0),
      .IS_CLK_INVERTED(1'b0),
      .IS_RST_INVERTED(1'b0),
      .REFCLK_FREQUENCY(300.0),
      .SIM_DEVICE("ULTRASCALE"),
      .UPDATE_MODE("ASYNC")
    ) ODELAYE3_inst (
      .CASC_OUT(),
      .CNTVALUEOUT(dc_raw),
      .DATAOUT(ddr_out_delayed),
      .CASC_IN(1'b0),
      .CASC_RETURN(),
      .CE(1'b0),
      .CLK(clk_div),
      .CNTVALUEIN(dc_in_buf_1),
      .EN_VTC(1'b0),
      .INC(1'b0),
      .LOAD(load_buf_1),
      .ODATAIN(ddr_out),
      .RST(rst)
    );

   OBUFDS
     OBUFDS_inst
       (
	.O  (O_p),
	.OB (O_n),
	.I  (ddr_out_delayed) );
   
endmodule
