# ネイティブ Linux セットアップ実録 & 再現ガイド（教材取得環境）

`WSL-SETUP-NOTES.md` のネイティブ Linux 版。**別の Linux 端末で同じ環境をゼロから作るとき**に、
今回ハマった所で二度とハマらないための手順＋躓きポイント集。使い方の正典は `README-TOOLS.md`。

このガイドの読み方：まず「検証環境」で自分の端末との差分を把握 → 「セットアップ手順」を上から実行 →
詰まったら「躓きポイント集」を症状で引く。

---

## 検証環境（この手順を確認した前提）

| 項目 | 値 |
|---|---|
| OS | Ubuntu 24.04.4 LTS（`apt` 系・amd64） |
| カーネル | 6.17.0-35-generic |
| デスクトップ | GNOME（`XDG_CURRENT_DESKTOP=ubuntu:GNOME`）／**WSL ではない** |
| GUI | あり（`DISPLAY=:1`, `XAUTHORITY=/run/user/<uid>/gdm/Xauthority`） |
| ユーザー | uid=1001, home=`/home/mktoho`, ログインシェル fish |
| 権限 | 一般ユーザー。`sudo` は使えるがパスワード必須（＝**Claude の非対話実行では sudo 不可**。sudo が要る所は本人が叩く） |
| AppArmor | 有効。ただし作業プロセス連鎖は全て `unconfined`（拘束なし） |
| 既存 | jq 1.7 は最初から。Node は system v18.19.1（**古い**）。uv/agent-browser/op は無し |

導入したもの（すべて **sudo 不要**で入る）：

| ツール | 版 | 置き場所 |
|---|---|---|
| Node（**mise** 管理） | v24.18.0 = `node@lts`（偶数=LTS）(npm 11.16.0) | `~/.local/share/mise/installs/node/lts/bin` |
| mise（版管理ツール本体） | 2026.7.5 | `~/.local/bin/mise` |
| agent-browser | 0.31.2（最新） | mise の node global → `~/.local/bin` にリンク |
| Chrome（agent-browser 同梱） | 150.0.7871.115 | `~/.agent-browser/browsers/` |
| op（1Password CLI） | 2.35.0 | `~/.local/bin/op`（手置き。**setgid 修正が要る**・下記） |

> 📌 **Node は mise で管理**（この端末の方針＝ランタイム類は全部 mise で最新安定を入れる）。
> 当初 nvm で入れたが mise に移行して nvm は撤去済み。`~/.local/bin/{node,npm,agent-browser}` は
> mise の install 先（`installs/node/lts/bin`）へのシンボリックリンクにしてある＝**mise を activate しない
> 非対話シェル・スクリプト（fetch 等）からも PATH だけで解決できる**（activate は fish/bash の
> インタラクティブ用。スクリプトはリンク頼み）。

sudo が要る（＝本人が叩く）のは：1Password デスクトップアプリ（8.12.26）の apt インストールと、
op の setgid グループ修正の2箇所だけ。

---

## 全体像：git で来るもの / 各端末で用意するもの

| git clone で来る | 各端末で用意（リポジトリに無い） |
|---|---|
| 学習ログ・`tools/`・`hooks/` | 教材 `material.md`（著作物＝再取得）、Node、agent-browser、Chrome、ZEN ログイン、(任意)op、(図が要るとき)uv |

→ クローン直後に `material.md` や `images/` が無いのは正常。

---

## セットアップ手順（上から実行・sudo は最小）

### 1. Node を mise で（sudo 不要）
system Node が古い／global prefix が `/usr/local`（sudo 必要）なので **mise で回避**＆版管理。
```bash
curl https://mise.run | sh                       # mise を ~/.local/bin へ（sudo 不要）
echo 'mise activate fish | source' >> ~/.config/fish/config.fish   # fish 有効化（bash なら activate bash）
mise use -g node@lts                              # 現行LTS(偶数)をグローバルに（今は node 24）
```
> `node@lts` は最新 LTS（偶数系）に解決。特定系を固定したいなら `node@24` 等。他ランタイムも `mise use -g <tool>@<ver>`。

### 2. agent-browser ＋ Chrome（sudo 不要）
```bash
npm install -g agent-browser          # nvm 領域に入るので sudo 不要
agent-browser install                 # Chrome を ~/.agent-browser/browsers/ に落とす
```
共有ライブラリ不足エラーが出たら `agent-browser install --with-deps`（sudo）。今回は不要だった。

