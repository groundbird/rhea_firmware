`timescale 1ns / 1ps
module sitcp_benchmark_tb;
    reg clk = 0;
    always #2.5 clk = ~clk;
    reg rst = 1, tcp_open_ack = 0, tcp_close_req = 0, tcp_error = 0, tcp_tx_full = 0;
    wire tcp_tx_wr;
    wire [7:0] tcp_tx_data;
    reg [31:0] rbcp_addr = 0;
    reg [7:0] rbcp_wd = 0;
    reg rbcp_we = 0, rbcp_re = 0;
    wire rbcp_ack;
    wire [7:0] rbcp_rd;
    sitcp_benchmark dut (.*);

    longint unsigned position = 0, accepted = 0, connected_cycles = 0, blocked_cycles = 0;
    reg [31:0] expected_word;
    reg [7:0] value;
    reg [255:0] saved;
    longint unsigned snap_accepted, snap_connected, snap_blocked;
    integer seed = 12345;
    integer i;

    // Independent interface scoreboard observes the same sampling edge as SiTCP.
    always @(posedge clk) begin
        if (rst) begin
            position = 0;
            accepted = 0;
            connected_cycles = 0;
            blocked_cycles = 0;
        end else begin
            if (!tcp_open_ack) position = 0;
            if (tcp_open_ack) connected_cycles++;
            if (tcp_open_ack && tcp_tx_full) blocked_cycles++;
            if (tcp_tx_wr) begin
                if (!tcp_open_ack || tcp_close_req || tcp_tx_full)
                    $fatal(1, "Write while unavailable");
                expected_word = position / 4;
                if (tcp_tx_data !== ((expected_word >> (8 * (position % 4))) & 8'hff))
                    $fatal(1, "Bad sequence at byte %0d", position);
                position++;
                accepted++;
            end
        end
    end

    task automatic write_byte(input [31:0] addr, input [7:0] data);
        @(negedge clk);
        rbcp_addr = addr; rbcp_wd = data; rbcp_we = 1;
        @(posedge clk); #1;
        if (!rbcp_ack) $fatal(1, "Missing write ACK");
        @(negedge clk); rbcp_we = 0;
    endtask

    task automatic read_byte(input [31:0] addr, output [7:0] data);
        @(negedge clk);
        rbcp_addr = addr; rbcp_re = 1;
        @(posedge clk); #1;
        if (!rbcp_ack) $fatal(1, "Missing read ACK");
        data = rbcp_rd;
        @(negedge clk); rbcp_re = 0;
    endtask

    initial begin
        repeat (4) @(negedge clk);
        rst = 0;
        read_byte(0, value);
        if (value != "S") $fatal(1, "Bad identity");
        read_byte(9, value);
        if (value != 1) $fatal(1, "Generator must be enabled after reset");
        @(negedge clk); tcp_open_ack = 1;
        saved = accepted;
        repeat (128) @(negedge clk);
        if (accepted - saved != 128) $fatal(1, "Source must sustain one byte per clock");
        // Stalls at arbitrary byte positions, including extended FULL periods.
        for (i = 0; i < 10000; i++) begin
            @(negedge clk);
            tcp_tx_full = ($random(seed) & 3) == 0;
        end
        @(negedge clk); tcp_tx_full = 1;
        repeat (40) @(negedge clk);
        tcp_tx_full = 0;
        write_byte(9, 0);
        saved = accepted;
        repeat (12) @(negedge clk);
        if (accepted != saved) $fatal(1, "Disable failed");
        write_byte(9, 1);
        repeat (20) @(negedge clk);

        // Snapshot captures pre-edge values, and is stable while traffic continues.
        @(negedge clk);
        snap_accepted = accepted;
        snap_connected = connected_cycles;
        snap_blocked = blocked_cycles;
        rbcp_addr = 'h10; rbcp_wd = 1; rbcp_we = 1;
        @(negedge clk); rbcp_we = 0;
        for (i = 0; i < 32; i++) begin
            read_byte('h20 + i, value);
            saved[8*i +: 8] = value;
        end
        if (saved[63:0] != snap_accepted || saved[127:64] != snap_connected ||
            saved[191:128] != snap_blocked || saved[223:192] != 1 || saved[255:224] != 0)
            $fatal(1, "Incoherent snapshot: %h", saved);
        @(negedge clk); tcp_close_req = 1;
        saved = accepted;
        repeat (10) @(negedge clk);
        if (accepted != saved) $fatal(1, "Close failed to stop source");
        tcp_open_ack = 0; tcp_close_req = 0;
        repeat (4) @(negedge clk);
        tcp_open_ack = 1;
        repeat (100) @(negedge clk);
        tcp_error = 1;
        repeat (5) @(negedge clk);
        tcp_error = 0;
        write_byte('h10, 1);
        read_byte('h38, value);
        if (value != 2) $fatal(1, "Connection count wrong");
        read_byte('h3c, value);
        if (value != 1) $fatal(1, "Error must count edges, not cycles");
        @(negedge clk); rst = 1;
        repeat (4) @(negedge clk);
        rst = 0; tcp_open_ack = 0;
        read_byte('h20, value);
        if (value != 0) $fatal(1, "Reset failed");
        $display("PASS: 1 byte/clock, sequence, random FULL, pause/resume, coherent counters, close/reconnect, reset");
        $finish;
    end
    initial begin
        #1000000;
        $fatal(1, "Simulation timeout");
    end
endmodule
