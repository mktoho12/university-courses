#!/usr/bin/env bash
# fetch_text.sh — ZEN Study 教材を1本のURLからテキスト抽出する（クリーンな JSON を stdout へ）
#
# 使い方:
#   tools/fetch_text.sh "<教材URL>" > out.json
#   例: tools/fetch_text.sh \
#       "https://www.nnn.ed.nico/contents/courses/52138186/chapters/800003128/movies/25449338951/references"
#
# 前提:
#   - agent-browser インストール済み（Mac: brew / WSL: npm i -g agent-browser）
#   - 保存セッション "nnn"（環境変数 ZEN_SESSION で上書き可）に ZEN Study ログイン状態がある
#     （初回ログインは README-TOOLS.md / WSL-SETUP-NOTES.md 参照）
#   - jq が必要
#
# ⚠️ セッション指定は環境変数 AGENT_BROWSER_SESSION で行う（下記）。
#    agent-browser 0.27 では旧フラグ --session-name が無視され default に落ちるため
#    （＝未ログインのセッションを見て空 [] になる）。詳細 WSL-SETUP-NOTES.md「詰まり⑤」。
#
# 出力: 抽出した JSON（[{kind,num,md},...]）を標準出力へ。これを AI が material.md に書き起こす。
#   数式は $LaTeX$ / $$LaTeX$$ で入る。ディスプレイ数式の直前にゴミ1行が漏れることがある
#   （既知バグ）ので書き起こし時に手で除去する。
#
# 実装メモ（過去に WSL で詰まった2点への対策・WSL-SETUP-NOTES.md「詰まり④」）:
#   1. SPA 描画レース: 開いてすぐ抽出すると未描画で空 [] が返る
#      → div.section / data-zen-number が現れるまでポーリングしてから抽出する。
#   2. 出力形式: agent-browser の eval 結果は「二重 JSON 文字列」＋状態行混じり
#      → 末尾行を jq fromjson で展開し、クリーンな JSON だけを stdout に出す。

set -euo pipefail

URL="${1:?usage: fetch_text.sh <教材URL>}"
SESSION="${ZEN_SESSION:-nnn}"
HERE="$(cd "$(dirname "$0")" && pwd)"
EXTRACT="$HERE/extract3.js"

[ -f "$EXTRACT" ] || { echo "extract3.js が見つからない: $EXTRACT" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq が必要です（sudo apt install jq）" >&2; exit 1; }

# セッション指定は環境変数で（--session-name は 0.27 で無視されるため。上部の注意参照）
export AGENT_BROWSER_SESSION="$SESSION"
ab() { agent-browser "$@"; }

# 1) ページを開く
ab open "$URL" >/dev/null

# 2) 描画待ち: 教材本文が現れるまで最大 ~15 秒ポーリング（初回レース対策）
for _ in $(seq 1 15); do
  n=$(ab eval "document.querySelectorAll('div.section,[data-zen-number]').length" 2>/dev/null \
        | tail -1 | tr -dc '0-9') || true
  if [ -n "${n:-}" ] && [ "$n" -gt 0 ] 2>/dev/null; then break; fi
  ab wait 1000 >/dev/null
done
ab wait 800 >/dev/null   # 描画の落ち着き待ち

# 3) 隠れている解答を開く（<details> と「解答を表示」ボタン）
ab eval "document.querySelectorAll('details').forEach(d=>d.open=true);
Array.from(document.querySelectorAll('button,a,span')).filter(e=>/解答を表示|答えを見る/.test(e.textContent||'')).forEach(e=>e.click());'opened'" >/dev/null
ab wait 800 >/dev/null

# 4) 抽出器を eval → 二重 JSON 文字列を展開してクリーンな JSON を出力
ab eval "$(cat "$EXTRACT")" 2>/dev/null | tail -1 | tr -d '\r' | jq 'fromjson'
