`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Ikemitsu Takuji
// Create Date: 2018/11/26 17:08:01
// Module Name: synchronizer
// Project Name: rhea
// Target Devices: kcu105
// Tool Versions: vivado2018.3
//////////////////////////////////////////////////////////////////////////////////

//`include "rhea_pkg.vh"

module synchronizer 
//  #(parameter n_ch_en  = `N_CHANNEL_EN)   
   (
    input  clk,
    input  rst,
//    input [n_ch_en-1:0] wr_en,
    input  wr_en,
    input  iq_en,
//    input [n_ch_en-1:0] wr_en_sync,
    input  wr_en_sync,
    input  fmt_busy,
    output valid,
    output valid_sync );

   reg [2:0] 		state_reg;
   localparam   reset      = 3'd0;
   localparam   idle       = 3'd1;
   localparam   busy_data  = 3'd2; // formatter is sending IQ_DS_data
   localparam   busy_count = 3'd3; // formatter is sending sync_counter
   localparam   wait_data  = 3'd4; // send valid after fmt finish sending sync_cnt
   localparam   wait_count = 3'd5; // send valid_sync after fmt finish sending IQ_DS_data
   localparam   fini       = 3'd6;

   // io valid buffer
   reg 			wr_en_buf;
   reg 			wr_en_sync_buf;
   reg 			obuf;
   reg 			sync_obuf;
   wire 		busy = fmt_busy | obuf | sync_obuf;
   // buffer in case wr_en come during fmt_busy  
   reg 			valid_buf;
   reg 			valid_sync_buf;
   // unify wr_en
//   wire 		any_wr_en      = (wr_en != 0);
//   wire 		any_wr_en_sync = (wr_en_sync != 0);

   assign valid      = obuf;
   assign valid_sync = sync_obuf;

   always @(posedge clk) begin
      if(rst) begin
	 wr_en_buf      <= 0;
	 wr_en_sync_buf <= 0;
      end
      else begin
	 wr_en_buf      <= (wr_en & iq_en);
	 wr_en_sync_buf <= (wr_en_sync & iq_en);
//	 wr_en_buf      <= (any_wr_en & iq_en);
//	 wr_en_sync_buf <= (any_wr_en_sync & iq_en);
      end
   end

   // state job
   always @(posedge clk) begin
      if(rst)
	state_reg <= reset;
      else begin
	 case(state_reg)
	   reset : begin
	      obuf           <= 1'b0;
	      sync_obuf      <= 1'b0;
	      valid_sync_buf <= 1'b0;
	      valid_buf      <= 1'b0;
	      state_reg      <= idle;
	   end
	   idle  : begin
	      if(wr_en_buf & ~wr_en_sync_buf) begin
		 obuf      <= 1'b1;
		 state_reg <= busy_data;
	      end
	      else if(~wr_en_buf & wr_en_sync_buf) begin
		 sync_obuf <= 1'b1;
		 state_reg <= busy_count;
	      end
	      else if(wr_en_buf & wr_en_sync_buf) begin // valid_data and valid_sync on time
		 obuf <= 1'b1;
		 valid_sync_buf <= 1'b1;
		 state_reg      <= wait_count;
	      end
	   end
	   busy_data : begin // sending data
	      obuf <= 1'b0;
	      if(wr_en_sync_buf)      valid_sync_buf <= 1'b1;
	      else if(valid_sync_buf) state_reg      <= wait_count;
	      else if(~busy)      state_reg      <= fini;
	   end
	   busy_count : begin // sending sync_counter
	      sync_obuf <= 1'b0;
	      if(wr_en_buf)      valid_buf <= 1'b1;
	      else if(valid_buf) state_reg <= wait_data;
	      else if(~busy) state_reg <= fini;
	   end
	   wait_data : begin // send data after finishing sending sync_counter
	      if(~busy) begin
		 obuf <= 1'b1;
		 valid_buf <= 1'b0;
		 state_reg <= busy_data;
	      end
	   end
	   wait_count : begin // send sync_counter after finishing sending data
	      if(~busy) begin
		 sync_obuf      <= 1'b1;
		 valid_sync_buf <= 1'b0;
		 state_reg      <= busy_count;
	      end
	      else if(obuf) obuf <= 1'b0;
	   end
	   fini : state_reg <= idle;
	 endcase
      end
   end

endmodule
