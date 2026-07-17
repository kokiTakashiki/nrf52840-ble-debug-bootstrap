# nrf52840-ble-debug-bootstrap

BLE PeripheralとCentralの二者間の通信を観測するデバッグ環境をApple Silicon Mac上に自動構築する`Makefile`を提供する。BLE Peripheralと観測機器の二つはnRF52840で統一して用意することを前提としている。BLE PeripheralはnRF52840 DKである`PCA10056`を測定対象として用意する。観測機器はnRF52840 MDBT50Q USB Dongleを用意する。各ツールの導入、ビルド、実機書き込みを `make` のコマンドから実行できる。詳しくは使い方を参照せよ。

## 用語

このドキュメントで繰り返し使う略語、ツール固有の用語をまとめる。

| 用語 | 展開・読み | 意味 |
| --- | --- | --- |
| NCS | nRF Connect SDK | Nordic 製の SDK。Zephyr RTOS をベースにした BLE 開発環境。 |
| Zephyr | — | NCS の土台となる RTOS。 |
| west | — | Zephyr 公式のコマンドラインツール。複数リポジトリの取得（`west init` / `west update`）とビルドをまとめて駆動する。Zephyr ではこれをメタツールと呼ぶ。 |
| nrfutil | unified nrfutil | Nordic 製の統合 CLI。現行の単一実行ファイル版を指す。 |
| DK | Development Kit | nRF52840 DK。デバッグ機能付きの開発ボード。 |
| Dongle | — | USB スティック型のボード。観測機器用ファームウェアの書き込み先として使う。本リポジトリではnRF52840 MDBT50Q USB Dongleを接続する。 |
| DFU | Device Firmware Update | ファームウェアを書き込む方式の一つ。ここではDongleへの USB 経由の書き込みに使う。 |
| Open Bootloader | — | nRF52840 Dongleに最初から書かれている DFU用のブートローダ。nRF52840 DongleのRESETボタンで起動する。 |
| extcap | external capture | Wiresharkが外部プログラムをキャプチャ元として使う仕組み。観測機器はこの仕組みで BLEパケットを Wiresharkに取り込む。 |

## 前提

`make setup` を実行する前に、次のものを用意しておく。

| 前提条件 | 用途 | 補足 |
| --- | --- | --- |
| Homebrew | 各 cask / nrfutil 配置先の基盤 | `check-os` が存在を検査し、無ければ停止する。 |
| nRF52840 DKとnRF52840 MDBT50Q USB Dongleの二つの実機 | 書き込みと検査 | `flash-*` / `verify` で必要。 |

## 使い方

### 基本の流れ

1. `make setup` でソフトウェア環境を用意する。ツールの導入、NCS ソースツリーの取得、ファームウェアのビルドまでを行う。この段階では実機が無くても完走する。
2. nRF52840 DKとDongleを接続する。
3. `make verify` を実行する。書き込み確認に `y` と答えると、ファームウェアを実機へ書き込んだうえで検査する。検査項目は、DK が BLE で広告しているか、Wireshark に観測機器のインタフェースが現れるかの二点である。これで環境整備が正常に完了したかを確認できる。

### コマンド一覧

| コマンド | 説明 |
| --- | --- |
| `make` | ターゲット一覧を表示する。 |
| `make setup` | ソフトウェア環境を構築する。前提の確認、ツールの導入、NCS ソースツリーの取得、ファームウェアのビルドを行う。 |
| `make deploy` | ファームウェアを実機へ書き込む。DK とDongleの接続が必要で、書き込み結果の検査は `make verify` で行う。 |
| `make check-os` | 実行環境の前提を確認する。arm64 アーキテクチャかどうかと、Homebrew がインストールされているかを調べる。 |
| `make install-nrfutil` | nrfutil 本体を導入する。Nordic 公式の arm64 バイナリを使う。 |
| `make install-tools` | nrfutil、NCS Toolchain、west、Wireshark、nrfjprog＋J-Link を導入する。 |
| `make install-sniffer` | nRF Sniffer の extcap プラグインを配置する。 |
| `make fetch-ncs` | NCS ソースツリーを取得する。数 GB のダウンロードを伴う。 |
| `make build-firmware` | peripheral_uart をビルドする。ソース未取得なら先に fetch-ncs を実行する。 |
| `make flash-dk` | 開発キット（DK）へ書き込む。DK の接続が必要。 |
| `make flash-sniffer-dongle` | Dongleへ Sniffer ファームウェアを書き込む。Dongleの接続が必要。 |
| `make verify` | 書き込みと検査を行う。実行前に `[y/N]` で確認し、`y` なら書き込んでから検査、`N`（既定）なら書き込まず検査のみ。 |
| `make clean` | ビルド成果物を削除する。 |

