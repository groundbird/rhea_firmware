# AXKU042 単一接続TCPプロトタイプ

2026-09-06に、SiTCPのネットリストを使わない独自RTLをAXKU042へ実装し、1 GbEで実機測定した。
この段階の目的は、単一クライアント専用設計で300 Mbps程度を得られるかを確認することである。

## 実装範囲

- RGMII/GMII変換、Ethernet受信FCS検査、送信FCS・padding・IFG生成
- 固定MAC `02:52:48:45:41:01`、固定IPv4 `192.168.10.16`
- ARP requestへのreply、IPv4 ICMP Echo reply
- TCPポート24、1接続分のTCB、passive open、3-way handshake
- IPv4/TCP checksum検査・生成、固定MSS 1460 byte
- 累積ACKと相手の16 bit receive window、最大10 MSSの送信中データ
- ACK付きカウンタストリーム送信、RST処理、基本的なFIN処理

送信データはSiTCP基準測定と同じ32 bit little-endian連番`0, 1, 2, ...`である。
各1460 byteセグメントは、TCP checksum計算とフレームバッファ生成の2パスで処理する。
この単純な構成の理論ペイロード速度は約324 Mbpsであり、1 byte/clock送信へ発展させる前の基準になる。

## 検証結果

Vivado/xsim 2025.2.1の独立ベクター試験で、次を確認した。

- ARP replyとICMP Echo replyの全wire byte一致
- Ethernet FCS、padding、IFG、IPv4/ICMP checksum
- bad FCSと異なる宛先IPv4の破棄
- TCP SYN/SYN-ACK/ACK、IP/TCP/FCS checksum
- 2個の1460 byte TCPセグメントについて、sequence/ACK番号とpayloadの全byte一致

AXKU042ではDigilent JTAGから揮発性bitstreamを書込み、ping 5/5応答、packet loss 0%、RTT平均0.201 msを確認した。
続いてLinux標準TCP socketで30秒受信し、次の結果を得た。

| 項目 | 独自TCP | SiTCP基準 |
|---|---:|---:|
| TCP payload | **40.080 MB/s (320.640 Mbps)** | 39.832 MB/s (318.654 Mbps) |
| 検査byte数 | 1,282,558,900 | 1,274,842,800 |
| 32 bit連番検査 | PASS | PASS |
| Total LUT | 2,862 | 2,852 |
| FF | 1,156 | 4,821 |
| RAMB36 / RAMB18 | 0 / 0 | 9 / 5 |
| post-route WNS / WHS | +1.401 / +0.034 ns | +0.990 / +0.020 ns |

独自TCPの1秒区間はおおむね320.5～320.7 Mbpsだった。PC側checkerはPython標準ライブラリを使用し、
TCPの任意の`recv()`分割をまたいで欠損、重複、順序違反を検査した。

## 再現方法

管理Docker内でプロジェクトを作成・ビルドする。

```bash
vivado -mode batch -nolog -nojournal \
  -source vivado/create_axku042_open_net_test.tcl -tclargs --build
```

USB JTAG版Docker内から揮発性設定へ書き込む。

```bash
vivado -mode batch -nolog -nojournal \
  -source vivado/axku042_open_net_hw.tcl \
  -tclargs --program \
  --target localhost:3121/xilinx_tcf/Digilent/210512180081
```

現在はRBCPをまだ持たないため、速度測定では識別・統計アクセスを省く。

```bash
python3 tools/sitcp_benchmark.py --no-rbcp --seconds 30 --warmup 2
```

## 次に必要な機能

このbitstreamは性能検証用プロトタイプであり、現時点ではパケット損失時の再送タイマー、RTT/RTO更新、
輻輳ウィンドウの増減、zero-window probe、順不同受信、TCP sequenceの周回比較を実装していない。
送信データも再生成可能な連番に限定しており、RHEAデータをACKまで保持する再送RAMは未接続である。

次段では、ACK済み・新規送信済み・未送信位置を分けた送信リング、RTOと再送、重複ACK、
接続終了の全経路を追加する。その後UDP/RBCPを同じMACへ載せ、既存`TCP_TX_FULL`の8 clock余裕を持つ
アダプターを介してRHEAデータFIFOへ接続する。LUTはSiTCPと同程度まで増えているため、
ARP/ICMP/TCPのヘッダー生成muxと分散RAMを整理し、BRAM使用との交換で削減する。
