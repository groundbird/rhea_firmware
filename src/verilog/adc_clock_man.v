`timescale 1ns / 1ps

module adc_clock_man(
    input  wire clk_in1_p,
    input  wire clk_in1_n,

    output wire clk_out1,
    output wire clk_out2,
    output wire clk_out3,
    output wire locked,
    
    
    input  wire clk_int,
    input  wire rst_int,
    
    input  wire rbcp_act,
    input  wire rbcp_we,
    input  wire rbcp_re,
    output wire rbcp_ack,
    input  wire [31:0] rbcp_addr,
    input  wire [ 7:0] rbcp_wd,
    output wire [ 7:0] rbcp_rd 
    );
    
    wire [3:0] araddr_res;

    // internal axi signal : rbcp_bridge to 8-32 converter
    wire [31:0] axi_awaddr_int ;
    wire [2:0]  axi_awprot_int ;
    wire        axi_awvalid_int;
    wire        axi_awready_int;
    wire [31:0] axi_wdata_int  ;
    wire [3:0]  axi_wstrb_int  ;
    wire        axi_wvalid_int ;
    wire        axi_wready_int ;
    wire [1:0]  axi_bresp_int  ;
    wire        axi_bvalid_int ;
    wire        axi_bready_int ;
    wire [31:0] axi_araddr_int ;
    wire [2:0]  axi_arprot_int ;
    wire        axi_arvalid_int;
    wire        axi_arready_int;
    wire [31:0] axi_rdata_int  ;
    wire        axi_rvalid_int ;
    wire        axi_rready_int ;
    wire [1:0]  axi_rresp_int  ;

    // internal axi signal : 8-32 converter to clocking wizard
    wire [31:0] axi_awaddr_cw ;
    wire [2:0]  axi_awprot_cw ;
    wire        axi_awvalid_cw;
    wire        axi_awready_cw;
    wire [31:0] axi_wdata_cw  ;
    wire [3:0]  axi_wstrb_cw  ;
    wire        axi_wvalid_cw ;
    wire        axi_wready_cw ;
    wire [1:0]  axi_bresp_cw  ;
    wire        axi_bvalid_cw ;
    wire        axi_bready_cw ;
    wire [31:0] axi_araddr_cw ;
    wire [2:0]  axi_arprot_cw ;
    wire        axi_arvalid_cw;
    wire        axi_arready_cw;
    wire [31:0] axi_rdata_cw  ;
    wire        axi_rvalid_cw ;
    wire        axi_rready_cw ;
    wire [1:0]  axi_rresp_cw  ;

    wire rbcp_we_sel;
    wire rbcp_re_sel;
    wire [7:0] rbcp_rd_sel;

    wire selected = (rbcp_addr[31:24] == 8'h13);
    wire [31:0] rbcp_addr_sel = {8'b0, rbcp_addr[23:0]};

    assign rbcp_we_sel = selected ? rbcp_we : 1'b0;
    assign rbcp_re_sel = selected ? rbcp_re : 1'b0;
    assign rbcp_rd = rbcp_ack ? rbcp_rd_sel : 8'b0;


    rbcp_bridge rbcp_bridge_inst(
        .clk(clk_int),
        .rst(rst_int),

        .rbcp_act(rbcp_act),
        .rbcp_addr(rbcp_addr_sel),
        .rbcp_wd(rbcp_wd),
        .rbcp_we(rbcp_we_sel),
        .rbcp_re(rbcp_re_sel),
        .rbcp_ack(rbcp_ack),
        .rbcp_rd(rbcp_rd_sel),
    
        .m_axi_awaddr  (axi_awaddr_int ),
        .m_axi_awprot  (axi_awprot_int ),
        .m_axi_awvalid (axi_awvalid_int),
        .m_axi_awready (axi_awready_int),
        .m_axi_wdata   (axi_wdata_int  ),
        .m_axi_wstrb   (axi_wstrb_int  ),
        .m_axi_wvalid  (axi_wvalid_int ),
        .m_axi_wready  (axi_wready_int ),
        .m_axi_bresp   (axi_bresp_int  ),
        .m_axi_bvalid  (axi_bvalid_int ),
        .m_axi_bready  (axi_bready_int ),
        .m_axi_araddr  (axi_araddr_int ),
        .m_axi_arprot  (axi_arprot_int ),
        .m_axi_arvalid (axi_arvalid_int),
        .m_axi_arready (axi_arready_int),
        .m_axi_rdata   (axi_rdata_int  ),
        .m_axi_rvalid  (axi_rvalid_int ),
        .m_axi_rready  (axi_rready_int ),
        .m_axi_rresp   (axi_rresp_int  ),

        .araddr_res(araddr_res),

        .debug_rresp(),
        .debug_bresp()
    );

    adapter_8_32 adapter_inst(
        .clk(clk_int),
        .rst(rst_int),
        .s_axi_awaddr (axi_awaddr_int ),
        .s_axi_awprot (axi_awprot_int ),
        .s_axi_awvalid(axi_awvalid_int),
        .s_axi_awready(axi_awready_int),
        .s_axi_wdata  (axi_wdata_int  ),
        .s_axi_wstrb  (axi_wstrb_int  ),
        .s_axi_wvalid (axi_wvalid_int ),
        .s_axi_wready (axi_wready_int ),
        .s_axi_bresp  (axi_bresp_int  ),
        .s_axi_bvalid (axi_bvalid_int ),
        .s_axi_bready (axi_bready_int ),
        .s_axi_araddr (axi_araddr_int ),
        .s_axi_arprot (axi_arprot_int ),
        .s_axi_arvalid(axi_arvalid_int),
        .s_axi_arready(axi_arready_int),
        .s_axi_rdata  (axi_rdata_int  ),
        .s_axi_rvalid (axi_rvalid_int ),
        .s_axi_rready (axi_rready_int ),
        .s_axi_rresp  (axi_rresp_int  ),

        .m_axi_awaddr (axi_awaddr_cw ),
        .m_axi_awprot (axi_awprot_cw ),
        .m_axi_awvalid(axi_awvalid_cw),
        .m_axi_awready(axi_awready_cw),
        .m_axi_wdata  (axi_wdata_cw  ),
        .m_axi_wstrb  (axi_wstrb_cw  ),
        .m_axi_wvalid (axi_wvalid_cw ),
        .m_axi_wready (axi_wready_cw ),
        .m_axi_bresp  (axi_bresp_cw  ),
        .m_axi_bvalid (axi_bvalid_cw ),
        .m_axi_bready (axi_bready_cw ),
        .m_axi_araddr (axi_araddr_cw ),
        .m_axi_arprot (axi_arprot_cw ),
        .m_axi_arvalid(axi_arvalid_cw),
        .m_axi_arready(axi_arready_cw),
        .m_axi_rdata  (axi_rdata_cw  ),
        .m_axi_rvalid (axi_rvalid_cw ),
        .m_axi_rready (axi_rready_cw ),
        .m_axi_rresp  (axi_rresp_cw  ),

        .araddr_res   (araddr_res   )
    );

    adc_clock adc_clock_inst(
        .s_axi_aclk      (clk_int),
        .s_axi_aresetn   (~rst_int),
        .s_axi_awaddr    (axi_awaddr_cw ),
        .s_axi_awvalid   (axi_awvalid_cw),
        .s_axi_awready   (axi_awready_cw),
        .s_axi_wdata     (axi_wdata_cw  ),
        .s_axi_wstrb     (axi_wstrb_cw  ),
        .s_axi_wvalid    (axi_wvalid_cw ),
        .s_axi_wready    (axi_wready_cw ),
        .s_axi_bresp     (axi_bresp_cw  ),
        .s_axi_bvalid    (axi_bvalid_cw ),
        .s_axi_bready    (axi_bready_cw ),
        .s_axi_araddr    (axi_araddr_cw ),
        .s_axi_arvalid   (axi_arvalid_cw),
        .s_axi_arready   (axi_arready_cw),
        .s_axi_rdata     (axi_rdata_cw  ),
        .s_axi_rresp     (axi_rresp_cw  ),
        .s_axi_rvalid    (axi_rvalid_cw ),
        .s_axi_rready    (axi_rready_cw ),
    
        .clk_out1(clk_out1),
        .clk_out2(clk_out2),
        .clk_out3(clk_out3),

        .locked(locked),
        .clk_in1_p(clk_in1_p),
        .clk_in1_n(clk_in1_n));
    
endmodule
