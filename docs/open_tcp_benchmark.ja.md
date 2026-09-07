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
- UDP port 4660のRBCP read/write、最大255 byte、200 MHzレジスタバスへのCDC、5 ms ACK timeout

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

統合版を実機へ書き込んだところ、最初はpingの約10%が欠落した。RBCPから読める受信カウンタを追加して
調べると、欠落したrequestとRGMII RXのFCS error数が一致した。KSZ9031の既定RXC delay約1.2 nsに加えて、
FPGA内のRX MMCMでRXCを45度（125 MHzで1.0 ns）遅らせ、DDR sampling位置をdata eye中央付近へ移した。
また、実装ごとのglobal clock配置変動を避けるため、AXKU042用BUFG位置を固定した。

2026-09-07の最初の8チャンネル再ビルドでは500 pingすべてに応答し、packet loss 0%、FPGAの受信FCS error 0、
受信drop 0だった。400回のRBCP試験（通常register、DAC内部register、ADC SPI、DAC SPIを各100回）も
bus error、timeout、retryすべて0だった。一方、実際の`health_check.py diagnosis`では約3,374アクセス中
26–29件、約0.8%のbus ACK timeoutが発生し、再試行を含めて約1.30秒かかっていた。

同一アドレスだけの反復では再現せず、内部register、DAC register、SPIなど異なるアドレスと応答時間を
切り替えた場合だけ再現した。RHEA内で要求とACKを別々の非同期FIFOへ入れていた経路を、ペイロードを
安定保持するtoggle CDCへ置き換えた。制御toggleの検出後にさらに1 destination clock待ってからaddress、
write data、read dataを使い、bundled dataの各bitが2段同期器を通過する時間を確保した。さらに、情報registerと
Clock Wizard registerは内部clock domainでACKされるため、これらの要求を外部RHEA clock domainへ送らないようにした。
AXKU042のXDCでは`clk_ab_p`からの生成clockも非同期clock groupへ含めた。

修正版では、異なる内部/外部/SPIアドレスを組み合わせたread-only 32,000要求とread/write 32,000要求を
再試行なしで実行し、bus error 0だった。`health_check.py diagnosis`と同じ処理も3回連続で各3,374アクセス、
bus error 0、timeout 0、retry 0となり、各回約0.74秒で完了した。ADC/DACのデバイス診断値は引き続き
不一致を示すが、RBCP転送エラーとは分離できた。通常registerとADC/DAC SPIを各100回読む回帰試験も全件成功した。
最終8チャンネル実装はWNS +0.149 ns、WHS +0.030 nsでtiming violation 0である。

8チャンネルIQ formatterを119 byte/packet、`accumulation=635`に設定した実データ経路では、
修正後の5秒試験では187,402,680 byte、**299.846 Mbps**を受信した。これは200 MHz / 635 × 119 byteの
source rate 299.843 Mbpsと一致する。1,889,755 packetのheader、footer、40 bit timestamp連続性を検査して
error 0、送信後もIQ active、FIFO error 0だった。

同じ設定を長時間続けると、TCP ACK処理による短いbackpressureでRHEAの送信FIFOがprogrammable-fullに達し、
既存`iq_reader`の安全動作によりIQ出力が停止した。`accumulation=656`へ下げた30秒試験では、
1,088,412,480 byte、**290.243 Mbps**を連続受信し、9,756,051 packetの検査error 0、
IQ active、FIFO error 0だった。`accumulation=645`の約295 Mbpsでは安全停止が再現したため、
再現用ツールの既定値は30秒完走済みの656としている。

| 項目 | RHEA 8チャンネル | RHEA 64チャンネル | 独自network core（64ch内） |
|---|---:|---:|---:|
| LUT | 26,863 | 88,196 | 3,621 |
| FF | 37,284 | 261,819 | 2,004 |
| RAMB36 / RAMB18 | 120 / 20 | 457 / 1 | 8 / 0 |
| DSP | 102 | 550 | 0 |
| post-route WNS / WHS | +0.149 / +0.030 ns | +0.036 / +0.030 ns | - |

両実装でVivadoが報告したDRCはwarningとadvisoryのみで、timing violationはない。CDC reportには、
RGMII入力IDDR、非同期reset、およびtoggleで安定保持bufferを渡す送信経路にCritical/Warning判定が残る。
送信経路はrequest toggleの2段同期中からdone toggleが戻るまでbufferを保持する設計で実機試験済みだが、
運用判定までにCDC制約またはVivadoが認識できる構造へ整理する。

通常ソースのチャンネル定数は64である。64チャンネルbitstreamは
`rhea-fpga/rhea-fpga.runs/impl_1/rhea.bit`、独立8チャンネルbitstreamは
`rhea-fpga-8ch/rhea-fpga-8ch.runs/impl_1/rhea.bit`に生成される。8チャンネル統合版は最終RBCP CDC版を
実機へ書き込み、RGMII、RBCP、IQ転送の試験まで完了した。64チャンネルbitstreamは同じソースから再生成が必要である。

独自network coreのread-only診断windowはRBCP `0xffff_ff00`から32 byteである。各値は
big-endian 32 bitで、順に受信正常frame、受信FCS error frame、受信drop frame、ARP reply、
ICMP reply、非対応frame、応答drop、TCP segmentを返す。

## 再現方法

管理Docker内でプロジェクトを作成・ビルドする。

RBCP CDCとnetwork coreのRTL回帰試験を実行する。

```bash
src/net/tb/run_net_tb.sh
```

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

8チャンネルRHEA統合版のIQ streamを約290 Mbpsで30秒測定し、packet形式とtimestampも検査する。

```bash
python3 tools/rhea_stream_benchmark.py --seconds 30 --warmup 2
```

約300 Mbpsの短時間試験には次の設定を使う。

```bash
python3 tools/rhea_stream_benchmark.py \
  --accumulation 635 --seconds 5 --warmup 1
```

## 次に必要な機能

このbitstreamは性能検証用プロトタイプである。固定1秒RTOによる再送と32 KiB送信保持は実装したが、RTTによるRTO更新、
指数バックオフ、輻輳ウィンドウの増減、zero-window probe、順不同受信、TCP sequenceの周回比較は未実装である。
200 MHzのSiTCP互換送信境界、RBCP、8/64チャンネルRHEAの配置配線までは完了した。

次段では64チャンネル版を最終RBCP CDC版で再生成し、同じ実データ試験と長時間連続転送を確認する。
RBCP受信UDP checksum検査と処理中のTCP ACK受信余裕も追加する。
並行して接続終了の全経路と重複ACKを強化する。LUTはSiTCPより増えているため、
ARP/ICMP/TCPのヘッダー生成muxと分散RAMを整理し、BRAM使用との交換で削減する。
