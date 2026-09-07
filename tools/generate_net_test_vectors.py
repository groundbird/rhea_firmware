#!/usr/bin/env python3
"""Generate independent Ethernet ARP/ICMP/TCP/RBCP vectors using Python zlib."""
import argparse
import ipaddress
import struct
import zlib
from pathlib import Path

LOCAL_MAC = bytes.fromhex("025248454101")
HOST_MAC = bytes.fromhex("1cc03503feaf")
LOCAL_IP = ipaddress.IPv4Address("192.168.10.16").packed
HOST_IP = ipaddress.IPv4Address("192.168.10.3").packed


def checksum(data):
    if len(data) & 1:
        data += b"\0"
    total = sum(struct.unpack(f"!{len(data)//2}H", data))
    while total >> 16:
        total = (total & 0xffff) + (total >> 16)
    return (~total) & 0xffff


def wire(frame):
    frame = frame.ljust(60, b"\0")
    return frame + struct.pack("<I", zlib.crc32(frame))


def ip_packet(src, dst, payload, ident=0x1234, protocol=1):
    header = struct.pack("!BBHHHBBH4s4s", 0x45, 0, 20 + len(payload), ident,
                         0x4000, 64, protocol, 0, src, dst)
    header = header[:10] + struct.pack("!H", checksum(header)) + header[12:]
    return header + payload


def icmp(kind, payload):
    packet = struct.pack("!BBHHH", kind, 0, 0, 0xBEEF, 7) + payload
    return packet[:2] + struct.pack("!H", checksum(packet)) + packet[4:]


def tcp(src_ip, dst_ip, src_port, dst_port, seq, ack, flags, window, payload=b""):
    segment = struct.pack("!HHIIBBHHH", src_port, dst_port, seq, ack,
                          5 << 4, flags, window, 0, 0) + payload
    pseudo = src_ip + dst_ip + struct.pack("!BBH", 0, 6, len(segment))
    csum = checksum(pseudo + segment)
    return segment[:16] + struct.pack("!H", csum) + segment[18:]


def udp(src_port, dst_port, payload):
    # UDP checksum zero is valid for IPv4 and matches the initial RBCP RTL.
    return struct.pack("!HHHH", src_port, dst_port, 8 + len(payload), 0) + payload


