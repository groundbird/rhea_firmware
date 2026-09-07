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
- UDP port 4660のRBCP read/write、最大255 byte、200 MHzレジスタバスへのCDC、100 ms ACK timeout

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
| TCP payload | **40.081 MB/s (320.649 Mbps)** | 40.080 MB/s (320.640 Mbps) | 39.832 MB/s (318.654 Mbps) |
| 32 bit連番検査 | PASS | PASS | PASS |
| Total LUT | 3,377 | 2,862 | 2,852 |
| FF | 1,400 | 1,156 | 4,821 |
| RAMB36 / RAMB18 | 8 / 0 | 0 / 0 | 9 / 5 |
| post-route WNS / WHS | +1.926 / +0.041 ns | +1.401 / +0.034 ns | +0.990 / +0.020 ns |

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
共通coreへ分離した構成の実機では10秒測定を直ちに2回行い、40.081 MB/s（320.649 Mbps）と40.080 MB/s（320.641 Mbps）で
両方とも連番検査PASSだった。

RBCP/UDPを追加し、1 byteずつ既存200 MHzレジスタバスへ渡すtoggle CDCを実装した。write/readの連続アドレス、
応答フレーム、bus timeout、timeout後の遅延ACK隔離をxsimで検証した。RBCP payloadにも2段同期を置いた最終構成では、
Vivado CDC reportの新規Criticalは0件である。独立トップの資源は3,912 LUT、2,227 FF、8 RAMB36、
post-route WNS/WHSは+1.604/+0.017 nsだった。

AXKU042ではPC側ツールからRBCPの`STB1`識別、統計snapshot、送信enable writeを行ってから5秒間受信し、
40.080 MB/s（320.644 Mbps）、240,479,520 byteの連番検査PASS、TCP error 0を確認した。

## RHEA統合

物理層からTCPまでを`axku042_open_net_core`へ分離し、既存`axku042_sitcp_core`と同じ外部ポートにした。
`sitcp.vhd`とRHEA topのgeneric `USE_OPEN_NET`、プロジェクト生成時の`--open-net`により、vendor SiTCP
netlistを読み込まずに独自coreを選べる。静的MAC/IP、TCP port 24、RBCP/UDP port 4660を用い、
EEPROMの読出し結果には依存しない。

64チャンネルではtriggerのRBCP threshold readbackが128要素のflat muxとなり、最初の実装は
WNS -0.784 ns、TNS -192.447 nsで失敗した。readを8要素、16 group、byteの3段に分け、write側も
channelとbyteをone-hot registerへ一度受けてから更新するようにした。channel 0、37、63のA/B threshold、
enable、隣接channel分離、遅延ACKをtrigger単体xsimで確認した。修正後の64チャンネル実装は
WNS +0.036 ns、WHS +0.030 nsでbitstream生成まで成功した。

ADC入力では、ビットごとのIDDRE1 reset FFがVivadoに統合されて長いreset netになっていたため、
`DONT_TOUCH`で14個を保持した。最悪recovery pathの始終点は同じADC bitの専用FFになっている。

8チャンネルdebug buildは通常の64チャンネルpackageを編集せず、`--debug-8ch`で専用packageと
`rhea-fpga-8ch` projectを生成できる。64チャンネル実装と並行して生成した最終版もtiming violation 0である。

| 項目 | RHEA 8チャンネル | RHEA 64チャンネル | 独自network core（64ch内） |
|---|---:|---:|---:|
| LUT | 26,843 | 88,196 | 3,479 |
| FF | 35,216 | 261,819 | 1,750 |
| RAMB36 / RAMB18 | 121 / 48 | 457 / 1 | 8 / 0 |
| DSP | 102 | 550 | 0 |
| post-route WNS / WHS | +0.008 / +0.030 ns | +0.036 / +0.030 ns | - |

両実装でVivadoが報告したDRCはwarningとadvisoryのみで、timing violationはない。CDC reportには、
RGMII入力IDDR、非同期reset、およびtoggleで安定保持bufferを渡す送信経路にCritical/Warning判定が残る。
送信経路はrequest toggleの2段同期中からdone toggleが戻るまでbufferを保持する設計で実機試験済みだが、
運用判定までにCDC制約またはVivadoが認識できる構造へ整理する。

通常ソースのチャンネル定数は64である。64チャンネルbitstreamは
`rhea-fpga/rhea-fpga.runs/impl_1/rhea.bit`、独立8チャンネルbitstreamは
`rhea-fpga-8ch/rhea-fpga-8ch.runs/impl_1/rhea.bit`に生成される。どちらも最終RBCP CDC版を含む。
FPGA上は引き続きstandalone RBCP benchmark版であり、これらのRHEA統合版はまだ書き込んでいない。

## 再現方法

管理Docker内でプロジェクトを作成・ビルドする。

```bash
vivado -mode batch -nolog -nojournal \
  -source vivado/create_axku042_open_net_test.tcl -tclargs --build
```

RHEA全体の独自network版は次の2段階で生成する。

```bash
vivado -mode batch -nolog -nojournal \
  -source rhea-fpga.tcl -tclargs --open-net
vivado -mode batch -nolog -nojournal \
  -source vivado/build_axku042_open_rhea.tcl
```

64チャンネル設定を変えずに、独立した8チャンネルdebug buildを生成する。

```bash
vivado -mode batch -nolog -nojournal \
  -source rhea-fpga.tcl -tclargs --debug-8ch
vivado -mode batch -nolog -nojournal \
  -source vivado/build_axku042_open_rhea.tcl \
  -tclargs --project-name rhea-fpga-8ch
```

64チャンネルの長い実装を分けて実行する場合は、合成後にcheckpointを再利用する。

```bash
vivado -mode batch -nolog -nojournal \
  -source vivado/build_axku042_open_rhea.tcl -tclargs --synth-only
vivado -mode batch -nolog -nojournal \
  -source vivado/build_axku042_open_rhea.tcl -tclargs --reuse-synth
```

USB JTAG版Docker内から揮発性設定へ書き込む。

```bash
vivado -mode batch -nolog -nojournal \
  -source vivado/axku042_open_net_hw.tcl \
  -tclargs --program \
  --target localhost:3121/xilinx_tcf/Digilent/210512180081
```

RBCPの識別・統計アクセスとTCPをまとめて測定する。

```bash
python3 tools/sitcp_benchmark.py --seconds 30 --warmup 2
```

## 次に必要な機能

このbitstreamは性能検証用プロトタイプである。固定1秒RTOによる再送と32 KiB送信保持は実装したが、RTTによるRTO更新、
指数バックオフ、輻輳ウィンドウの増減、zero-window probe、順不同受信、TCP sequenceの周回比較は未実装である。
200 MHzのSiTCP互換送信境界、RBCP、8/64チャンネルRHEAの配置配線までは完了した。

次段では8チャンネルRHEA版を実機へ書き込み、RHEAのレジスタマップ、データ形式、連続転送を確認する。
その後64チャンネル版でも同じ試験を行う。RBCP受信UDP checksum検査と処理中のTCP ACK受信余裕も追加する。
並行して接続終了の全経路と重複ACKを強化する。LUTはSiTCPより増えているため、
ARP/ICMP/TCPのヘッダー生成muxと分散RAMを整理し、BRAM使用との交換で削減する。
