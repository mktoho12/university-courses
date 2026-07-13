#!/bin/bash
# Stop フック：大学の勉強フォルダ（university-courses 配下）でのみ発動。
#
# 目的：チューターの最頻の過剰パターン＝「生徒の答え合わせをした“直後”に、頼まれてもいない
#       『次どうする?（2-6-X をやる／一区切り…）』という選択肢提示を付け足す」を検出して差し戻す。
#       CLAUDE.md の出力テンプレート（答え合わせ → 正誤＋一言で止める。次の選択肢は出さない）の物理ゲート。
#
# 設計（誤検出を避ける・安全側＝迷ったら通す）：
#  - 直前の user 発言が「次どうする?」系（next/どうしたら/何をすれば 等）なら選択肢提示は正当 → 通す。
#  - 「答え合わせの合図（正解／合ってい／一致／その通り 等）」と
#    「選択肢提示の合図（いきますか？／一区切り／どうしますか？ が、箇条書きや『か』の二択以上と同居）」の
#    両方がそろったときだけブロック。片方だけなら通す。
#  - これは保険。本体は CLAUDE.md の実行形テンプレート。フックは「禁止形指示が効かない」ぶんの下支え。

set -euo pipefail

input=$(cat)
transcript_path=$(jq -r '.transcript_path // empty' <<<"$input")
cwd=$(jq -r '.cwd // empty' <<<"$input")

# --- スコープ：university-courses 配下でなければ何もしない ---
case "$cwd" in
  */university-courses/*|*/university-courses) : ;;
  *) exit 0 ;;
esac

[ -n "$transcript_path" ] && [ -f "$transcript_path" ] || exit 0

# 「text を持つ最後の assistant メッセージ」を取り出す（末尾が tool_use だけのケースに強い形）。
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

# 直前の user 発言（text を持つ最後の user メッセージ）。
last_user=$(jq -rs '
  [ .[]
    | select(.type? == "user" or .role? == "user" or (.message?.role? == "user"))
    | ( .message.content // .content // [] )
    | if type == "string" then .
      else [ .[] | select(.type? == "text") | .text ] | join("\n")
      end
    | select(. != null and (. | gsub("\\s";"")) != "")
  ] as $texts
  | ($texts | last // "")
' "$transcript_path" 2>/dev/null || echo "")

# --- 誤検出ガード1：生徒が「次どうする?」系を自分で聞いていたら選択肢提示は正当 → 通す ---
if printf '%s' "$last_user" | grep -qiE '次(は)?どう|どうしたら|どうすれば|何をすれば|次に何|next|選択肢|どれにする|進め方'; then
  exit 0
fi

# --- 答え合わせの合図（正解判定）が直近の応答にあるか ---
graded=$(printf '%s' "$last_text" | grep -cE '正解|合ってい|合っています|一致(です|します)|その通り|完璧|正しいです' || true)

# --- 「次どうする選択肢」提示の合図があるか ---
#   箇条書き（・/ - / 数字.）で複数案、または「…か、…か」「いきますか」「一区切り」「どうしますか」等。
nextopts=$(printf '%s' "$last_text" | grep -cE 'いきますか|進みますか|やりますか|一区切り|どうしますか|どちらに|どれにし' || true)

if [ "$graded" -gt 0 ] && [ "$nextopts" -gt 0 ]; then
  reason="【出力テンプレート違反】答え合わせ（正解判定）の直後に、生徒が求めていない『次どうする?』の選択肢提示を付け足しています。

CLAUDE.md の出力テンプレート：答え合わせ → 正誤＋合っている/違う箇所の一言で“止める”。別解・作法・意義づけ・『次は2-6-X をやる/一区切り…』の選択肢提示はしない（生徒が次を自分で指定する／生徒が『次どうする?』と聞いたときだけ選択肢を出す）。

この応答から『次どうする』の選択肢部分を削り、正誤＋一言だけにして送り直してください。"
  jq -n --arg r "$reason" '{decision:"block", reason:$r}'
  exit 0
fi

exit 0