def write_hex(path, data):
    path.write_text("\n".join(f"{byte:02x}" for byte in data) + "\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)

    arp_body = struct.pack("!HHBBH6s4s6s4s", 1, 0x0800, 6, 4, 1,
                           HOST_MAC, HOST_IP, bytes(6), LOCAL_IP)
    arp_request = bytes(6) + HOST_MAC + b"\x08\x06" + arp_body
    arp_reply_body = struct.pack("!HHBBH6s4s6s4s", 1, 0x0800, 6, 4, 2,
                                 LOCAL_MAC, LOCAL_IP, HOST_MAC, HOST_IP)
    arp_reply = HOST_MAC + LOCAL_MAC + b"\x08\x06" + arp_reply_body

    payload = b"RHEA-open-net-icmp-vector-01"
    request_ip = ip_packet(HOST_IP, LOCAL_IP, icmp(8, payload))
    reply_ip = ip_packet(LOCAL_IP, HOST_IP, icmp(0, payload))
    icmp_request = LOCAL_MAC + HOST_MAC + b"\x08\x00" + request_ip
    icmp_reply = HOST_MAC + LOCAL_MAC + b"\x08\x00" + reply_ip

    wrong_ip = ipaddress.IPv4Address("192.168.10.99").packed
    wrong_request_ip = ip_packet(HOST_IP, wrong_ip, icmp(8, payload), ident=0x5678)
    wrong_request = LOCAL_MAC + HOST_MAC + b"\x08\x00" + wrong_request_ip

    host_port = 40000
    host_seq = 0x12345678
    fpga_isn = 0x52484541

    def tcp_frame(src_mac, dst_mac, src_ip, dst_ip, src_port, dst_port,
                  seq, ack, flags, window, ident, payload=b""):
        segment = tcp(src_ip, dst_ip, src_port, dst_port, seq, ack,
                      flags, window, payload)
        return dst_mac + src_mac + b"\x08\x00" + ip_packet(
            src_ip, dst_ip, segment, ident=ident, protocol=6)

    tcp_syn = tcp_frame(HOST_MAC, LOCAL_MAC, HOST_IP, LOCAL_IP,
                        host_port, 24, host_seq, 0, 0x02, 0xffff, 0x2000)
    tcp_synack = tcp_frame(LOCAL_MAC, HOST_MAC, LOCAL_IP, HOST_IP,
                           24, host_port, fpga_isn, host_seq + 1,
                           0x12, 0x8000, 1)
    tcp_ack = tcp_frame(HOST_MAC, LOCAL_MAC, HOST_IP, LOCAL_IP,
                        host_port, 24, host_seq + 1, fpga_isn + 1,
                        0x10, 0xffff, 0x2001)

    def benchmark_payload(first_word):
        return b"".join(struct.pack("<I", first_word + i) for i in range(365))

    tcp_data0 = tcp_frame(LOCAL_MAC, HOST_MAC, LOCAL_IP, HOST_IP,
                          24, host_port, fpga_isn + 1, host_seq + 1,
                          0x18, 0x8000, 2, benchmark_payload(0))
    tcp_ack0 = tcp_frame(HOST_MAC, LOCAL_MAC, HOST_IP, LOCAL_IP,
                         host_port, 24, host_seq + 1, fpga_isn + 1 + 1460,
                         0x10, 0xffff, 0x2002)
    tcp_rst = tcp_frame(HOST_MAC, LOCAL_MAC, HOST_IP, LOCAL_IP,
                        host_port, 24, host_seq + 1,
                        fpga_isn + 1 + 2 * 1460, 0x14, 0xffff, 0x2003)
    tcp_data0_retx = tcp_frame(LOCAL_MAC, HOST_MAC, LOCAL_IP, HOST_IP,
                               24, host_port, fpga_isn + 1, host_seq + 1,
                               0x18, 0x8000, 3, benchmark_payload(0))
    tcp_data1 = tcp_frame(LOCAL_MAC, HOST_MAC, LOCAL_IP, HOST_IP,
                          24, host_port, fpga_isn + 1 + 1460, host_seq + 1,
                          0x18, 0x8000, 3, benchmark_payload(365))
    tcp_synack_reconnect = tcp_frame(
        LOCAL_MAC, HOST_MAC, LOCAL_IP, HOST_IP, 24, host_port, fpga_isn,
        host_seq + 1, 0x12, 0x8000, 4)
    tcp_data_reconnect = tcp_frame(
        LOCAL_MAC, HOST_MAC, LOCAL_IP, HOST_IP, 24, host_port, fpga_isn + 1,
        host_seq + 1, 0x18, 0x8000, 5, benchmark_payload(0))

    rbcp_port = 4660
    rbcp_host_port = 50000
    rbcp_addr = 0x40000010
    rbcp_payload = b"\x12\x34\x56"

    def rbcp_header(command, ident, length):
        return struct.pack("!BBBBI", 0xff, command, ident, length, rbcp_addr)

    def udp_frame(src_mac, dst_mac, src_ip, dst_ip, src_port, dst_port,
                  payload, ident):
        datagram = udp(src_port, dst_port, payload)
        return dst_mac + src_mac + b"\x08\x00" + ip_packet(
            src_ip, dst_ip, datagram, ident=ident, protocol=17)

    rbcp_write_request = udp_frame(
        HOST_MAC, LOCAL_MAC, HOST_IP, LOCAL_IP, rbcp_host_port, rbcp_port,
        rbcp_header(0x80, 0x5a, len(rbcp_payload)) + rbcp_payload, 0x3000)
    rbcp_write_reply = udp_frame(
        LOCAL_MAC, HOST_MAC, LOCAL_IP, HOST_IP, rbcp_port, rbcp_host_port,
        rbcp_header(0x88, 0x5a, len(rbcp_payload)) + rbcp_payload, 1)
    rbcp_read_request = udp_frame(
        HOST_MAC, LOCAL_MAC, HOST_IP, LOCAL_IP, rbcp_host_port, rbcp_port,
        rbcp_header(0xc0, 0x5b, len(rbcp_payload)), 0x3001)
    rbcp_read_reply = udp_frame(
        LOCAL_MAC, HOST_MAC, LOCAL_IP, HOST_IP, rbcp_port, rbcp_host_port,
        rbcp_header(0xc8, 0x5b, len(rbcp_payload)) + rbcp_payload, 2)

    for name, data in {
        "arp_request.hex": wire(arp_request),
        "arp_reply.hex": wire(arp_reply),
        "icmp_request.hex": wire(icmp_request),
        "icmp_reply.hex": wire(icmp_reply),
        "wrong_ip_request.hex": wire(wrong_request),
        "tcp_syn.hex": wire(tcp_syn),
        "tcp_synack.hex": wire(tcp_synack),
        "tcp_ack.hex": wire(tcp_ack),
        "tcp_data0.hex": wire(tcp_data0),
        "tcp_ack0.hex": wire(tcp_ack0),
        "tcp_rst.hex": wire(tcp_rst),
        "tcp_data0_retx.hex": wire(tcp_data0_retx),
        "tcp_data1.hex": wire(tcp_data1),
        "tcp_synack_reconnect.hex": wire(tcp_synack_reconnect),
        "tcp_data_reconnect.hex": wire(tcp_data_reconnect),
        "rbcp_write_request.hex": wire(rbcp_write_request),
        "rbcp_write_reply.hex": wire(rbcp_write_reply),
        "rbcp_read_request.hex": wire(rbcp_read_request),
        "rbcp_read_reply.hex": wire(rbcp_read_reply),
    }.items():
        write_hex(args.output / name, data)


if __name__ == "__main__":
    main()
