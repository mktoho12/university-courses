# WSL 別端末セットアップ 実録メモ（詰まりどころ & 解決）

2026-07-14、Windows WSL で学習環境をゼロから再現したときの記録。
`README-TOOLS.md` / `hooks/README-WSL-SETUP.md` の手順を「実際にやると詰まる所」で補足する。
**別端末で同じことをする（または再セットアップする）ときの近道メモ。**

---

## 全体像：git で来るもの / 各端末で用意するもの

| git pull で来る | 各端末で用意（リポジトリに無い） |
|---|---|
| 学習ログ・`tools/`・`hooks/`（スクリプトとフック本体） | 教材 `material.md`（著作物＝再取得）、`.venv`（`uv sync`）、`~/.claude/hooks`（install）、`agent-browser`（npm）、ZEN ログイン、op 認証 |

→ **クローンに `material.md` や `images/` が無いのは正常**（著作物 & 生成物）。

---

## 詰まり① 「agent-browser は Mac 専用？」→ 違う。npm 公開ツール

- `npm install -g agent-browser` → `agent-browser install`（Chrome を `~/.agent-browser/` に落とす）。
- WSL でも **headless で起動する**（WSLg 環境で確認済み）。共有ライブラリ不足エラーが出たら
  `agent-browser install --with-deps`（sudo）。今回は不要だった。
- **PATH 注意**：Node が fnm 管理だと agent-browser は
  `~/.local/share/fnm/node-versions/<ver>/installation/bin` に入る（`npm config get prefix` で確認）。

## 詰まり② op（1Password CLI）を WSL で使う → Windows アプリ連携が本命

Linux 版 op を単体 `signin` するより、**Windows デスクトップアプリに橋渡し**する方が楽（Mac と同じ生体認証 UX・毎回のパスワード入力が要らない）。

1. **Windows に op.exe を入れる**：`winget install AgileBits.1Password.CLI`
   （デスクトップアプリ本体は `AgileBits.1Password`）。**WSL からも `winget.exe install ...` で実行できる**。
2. **デスクトップアプリで2つ設定**：
   - 設定 → セキュリティ → **Windows Hello** を有効化
   - 設定 → 開発者(Developer) → **「1Password CLI と統合する」を ON** ← **これを忘れると
     `op vault list` が「No accounts configured」になる**（今回ここで一度詰まった）。
3. **WSL から `op` で呼べるようラッパーを作る**：
   op.exe の実体（例）= `/mnt/c/Users/<user>/AppData/Local/Microsoft/WinGet/Packages/AgileBits.1Password.CLI_Microsoft.Winget.Source_8wekyb3d8bbwe/op.exe`
   ```bash
   mkdir -p ~/.local/bin
   printf '#!/usr/bin/env bash\nexec "<上の op.exe のフルパス>" "$@"\n' > ~/.local/bin/op
   chmod +x ~/.local/bin/op
   ```
4. **確認**：`op vault list`（Windows Hello が出たら承認）→ `Personal` 等が並べば成立。

## 詰まり③ ZEN ログインは多段フォーム（自動化の道順）

- 入口：トップ `https://www.nnn.ed.nico/` → 「ログイン」→ 種別選択で **「ZEN大学生/出願者」**
  → `auth.zenid.jp` へ遷移。
- フロー：**メール入力 →「次へ」→ パスワード入力 →「ログイン」→（必要なら OTP）**。
  今回は OTP を求められず `/home` に到達した。
- 認証情報は op から（値は画面に出さない）：
  - メール：`op read 'op://Personal/ZEN ID/username'`
  - パスワード：`op read 'op://Personal/ZEN ID/password'`
  - OTP（登録あり）：`op item get 'ZEN ID' --vault Personal --otp`
- **セレクタ（ref）は毎回変わる**ので、`agent-browser --session nnn snapshot` で ref を拾ってから
  `fill`/`click` する（決め打ちしない）。
- ログインは**端末ごとに1回**。以後 session `nnn` に保存され、ヘッドレスで教材取得できる。
- ⚠️ セッション指定は **`--session nnn` または環境変数 `AGENT_BROWSER_SESSION=nnn`** で行う
  （**`--session-name` は使わない**。理由は下の「詰まり⑤」）。ログインも取得も同じ指定に揃えること。

## 詰まり④ fetch_text.sh の2つの罠（→ 改善済み）

- **描画レース**：開いてすぐ抽出すると SPA 未描画で **空 `[]`** が返る。
  → 改善版は `div.section` / `data-zen-number` が現れるまでポーリングしてから抽出。
- **出力形式**：agent-browser の `eval` 結果は「**二重 JSON 文字列**」＋状態行(`✓`)混じり。
  → 改善版は末尾行を `jq 'fromjson'` で展開し、**クリーンな JSON だけ**を stdout に出す。
- 取得後の鉄則は不変：`data-zen-number`(num) で **example/problem の取りこぼしが無いか必ず確認**。

## 詰まり⑤ agent-browser の `--session-name` は 0.27 で無視される（今回の主犯）

- **症状**：ログインは通っているのに `fetch_text.sh` が毎回 空 `[]` を返す。
- **正体**：agent-browser 0.27（npm 版）は **`--session-name` を認識せず**、指定した名前を無視して
  **`default` セッション**（＝未ログイン）で実行してしまう。効くのは **`--session <名前>`** か
  環境変数 **`AGENT_BROWSER_SESSION`**。
  ```bash
  agent-browser --session      nnn session   # → nnn   （効く）
  agent-browser --session-name nnn session   # → default（無視されている！）
  AGENT_BROWSER_SESSION=nnn agent-browser session  # → nnn（効く・最も版に強い）
  ```
- **注意**：Mac の brew 版は `--session-name` を受け付けていた（版差）。**両端末で確実なのは
  環境変数 `AGENT_BROWSER_SESSION`**。改善版 `fetch_text.sh` はこれを使うよう修正済み。
- **教訓**：ログインと取得で**別のセッション指定を混ぜない**。`--session nnn` でログインしたら
  取得も `--session nnn`（or 同じ env）に揃える。旧 README-TOOLS の `--session-name` は WSL では
  `--session` / env に読み替える。

---

## この端末の PATH まとめ（参考）

| ツール | 場所 |
|---|---|
| agent-browser | `~/.local/share/fnm/node-versions/v22.22.1/installation/bin` |
| op ラッパー | `~/.local/bin/op` → Windows の op.exe |
| uv | `~/.local/bin/uv` |

## 図（matplotlib）の日本語フォント

Mac はヒラギノ固定だったが WSL に無い。`tools/plot_setup.py`（`from plot_setup import plt, np`）が
その端末の日本語フォントを自動選択する（WSL では IPAGothic を検出）。無ければ
`sudo apt install -y fonts-noto-cjk` を促す。
