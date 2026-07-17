#!/usr/bin/env bash
# zen-login.sh — セッション nnn の ZEN Study ログイン窓を開く（初回 or 期限切れ再ログイン用）。
#
# この端末では op（1Password CLI）が Claude 実行環境から使えない
# （desktop app が接続元プロセスの資格情報を取れず PipeAuthError(NoCreds)）ため、
# 認証情報の自動投入はせず、GUI 窓を出して手入力/1Passwordアプリからのコピペでログインする。
#
# 使い方（あなたのターミナル、または Claude から）:
#   tools/zen-login.sh
#   → 開いた ZEN Study の窓でログイン（ログイン→種別「ZEN大学生/出願者」→メール/パスワード→必要ならOTP）。
#   → /home 等に着けば完了。セッション nnn に保存され、以後 tools/fetch.sh で取得できる。
#
# 確認: tools/fetch.sh "<教材URL>" が中身を返せばログイン成功（未ログインだと [] が返る）。
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
export AGENT_BROWSER_SESSION="${ZEN_SESSION:-nnn}"
export AGENT_BROWSER_HEADED=1
# GUI: 既存の DISPLAY を尊重、無ければこの端末の既定 :1
export DISPLAY="${DISPLAY:-:1}"
[ -z "${XAUTHORITY:-}" ] && [ -f /run/user/"$(id -u)"/gdm/Xauthority ] && export XAUTHORITY=/run/user/"$(id -u)"/gdm/Xauthority

agent-browser open "https://www.nnn.ed.nico/" >/dev/null
echo "ZEN Study の窓を開きました（DISPLAY=$DISPLAY）。"
echo "窓でログインしてください: ログイン → 種別「ZEN大学生/出願者」→ メール/パスワード（→必要ならOTP）。"
echo "1Password アプリの「ZEN ID」項目からコピペでOK。"
echo "/home 等に着いたら完了。確認: tools/fetch.sh \"<教材URL>\" が中身を返せば成功。"