### 3. `~/.local/bin` にリンク（どのシェルからも素で使う）
`~/.local/bin` が PATH に入っていれば、mise を activate しなくても（スクリプト・非対話シェルから）使える。
agent-browser の shebang は `env node` なので **node も同じ場所に置く**のが肝。
```bash
NB="$HOME/.local/share/mise/installs/node/lts/bin"   # mise の LTS install 先
mkdir -p ~/.local/bin
ln -sf "$NB/node" ~/.local/bin/node
ln -sf "$NB/agent-browser" ~/.local/bin/agent-browser
ln -sf "$NB/npm" ~/.local/bin/npm
```
> agent-browser は `mise exec -- npm install -g agent-browser` で mise の node 上に入れる（この node の bin に配置される）。
> npm 11 は postinstall を既定でブロック（`allow-scripts` 警告）するが、agent-browser は別途 `agent-browser install` で
> ブラウザを入れるので実害なし。

### 4. jq（無ければ）
`command -v jq || sudo apt install -y jq`

### 5. ZEN Study にログイン → セッション `nnn` 作成
2通り。**op が使えるなら①が楽（人手ゼロ・ヘッドレス）**：
```bash
tools/zen-login-op.sh        # ① op の認証情報で自動ログイン（推奨・GUI不要）
tools/zen-login.sh           # ② headed 窓で手動ログイン（op が無い/使えないとき）
```
①は op（要 setgid・手順7）が前提。auth.zenid.jp(Auth0) の email→password→(MFAなら OTP自動入力) を回す。
`/home` に着けば `nnn` に保存され、以後ヘッドレスで取得できる。

### 6. 取得（いつでも・ヘッドレスOK・自己修復つき）
```bash
tools/fetch.sh "https://www.nnn.ed.nico/contents/courses/52138186/chapters/<ch>/movies/<mv>/references" > out.json
```
- 既知の courseId/chapterId/movieId は `analysis-1/STUDY_LOG.md`「URL構造のメモ」。
- **空応答（未ログイン）を検知したら `zen-login-op.sh` で自動再ログインして1回だけ再試行**する（op 前提）。
  op を触りたくないときは `ZEN_NO_AUTOLOGIN=1 tools/fetch.sh ...`。

### 7. op を使えるようにする（①の自動ログインに必要）
デスクトップアプリ導入＋CLI 統合＋**setgid 修正**（→ 躓き④）。項目は保管庫 `Personal` の `ZEN ID`
（username / password / OTP）。**教材取得自体は op 無しでも回る**（②で手動ログインすればよい）。

---

## 🔴 躓きポイント集（症状 → 原因 → 対策）

### ① `npm install -g` が EACCES / sudo を要求する
- 原因：system npm の global prefix が `/usr/local`。
- 対策：**mise（or nvm）で Node を入れる**（global がユーザー配下になり sudo 不要）。手順1。

### ② system Node が古すぎて agent-browser が動かない懸念
- 症状：Ubuntu 同梱 Node は v18 など。agent-browser は新しめの Node 前提。
- 対策：mise で `node@lts`（今は 24）。**system Node は触らない**（他の物が依存している）。
- ⚠️ **agent-browser を上げると稼働中セッションのログインが飛ぶ**：version を上げると取得デーモンが
  入れ替わり、ZEN ログインを引き継げず取得が空 `[]` になった（0.27→0.31.2 で実際に発生）。
  上げたら **`zen-login-op.sh`（op自動）で再ログイン → `fetch.sh` で1件検証**まで一続きでやる（fetch.sh は空応答なら自動でこれを呼ぶ）。
  （抽出器の出力形式＝二重JSON文字列→`jq fromjson` は 0.31.2 でも不変で、`fetch_text.sh` は互換。）

### ③ agent-browser の `--session-name` が無視される（0.27）
- 症状：ログインしたのに `fetch` が毎回 空 `[]`。指定した名前が無視され `default`（未ログイン）で動く。
- 対策：**`--session <名前>` か環境変数 `AGENT_BROWSER_SESSION`** を使う。`fetch_text.sh`/`fetch.sh`/`zen-login.sh`
  は env 方式で統一済み。ログインと取得で指定を揃える。（WSL メモ「詰まり⑤」と同じ）

### ④【今回の主犯】op が `connection reset` / アプリログ `PipeAuthError(NoCreds)`
- 症状：デスクトップアプリで「開発者→1Password CLI と連携」を ON にしても、
  `op whoami` が `connecting to desktop app: read: connection reset`。
  アプリログ `~/.config/1Password/logs/1Password_rCURRENT.log` に `PipeAuthError(NoCreds)`。