### Dongleへの書き込み（`flash-sniffer-dongle`）

書き込みは Open Bootloader 経由の DFU で行う。

**確認プロンプト:** 実行すると、Open Bootloader への準備を促す確認（`[y/N]`）が入る。Dongleを Open Bootloader にしてから `y` と答える。`y` 以外を選んだ場合や、端末が無く無回答になった場合は、書き込みをスキップして正常終了する。すでに書き込み済みのDongleには何もしないため、再実行しても安全である。この確認は、`make verify` で `y` を選んで deploy 経由で書き込むときにも同じように入る。

**事前準備（Open Bootloader への入り方）:** ボードで異なる。**LED がフェード明滅／赤点滅**すれば起動中である。
- Nordic 純正（PCA10059）: 横向きの **RESET ボタンを押す**。
- RAYTAC など筐体入り（MDBT50Q 系）: **ボタンを押しながら USB に挿す**。

**書き込むファームウェア:** `nrfutil ble-sniffer` が同梱する署名付き DFU パッケージ（`sniffer_nrf52840dongle_nrf52840_*.zip`）を用いる。`make install-sniffer` が導入し、`$(HOME)/.nrfutil/share/nrfutil-ble-sniffer/firmware` に配置する。

**書き込みコマンド:** `nrfutil device program --firmware <zip> --traits nordicDfu`。DFU モードのデバイスが複数検出された場合は `SERIAL_PORT=<シリアル番号>` で対象を明示する（`nrfutil device list --traits nordicDfu` で確認できる）。`SERIAL_PORT` は従来の tty パスではなく**シリアル番号**を指す点に注意する。

## 導入されるツール

本リポジトリが使うツールの一覧を示す。基本的に `make setup` が公式ソースから自動で導入し、すでに導入済みのものはスキップする。nRF Sniffer の extcap プラグインは `install-sniffer` が配置する。`make setup` では導入されないので注意する。

| ツール | 入手元 | 配置先 | 用途 | 区分 |
| --- | --- | --- | --- | --- |
| **nrfutil**（本体） | Nordic 公式 arm64 バイナリ（`files.nordicsemi.com`） | `$(brew --prefix)/bin/nrfutil` | NCS ツールチェイン管理・デバイス操作の統合 CLI | 必須 |
| nrfutil **toolchain-manager** コマンド | `nrfutil install toolchain-manager` | nrfutil 管理下 | NCS ツールチェインの導入 / `launch` 実行 | 必須 |
| nrfutil **device** コマンド | `nrfutil install device` | nrfutil 管理下 | `device program` によってDongleへ DFU 書き込み操作を行う | 必須 |
| nrfutil **ble-sniffer** コマンド | `nrfutil install ble-sniffer` | nrfutil 管理下（FW は `~/.nrfutil/share/nrfutil-ble-sniffer/firmware`） | Wireshark から nRF Sniffer を使うための extcap プラグインを配置（`bootstrap`）し、Dongleに書き込む Sniffer 用ファームウェアを供給する | 必須 |
| **NCS Toolchain**（`NCS_VERSION`） | `nrfutil toolchain-manager install` | `/opt/nordic/ncs/toolchains/…` | Zephyr/NCS のコンパイラ・ビルド依存一式（数 GB） | 必須 |
| **NCS ソースツリー**（`NCS_VERSION`） | `west init -m sdk-nrf --mr` + `west update`（`fetch-ncs` が実行） | `$(HOME)/ncs/$(NCS_VERSION)`（`nrf/`・`zephyr/`・`samples/` 等） | サンプル `peripheral_uart` と Zephyr 本体のソース。ビルドに必須。 | 必須 |
| **west** | `python3 -m pip install --user west` | Python ユーザー site の `bin` | Zephyr メタツール（ビルド駆動） | 必須 |
| **Wireshark** | Homebrew cask | `/Applications/Wireshark.app` | パケット解析 | 必須 |
| **nRF Connect for Desktop** | Homebrew cask | `/Applications` | GUI ツール群（Programmer 等） | 任意 |
| **nrfjprog ＋ SEGGER J-Link** | Homebrew cask `nordic-nrf-command-line-tools`（`segger-jlink` を依存導入） | `/usr/local/bin` ほか | DK の J-Link 書き込み（`flash-dk`）。`.pkg` のため導入時に sudo を求める。 | 必須 |
| **nRF Sniffer extcap プラグイン** | `nrfutil ble-sniffer bootstrap` | `WIRESHARK_EXTCAP_DIR`（既定 `~/.local/lib/wireshark/extcap`） | Wireshark で BLE をキャプチャ | 必須 |

