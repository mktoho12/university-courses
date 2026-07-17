#!/usr/bin/env bash
# fetch.sh — この端末で ZEN 教材を取得するワンコマンド・ラッパー（自己修復つき）。
# どのシェル(fish 等)からでも `tools/fetch.sh "<URL>"` で動くよう PATH と セッション(nnn) を固める。
# 取得結果が空（＝未ログインの可能性）なら、op でヘッドレス自動ログインして1回だけ再試行する。
#
# 使い方:
#   tools/fetch.sh "https://www.nnn.ed.nico/contents/courses/52138186/chapters/<ch>/movies/<mv>/references" > out.json
#
# 環境変数:
#   ZEN_SESSION        セッション名（既定 nnn）
#   ZEN_NO_AUTOLOGIN=1 空でも自動ログインを試みない（op を触りたくないとき）
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
export AGENT_BROWSER_SESSION="${ZEN_SESSION:-nnn}"
HERE="$(cd "$(dirname "$0")" && pwd)"
URL="${1:?usage: fetch.sh <references URL>}"

run(){ bash "$HERE/fetch_text.sh" "$URL"; }

OUT="$(run || true)"
compact="$(printf '%s' "$OUT" | tr -d '[:space:]')"
if [ -z "${ZEN_NO_AUTOLOGIN:-}" ] && { [ -z "$compact" ] || [ "$compact" = "[]" ]; }; then
  echo "[fetch] 空応答＝未ログインの可能性。op でヘッドレス自動ログインして再試行…" >&2
  if [ -x "$HERE/zen-login-op.sh" ] && bash "$HERE/zen-login-op.sh" "$AGENT_BROWSER_SESSION" >&2; then
    OUT="$(run || true)"
  else
    echo "[fetch] 自動ログイン不可。tools/zen-login-op.sh（op）か tools/zen-login.sh（手動）を確認。" >&2
  fi
fi
printf '%s\n' "$OUT"
