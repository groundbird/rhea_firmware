#!/usr/bin/env python3
"""Measure AXKU042 SiTCP TCP payload throughput and verify uint32-LE sequence.

No dependencies required. Optional NumPy accelerates verification. --no-verify
measures host receive throughput separately from sequence-checking overhead.
"""
import argparse
import array
import datetime
import json
import socket
import struct
import sys
import time
from pathlib import Path


class SequenceChecker:
    def __init__(self, backend="auto", start=0):
        self.next_word = start
        self.tail = b""
        self.checked_bytes = 0
        self.np = None
        if backend != "stdlib":
            try:
                import numpy as np
                self.np = np
            except ImportError:
                if backend == "numpy":
                    raise RuntimeError("NumPy requested but not installed") from None
        self.backend = "numpy" if self.np is not None else "stdlib"

    def feed(self, data):
        data = self.tail + data
        count = len(data) // 4
        body, self.tail = data[:count * 4], data[count * 4:]
        if not count:
            return
        # Build expected words in native C-backed storage; handle uint32 wrap.
        if self.np is not None:
            expected = (self.np.arange(count, dtype=self.np.uint32) +
                        self.np.uint32(self.next_word)).astype("<u4", copy=False).tobytes()
        else:
            end = self.next_word + count
            words = array.array("I", range(self.next_word, min(end, 1 << 32)))
            if end > 1 << 32:
                words.extend(range(end - (1 << 32)))
            if words.itemsize != 4:
                raise RuntimeError("This platform does not have 32-bit array('I')")
            if sys.byteorder != "little":
                words.byteswap()
            expected = words.tobytes()
        if body != expected:
            offset = next(i for i, (a, b) in enumerate(zip(body, expected)) if a != b)
            raise ValueError(f"Sequence mismatch at byte {self.checked_bytes + offset}: "
                             f"got 0x{body[offset]:02x}, expected 0x{expected[offset]:02x}")
        self.next_word = (self.next_word + count) & 0xffffffff
        self.checked_bytes += count * 4

    def check_tail(self):
        expected = struct.pack("<I", self.next_word)
        if self.tail != expected[:len(self.tail)]:
            raise ValueError(f"Sequence mismatch in trailing bytes at {self.checked_bytes}")
        return self.checked_bytes + len(self.tail)


class RBCP:
    def __init__(self, host, port=4660, timeout=1.0):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.settimeout(timeout)
        self.sock.connect((host, port))
        self.ident = 0

    def close(self):
        self.sock.close()

    def transact(self, address, length, payload=None):
        if not 1 <= length <= 255:
            raise ValueError("RBCP length must be 1..255")
        if payload is not None and len(payload) != length:
            raise ValueError("RBCP write length mismatch")
        self.ident = (self.ident + 1) & 255
        command = 0xc0 if payload is None else 0x80
        header = struct.pack("!BBBBI", 0xff, command, self.ident, length, address)
        self.sock.send(header + (payload or b""))
        # No automatic write retries: a lost reply does not prove write failure.
        deadline = time.monotonic() + self.sock.gettimeout()
        timeout = self.sock.gettimeout()
        try:
            while True:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise TimeoutError("RBCP response deadline expired")
                self.sock.settimeout(remaining)
                reply = self.sock.recv(2048)
                if len(reply) < 8:
                    raise ValueError("Short RBCP response")
                ver, cmd, ident, size, addr = struct.unpack("!BBBBI", reply[:8])
                if ident != self.ident:
                    continue
                if cmd & 1:
                    raise ValueError(f"RBCP bus error at 0x{address:08x}")
                if (ver, cmd, size, addr) != (0xff, command | 8, length, address):
                    raise ValueError("Unexpected RBCP response header")
                if len(reply) != 8 + length:
                    raise ValueError("Unexpected RBCP response length")
                if payload is not None and reply[8:] != payload:
                    raise ValueError("Unexpected RBCP write echo")
                return reply[8:]
        finally:
            self.sock.settimeout(timeout)

    def read(self, address, length):
        return self.transact(address, length)

    def write(self, address, payload):
        return self.transact(address, len(payload), payload)

    def snapshot(self):
        self.write(0x10, b"\x01")
        values = struct.unpack("<QQQII", self.read(0x20, 32))
        return dict(zip(("accepted_bytes", "open_cycles", "full_cycles",
                         "connections", "tcp_errors"), values))


