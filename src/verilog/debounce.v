`timescale 1ns / 1ps

module debounce
  #(
    parameter DE_COUNT_WIDTH = 21,
    parameter DE_N_DIVIDE = 21'd2000000 ) // if clk is 100MHz -> 50Hz
   (
    input      clk,
    input      rst,
    input      in,
    output reg q_rise,
    output reg q_fall
    );

   reg [DE_COUNT_WIDTH - 1:0] cnt;
   wire 		      div = (cnt == DE_N_DIVIDE - 1);

   reg 			      ff1;
   reg 			      ff2;

   always @(posedge clk) begin
      if(rst)
	cnt <= 0;
      else  begin
	 if(div)
	   cnt <= 0;
	 else
	   cnt <= cnt + 1;
      end
   end

   always @(posedge clk) begin
      if(rst) begin
	 ff1 <= 1'd0;
	 ff2 <= 1'd0;
      end 
      else if(div) begin
	 ff2 <= ff1;
	 ff1 <= in;
      end
   end

   // detect rising edge
   wire temp_rise = ff1 & ~ff2 & div;

   always @(posedge clk) begin
      if(rst)
	q_rise <= 1'b0;
      else
	q_rise <= temp_rise;
   end
   
   // detect falling edge
   wire temp_fall = ~ff1 & ff2 & div;

   always @(posedge clk) begin
      if(rst)
	q_fall <= 1'b0;
      else
	q_fall <= temp_fall;
   end
   
endmodule
