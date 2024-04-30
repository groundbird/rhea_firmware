// Made by Bee Beans Technologies Co., Ltd.
`timescale  1 ps / 1 ps


module AT93C46_M24C08_TB;


	wire	IIC_MAIN_SDA;
	wire	IIC_MAIN_SCL;
	wire	SDI;
	wire	SDO;
	wire	SDT;
	reg		CLK_125M;
	reg		SYS_RSTn;

	IOBUF	sda_buf( .O(SDI), .I(SDO), .T(SDT), .IO(IIC_MAIN_SDA) );


	AT93C46_M24C08 #(.SYSCLK_FREQ_IN_MHz(125)) AT93C46_M24C08(
		.AT93C46_CS_IN		(1'b0),
		.AT93C46_SK_IN		(1'b0),
		.AT93C46_DI_IN		(1'b0),
		.AT93C46_DO_OUT		(),

		.M24C08_SCL_OUT		(IIC_MAIN_SCL),
		.M24C08_SDA_OUT		(SDO),
		.M24C08_SDA_IN		(SDI),
		.M24C08_SDAT_OUT	(SDT),

		.RESET_IN			(~SYS_RSTn),
		.SiTCP_RESET_OUT	(SiTCP_RESET),

		.SYSCLK_IN			(CLK_125M)
	);

	initial begin
		CLK_125M	= 0;
		forever begin
			CLK_125M	<= 0;
			#4000;
			CLK_125M	<= 1;
			#4000;
		end
	end

	initial begin
		SYS_RSTn=0;
		repeat(10)		@(posedge CLK_125M);
		SYS_RSTn=1;
	end

endmodule
