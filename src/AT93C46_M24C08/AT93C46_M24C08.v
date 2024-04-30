// Made by Bee Beans Technologies Co., Ltd.
//-------------------------------------------------------------------//
//
//	System      : AT93C46_M24C08
//
//	Module      : AT93C46_M24C08
//
//	Description : Top Module
//
//	file	: AT93C46_M24C08.v
//
//	Note	:
//
//	history	:
//		1.0.0.0		150629	-----	Created by N.Tanaka
//
//-------------------------------------------------------------------//



module AT93C46_M24C08 #(parameter SYSCLK_FREQ_IN_MHz=9'd100)(
	AT93C46_CS_IN,
	AT93C46_SK_IN,
	AT93C46_DI_IN,
	AT93C46_DO_OUT,

	M24C08_SCL_OUT,
	M24C08_SDA_OUT,
	M24C08_SDA_IN,
	M24C08_SDAT_OUT,

	RESET_IN,
	SiTCP_RESET_OUT,

	SYSCLK_IN
);

	input	wire	AT93C46_CS_IN;
	input	wire	AT93C46_SK_IN;
	input	wire	AT93C46_DI_IN;
	output	wire	AT93C46_DO_OUT;

	output	wire	M24C08_SCL_OUT;
	output	wire	M24C08_SDA_OUT;
	input	wire	M24C08_SDA_IN;
	output	wire	M24C08_SDAT_OUT;

	input	wire	RESET_IN;
	output	wire	SiTCP_RESET_OUT;

	input	wire	SYSCLK_IN;


	reg		[8:0]	CNT1M;
	reg		[1:0]	CNT3;
	reg				INT400K;

	reg		[7:0]	TCA9544_CNT;
	reg				TCA9544_ENB;
	reg		[19:0]	TCA9544_DAT;
	reg		[19:0]	TCA9544_OEB;
	reg		[ 3:0]	M24C08_RCNT;
	reg				M24C08_RESET;
	reg				TCA9544_SCL;
	reg				TCA9544_SDA;
	reg				TCA9544_SDAT;

	always @( posedge SYSCLK_IN or posedge RESET_IN ) begin
		if ( RESET_IN ) begin
			CNT1M[8:0]			<= 9'd0;
			CNT3[1:0]			<= 2'd0;
			INT400K				<= 1'd0;

			TCA9544_CNT[7:0]	<= 8'b1_01101_01;		// 13 - 32(0) [13(ST) 14(bit18)-31(bit1) 32(SP)]
			TCA9544_ENB			<= 0;
			TCA9544_DAT[19:0]	<= 20'b0_1110_1010_0_0000_0111_1_0;
			TCA9544_OEB[19:0]	<= 20'b1_1111_1111_0_1111_1111_0_1;
			M24C08_RCNT[3:0]	<= 4'b0000;
			M24C08_RESET		<= 1;
			TCA9544_SCL			<= 1;
			TCA9544_SDA			<= 1;
			TCA9544_SDAT		<= 1;
		end else begin
			CNT1M[8:0]		<= ( CNT1M[8:0] == ( SYSCLK_FREQ_IN_MHz - 9'd1 ) ) ? 9'd0 : CNT1M[8:0] + 9'd1;
			CNT3[1:0]		<= ( CNT1M[8:0] == 9'd0 ) ? ( ( CNT3[1:0] == 2'd2 ) ? 2'd0 : CNT3[1:0] + 2'd1 ) : CNT3[1:0];
			INT400K			<= ( CNT1M[8:0] == 9'd0 ) & ( CNT3[1:0] == 2'd2 );

			if (INT400K) begin
				TCA9544_CNT[7:0]	<= (TCA9544_ENB|TCA9544_CNT[7])?	(TCA9544_CNT[7:0] + 8'd1):		TCA9544_CNT[7:0];
				TCA9544_ENB			<= (
					(TCA9544_ENB    & (TCA9544_CNT[1:0] == 2'b11))|
					(TCA9544_ENB    & (TCA9544_CNT[1:0] == 2'b00))|
					(TCA9544_ENB    & (TCA9544_CNT[1:0] == 2'b01))|
					(TCA9544_CNT[7] & (TCA9544_CNT[1:0] == 2'b10))
				);
				TCA9544_DAT[19]		<= (TCA9544_CNT[1:0] == 2'b00)?		TCA9544_DAT[18]:			(((TCA9544_CNT[1:0] == 2'b10) & ~TCA9544_OEB[19])?	M24C08_SDA_IN:	TCA9544_DAT[19]);
				TCA9544_DAT[18:0]	<= (TCA9544_CNT[1:0] == 2'b00)?		{TCA9544_DAT[17:0],1'b1}:	TCA9544_DAT[18:0];
				TCA9544_OEB[19:0]	<= (TCA9544_CNT[1:0] == 2'b11)?		{TCA9544_OEB[18:0],1'b1}:	TCA9544_OEB[19:0];
				M24C08_RCNT[3:0]	<= (M24C08_RCNT[3]|TCA9544_CNT[7]|TCA9544_ENB)?		M24C08_RCNT[3:0]:	(M24C08_RCNT[3:0] + 4'd1);
				M24C08_RESET		<= ~M24C08_RCNT[3];
			end
			TCA9544_SCL		<= TCA9544_ENB?		TCA9544_CNT[1]:		1'b1;
			TCA9544_SDA		<= TCA9544_ENB?		TCA9544_DAT[19]:	1'b1;
			TCA9544_SDAT	<= TCA9544_OEB[19];
		end
	end

	wire	M24C08_SCL_R;
	wire	M24C08_SDA_R;
	wire	M24C08_SDAT_R;
	wire	M24C08_SCL_W;
	wire	M24C08_SDA_W;
	wire	M24C08_SDAT_W;

	assign	M24C08_SCL_OUT	=   TCA9544_SCL  & M24C08_SCL_R  & M24C08_SCL_W;
	assign	M24C08_SDA_OUT	=   TCA9544_SDA  & M24C08_SDA_R  & M24C08_SDA_W;
	assign	M24C08_SDAT_OUT	= ~(TCA9544_SDAT & M24C08_SDAT_R & M24C08_SDAT_W );

//	assign	M24C08_SCL_OUT	=  TCA9544_SCL;
//	assign	M24C08_SDA_OUT	=  TCA9544_SDA;
//	assign	M24C08_SDAT_OUT	= ~TCA9544_SDAT;


	wire			MEM_CLKB;
	wire			MEM_WEB;
	wire	[6:0]	MEM_ADDRB;
	wire	[7:0]	MEM_DINB;

	M24_READER	M24_READER(
		.M24C08_SCL_OUT		(M24C08_SCL_R		),
		.M24C08_SDA_OUT		(M24C08_SDA_R		),
		.M24C08_SDA_IN		(M24C08_SDA_IN		),
		.M24C08_SDAT_OUT	(M24C08_SDAT_R		),

		.RESET_IN			(M24C08_RESET		),
		.SiTCP_RESET_OUT	(SiTCP_RESET_OUT	),

		.INT400K_IN			(INT400K			),
		.SYSCLK_IN			(SYSCLK_IN			),

		.MEM_WE_OUT			(MEM_WEB			),
		.MEM_ADDR_OUT		(MEM_ADDRB[6:0]		),
		.MEM_DIN_OUT		(MEM_DINB[7:0]		)
	);



	reg		[5:0]	BIT_COUNT;
	reg		[7:0]	OUT_BUFFER;
	reg		[7:0]	IN_BUFFER;
	reg		[2:0]	OPCODE;
	reg		[6:0]	ADDRESS;

	reg				MEM_WEA;
	wire	[6:0]	MEM_ADDRA;
	wire	[7:0]	MEM_DINA;
	wire	[7:0]	MEM_DOUTA;

	assign	MEM_ADDRA[6:0] = ( OPCODE == 3'b110 ) ? {IN_BUFFER[5:0],AT93C46_DI_IN} : ADDRESS[6:0];
	assign	MEM_DINA[7:0] = IN_BUFFER[7:0];
	assign	AT93C46_DO_OUT = OUT_BUFFER[7];

	blk_mem_gen_v7_3 BUFFER(
		.clka		(SYSCLK_IN			),
		.wea		(MEM_WEA			),
		.addra		(MEM_ADDRA[6:0]		),
		.dina		(MEM_DINA[7:0]		),
		.douta		(MEM_DOUTA[7:0]		),
		.clkb		(SYSCLK_IN			),
		.web		(MEM_WEB			),
		.addrb		(MEM_ADDRB[6:0]		),
		.dinb		(MEM_DINB[7:0]		),
		.doutb		(					)
	);



	M24_WRITER M24_WRITER(
		.M24C08_SCL_OUT		(M24C08_SCL_W	),
		.M24C08_SDA_OUT		(M24C08_SDA_W	),
		.M24C08_SDA_IN		(M24C08_SDA_IN	),
		.M24C08_SDAT_OUT	(M24C08_SDAT_W	),

		.RESET_IN			(M24C08_RESET	),

		.INT400K_IN			(INT400K		),
		.SYSCLK_IN			(SYSCLK_IN		),

		.CLK_IN				(AT93C46_SK_IN	),
		.ROM_WE_IN			(MEM_WEA		),
		.ROM_ADDR_IN		(MEM_ADDRA[6:0]	),
		.ROM_DATA_IN		(MEM_DINA[7:0]	)
	);


	reg		AT93C46_SK_P0;
	reg		AT93C46_SK_P1;
	wire	AT93C46_SK_RISE	= ~AT93C46_SK_P1 & AT93C46_SK_P0;
	wire	AT93C46_SK_FALL	= AT93C46_SK_P1 & ~AT93C46_SK_P0;
	reg		AT93C46_CS_P0;
	reg		AT93C46_CS_P1;
	wire	AT93C46_CS_FALL = AT93C46_CS_P0 & ~AT93C46_CS_IN;
	reg		[7:0]	MEM_DOUTA_REG;

	always @( posedge SYSCLK_IN or posedge M24C08_RESET ) begin
		if ( M24C08_RESET ) begin
			MEM_WEA			<= 1'd0;
			MEM_DOUTA_REG	<= 8'd0;
			BIT_COUNT		<= 6'd0;
			AT93C46_SK_P0	<= 1'd0;
			AT93C46_SK_P1	<= 1'd0;
			AT93C46_CS_P0	<= 1'd0;
			AT93C46_CS_P1	<= 1'd0;
			OUT_BUFFER[7:0]	<= 8'hff;
		end else begin
			AT93C46_SK_P0	<= AT93C46_SK_IN;
			AT93C46_SK_P1	<= AT93C46_SK_P0;
			AT93C46_CS_P0	<= AT93C46_CS_IN;
			AT93C46_CS_P1	<= AT93C46_CS_P0;

			BIT_COUNT[5:0]	<= ~AT93C46_CS_P1 ? 6'd0 : ~AT93C46_SK_RISE ? BIT_COUNT[5:0]	: BIT_COUNT[5:0] + 6'd1;
			IN_BUFFER[7:0]	<= ~AT93C46_SK_RISE ? IN_BUFFER[7:0]	: {IN_BUFFER[6:0],AT93C46_DI_IN};
			OPCODE[2:0]		<= ~AT93C46_SK_RISE ? OPCODE[2:0]		: ( BIT_COUNT[5:0] == 6'd3 ) ? IN_BUFFER[2:0] : OPCODE[2:0];
			ADDRESS[6:0]	<= ~AT93C46_SK_RISE ? ADDRESS[6:0]		: ( BIT_COUNT[5:0] == 6'd10 ) ? IN_BUFFER[6:0] : ADDRESS[6:0];
			MEM_WEA			<= ~AT93C46_SK_RISE ? MEM_WEA			: ( BIT_COUNT[5:0] == 6'd17 ) & ( OPCODE == 3'b101 );
			MEM_DOUTA_REG	<= ~AT93C46_SK_RISE ? MEM_DOUTA_REG		: MEM_DOUTA;
			OUT_BUFFER[7:0]	<= ~AT93C46_SK_FALL ? OUT_BUFFER[7:0]	:
							   ( BIT_COUNT[5:0] == 6'd9 ) & ( OPCODE == 3'b110 ) ? 8'd0 :
							   ( BIT_COUNT[5:0] == 6'd10 ) & ( OPCODE == 3'b110 ) ? MEM_DOUTA_REG[7:0] : {OUT_BUFFER[6:0],1'b1};
		end
	end


endmodule
