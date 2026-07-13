#!/usr/bin/env bash
# fetch_text.sh — ZEN Study 教材を1本のURLからテキスト抽出する
#
# 使い方:
#   tools/fetch_text.sh "<教材URL>"
#   例: tools/fetch_text.sh \
#       "https://www.nnn.ed.nico/contents/courses/52138186/chapters/800003128/movies/25449338951/references"
#
# 前提:
#   - agent-browser がインストール済み（Mac: brew / WSL: npm i -g agent-browser）
#   - 保存セッション "nnn" に ZEN Study ログイン状態がある
#     （初回はこのセッションで一度ログインが必要。README-TOOLS.md 参照）
#
# 出力: 抽出した JSON（[{kind,num,md},...]）を標準出力へ。
#   これを AI が material.md に書き起こす。
#
# 数式は $LaTeX$ / $$LaTeX$$ で入る。ディスプレイ数式の直前にゴミ1行が
# 漏れることがある（既知バグ）ので書き起こし時に手で除去する。

set -euo pipefail

URL="${1:?usage: fetch_text.sh <教材URL>}"
SESSION="${ZEN_SESSION:-nnn}"
HERE="$(cd "$(dirname "$0")" && pwd)"
EXTRACT="$HERE/extract3.js"

[ -f "$EXTRACT" ] || { echo "extract3.js が見つからない: $EXTRACT" >&2; exit 1; }

# 1) ページを開く
agent-browser --session-name "$SESSION" open "$URL"

# 2) MathJax レンダリング待ち
agent-browser --session-name "$SESSION" wait 3000

# 3) 隠れている解答を開く（<details> と「解答を表示」ボタン）
agent-browser --session-name "$SESSION" eval \
  "document.querySelectorAll('details').forEach(d=>d.open=true);
   Array.from(document.querySelectorAll('button,a,span')).filter(e=>/解答を表示|答えを見る/.test(e.textContent||'')).forEach(e=>e.click());
   'opened'"

# 少し待ってから抽出（解答描画待ち）
agent-browser --session-name "$SESSION" wait 800

# 4) 抽出器を eval して JSON を得る
agent-browser --session-name "$SESSION" eval "$(cat "$EXTRACT")"
