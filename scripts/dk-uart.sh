#!/usr/bin/env bash
# ============================================================
# dk-uart.sh — DK(nRF52840) の J-Link 仮想シリアル(VCOM)を識別し、
#              115200 bps で送受信するための device 操作プリミティブ。
#
# peripheral_uart は BLE(NUS) と DK の UART を橋渡しするだけなので、往復検証には
# 「DK のシリアル端末」へ送る/から受ける手段が要る。その host 側 device 操作を
# ここに閉じ込め、uart-port / uart-send / uart-capture の各ターゲットとして公開する
# （対話的な誘導 UX は呼び出し側に委ねる）。
#
# 対象: Apple Silicon Mac（ioreg / stty -f / perl を使用）。
# サブコマンド:
#   port            … DK コンソールの VCOM パスを 1 行で出力（識別）
#   send [MSG]      … MSG（既定 world）に CR+LF を付けて DK シリアルへ送信（上り検査）
#   capture [SECS]  … DK シリアルを SECS 秒（既定 30）読み、受信バイトを stdout へ（下り検査）
#
# ポート識別: SEGGER J-Link 配下の cu.usbmodem を列挙し、最小番号をコンソールとみなす
# （nRF52840 DK は J-Link OB が複数 VCOM を出すことがあり、アプリ UART は先頭=最小番号）。
# UART_PORT=/dev/cu.xxx を指定すれば識別を上書きできる。
# ============================================================
set -euo pipefail

BAUD=115200

# --- DK コンソールの VCOM を識別 ---
detect_port() {
	if [ -n "${UART_PORT:-}" ]; then
		echo "$UART_PORT"
		return 0
	fi
	local port
	port=$(ioreg -p IOService -c IOUSBHostDevice -r -l -w0 2>/dev/null | awk '
		/"USB Vendor Name"/  { v=$0 }
		/"USB Product Name"/ { p=$0 }
		/IOCalloutDevice/ {
			if (index(v,"SEGGER")>0 || index(p,"J-Link")>0 || index(p,"J_Link")>0) {
				if (match($0, /\/dev\/cu\.[A-Za-z0-9._-]+/)) print substr($0,RSTART,RLENGTH)
			}
		}' | sort -u | head -1)
	if [ -z "$port" ]; then
		echo "ERROR(dk-uart): SEGGER J-Link の仮想シリアル(VCOM)が見つかりません。" >&2
		echo "  DK の USB 接続を確認してください。UART_PORT=/dev/cu.xxx で明示指定もできます。" >&2
		return 1
	fi
	echo "$port"
}

# --- ポートを開いたまま 115200 を確実に適用（再オープンでの既定値戻りを防ぐ） ---
set_baud() {
	stty -f "$1" "$BAUD" cs8 -cstopb -parenb raw -echo 2>/dev/null || true
}

cmd="${1:-}"
case "$cmd" in
	port)
		detect_port
		;;
	send)
		msg="${2:-world}"
		port="$(detect_port)"
		# fd を開いたままボー設定 → その fd へ書く（化け対策）
		exec 4<>"$port"
		set_baud "$port"
		printf '%s\r\n' "$msg" >&4
		exec 4>&-
		echo "sent '${msg}' -> ${port} @ ${BAUD}bps" >&2
		;;
	capture)
		secs="${2:-30}"
		port="$(detect_port)"
		# fd を開いたままボーを確定させ、その fd から secs 秒読む。
		# perl 側で時間到達時に自分で exit 0 する（SIGALRM kill による
		# "Alarm clock" ノイズと非 0 終了を避ける）。受信バイトは stdout へ素通し。
		exec 4<>"$port"
		set_baud "$port"
		perl -e '
			my $secs = shift;
			$SIG{ALRM} = sub { exit 0 };
			alarm $secs;
			binmode STDIN; binmode STDOUT; $| = 1;
			while (sysread(STDIN, my $buf, 4096)) { syswrite(STDOUT, $buf); }
		' "$secs" <&4
		exec 4>&-
		;;
	*)
		echo "usage: dk-uart.sh {port|send [MSG]|capture [SECS]}" >&2
		exit 2
		;;
esac
