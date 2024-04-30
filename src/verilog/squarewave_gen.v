`timescale 1ns / 1ps

module squarewave_gen
  #(
    parameter WG_COUNT_WIDTH = 17, 
    parameter WG_PULSE_WIDTH = 17'd100000 ) //100MHz clk -> 1ms
   (
    input  CLK,
    input  RST,
    input  START,
    output Q );


   reg [WG_COUNT_WIDTH - 1:0] cnt_1ms;
   wire 		   pulse_end = (cnt_1ms == WG_PULSE_WIDTH -1);
   reg 			   pulse;

   // up and down
   always@(posedge CLK) begin
      if(RST)
	pulse <= 0;
      else begin
	 if(START)
	   pulse <= 1;
	 else if(pulse_end)
	   pulse <= 0;
      end
   end

   // count wavewidth
   always@(posedge CLK) begin
      if(RST)
	cnt_1ms <= 0;
      else begin
	 if(pulse_end)
	   cnt_1ms <= 0;
	 else if(pulse) // enable to count when pulse is H.
	   cnt_1ms <= cnt_1ms + 1;
      end
   end

   assign Q = pulse;
   
endmodule
