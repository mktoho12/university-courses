# tools/ — 教材取得スクリプト（どの端末でも使える）

ZEN Study（`nnn.ed.nico`）の教材を、どの端末（Mac / Windows WSL）でも
テキスト抽出できるようにするためのスクリプト一式。これらは自作物なので
リポジトリに含めてあり、`git pull` だけで全端末に配られる。

```
extract3.js       ★推奨。section＋例題・練習問題・定義・定理を全部拾う抽出器
extract.js        旧版（section のみ。取りこぼしバグあり。参照用）
fetch_text.sh     URLを1本渡すと open→wait→解答展開→抽出まで一気にやるラッパー
README-TOOLS.md   このファイル
```

---

## 1. 前提ツール：agent-browser のインストール

`agent-browser` は AI 用のブラウザ自動化 CLI（Apache-2.0, npm 公開）。
**Mac も WSL もネイティブ Linux も入れられる。**

> 📎 **環境別のゼロからの構築手順＋躓きポイント集**は別ファイルにある（新しい端末はこちらが近道）：
> - ネイティブ Linux（Ubuntu/GNOME 等）… `tools/LINUX-SETUP-NOTES.md`
>   （Node は nvm・agent-browser の session 指定・**op の setgid グループ**等の落とし穴を網羅）
> - Windows WSL … `tools/WSL-SETUP-NOTES.md`

### Mac
```bash
brew install agent-browser
agent-browser install      # ブラウザ本体のセットアップ（初回のみ）
```

### Windows WSL (Ubuntu)
```bash
# Node.js が無ければ先に入れる（nvm 推奨）
#   curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
#   nvm install --lts
npm install -g agent-browser
agent-browser install      # WSL 用に依存ブラウザ＋必要ライブラリを入れる
```
> WSL でブラウザを動かすには、ヘッドレス動作に必要な共有ライブラリが要ることがある。
> `agent-browser install` が案内する。GUI 表示は不要（ヘッドレスで抽出できる）。

---

## 2. ZEN Study にログイン（各端末で1回だけ）

抽出には ZEN Study にログイン済みの保存セッション（名前 `nnn`）が要る。
**この認証状態は端末をまたいで持ち運べない**（Cookie コピーは壊れやすいので非推奨）。
各端末で一度ログインしてセッションを作る:

```bash
# ログインページを開いてセッション nnn に保存
agent-browser --session-name nnn open "https://www.nnn.ed.nico/"
# → 表示された画面でメール/パスワード（＋必要なら OTP）を入力してログイン。
#    ログイン情報は 1Password: op://Personal/ZEN ID を参照。
# 以後 --session-name nnn は認証済み状態を再利用する。
```
> ヘッドレスで入力しづらい場合は、一時的に GUI モード（`--headed` 等）で
> ログインだけ済ませてから、抽出はヘッドレスで回す運用でよい。

---

## 3. 教材を取得する

```bash
tools/fetch_text.sh "<教材URL>"
```

教材URLは必ず **movieId 込みの references 形式**を直叩きする:
```
https://www.nnn.ed.nico/contents/courses/<courseId>/chapters/<chapterId>/movies/<movieId>/references
```
既知の courseId / chapterId / movieId は `analysis-1/STUDY_LOG.md` の
「URL構造のメモ」に全部記録してある。

出力される JSON（`[{kind,num,md},...]`）を、AI が該当セクションの
`material.md` に書き起こす。

### 注意（STUDY_LOG より）
- ディスプレイ数式（`$$...$$`）の直前にレンダリング済みのゴミ1行が漏れることがある
  → 書き起こし時に手で除去。
- 各セクション取得後、`data-zen-number` を持つ example/problem を取りこぼしていないか
  必ず確認する（演習を落とすと学習の核心を落とす）。
- セッション名は環境変数 `ZEN_SESSION` で上書き可（既定 `nnn`）。

---

## 4. 著作権メモ

- **これらのスクリプトは自作物**＝リポジトリに入れて公開してよい。
- **取得した教材本文（material.md / slides / images）は先生の著作物**＝
  `.gitignore` で除外済み。リポジトリには絶対に入れない。各端末で取り直す。
