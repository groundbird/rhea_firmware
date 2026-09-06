"""Run with: python3 -m unittest discover -s tools -p 'test_sitcp_benchmark.py'."""
import argparse
import contextlib
import io
import itertools
import json
import struct
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from sitcp_benchmark import RBCP, SequenceChecker, measure


class SequenceTests(unittest.TestCase):
    def test_fragmented_stream_and_uint32_wrap(self):
        checker = SequenceChecker("stdlib", start=0xfffffffd)
        data = struct.pack("<6I", 0xfffffffd, 0xfffffffe, 0xffffffff, 0, 1, 2)
        for a, b in ((0, 1), (1, 3), (3, 14), (14, 17), (17, 24)):
            checker.feed(data[a:b])
        self.assertEqual(checker.check_tail(), len(data))

    def test_missing_and_duplicate_words(self):
        for words in ((0, 1, 3), (0, 1, 1)):
            with self.subTest(words=words), self.assertRaises(ValueError):
                SequenceChecker("stdlib").feed(struct.pack("<3I", *words))

    def test_partial_last_word(self):
        checker = SequenceChecker("stdlib")
        checker.feed(struct.pack("<2I", 0, 1)[:7])
        self.assertEqual(checker.check_tail(), 7)
        checker = SequenceChecker("stdlib")
        checker.feed(b"\x01")
        with self.assertRaises(ValueError):
            checker.check_tail()


class FakeUDP:
    def __init__(self, *args, **kwargs):
        self.timeout = 1
        self.transform = lambda data: data

    def settimeout(self, timeout):
        self.timeout = timeout

    def gettimeout(self):
        return self.timeout

    def connect(self, peer):
        pass

    def send(self, data):
        self.request = data

    def recv(self, size):
        ver, cmd, ident, length, addr = struct.unpack("!BBBBI", self.request[:8])
        payload = self.request[8:] if cmd == 0x80 else bytes(range(length))
        return self.transform(struct.pack("!BBBBI", ver, cmd | 8, ident, length, addr) + payload)

    def close(self):
        pass


class ProtocolTests(unittest.TestCase):
    def test_timed_receive_with_warmup(self):
        class FakeTCP(FakeUDP):
            position = 0

            def __enter__(self):
                return self

            def __exit__(self, *args):
                pass

            def setsockopt(self, *args):
                pass

            def getsockopt(self, *args):
                return 8192

            def recv(self, size):
                # Deliberately not aligned to word boundaries.
                stream = struct.pack("<256I", *range(256))
                data = stream[self.position:self.position + 13]
                self.position += len(data)
                return data

        args = argparse.Namespace(no_verify=False, backend="stdlib", host="127.0.0.1",
                                  port=24, seconds=.05, warmup=.02, no_rbcp=True,
                                  timeout=1, receive_buffer=4096, json=None, chunk_bytes=128)
        times = itertools.count(0, .01)
        with patch("sitcp_benchmark.socket.socket", FakeTCP), \
                patch("sitcp_benchmark.time.perf_counter", side_effect=lambda: next(times)), \
                contextlib.redirect_stdout(io.StringIO()):
            result = measure(args)
        self.assertEqual(result["status"], "passed")
        self.assertEqual(result["verified_bytes"], result["received_bytes"])
        self.assertLess(result["measured_bytes"], result["received_bytes"])
        self.assertGreaterEqual(result["elapsed_seconds"], args.seconds)

    def test_rbcp_read_write_and_bad_reply(self):
        with patch("sitcp_benchmark.socket.socket", FakeUDP):
            client = RBCP("127.0.0.1")
            self.assertEqual(client.read(0x20, 4), bytes(range(4)))
            client.write(9, b"\x01")
            self.assertEqual(client.sock.request, b"\xff\x80\x02\x01\x00\x00\x00\x09\x01")
            client.sock.transform = lambda data: data[:1] + b"\xc9" + data[2:]
            with self.assertRaisesRegex(ValueError, "bus error"):
                client.read(0, 4)
            client.sock.transform = lambda data: data[:-1]
            with self.assertRaisesRegex(ValueError, "length"):
                client.read(0, 4)

    def test_failed_measurement_is_saved(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "result.json"
            args = argparse.Namespace(no_verify=False, backend="stdlib", host="127.0.0.1",
                                      port=24, seconds=1, warmup=0, no_rbcp=True,
                                      timeout=1, receive_buffer=4096, json=str(path))
            with patch("sitcp_benchmark.socket.socket", side_effect=OSError("offline")):
                with contextlib.redirect_stdout(io.StringIO()), self.assertRaises(OSError):
                    measure(args)
            self.assertEqual(json.loads(path.read_text())["status"], "failed")


if __name__ == "__main__":
    unittest.main()
