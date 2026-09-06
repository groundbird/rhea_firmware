# AXKU042 SiTCP転送速度の基準測定

既存の`axku042_sitcp_test_top.v`にビルドパラメーター`BENCHMARK=1`を追加した独立試験回路。
RHEAのADC/DACやDDS/DDCは使用しない。既存のPHY接続・クロック・制約を土台に、SiTCPの転送能力とPCの受信能力を測る。
`BENCHMARK=0`（既定）は従来のecho試験。

## 起動設定と送信形式

- `FORCE_DEFAULTn=0`固定。EEPROMブリッジをインスタンス化せず、EEPROM_DOは1、EEPROM出力は未接続。
- **192.168.10.16、TCP 24、RBCP/UDP 4660**。このSiTCPラッパーはforce default時にEXT_IP_ADDR/EXT_TCP_PORT/EXT_RBCP_PORTを無視するため、EXT_*の定数変更だけではアドレスは変わらない。
- TCP接続すると、32 bit符号なし連番`0, 1, 2, ...`をlittle-endianで連続送信。2^32で周回する。TCPの送信パケット境界は連番の境界とは限らない。
- SiTCPのFULL中は送信位置を保持し、解除後に続きのbyteから送信する。CLOSE要求中は新規書込みを止める。接続を開き直すと0から開始。
- ADCを含まない送信源は200 MHzで最大1 byte/clockを供給できる。これは1 GbEより速いが、実際のTCP速度を保証する数値ではない。
- TCP受信データは使わず、SiTCPの`TCP_RX_WC=0`。RBCPはTCP転送とは別に統計を読める。

## Docker内でビルドする

このマシンのAMD/Xilinxツールは`/home/jsuzuki/fpga_projects/amd-vitis-docker`のinstructionに従う。
ホストのVivadoを直接実行しない。短時間の操作は次の固定ランチャーで行う。

```bash
amd-vitis-2025.2.1-cli
source /tools/2025.2.1/Vitis/settings64.sh
cd /workspace/rhea_firmware_codex
```

コンテナの`/workspace/rhea_firmware_codex`は、ホストの
`/srv/amd-vitis-2025.2.1/users/jsuzuki/workspace/rhea_firmware_codex`に対応する。

長時間ビルドはホストから指定のジョブ管理ツールを使う。

```bash
python3 /home/jsuzuki/fpga_projects/amd-vitis-docker/codex/skills/vitis-docker/scripts/vitis_job.py start \
  --name sitcp-benchmark \
  --host-workdir /srv/amd-vitis-2025.2.1/users/jsuzuki/workspace/rhea_firmware_codex \
  --container-workdir /workspace/rhea_firmware_codex \
  --timeout-seconds 3600 \
  -- vivado -mode batch -source vivado/create_axku042_sitcp_test.tcl \
     -nolog -nojournal -tclargs --benchmark --build
```

返されたjob_dirを`vitis_job.py wait JOB_DIR`に渡して完了を待つ。
Vivadoでプロジェクトを作るだけなら`--build`を省略する。

生成物（リポジトリ相対）:

- `vivado/build/axku042_sitcp_benchmark/axku042_sitcp_benchmark.xpr`
- `vivado/build/axku042_sitcp_benchmark/axku042_sitcp_benchmark.runs/impl_1/axku042_sitcp_test_top.bit`
- `vivado/build/axku042_sitcp_benchmark/reports/`：資源量、timing、DRC、CDC、クロック。

## 実機へ書き込む

JTAG-USBを使う場合は、USBパススルーを有効にした固定ランチャーを使う。通常版の
`amd-vitis-2025.2.1-cli`には`/dev/bus/usb`がなく、Docker内のhw_serverからケーブルを列挙できない。

```bash
amd-vitis-2025.2.1-usb-cli
source /tools/2025.2.1/Vitis/settings64.sh
cd /workspace/rhea_firmware_codex
hw_server -d
```

USB版ランチャーは、ホストの`/dev/bus/usb`のbind mountとUSB character device major 189の
device-cgroup許可を持つ。2026-09-06の試験ではDigilent USB ID `0403:6014`、
ターゲット`localhost:3121/xilinx_tcf/Digilent/210512180081`、デバイス`xcku040_0`を確認した。

同じUSB版Docker内から、接続可能なhw_serverを指定してターゲットを確認する。

```bash
vivado -mode batch -source vivado/axku042_benchmark_hw.tcl -nolog -nojournal \
  -tclargs --server localhost:3121
```

AXKU042のターゲットが1つと確認できたら、`--program`を追加してFPGAの揮発性設定へ書き込む。
複数ターゲットの場合は`--target`に表示された正確なターゲット名を渡す。スクリプトはKU040が1つの場合だけ書き込む。
フラッシュやEEPROMには書き込まない。hw_serverとクライアントの版の不一致で接続を拒否された場合は、対応するサーバーを指定する。

## PC側の測定

PCを192.168.10.x/24（FPGAと重複しないアドレス）に設定し、1 GbEで接続する。
Python 3の標準ライブラリだけで動作する。NumPyがあれば連番検査に自動使用する。

最初に連番を検査し、次に検査を省いてPCの処理負荷を減らした転送速度を測る。
各実行は新しいTCP接続。再接続に失敗する場合はSiTCPの接続終了を待ってから再実行する。

```bash
python3 tools/sitcp_benchmark.py --seconds 30 --json verified.json
python3 tools/sitcp_benchmark.py --seconds 30 --no-verify --json throughput.json
```

