`timescale 1ns / 1ps
module tcp_tx_async_adapter_tb;
    reg wr_clk = 0, rd_clk = 0;
    always #2.5 wr_clk = ~wr_clk;
    always #4.0 rd_clk = ~rd_clk;
    reg wr_rst = 1, rd_rst = 1;
    reg tcp_open_rx = 0, tcp_tx_wr = 0;
    reg [7:0] tcp_tx_data = 0;
    wire tcp_open_ack, tcp_tx_full;
    reg session_start_rx = 0, replay_full = 1;
    wire replay_wr;
    wire [7:0] replay_data;
    wire [31:0] overflow_count, closed_write_count;
    integer i, received;
    reg second_session = 0;

    tcp_tx_async_adapter #(
        .ADDR_WIDTH(6), .DEPTH_BYTES(64), .FULL_GUARD_BYTES(8)
    ) dut (
        .wr_clk(wr_clk), .wr_rst(wr_rst),
        .tcp_open_rx(tcp_open_rx), .tcp_open_ack(tcp_open_ack),
        .tcp_tx_wr(tcp_tx_wr), .tcp_tx_data(tcp_tx_data),
        .tcp_tx_full(tcp_tx_full), .overflow_count(overflow_count),
        .closed_write_count(closed_write_count), .rd_clk(rd_clk),
        .rd_rst(rd_rst), .session_start_rx(session_start_rx),
        .replay_full(replay_full), .replay_wr(replay_wr),
        .replay_data(replay_data)
    );

    task automatic write_byte(input [7:0] value);
        begin
            @(negedge wr_clk);
            tcp_tx_data = value;
            tcp_tx_wr = 1;
            @(negedge wr_clk);
            tcp_tx_wr = 0;
        end
    endtask

    always @(posedge rd_clk) begin
        if (!rd_rst && replay_wr) begin
            if (replay_data !== (second_session
                    ? (8'ha0 + received[7:0])
                    : (received[7:0] ^ 8'h6d)))
                $fatal(1, "CDC byte %0d mismatch: got %02x", received,
                    replay_data);
            received <= received + 1;
        end
    end

    initial begin
        received = 0;
        repeat (5) @(negedge wr_clk);
        wr_rst = 0;
        repeat (3) @(negedge rd_clk);
        rd_rst = 0;
        session_start_rx = 1;
        @(negedge rd_clk);
        session_start_rx = 0;
        tcp_open_rx = 1;
        wait (tcp_open_ack);

        for (i = 0; i < 56; i = i + 1)
            write_byte(i[7:0] ^ 8'h6d);
        if (!tcp_tx_full)
            $fatal(1, "FULL did not reserve eight CDC locations");
        // SiTCP allows these writes already in flight after FULL rises.
        for (i = 56; i < 64; i = i + 1)
            write_byte(i[7:0] ^ 8'h6d);
        if (overflow_count != 0)
            $fatal(1, "Guarded writes overflowed the physical FIFO");
        write_byte(8'hff);
        if (overflow_count != 1)
            $fatal(1, "Physical overflow was not counted");

        replay_full = 0;
        wait (received == 64);
        repeat (5) @(posedge rd_clk);
        if (replay_wr)
            $fatal(1, "CDC FIFO produced extra data");

        tcp_open_rx = 0;
        wait (!tcp_open_ack);
        if (!tcp_tx_full || closed_write_count != 0)
            $fatal(1, "Closed interface state is incorrect");
        write_byte(8'haa);
        if (closed_write_count != 1)
            $fatal(1, "Write while closed was not contained");

        // A new SYN flushes any stale CDC state before OPEN reaches the
        // write clock. The second stream must restart at its first byte.
        replay_full = 1;
        session_start_rx = 1;
        @(negedge rd_clk);
        session_start_rx = 0;
        tcp_open_rx = 1;
        wait (tcp_open_ack);
        for (i = 0; i < 16; i = i + 1)
            write_byte(8'ha0 + i[7:0]);
        second_session = 1;
        received = 0;
        replay_full = 0;
        wait (received == 16);

        $display("PASS: 200/125 MHz CDC ordering, FULL+8 guard, close and reconnect flush");
        $finish;
    end

    initial begin
        #200000;
        $fatal(1, "TCP transmit CDC simulation timeout");
    end
endmodule
