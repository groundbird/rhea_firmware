`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Ikemitsu Takuji
// Create Date: 2019/04/17 13:06:58
// Design Name: 1 byte data sirial to parallel converter
// Module Name: uart_reader
// Project Name: rhea-fpga
// Target Devices: kcu105
// Tool Versions: vivado 2018.3
// Description: convert uart read-data to logic vecter.
//              bit arrange : start_LSB_..._MSB_parity_stop
//////////////////////////////////////////////////////////////////////////////////

module uart_reader
  #(
    parameter div_cnt_bit = 32,
    parameter div_cnt_rate = 32'd1736 ) // clk = 200MHz, baud rate = 115200 bps
   (
    input 	 clk,
    input 	 rst,
    input 	 rxd,
    output 	 valid,
    output 	 parity_flg, // even->0, odd->1
    output [7:0] q
    );
   
   reg [div_cnt_bit - 1:0] div_cnt;
   wire 		   div;
   reg 			   div_en;
   wire 		   cnt_rst;
   reg [7:0] 		   bit_cnt;
   wire 		   start;
   wire 		   stop;
   reg 			   stop_buf;
   reg 			   edge_reg;
   reg [9:0] 		   data_buf;
   reg [8:0] 		   obuf;
   reg 			   valid_buf;
   
   
   // start bit (detect negedge)
   always @(posedge clk) begin
      if(rst)
	edge_reg <= 1'b0;
      else
	edge_reg <= rxd;
   end
   assign start = (edge_reg == 1'b1 & rxd == 1'b0) & ~div_en;

   // stop bit
   assign stop = (bit_cnt == 11);
   always @(posedge clk) begin
      stop_buf <= stop;
   end

   // generate divided clk
   always @(posedge clk) begin
      if(rst)
	div_en <= 1'b0;
      else if(start)
	div_en <= 1'b1;
      else if(stop)
	div_en <= 1'b0;
   end
   always @(posedge clk) begin
      if(cnt_rst)
	div_cnt <= 0;
      else if(start)
	div_cnt <= {1'b0, div_cnt_rate[div_cnt_bit - 1:1]}; // start from half period
      else if(div_en)
	div_cnt <= div_cnt + 1'b1;
      else
	div_cnt <= 0;
   end
   assign cnt_rst = rst | (div_cnt == div_cnt_rate - 1);
   assign div = (div_cnt == div_cnt_rate - 1) & div_en;

   // bit counter
   always @(posedge clk) begin
      if(rst)
	bit_cnt <= 0;
      else if(start)
	bit_cnt <= 0;
      else if(div)
	bit_cnt <= bit_cnt+1;
      else if(bit_cnt == 11)
	bit_cnt <= 0;
   end

   // sirial to parallel
   always @(posedge clk) begin
      if(rst)
	data_buf <= 0;
      else if(div)
	data_buf <= {rxd, data_buf[9:1]};
   end
   always @(posedge clk) begin
      if(rst)
	obuf <= 0;
      else if(stop)
	obuf <= data_buf[8:0];
   end
   assign q = obuf[7:0];

   // valid
   always @(posedge clk) begin
      if(rst)
	valid_buf <= 1'b0;
      else
	valid_buf <= stop_buf;
   end
   assign parity_flg = obuf[0]+obuf[1]+obuf[2]+obuf[3]+obuf[4]+obuf[5]+obuf[6]+obuf[7]+obuf[8];
   
   assign valid = valid_buf;

endmodule
