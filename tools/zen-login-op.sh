#!/usr/bin/env bash
# zen-login-op.sh — 1Password(op) の認証情報で ZEN Study に「ヘッドレス自動ログイン」する。
#   人手不要。セッションが切れたらこれ1本でログインし直せる（headed 手入力の zen-login.sh の上位版）。
#
# 使い方:
#   tools/zen-login-op.sh            # セッション nnn にログイン
#   tools/zen-login-op.sh <session>  # 別セッション名に
#
# 前提:
#   - op が使える（onepassword-cli setgid 済み・アプリ統合ON。詳細 LINUX-SETUP-NOTES.md 躓き④）。
#     ※ op の値読み取りは初回にアプリの承認ポップアップが要る。無人で回すなら事前に一度承認しておく。
#   - 保管庫 Personal に項目 "ZEN ID"（username / password / ワンタイムパスワード(OTP)）。
#   - agent-browser（~/.local/bin）と ZEN の Auth0 ログイン画面構造（下記）に依存。
#
# ログインフロー（auth.zenid.jp = Auth0 identifier-first）:
#   /oauth_login?target_type=zen_id → /u/login/identifier(#username→次へ)
#   → /u/login/password(#password→ログイン) → [MFAが出れば OTP] → www.nnn.ed.nico/home
#
# 確認: 成功なら exit 0＋URL 表示。取得は tools/fetch.sh で。
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"

SESSION="${1:-${ZEN_SESSION:-nnn}}"
export AGENT_BROWSER_SESSION="$SESSION"
ITEM='op://Personal/ZEN ID'
OTP_ITEM='ZEN ID'; OTP_VAULT='Personal'
OAUTH="https://www.nnn.ed.nico/oauth_login?next_url=https%3A%2F%2Fwww.nnn.ed.nico%2Fhome&target_type=zen_id"

command -v op >/dev/null || { echo "op が見つからない（PATH?）" >&2; exit 2; }
command -v agent-browser >/dev/null || { echo "agent-browser が見つからない（PATH?）" >&2; exit 2; }

ab(){ agent-browser "$@"; }
cur_url(){ ab eval 'location.href' 2>/dev/null | tail -1 | tr -d '"'; }
# $1=部分一致文字列 $2=秒
wait_url(){ local i; for ((i=0;i<${2:-20};i++)); do case "$(cur_url)" in *"$1"*) return 0;; esac; ab wait 1000 >/dev/null 2>&1; done; return 1; }

# --- 認証情報を op から（画面に出さない） ---
EMAIL="$(op read "$ITEM/username" 2>/dev/null)" || { echo "op: メール取得失敗（アプリの承認/統合を確認）" >&2; exit 2; }
PW="$(op read "$ITEM/password" 2>/dev/null)"    || { echo "op: パスワード取得失敗" >&2; exit 2; }
[ -n "$EMAIL" ] && [ -n "$PW" ] || { echo "op: 認証情報が空" >&2; exit 2; }

echo "[zen-login-op] session=$SESSION でログイン開始（ヘッドレス）"
ab open "$OAUTH" >/dev/null 2>&1
ab wait 3000 >/dev/null 2>&1

# 既にログイン済みなら Auth0 を素通りして /home に着く → 各ステップは自動でスキップされる
# Step 1: identifier（メール）
if wait_url "auth.zenid.jp/u/login/identifier" 8; then
  ab wait '#username' >/dev/null 2>&1 || true
  ab fill '#username' "$EMAIL" >/dev/null 2>&1
  ab click 'button[type=submit]' >/dev/null 2>&1
  ab wait 3000 >/dev/null 2>&1
fi

# Step 2: password
if wait_url "auth.zenid.jp/u/login/password" 10; then
  ab wait '#password' >/dev/null 2>&1 || true
  ab fill '#password' "$PW" >/dev/null 2>&1
  ab click 'button[type=submit]' >/dev/null 2>&1
  ab wait 3500 >/dev/null 2>&1
fi

# Step 3: MFA/OTP（出た場合のみ）。まだ auth ドメインに留まっていて OTP 欄があれば op の TOTP を入れる
if case "$(cur_url)" in *auth.zenid.jp*) true;; *) false;; esac; then
  # OTP 入力欄を探す（name/id に code/otp/token、one-time-code、数値入力 のいずれか）
  SEL="$(ab eval "(()=>{const i=[...document.querySelectorAll('input')].find(e=>e.type!=='hidden'&&(/code|otp|token|passcode/i.test((e.name||'')+(e.id||''))||e.autocomplete==='one-time-code'||e.inputMode==='numeric'));return i?(i.id?('#'+i.id):(i.name?('input[name=\"'+i.name+'\"]'):'')):''})()" 2>/dev/null | tail -1 | tr -d '"')"
  if [ -n "$SEL" ]; then
    CODE="$(op item get "$OTP_ITEM" --vault "$OTP_VAULT" --otp 2>/dev/null | tr -dc '0-9')"
    if [ -n "$CODE" ]; then
      echo "[zen-login-op] MFA 検出 → OTP を自動入力"
      ab fill "$SEL" "$CODE" >/dev/null 2>&1
      ab click 'button[type=submit]' >/dev/null 2>&1
      ab wait 3500 >/dev/null 2>&1
    else
      echo "[zen-login-op] MFA だが op から OTP を取得できず（承認 or OTP 未登録?）" >&2
    fi
  fi
fi

# --- 検証：nnn.ed.nico に戻り、ログイン画面でないこと ---
if wait_url "www.nnn.ed.nico" 15; then
  U="$(cur_url)"
  case "$U" in
    *"/login"*|*auth.zenid.jp*) echo "✗ ログイン未完了: $U" >&2; exit 1;;
    *) echo "✓ ログイン成功（session=$SESSION）: $U"; exit 0;;
  esac
else
  echo "✗ ログイン未完了（nnn に戻らず）: $(cur_url)" >&2; exit 1
fi