> 初回の `make setup` は数 GB のダウンロードを伴うため、環境によっては時間がかかる。ファームウェアのビルドには、ツールチェインだけでなく NCS のソースツリー（`nrf/`、`zephyr/`、`samples/` など）も必要になる。ソースツリーは `fetch-ncs` が取得し、`make setup` が自動で呼び出す。取得済みなら再ダウンロードはしない。

## 設定（Make 変数）

ビルドや書き込みの挙動は、以下の Make 変数で変えられる。既定値のままでも動作する。別のボードを対象にする、NCS のバージョンを変えるといった場合は、コマンドラインで変数を渡して上書きする。

```sh
make build-firmware BOARD=... NCS_VERSION=...
```

| 変数 | 既定値 | 説明 |
| --- | --- | --- |
| `NCS_VERSION` | `v2.6.1` | 使用する nRF Connect SDK のバージョン。 |
| `BOARD` | `nrf52840dk_nrf52840` | ビルド対象のボード。 |
| `WIRESHARK_EXTCAP_DIR` | `~/.local/lib/wireshark/extcap` | extcap プラグインの配置先。`nrfutil ble-sniffer bootstrap --extcap-dir` に渡される。 |
| `SNIFFER_DONGLE_FW` | `~/.nrfutil/share/nrfutil-ble-sniffer/firmware/sniffer_nrf52840dongle_nrf52840_*.zip` | Dongleへ書き込む Sniffer ファームウェア（DFU zip）。`nrfutil ble-sniffer` が同梱する。通常は変更不要。 |
| `SERIAL_PORT` | 自動検出 | 書き込み対象Dongleの**シリアル番号**（`nrfutil device program --serial-number`）。未指定時は `nordicDfu` トレイトで DFU モードのDongleを自動検出する。複数見つかった場合に指定する。従来の tty パスではない点に注意。 |

## ライセンス

本リポジトリ（Makefile とドキュメント）は [MIT ライセンス](LICENSE) である。© 2026 kokiTakeda。

第三者のツール、SDK、ファームウェアは一切同梱しておらず、`make` の実行時に各ツールを公式ソースからダウンロードする。これは Homebrew の formula や Nordic 公式の `nrf-docker` と同じ方式である。したがって本リポジトリの MIT ライセンスは自作物にのみ適用され、各ツールはそれぞれのライセンスや EULA に従う。

| ツール | 取得元 | ライセンス（概略） |
| --- | --- | --- |
| nrfutil / nRF Connect for Desktop / nRF Command Line Tools | Nordic 公式（`files.nordicsemi.com` / Homebrew） | Nordic 独自 EULA（プロプライエタリ） |
| nRF Connect SDK — `nrf/`（sdk-nrf） | github.com/nrfconnect/sdk-nrf（`west`） | LicenseRef-Nordic-5-Clause |
| nRF Connect SDK — Zephyr 等の構成要素 | `west update` で取得 | Apache-2.0 ほか |
| nRF Sniffer for Bluetooth LE（extcap / FW） | Nordic 公式 | Nordic 独自ライセンス |
| Wireshark | Homebrew cask | GPL-2.0-or-later |

> 上表のライセンスは概略である。各ツールの利用には提供元の EULA／ライセンスが適用され、それに従う主体はツールの利用者である。本リポジトリはこれらを再配布せず、取得を自動化するスクリプトのみを提供する。正確な条件は各提供元の一次ライセンス文書を参照のこと。