- 初期2秒をwarmupとして速度集計から除外。`--warmup`で変更できる。
- MB/sは10^6 byte/s、Mbit/sは10^6 bit/s。TCPペイロードのアプリケーション受信速度を表示する。
- `--no-verify`の結果は`measured_unverified`となり、無欠損確認済みとは扱わない。
- 検査ありではTCPの任意の受信分割、部分word、uint32周回を処理し、欠損・重複・順序違反を検出する。
- 検査ありの速度が低ければ、Python検査処理が制限している可能性がある。JSONに実際のbackendとsocket receive buffer値を保存する。
- RBCPで識別子`STB1`を確認してから接続する。既存echo版やRHEA本体を誤って測定しないための確認。`--no-rbcp`は識別と統計を省く診断用。
- FPGA統計は測定前とTCP測定終了後に採る。warmupやSiTCP内部に滞留中のデータも含み、PCの測定区間と厳密には一致しない。accepted_bytesはSiTCPへ渡したbyte数であり、TCP ACK済み数やPC受信済み数ではない。
- 時間制限で受信を終了すると、未読データが残った接続をOSがRSTで閉じる場合がある。終了直後のTCP errorを、測定中のデータ破損と混同しない。
- 完了・失敗ともJSONを保存する。短い測定を繰り返した後、`--seconds 3600`等で長時間検証できる。

## RBCPレジスタ（多byte値はlittle-endian）

| アドレス | R/W | 内容 |
|---|---|---|
| 0x00–0x03 | R | ASCII `STB1` |
| 0x04–0x07 | R | クロック周波数200000000 Hz |
| 0x08 | R | bit0: OPEN、bit1: FULL、bit2: CLOSE要求、bit3: TCP_ERROR |
| 0x09 | R/W | bit0: 送信許可。リセット後1。0では位置を保持して停止 |
| 0x10 | W | 任意のbyte書込みで下記統計を一括スナップショット |
| 0x20–0x27 | R | SiTCPへ渡した累積byte数（64 bit） |
| 0x28–0x2F | R | OPENの累積clock数（64 bit） |
| 0x30–0x37 | R | OPENかつFULLの累積clock数（64 bit） |
| 0x38–0x3B | R | OPEN立上がり回数（32 bit） |
| 0x3C–0x3F | R | TCP_ERROR立上がり回数（32 bit） |

統計はユーザー回路リセットまで累積し、接続終了後も保持する。スナップショットは読出し中に更新されない。
上記以外のユーザーアドレスはACKして0を返す。SiTCP予約アドレスはSiTCP自身が処理する。

## 自動検証と今回の結果（2026-09-06）

Docker内のVivado/xsim 2025.2.1を使用。

- 合成・配置配線・bit生成：成功。ライセンスのSynthesis/Implementation取得をログで確認。
- 最終`reports/timing.rpt`：WNS +0.990 ns、WHS +0.020 ns、TNS/THS 0。内部の無制約endpointは0。
- 全体：2852 LUT、4821 FF、RAMB36×9、RAMB18×5、DSP 0。
- 追加したbenchmarkモジュール：90 LUT、558 FF、BRAM/DSP 0（階層別配置配線後レポート）。
- 追加回路のRTLシミュレーション：連番、ランダムFULL、停止・再開、スナップショット整合、切断・再接続、リセットを確認。
- PC側：6件のテスト成功。分割受信、uint32周回、欠損・重複検出、部分word、RBCP要求・応答、warmup集計と失敗時保存を含む。
- USB版Docker内のhw_server 2025.2.1からDigilent JTAGとKU040を列挙し、生成bitを揮発性設定へ書込み成功。startup statusはHIGH。フラッシュとEEPROMは未変更。
- AXKU042接続NICは1000 Mb/s、full duplex、link up。PCは192.168.10.3、FPGAはforce defaultの192.168.10.16。
- 10秒、連番検査あり：39.857 MB/s（318.858 Mbit/s）、478,363,160 byte検査成功、TCP error 0。
- 10秒、連番検査なし：39.391 MB/s（315.131 Mbit/s）。検査ありとの差がないため、Pythonの連番検査が速度を制限した形跡はない。
- 30秒、連番検査あり：**39.832 MB/s（318.654 Mbit/s）**、1,274,842,800 byte検査成功、TCP error 0。1秒区間は概ね39.4–40.0 MB/sで、1区間のみ38.826 MB/s。
- 30秒試験でFPGAがSiTCPへ受理させたbyte数は1,274,875,540、OPEN中の`TCP_TX_FULL`率は80.0803%。送信源は1 byte/clockを維持できるため、今回の約40 MB/sは送信連番生成回路による制限ではない。

既存XDCのRGMII入出力false path指定、clock/CDCに関する指摘、CFGBVS/CONFIG_VOLTAGE未指定とSiTCP内BRAMのDRC warningは残っている。
元の動作構成との比較を優先して制約・PHY回路は変更していない。正のslackは指定済み制約に対する結果であり、RGMIIの外部タイミングや全CDCの適合を保証しない。
追加回路のシミュレーションもSiTCP netlistとPHYを含むEthernet全体の試験ではない。

RTL試験の再実行（Docker内、リポジトリ直下から）:

```bash
mkdir -p vivado/build/benchmark_validation/xsim_docker
cd vivado/build/benchmark_validation/xsim_docker
xvlog -sv ../../../../src/AXKU042/sitcp_benchmark.v ../../../../src/AXKU042/tb/sitcp_benchmark_tb.sv
xelab sitcp_benchmark_tb -s benchmark_tb
xsim benchmark_tb -runall
```

ログに`PASS:`があり、`Fatal`/`ERROR`がないことを確認する。xsimの終了コードだけで判定しない。
Pythonの試験はリポジトリ直下で次を実行する。

```bash
python3 -m unittest discover -s tools -p test_sitcp_benchmark.py
```
