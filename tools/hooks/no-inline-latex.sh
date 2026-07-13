#!/bin/bash
# Stop フック：大学の勉強フォルダ（university-courses 配下）でのみ発動。
# 直前のアシスタント発言に「地の文のインライン $...$ LaTeX」が混じっていたら
# ターンをブロックし、Unicode 表記での書き直しを差し戻す。
#
# 背景：チャット端末は生の $...$ をそのまま文字列表示するためユーザーが式を読めない。
# ルール = 地の文は Unicode（√, ², ′, →, ≈ 等）、強調する式だけ $$...$$ ブロック。
# メモリ（AIの意志頼み）では再発したため、物理的なゲートとして導入。
#
# 設計上の注意（誤検出を避ける）：
#  - $$...$$ ディスプレイブロックは正規の用法なので除外する。
#  - $5, $8177 のような金額や、コード断片の $ は拾わない。
#    → 「$ の直後が空白でなく、同じ行内に対応する閉じ $ があり、中身に LaTeX らしさがある」場合のみ検出。

set -euo pipefail

# stdin から Stop フックの JSON を受け取る
input=$(cat)

transcript_path=$(jq -r '.transcript_path // empty' <<<"$input")
cwd=$(jq -r '.cwd // empty' <<<"$input")

# --- スコープ判定：university-courses 配下でなければ何もしない ---
case "$cwd" in
  */university-courses/*|*/university-courses) : ;;
  *) exit 0 ;;
esac

[ -n "$transcript_path" ] && [ -f "$transcript_path" ] || exit 0

# transcript(JSONL) から「テキストを実際に含む最後の assistant メッセージ」の
# テキストを取り出す。
#
# ⚠️ 重要な修正（2026-06-30）：以前は単純に「最後の assistant メッセージ」を見ていた。
# だが assistant の最終メッセージが tool_use ブロックだけ（text 無し）のことがある
# （例：地の文を出した直後に確認ツールを呼ぶ、ツール実行ターンで Stop が走る 等）。
# その場合 text が空になり、手前の「$...$ を含む地の文ターン」を見ずに素通りしていた。
# → 末尾固定（last）ではなく「text を持つ最後の assistant メッセージ」を対象にする。
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

# まずテキスト全体から $$...$$ ディスプレイブロック（改行をまたぐ場合も含む）を
# 除去する。これを先にやらないと、$$ の対の片割れがインライン $ と誤認される。
# perl で複数行・非貪欲に $$...$$ を消す。
stripped=$(printf '%s' "$last_text" | perl -0777 -pe 's/\$\$.*?\$\$//gs' 2>/dev/null || printf '%s' "$last_text")

# 残ったテキストを行ごとに見て「インライン $...$」を探す。
# $ の直後が英数字・\・(・{ 等の「式の始まり」で、同じ行に閉じ $ がある形のみ拾う。
# 金額 $5 や $word（直後が空白や行末）は対応する閉じ $ が無いので match しにくい。
offending=$(printf '%s\n' "$stripped" | awk '
  {
    if (match($0, /\$[\\A-Za-z0-9([{][^$]*\$/)) {
      print
    }
  }
' || true)

if [ -n "$offending" ]; then
  # 検出した行を理由に添えて差し戻す（最大3行まで）
  sample=$(printf '%s\n' "$offending" | head -3)
  reason="地の文にインライン \$...\$ LaTeX が混入しています（チャット端末では生の \$ がそのまま表示され、ユーザーは式を読めません）。

検出した行:
$sample

ルール：地の文の式は Unicode プレーン表記（√, ², ³, ′, →, ≈, ×, ÷, ≤, ≥, ∫, Σ, π, θ, ∞, eᵃ, x²ⁿ 等）で書く。強調したい独立した式だけ \$\$...\$\$ ブロックにする。コードブロックに逃げるのも不可。この発言を Unicode 表記に書き直してください。"

  jq -n --arg r "$reason" '{decision:"block", reason:$r}'
  exit 0
fi

exit 0
