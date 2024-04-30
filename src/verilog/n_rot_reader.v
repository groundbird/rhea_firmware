`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Ikemitsu Takuji
// 
// Create Date: 2019/04/18 19:44:27
// Design Name: several-byte sirial to parallel converter
// Module Name: n_rot_reader
// Project Name: rhea
// Target Devices: kcu105
// Tool Versions: vivado2018.3
// 
//////////////////////////////////////////////////////////////////////////////////


module n_rot_reader
  #(
    parameter n_byte = 5 )
   (
    input 		  clk,
    input 		  rst,
    input 		  uart_in,
    output 		  valid,
    output [n_byte*8-1:0] q
    );

   wire 		  byte_valid;
//   wire 		  parity_flg;
   wire [7:0] 		  byte_data;
   reg [n_byte*8-1:0] 	  obuf;
   reg [2:0] 		  byte_cnt;
   reg 			  valid_buf;
   reg 			  bad_packet_flg;
   reg 			  reading_flg;
   reg [17:0]			  veto_cnt;
   reg [17:0]			  read_cnt;
   wire 			  rst_int;
   reg 				  tmp;
   
   assign rst_int = rst | bad_packet_flg;
   
   uart_reader
     #(.div_cnt_bit(32),
       .div_cnt_rate(32'd1736) )
   uart_reader(
	       .clk        (clk         ),
	       .rst        (rst_int     ),
	       .rxd        (uart_in     ),
	       .valid      (byte_valid  ),
	       .parity_flg (),
	       .q          (byte_data   ) );

   // check if header byte is valid
   // check if 5 bytes come in 1ms.
   // BAD header -> reset & 1ms veto
   // less than 5 bytes -> reset & 1ms veto
   always @(posedge clk) begin
      if(rst | (veto_cnt == 18'd200_000))
	bad_packet_flg <= 1'b0;
      else if((byte_cnt==0) & byte_valid) begin
	 if(byte_data != 8'h55)
	   bad_packet_flg <= 1'b1;
	 else
	   bad_packet_flg <= 1'b0;
      end
      else if((read_cnt==18'd200_000) & (byte_cnt>0) & (byte_cnt<6))
	bad_packet_flg <= 1'b1;
   end
   always @(posedge clk) begin
      if(rst | bad_packet_flg == 1'b0)
	veto_cnt <= 18'd0;
      else if(bad_packet_flg == 1'b1)
	veto_cnt <= veto_cnt + 1;
   end

   always @(posedge clk) begin
      if(rst | (read_cnt == 18'd200_000))
	reading_flg <= 1'b0;
      else if((byte_cnt==0) & byte_valid)
	reading_flg <= 1'b1;
   end
   always @(posedge clk) begin
      if(rst_int | read_cnt > 18'd200_000)
	read_cnt <= 18'd0;
      else if(reading_flg == 1'b1)
	read_cnt <= read_cnt + 1;
   end
   
   

   always @(posedge clk) begin
      if(rst_int)
	obuf <= 0;
      else if(byte_valid)
	obuf <= (n_byte != 1) ? {byte_data, obuf[n_byte*8-1:8]} : byte_data;
   end

   always @(posedge clk) begin
      if(rst_int)
	byte_cnt <= 0;
      else if(byte_valid)
	byte_cnt <= byte_cnt + 1;
      else if(byte_cnt == n_byte + 1)
	byte_cnt <= 0;
   end

   always @(posedge clk) begin
      tmp <= (byte_cnt == n_byte + 1);
   end

   always @(posedge clk) begin
      if(rst_int)
	valid_buf <= 1'b0;
      else if((tmp == 1'b1) & (bad_packet_flg == 1'b0))
	valid_buf <= 1'b1;
      else
	valid_buf <= 1'b0;
   end

   assign q = obuf;
   assign valid = valid_buf;
   
endmodule
