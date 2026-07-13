#!/bin/bash
# Stop フック：大学の勉強フォルダ（university-courses 配下）でのみ発動。
# 直前のアシスタント発言に「ロール混同（role confusion）」の物理的痕跡が
# 混入していたらターンをブロックし、書き直しを差し戻す。
#
# 背景（実際に起きた事故）：
#   長いコンテキストの終盤で、会話の区切りトークンや「ユーザーの番」を示す
#   内部マーカーがアシスタントの生成テキストに漏れ出し、AIが自分の生成物と
#   ユーザーの実入力を区別できなくなる。学術的には role confusion /
#   speaker attribution error と呼ばれる既知のバグ（長コンテキストで悪化）。
#   実例：
#     - `usercos x cos x + sin x (-sin x)` … `user` ラベルがユーザー入力に密着して漏洩
#     - `system The task tools haven't been used...` … ハーネスのリマインダーが生表示
#   これらはAIの意志（メモリ・ルール）では再発したため、物理ゲートとして導入。
#
# 設計の鉄則（誤検出を絶対に避ける）：
#   正常な日本語の解説にも "user" "assistant" という英単語、引用 "> " は出る。
#   それらを拾うと勉強が止まる。だから「正常な文章にはまず現れない物理的特徴」
#   だけを、極めて狭く検出する：
#     (1) 行頭が role ラベル + 直後が非空白（区切りトークンが本文に密着）
#         例: "usercos..."、"assistantよって..."、"humanf(x)..."
#         ※ "user " のように直後が空白なら正常な英文として見逃す（誤検出回避）
#     (2) ハーネスのシステムリマインダー文がそのまま本文に出ている
#         例: "system The task tools haven't been used"
#   この2つだけ。引用ブロックの多さ等の曖昧な指標は使わない（誤検出源なので）。

set -euo pipefail

input=$(cat)

transcript_path=$(jq -r '.transcript_path // empty' <<<"$input")
cwd=$(jq -r '.cwd // empty' <<<"$input")

# --- スコープ判定：university-courses 配下でなければ何もしない ---
case "$cwd" in
  */university-courses/*|*/university-courses) : ;;
  *) exit 0 ;;
esac

[ -n "$transcript_path" ] && [ -f "$transcript_path" ] || exit 0

# transcript(JSONL) から「テキストを実際に含む最後の assistant メッセージ」を取り出す。
# ⚠️ 修正（2026-06-30）：末尾メッセージが tool_use だけ（text 無し）だと素通りしていた
# バグを修正。last 固定ではなく「text を持つ最後の assistant」を対象にする。
last_text=$(jq -rs '
  [ .[]
    | select(.type? == "assistant" or .role? == "assistant" or (.message?.role? == "assistant"))
    | ( .message.content // .content // [] )
    | if type == "string" then .
      else [ .[] | select(.type? == "text") | .text ] | join("\n")
      end
    | select(. != null and (. | gsub("\\s";"")) != "")
  ] as $texts
  | ($texts | last // "")
' "$transcript_path" 2>/dev/null || echo "")

[ -n "$last_text" ] || exit 0

reason=""

# --- 検査(1): role ラベルが本文に密着して漏洩している ---
# 行頭（前後の空白を許容）の直後に user/assistant/human が来て、
# その直後が「空白でない＝本文がくっついている」場合だけ拾う。
# grep -nE：行頭^、任意の空白、role語、直後が空白でも区切りでもない1文字。
leak1=$(printf '%s\n' "$last_text" \
  | grep -nE '^[[:space:]]*(user|assistant|human)[^[:space:][:punct:]]' \
  2>/dev/null || true)

# --- 検査(2): ハーネスのシステムリマインダーが生で混入 ---
# "system The task tools" や "<system-reminder" の生表示は、正常な解説には出ない。
leak2=$(printf '%s\n' "$last_text" \
  | grep -nE 'system The task tools haven.t been used|<system-reminder|This is just a gentle reminder - ignore if not applicable' \
  2>/dev/null || true)

if [ -n "$leak1" ] || [ -n "$leak2" ]; then
  sample=$(printf '%s\n%s\n' "$leak1" "$leak2" | grep -v '^$' | head -4)
  reason="🚨 ロール混同（role confusion）の痕跡が出力に混入しています。会話の区切りトークンやシステムリマインダーが生成テキストに漏れ出した可能性が高く、これは『自分の生成物とユーザーの実入力を区別できなくなる』既知の事故の物理的サインです。

検出した行:
$sample

この発言を破棄して書き直してください。書き直す前に必ず：
1. ユーザーが実際に入力していない発言を『ユーザーが言った』として引用していないか、transcript を確認する。
2. user / assistant / human 等のロールラベルや、システムリマインダー文が本文に混ざっていないか確認して除去する。
3. 少しでも怪しければ、ユーザーの記憶を疑う前に自分の出力を疑い、ログで裏を取る。
（このセッションはコンテキストが育って境界が溶けている可能性があります。区切りの良いところで /clear を提案するのも検討してください。）"

  jq -n --arg r "$reason" '{decision:"block", reason:$r}'
  exit 0
fi

exit 0
