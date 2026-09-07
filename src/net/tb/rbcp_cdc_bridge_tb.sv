`timescale 1ns / 1ps
module rbcp_cdc_bridge_tb;
    reg src_clk = 0, dst_clk = 0, rst = 1;
    always #4 src_clk = ~src_clk;
    always #2.5 dst_clk = ~dst_clk;

    reg src_start = 0, src_we = 0;
    reg [31:0] src_addr = 0;
    reg [7:0] src_wd = 0;
    wire src_busy, src_done, src_error;
    wire [7:0] src_rd;
    wire rbcp_act, rbcp_we, rbcp_re;
    wire [31:0] rbcp_addr;
    wire [7:0] rbcp_wd;
    reg rbcp_ack = 0;
    reg [7:0] rbcp_rd = 0;

    rbcp_cdc_bridge #(.TIMEOUT_CYCLES(8)) dut (
        .src_clk(src_clk), .src_rst(rst), .src_start(src_start),
        .src_addr(src_addr), .src_wd(src_wd), .src_we(src_we),
        .src_busy(src_busy), .src_done(src_done), .src_error(src_error),
        .src_rd(src_rd), .dst_clk(dst_clk), .dst_rst(rst),
        .rbcp_act(rbcp_act), .rbcp_addr(rbcp_addr), .rbcp_wd(rbcp_wd),
        .rbcp_we(rbcp_we), .rbcp_re(rbcp_re), .rbcp_ack(rbcp_ack),
        .rbcp_rd(rbcp_rd)
    );

    task automatic launch_read(input [31:0] address);
        begin
            @(negedge src_clk);
            src_addr = address;
            src_we = 0;
            src_start = 1;
            @(negedge src_clk);
            src_start = 0;
        end
    endtask

    initial begin
        repeat (6) @(negedge src_clk);
        rst = 0;

        // Let the first access time out.
        launch_read(32'h1234_0000);
        while (!src_done) @(negedge src_clk);
        if (!src_error || src_busy)
            $fatal(1, "Expected first access to time out");

        // Queue another request, then inject an ACK from the old access.
        // The destination must keep the new RE inactive during quarantine.
        launch_read(32'h1234_0001);
        rbcp_ack = 1;
        rbcp_rd = 8'hee;
        repeat (4) begin
            @(negedge dst_clk);
            if (rbcp_re || rbcp_we)
                $fatal(1, "New access started while late ACK was active");
        end
        rbcp_ack = 0;

        while (!rbcp_re) @(negedge dst_clk);
        if (rbcp_addr != 32'h1234_0001)
            $fatal(1, "Wrong address after timeout quarantine");
        @(negedge dst_clk);
        rbcp_rd = 8'h5a;
        rbcp_ack = 1;
        @(negedge dst_clk);
        rbcp_ack = 0;

        while (!src_done) @(negedge src_clk);
        if (src_error || src_rd != 8'h5a)
            $fatal(1, "Second access did not complete after quarantine");
        if (rbcp_act)
            $fatal(1, "RBCP ACT remained asserted");

        $display("PASS: RBCP CDC timeout and late-ACK quarantine");
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Simulation timeout");
    end
endmodule