- **誤診に注意**：最初「Claude の実行環境（ラッパー越し起動）が原因」と疑ったが**外れ**。
  切り分け：作業プロセスは全て `unconfined`・ホスト PID 名前空間・uid はアプリと同じ・`setsid` でも同じ、
  そして **本人の素のターミナルでも同じ NoCreds** ＝ 実行環境は無関係だった。
- **真因（Linux 特有・ここが要点）**：Linux 版 1Password は「接続してきた op が
  **`onepassword-cli` グループの setgid バイナリ**か」で本物判定する。公式 apt/brew/winget の op には
  これが付くが、**zip を手置きした op は mode 755・setgid 無し・グループが個人グループ**なので、
  peer 資格情報のグループが一致せず弾かれる（`onepassword-cli` グループ自体も未作成）。
- **対策A（手置きを続ける場合・公式手順。sudo）**：
  ```bash
  sudo groupadd -f onepassword-cli
  sudo chgrp onepassword-cli ~/.local/bin/op   # ← op の実パスに合わせる
  sudo chmod g+s ~/.local/bin/op               # → mode 2755, group onepassword-cli
  ```
- **対策B（推奨・そもそもハマらない）**：**op は公式 apt パッケージ `1password-cli` で入れる**。
  setgid とグループを自動でやってくれる（Mac の brew / WSL の winget と同じ形態）。手置きより堅い。
- 教訓：**Mac/WSL で op が動いていたのは Linux ネイティブ統合の保証にならない**
  （WSL は Windows の op.exe＋Windows アプリ、Mac は macOS 署名/XPC で、検証機構が別物）。

### ⑤ op で項目の値を読むとコマンドがハングする
- 症状：`op vault list` は通るのに、`op read`/`op item get`（値の読み取り）が無反応→タイムアウト。
- 原因：初回アクセスで**デスクトップアプリが承認ポップアップ**を出す（セキュリティ仕様）。
  本人がボタンを押すまで待つ。押されないと数分で消えて失敗する。
- 対策：ポップアップを承認する。無人自動化したいなら承認を永続化する設定を検討。

### ⑥ ヘッドレス取得が空 `[]` になる（ログイン済みなのに）
- 原因1：セッションが未ログイン → `tools/zen-login-op.sh`（op自動・推奨）か `tools/zen-login.sh`（手動）でログイン。
  `fetch.sh` は空応答なら自動で `zen-login-op.sh` を呼んで再試行する。
- 原因2：**環境変数 `XDG_RUNTIME_DIR` を消して**実行した（例 `env -i`）。稼働中のセッション daemon
  （`~/.agent-browser/nnn.sock`）に繋がらず別ブラウザを起こす。**`XDG_RUNTIME_DIR` は残す**。
  DISPLAY は取得（ヘッドレス）には不要、ログイン（headed）にのみ必要。

### ⑦ 取得後の中身のケア（既知・詳細は README-TOOLS / STUDY_LOG）
- ディスプレイ数式 `$$...$$` の直前にレンダリング済みゴミ1行が漏れる → 書き起こし時に手で除去。
- `div.section` だけ見ると例題/練習問題を取りこぼす → `extract3.js` が全ボックスを拾う。
  取得後は必ず `data-zen-number`（num）で example/problem の取りこぼしが無いか確認。

---

## この端末固有の値（他 env では読み替え）

| 項目 | この端末 | 他 env での読み替え |
|---|---|---|
| uid / home | 1001 / `/home/mktoho` | `id -u` / `$HOME` |
| GUI | `DISPLAY=:1`, `XAUTHORITY=/run/user/1001/gdm/Xauthority` | 自分の `echo $DISPLAY` / gdm の Xauthority パス |
| op 実パス | `~/.local/bin/op`（手置き） | apt なら `/usr/bin/op`（対策B） |
| Node bin | `~/.local/share/mise/installs/node/lts/bin`（mise） | `dirname "$(mise which node)"` |
| セッション daemon | `~/.agent-browser/nnn.*` | 同じ（セッション名 `nnn`） |

`zen-login.sh` は DISPLAY/XAUTHORITY を「既存を尊重、無ければ `:1`/gdm」で自動補完するので、
GNOME 系ならたいてい読み替え不要で動く。

---

## 図（matplotlib）用の日本語フォント（未整備・学習で図が要るとき）
`uv` 未導入。図生成が要るとき `curl -LsSf https://astral.sh/uv/install.sh | sh` → `analysis-1` で `uv sync`。
日本語フォントは `tools/plot_setup.py` が自動選択（無ければ `sudo apt install -y fonts-noto-cjk`）。
