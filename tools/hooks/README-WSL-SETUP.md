# WSL で解析学1の学習環境を動かすセットアップ

学習チューター用フックを WSL で動かすための手順。
このディレクトリ（リポジトリの `tools/hooks/`）の中身：

```
latex-display-filter.sh          ┐
no-inline-latex.sh               │ フック4本（そのままコピーする）
role-confusion-guard.sh          │
no-unrequested-next-options.sh   ┘
settings.hooks-only.json      ← settings.json の hooks 部分だけ（Mac固有設定は除去済み）
README-WSL-SETUP.md           ← このファイル
```

> リポジトリを clone 済みなら、このディレクトリはすでに手元にある（`git pull` で最新化される）。
> tar で受け取った場合も手順は同じ。

---

## 0. 前提：何を動かすのか

- **学習ログ（vault）** は GitHub から取る：https://github.com/mktoho12/university-courses （公開）
- **教材**（先生の著作物）は git に入っていない。WSL で教材取得までやらないなら不要。
- ここで整えるのは「Mac と同じ**チューターのふるまい**（インライン LaTeX 変換・逸脱ガード）」を出す4本のフック。

---

## 1. リポジトリを clone

```bash
cd ~/work    # 任意の作業場所
git clone https://github.com/mktoho12/university-courses.git
cd university-courses
git ls-files | grep dialogue    # dialogue-*.md が取れていれば成功
```

## 2. 依存パッケージ

```bash
sudo apt update
sudo apt install -y jq perl locales
```
- `jq`：フック4本すべてが使う（必須）
- `perl`：latex/no-inline フックが使う（Ubuntu標準だが最小構成なら要）
- `awk`(mawk)・`grep`・`bash` は標準搭載でOK

## 3. ロケールを UTF-8 に（日本語パターンのマッチに必要）

```bash
sudo locale-gen ja_JP.UTF-8 en_US.UTF-8
```
`~/.bashrc` に追記：
```bash
export LANG=ja_JP.UTF-8
export LC_ALL=$LANG
```
→ `source ~/.bashrc`

（理由：no-unrequested-next-options.sh は「正解」「一区切り」等の日本語を grep する。
C ロケールだとバイト比較になりマッチが不安定になる。）

## 4. フックを配置

このディレクトリの `*.sh` を WSL の `~/.claude/hooks/` にコピー
（`tools/hooks/` にいる状態で）：
```bash
mkdir -p ~/.claude/hooks
cp *.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/*.sh
```

## 5. settings.json にフックを登録

`settings.hooks-only.json` の中身を `~/.claude/settings.json` にマージする。
- まだ settings.json が無ければ、このファイルをそのままコピーしてよい：
  ```bash
  cp settings.hooks-only.json ~/.claude/settings.json
  ```
- すでに settings.json がある場合は `"hooks"` ブロックだけを既存ファイルに追加する
  （`jq -s '.[0] * .[1]' 既存 settings.hooks-only.json` でマージ可）。

※ command は `$HOME/.claude/hooks/...` を参照しているので**パス書き換え不要**。

## 6. 動作確認

Claude Code を WSL で起動し、`~/.claude/hooks/` の各スクリプトに
空の JSON を食わせてエラーにならないか：
```bash
echo '{}' | bash ~/.claude/hooks/no-inline-latex.sh; echo "exit=$?"
```
（設計上、対象外入力では素通り＝exit 0 になる。エラーが出たら jq 未インストール等を疑う）

---

## 持っていかないもの（Mac固有・WSL不要）

- **agent-browser**：Homebrew formula（ZEN Study ログイン用ブラウザ自動化）。
  WSL に brew は無いので現物コピー不可。教材取得を WSL でやるときだけ別途導入を検討。
  学習ログの同期だけなら不要。
- **statusLine / clangd プラグイン / remoteControlAtStartup 等**：
  Mac 環境固有。持ち込むとむしろエラー要因なので settings から除外済み。

---

## 日々の同期運用

- 作業開始時：`git pull`（Mac 側の更新を取り込む）
- 作業後　　：`git add -A && git commit -m "..." && git push`
- Mac↔iPhone は Obsidian 純正 Sync、Mac↔WSL は git。
  **同じファイルを両方で同時編集すると競合する**ので、WSL では git 一本に寄せるのが安全。
