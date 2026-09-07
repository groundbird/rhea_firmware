#!/usr/bin/env python3
"""Configure and measure the RHEA IQ stream over the open TCP core."""

import argparse
import socket
import sys
import time

from sitcp_benchmark import RBCP


IQ_STATUS = 0x50000000
IQ_RESET_TIMESTAMP = 0x50000001
IQ_FIFO_ERROR = 0x50000002
IQ_READ_WIDTH = 0x50000010
DS_ACCUMULATION = 0x61000000


class PacketChecker:
    def __init__(self, channels):
        self.packet_bytes = 7 + channels * 2 * 7
        self.tail = b""
        self.data_packets = 0
        self.sync_packets = 0
        self.next_timestamp = None

    def feed(self, data):
        data = self.tail + data
        complete = len(data) // self.packet_bytes
        for index in range(complete):
            packet = data[index * self.packet_bytes:(index + 1) * self.packet_bytes]
            if packet[-1] != 0xee:
                raise ValueError(f"Bad packet footer at packet {self.data_packets}")
            if packet[0] == 0xf5:
                self.sync_packets += 1
                continue
            if packet[0] != 0xff:
                raise ValueError(
                    f"Bad packet header 0x{packet[0]:02x} at packet {self.data_packets}")
            timestamp = int.from_bytes(packet[1:6], "big")
            if self.next_timestamp is not None and timestamp != self.next_timestamp:
                raise ValueError(
                    f"Timestamp discontinuity at packet {self.data_packets}: "
                    f"got {timestamp}, expected {self.next_timestamp}")
            self.next_timestamp = (timestamp + 1) & ((1 << 40) - 1)
            self.data_packets += 1
        self.tail = data[complete * self.packet_bytes:]


def transact_retry(rbcp, address, payload=None, length=None, attempts=6):
    for attempt in range(attempts):
        try:
            if payload is None:
                return rbcp.read(address, length)
            return rbcp.write(address, payload)
        except (OSError, TimeoutError, ValueError):
            if attempt + 1 == attempts:
                raise
            time.sleep(0.01)
    raise AssertionError("unreachable")


def write_register(rbcp, address, value, length=1):
    transact_retry(rbcp, address, value.to_bytes(length, "big"))


def measure(args):
    checker = PacketChecker(args.channels)
    rbcp = RBCP(args.host, args.rbcp_port, args.timeout)
    tcp = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    tcp.settimeout(args.timeout)
    tcp.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, args.receive_buffer)
    enabled = False
    measured_bytes = 0
    try:
        tcp.connect((args.host, args.port))
        write_register(rbcp, IQ_STATUS, 0)
        write_register(rbcp, IQ_READ_WIDTH, args.channels)
        write_register(rbcp, DS_ACCUMULATION, args.accumulation, 4)
        write_register(rbcp, IQ_FIFO_ERROR, 0)
        write_register(rbcp, IQ_RESET_TIMESTAMP, 1)
        write_register(rbcp, IQ_STATUS, 1)
        enabled = True

        started = time.perf_counter()
        warmup_end = started + args.warmup
        stop_at = warmup_end + args.seconds
        measured_start = None
        while True:
            try:
                data = tcp.recv(args.chunk_bytes)
            except socket.timeout as exc:
                iq_status = transact_retry(rbcp, IQ_STATUS, length=1)[0]
                fifo_error = transact_retry(rbcp, IQ_FIFO_ERROR, length=1)[0]
                raise TimeoutError(
                    f"TCP receive timed out; IQ active: {bool(iq_status)}; "
                    f"FIFO error: {bool(fifo_error)}") from exc
            now = time.perf_counter()
            if not data:
                raise ConnectionError("FPGA closed the TCP connection")
            if not args.no_verify:
                checker.feed(data)
            if now >= warmup_end:
                if measured_start is None:
                    measured_start = now
                measured_bytes += len(data)
            if now >= stop_at:
                break

        elapsed = now - measured_start
        rate_mbps = measured_bytes * 8 / elapsed / 1e6
        iq_status = transact_retry(rbcp, IQ_STATUS, length=1)[0]
        fifo_error = transact_retry(rbcp, IQ_FIFO_ERROR, length=1)[0]
        expected = (200_000_000 / args.accumulation * checker.packet_bytes * 8 /
                    1e6)
        print(f"Rate: {rate_mbps:.3f} Mbps; expected source rate: {expected:.3f} Mbps")
        print(f"Measured: {measured_bytes} bytes in {elapsed:.6f} s; "
              f"IQ active: {bool(iq_status)}; FIFO error: {bool(fifo_error)}")
        if not args.no_verify:
            print(f"Verified: {checker.data_packets} data packets, "
                  f"{checker.sync_packets} sync packets, "
                  f"{len(checker.tail)} trailing bytes")
        if not iq_status or fifo_error:
            raise RuntimeError("RHEA stream stopped or reported a FIFO error")
    finally:
        if enabled:
            try:
                write_register(rbcp, IQ_STATUS, 0)
            except (OSError, TimeoutError, ValueError) as exc:
                print(f"WARNING: could not stop IQ stream: {exc}", file=sys.stderr)
        tcp.close()
        rbcp.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="192.168.10.16")
    parser.add_argument("--port", type=int, default=24)
    parser.add_argument("--rbcp-port", type=int, default=4660)
    parser.add_argument("--channels", type=int, default=8)
    parser.add_argument("--accumulation", type=int, default=656)
    parser.add_argument("--seconds", type=float, default=5)
    parser.add_argument("--warmup", type=float, default=1)
    parser.add_argument("--timeout", type=float, default=2)
    parser.add_argument("--chunk-bytes", type=int, default=262144)
    parser.add_argument("--receive-buffer", type=int, default=4 * 1024 * 1024)
    parser.add_argument("--no-verify", action="store_true")
    args = parser.parse_args()
    if (not 1 <= args.channels <= 64 or
            not 10 <= args.accumulation <= 200_000 or
            args.seconds <= 0 or args.warmup < 0 or args.timeout <= 0 or
            not 119 <= args.chunk_bytes <= 16 * 1024 * 1024):
        parser.error("Invalid channels, accumulation, duration, timeout, or chunk size")
    try:
        measure(args)
    except (ConnectionError, OSError, TimeoutError, ValueError, RuntimeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
