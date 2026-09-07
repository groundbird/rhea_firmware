`timescale 1ns / 1ps
module tcp_tx_replay_buffer_tb;
    reg clk = 0;
    always #2.5 clk = ~clk; // eventual user-side interface: 200 MHz
    reg rst = 1;
    reg session_start = 0;
    reg [31:0] session_first_seq = 0;
    reg tx_wr = 0;
    reg [7:0] tx_data = 0;
    wire tcp_tx_full;
    reg ack_valid = 0;
    reg [31:0] ack_seq = 0;
    reg [31:0] read_seq = 0;
    wire [7:0] read_data;
    wire [31:0] first_stored_seq, write_seq;
    wire [5:0] buffered_bytes;
    wire [31:0] overflow_count, invalid_ack_count;
    integer i;
    localparam [31:0] START = 32'hfffffff8;

    tcp_tx_replay_buffer #(
        .ADDR_WIDTH(5), .DEPTH_BYTES(32), .FULL_GUARD_BYTES(8)
    ) dut (
        .clk(clk), .rst(rst), .session_start(session_start),
        .session_first_seq(session_first_seq), .tx_wr(tx_wr),
        .tx_data(tx_data), .tcp_tx_full(tcp_tx_full),
        .overflow_count(overflow_count), .ack_valid(ack_valid),
        .ack_seq(ack_seq), .invalid_ack_count(invalid_ack_count),
        .read_seq(read_seq), .read_data(read_data),
        .first_stored_seq(first_stored_seq), .write_seq(write_seq),
        .buffered_bytes(buffered_bytes)
    );

    task automatic write_byte(input [7:0] value);
        begin
            @(negedge clk);
            tx_data = value;
            tx_wr = 1;
            @(negedge clk);
            tx_wr = 0;
        end
    endtask

    task automatic apply_ack(input [31:0] value);
        begin
            @(negedge clk);
            ack_seq = value;
            ack_valid = 1;
            @(negedge clk);
            ack_valid = 0;
        end
    endtask

    task automatic check_byte(input [31:0] sequence_number,
                              input [7:0] expected);
        begin
            @(negedge clk);
            read_seq = sequence_number;
            @(posedge clk);
            #1;
            if (read_data !== expected)
                $fatal(1, "Replay data mismatch at seq %08x: got %02x expected %02x",
                    sequence_number, read_data, expected);
        end
    endtask

    initial begin
        repeat (4) @(negedge clk);
        rst = 0;
        session_first_seq = START;
        session_start = 1;
        @(negedge clk);
        session_start = 0;

        // Fill through 32-bit sequence wrap. FULL rises with eight physical
        // byte slots left, but those late writes must still be accepted.
        for (i = 0; i < 24; i = i + 1)
            write_byte(i[7:0] ^ 8'ha5);
        if (!tcp_tx_full || buffered_bytes != 24)
            $fatal(1, "FULL guard did not assert at 24/32 bytes");
        for (i = 24; i < 32; i = i + 1)
            write_byte(i[7:0] ^ 8'ha5);
        if (write_seq != START + 32 || buffered_bytes != 32 || overflow_count != 0)
            $fatal(1, "Late writes after FULL were not retained");
        write_byte(8'hff);
        if (overflow_count != 1 || write_seq != START + 32)
            $fatal(1, "Full-buffer overflow was not contained");

        for (i = 0; i < 32; i = i + 1)
            check_byte(START + i, i[7:0] ^ 8'ha5);

        apply_ack(START + 16);
        if (first_stored_seq != START + 16 || buffered_bytes != 16 || tcp_tx_full)
            $fatal(1, "Wrapped cumulative ACK did not release storage");
        apply_ack(START + 8); // stale ACK
        apply_ack(START + 40); // ACK beyond written data
        if (invalid_ack_count != 2 || first_stored_seq != START + 16)
            $fatal(1, "Invalid ACK filtering failed");
        apply_ack(START + 32);
        if (buffered_bytes != 0 || first_stored_seq != write_seq)
            $fatal(1, "Final ACK did not empty replay ring");

        $display("PASS: replay BRAM ring, sequence wrap, FULL+8 guard and ACK validation");
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "Replay-buffer simulation timeout");
    end
endmodule
