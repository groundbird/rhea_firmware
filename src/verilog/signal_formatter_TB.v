`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Ikemitsu Takuji
// 
// Create Date: 2019/04/18 17:39:27
// Module Name: signal_formatter_TB
// 
//////////////////////////////////////////////////////////////////////////////////


module signal_formatter_TB;

   parameter PERIOD200 = 5.0;
   parameter PERIOD50 = 20;

   reg       OSC200;
   reg 	     RST;
   reg 	     SIG_IN;
   wire      SYNC;
   wire      SIG_OUT;

   signal_formatter
     signal_formatter
       (.clk        (OSC200),
	.rst        (RST),
	.sig_in     (SIG_IN),
	.sync_pulse (SYNC),
	.sig_out    (SIG_OUT) );

   // 200MHz clk
   always begin
      OSC200 = 1'b1;
      #(PERIOD200/2);
      OSC200 = 1'b0;
      #(PERIOD200/2);
   end
   
   always begin
      SIG_IN <= 1'b0;
      #17361;
      SIG_IN <= 1'b1;
      #17361;
   end
   
   initial begin
      RST = 1'b0;
      #100;
      RST = 1'b1;
      #100;
      RST = 1'b0;
   end

endmodule
