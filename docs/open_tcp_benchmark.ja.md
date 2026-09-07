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
- 1秒RTO、最古の未ACKシーケンスからのSYN-ACK・データ・FIN再送
- ACKまで送信データを保持する32 KiBリプレイリング
- SiTCP相当の1 byte送信入力、`TCP_OPEN_ACK`相当の接続状態、`TCP_TX_FULL`立上がり後8 byteの書込み余裕
- 200 MHzユーザー入力から125 MHz PHY受信clockへ渡す64 byte非同期FIFO

送信データはSiTCP基準測定と同じ32 bit little-endian連番`0, 1, 2, ...`である。
カウンタ生成器は通常のアプリケーション送信源としてリプレイリングへ書き込み、TCPエンジンは
チェックサム計算時とフレーム生成時にBRAMから読み出す。RTO再送でも同じsequence位置を読み直すため、
任意のRHEAデータへ置換できる経路になった。
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

| 項目 | リプレイBRAM版 | 再生成版 | SiTCP基準 |
|---|---:|---:|---:|
| TCP payload | **40.080 MB/s (320.641 Mbps)** | 40.080 MB/s (320.640 Mbps) | 39.832 MB/s (318.654 Mbps) |
| 32 bit連番検査 | PASS | PASS | PASS |
| Total LUT | 3,378 | 2,862 | 2,852 |
| FF | 1,400 | 1,156 | 4,821 |
| RAMB36 / RAMB18 | 8 / 0 | 0 / 0 | 9 / 5 |
| post-route WNS / WHS | +1.853 / +0.042 ns | +1.401 / +0.034 ns | +0.990 / +0.020 ns |

独自TCPの1秒区間はおおむね320.5～320.7 Mbpsだった。PC側checkerはPython標準ライブラリを使用し、
TCPの任意の`recv()`分割をまたいで欠損、重複、順序違反を検査した。

固定1秒RTOと再送を追加した構成では、ACKを意図的に省いたxsim試験で`snd_una`からの
1460 byte再送を全wire byte照合した。実機10秒試験は40.081 MB/s（320.649 Mbps）で連番検査PASS、
post-route WNS/WHSは+1.701/+0.021 ns、資源量は3,011 LUT、1,181 FF、BRAM 0だった。

続いて32 KiBリプレイリングを統合した。xsimではTCP sequenceの32 bit周回、FULL通知後8 byte、
過剰書込みの封じ込め、累積ACK解放、通常の2セグメント送信、ACK欠落時にBRAMから同一内容を再送することを確認した。
Vivadoはリングを8個のRAMB36E2として推論した。AXKU042の30秒実機試験は40.079 MB/s
（320.632 Mbps）で連番検査PASSとなった。さらに接続確立前の入力を停止する最終構成で10秒測定し、
40.080 MB/s（320.642 Mbps）、連番検査PASSだった。BRAM読出しによる速度低下は測定上見られなかった。

RHEA側と同じ200 MHz入力へ64 byte非同期FIFOを追加し、Gray code pointerを2段同期した。
FULLはFIFO満杯の8 byte前に通知する。切断時にFIFOへ残ったbyteが次接続へ出ないよう、session resetを
125 MHz側から200 MHz側へ送り、write pointerのreset完了ackが戻るまでread側を停止する。
xsimでは異なるclock位相でFULL後8 byte、順序、切断中書込み、RST後の再接続とpayloadの0再開を確認した。
実機では10秒測定を直ちに2回行い、40.079 MB/s（320.631 Mbps）と40.080 MB/s（320.641 Mbps）で
両方とも連番検査PASSだった。

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

このbitstreamは性能検証用プロトタイプである。固定1秒RTOによる再送と32 KiB送信保持は実装したが、RTTによるRTO更新、
指数バックオフ、輻輳ウィンドウの増減、zero-window probe、順不同受信、TCP sequenceの周回比較は未実装である。
200 MHzのSiTCP互換送信境界までは実装したが、現在のテストトップはRHEAの代わりに連番生成器を接続している。

次段ではこの境界を既存`data_transfer_to_sitcp`と代替可能なcore wrapperへ組み込み、RHEA全体をビルドする。
並行して接続終了の全経路と重複ACKを強化し、その後UDP/RBCPを同じMACへ載せる。LUTはSiTCPより増えているため、
ARP/ICMP/TCPのヘッダー生成muxと分散RAMを整理し、BRAM使用との交換で削減する。