def measure(args):
    checker = None if args.no_verify else SequenceChecker(args.backend)
    rbcp = None
    result = {
        "utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "host": args.host, "port": args.port,
        "requested_seconds": args.seconds, "warmup_seconds": args.warmup,
        "verification": checker.backend if checker else "disabled",
        "status": "running", "intervals": [],
    }
    print(f"Verification: {result['verification']}; units: decimal MB/s", flush=True)
    try:
        if not args.no_rbcp:
            rbcp = RBCP(args.host, args.rbcp_port, args.timeout)
            identity = rbcp.read(0, 8)
            if identity[:4] != b"STB1":
                raise ValueError(f"Not benchmark firmware (signature {identity[:4]!r})")
            result["fpga_clock_hz"] = struct.unpack("<I", identity[4:])[0]
            result["fpga_before"] = rbcp.snapshot()
            rbcp.write(9, b"\x01")
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.settimeout(args.timeout)
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, args.receive_buffer)
            sock.connect((args.host, args.port))
            result["socket_receive_buffer"] = sock.getsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF)
            start = time.perf_counter()
            warmup_end = start + args.warmup
            measured_start = start if args.warmup == 0 else None
            interval_start = start
            interval_bytes = total = measured = 0
            while True:
                data = sock.recv(args.chunk_bytes)
                now = time.perf_counter()
                if not data:
                    raise ConnectionError("TCP peer closed before measurement completed")
                if checker:
                    checker.feed(data)
                now = time.perf_counter()
                total += len(data)
                if measured_start is None:
                    if now >= warmup_end:
                        measured_start = now
                        interval_start = now
                    continue  # Discard the whole chunk crossing the warmup boundary.
                measured += len(data)
                interval_bytes += len(data)
                # Include checker cost in throughput: this is an application rate.
                if now - interval_start >= 1.0:
                    elapsed = now - interval_start
                    rate = interval_bytes / elapsed / 1e6
                    result["intervals"].append({"seconds": now - measured_start,
                                                "MB_per_s": rate})
                    print(f"{now - measured_start:7.2f} s  {rate:8.3f} MB/s  "
                          f"{rate * 8:8.3f} Mbit/s", flush=True)
                    interval_start, interval_bytes = now, 0
                if now - measured_start >= args.seconds:
                    break
            result.update(received_bytes=total, measured_bytes=measured,
                          elapsed_seconds=now - measured_start,
                          MB_per_s=measured / (now - measured_start) / 1e6)
            if checker:
                result["verified_bytes"] = checker.check_tail()
            # Snapshot after the timed section, so UDP latency is not timed as TCP.
            if rbcp:
                result["fpga_after"] = rbcp.snapshot()
                before, after = result["fpga_before"], result["fpga_after"]
                delta = {k: (after[k] - before[k]) % (1 << (32 if k in
                         ("connections", "tcp_errors") else 64)) for k in before}
                result["fpga_delta"] = delta
                if delta["open_cycles"]:
                    result["fpga_full_fraction"] = delta["full_cycles"] / delta["open_cycles"]
        result["status"] = "passed" if checker else "measured_unverified"
        print(f"Average: {result['MB_per_s']:.3f} MB/s "
              f"({result['MB_per_s'] * 8:.3f} Mbit/s); {result['status']}")
        return result
    except (OSError, ValueError, RuntimeError) as exc:
        result.update(status="failed", error=str(exc))
        raise
    finally:
        if rbcp:
            rbcp.close()
        if args.json:
            Path(args.json).write_text(json.dumps(result, indent=2) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="192.168.10.16")
    parser.add_argument("--port", type=int, default=24)
    parser.add_argument("--rbcp-port", type=int, default=4660)
    parser.add_argument("--seconds", type=float, default=30)
    parser.add_argument("--warmup", type=float, default=2)
    parser.add_argument("--timeout", type=float, default=5)
    parser.add_argument("--chunk-bytes", type=int, default=262144)
    parser.add_argument("--receive-buffer", type=int, default=4 * 1024 * 1024)
    parser.add_argument("--backend", choices=("auto", "stdlib", "numpy"), default="auto")
    parser.add_argument("--no-verify", action="store_true")
    parser.add_argument("--no-rbcp", action="store_true", help="Skip identity and statistics checks")
    parser.add_argument("--json", help="Write result, including failures, to this path")
    args = parser.parse_args()
    if (args.seconds <= 0 or args.warmup < 0 or args.timeout <= 0 or
            args.chunk_bytes < 4 or args.chunk_bytes > 16 * 1024 * 1024 or
            args.receive_buffer <= 0):
        parser.error("Invalid duration, timeout, chunk size (4..16 MiB), or receive buffer")
    try:
        measure(args)
    except (OSError, ValueError, RuntimeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
