`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Ikemitsu Takuji
// 
// Create Date: 2019/04/18 17:31:01
// Design Name: 
// Module Name: signal_formatter
// Project Name: rhea
// Target Devices: kcu105
// Tool Versions: vivado2018.3
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module signal_formatter
  #(parameter veto_cnt_width = 17,
    parameter veto_cnt_length = 17'd100_000)
  (
   input      clk,
   input      rst,
   input      sig_in,
   output     start_pulse,
   output reg sig_out );

   reg [1:0]  state_reg;
   localparam reset   = 2'd0;
   localparam idle    = 2'd1;
   localparam reading = 2'd2;
   
   wire       rising;
   wire       falling;

   reg [veto_cnt_width-1:0] veto_cnt;
   
   // prevent from chattaring
   debounce
     #(
       .DE_COUNT_WIDTH(5),
       .DE_N_DIVIDE(5'd10)) // 200MHz->20MHz : pulse_rising less than 50ns.
   debounce_inst
     (
      .clk      (clk),
      .rst      (rst),
      .in       (sig_in),
      .q_rise   (rising),
      .q_fall   (falling) );

   // regenerate sig_in
   always @(posedge clk) begin
      if(rst)
	sig_out <= 1'b1;
      else if(falling)
	sig_out <= 1'b0;
      else if(rising)
	sig_out <= 1'b1;
   end

   // state job
   always @(posedge clk) begin
      if(rst) begin
	 state_reg <= reset;
	 veto_cnt <= 0;
      end
      else begin 
	 case(state_reg)
	   reset : state_reg <= idle;
	   idle : begin
	      if(falling)
		state_reg <= reading;
	   end
	   reading :begin
	      veto_cnt <= veto_cnt + 1;
	      if(veto_cnt == veto_cnt_length)
		state_reg <= idle;
	   end
	 endcase
      end
   end
   
   assign start_pulse = falling & (state_reg == idle);
   

endmodule
