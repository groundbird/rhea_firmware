`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Ikemitsu Takuji
// 
// Create Date: 2019/04/17 18:37:59
// Module Name: uart_reader_TB
//////////////////////////////////////////////////////////////////////////////////


module uart_TB;

   parameter PERIOD200 = 5.0;
   parameter PERIOD50 = 20;

   reg       OSC50;
   reg       OSC200;
   reg 	     RST;
   reg [7:0] DIN;
   reg 	     WR_EN;
   wire      D_LINE;
   wire [7:0] Q;
   wire       VALID;
   wire       BUSY;

   uart_writer
     #(.div_cnt_bit  (9),
       .div_cnt_rate (9'd434) )
   writer
     (.clk           (OSC50),
      .rst           (RST),
      .din           (DIN),
      .wr_en         (WR_EN),
      .busy          (BUSY),
      .wxd           (D_LINE) );
   
   uart_reader
     #(.div_cnt_bit  (11),
       .div_cnt_rate (11'd1736) )
   reader
     (.clk           (OSC200),
      .rst           (RST),
      .rxd           (D_LINE),
      .valid         (VALID),
      .q             (Q) );

   // 200MHz clk
   always begin
      OSC200 = 1'b1;
      #(PERIOD200/2);
      OSC200 = 1'b0;
      #(PERIOD200/2);
   end
   
   // 50MHz clk
   always begin
      OSC50 = 1'b1;
      #(PERIOD50/2);
      OSC50 = 1'b0;
      #(PERIOD50/2);
   end

   always @(posedge OSC50) begin
      if(RST) begin
	 WR_EN = 1'b0;
	 DIN[7:0] = 8'h00;
      end
      else if(~BUSY) begin
	 DIN <= DIN + 8'h01;
	 WR_EN <= 1'b1;
      end
      else
	WR_EN <= 1'b0;
   end

   initial begin
      RST = 1'b0;
      #100;
      RST = 1'b1;
      #100;
      RST = 1'b0;
   end
   
endmodule
