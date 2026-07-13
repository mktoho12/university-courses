# Obsidian Sync セットアップ（headless CLI 方式）— 実施記録 & 他デバイス手順

`university-courses/` フォルダ全体（公共哲学＋今後の他教科）を Obsidian の **Vault** とし、
公式 **Obsidian Sync** で Mac・Windows・スマホ間を同期する。
Mac 側は公式 headless CLI（`obsidian-headless` / `ob`）でセットアップ済み。

---

## 構成（このVaultの事実）

| 項目 | 値 |
|---|---|
| Vault 名 | `university-courses` |
| Vault ID | `ac7a21c924f8c59cdfe3e173c0db354d` |
| ローカルパス（Mac） | `/Users/mktoho/work/ai/university-courses` |
| リージョン | Asia |
| 暗号化 | **End-to-End（E2E）** |
| 同期モード | bidirectional / コンフリクト strategy = merge（新しい版を優先） |
| 同期対象ファイル | md（常時）＋ image / audio / pdf / video（教材スライドPNGを含む） |
| `.obsidian/` 設定同期 | **OFF**（複数PCの設定競合を避けるため。これは推奨どおり） |

### 1Password の関連項目（Personal vault）
- `Obsidian`（id: `yocqxpzj6kqfw3vjonddg5t2aa`）= Obsidianアカウント（username=メール / password）
- `Obsidian Sync - E2E (university-courses)`（id: `4uuj23dd2rugtcqgjoeont2e4e`）= **E2E暗号化パスワード**
  - ※ E2Eパスワードは Obsidian 社も復元不可。**この op 項目が唯一の保管場所**。消さないこと。

---

## Mac での実施内容（完了済み・再現コマンド）

```bash
# インストール（Node.js 22+ 必須。実機は v25）
npm install -g obsidian-headless          # 公式: github.com/obsidianmd/obsidian-headless

# ログイン（op から資格情報を渡す。画面・ログに平文を出さない）
ob login --email "$(op read 'op://Personal/yocqxpzj6kqfw3vjonddg5t2aa/username')" \
         --password "$(op read 'op://Personal/yocqxpzj6kqfw3vjonddg5t2aa/password')"

# リモートVault作成（E2E。初回の1回だけ。実施済みなので再実行不要）
E2E="$(op read 'op://Personal/4uuj23dd2rugtcqgjoeont2e4e/password')"
ob sync-create-remote --name "university-courses" --encryption e2ee --password "$E2E"

# ローカルフォルダを紐付け
ob sync-setup --vault "ac7a21c924f8c59cdfe3e173c0db354d" \
              --path /Users/mktoho/work/ai/university-courses \
              --password "$E2E" --device-name "MacBook"

# 同期実行
ob sync --path /Users/mktoho/work/ai/university-courses             # 1回だけ
ob sync --path /Users/mktoho/work/ai/university-courses --continuous # 変更を監視して常時同期
```

### Mac の日常運用
- ファイルを編集したら `ob sync` を1回叩けば反映される。
- 常時同期したいときは `ob sync --continuous`（ターミナルを開いている間ずっと同期）。
- Claude Code で作業する場合は従来どおりこのフォルダを直接編集 → 区切りで `ob sync`。
- GUI版 Obsidian も併用したい場合：**headless と GUI の Sync を同一デバイスで同時に走らせない**（公式が併用非推奨）。
  GUIで開くだけ（Open folder as vault）なら可。同期はどちらか一方に統一する。

---

## Windows（2台目）セットアップ手順

```powershell
# 1. Node.js 22+ をインストール
# 2. CLI を入れる
npm install -g obsidian-headless
# 3. ログイン（対話 or 引数。1PasswordのWindows版CLI `op` を入れていれば同じ書き方が使える）
ob login            # 対話でメール/パスワード/MFAを入力
# 4. 既存リモートVaultに紐付け（リモート作成は不要。Macで作成済み）
#    E2Eパスワードは 1Password の "Obsidian Sync - E2E (university-courses)" から取得
ob sync-setup --vault "ac7a21c924f8c59cdfe3e173c0db354d" `
              --path "C:\path\to\university-courses" `
              --device-name "WindowsPC"
# 5. 同期
ob sync --path "C:\path\to\university-courses" --continuous
```

---

## スマホ（iOS / Android）— GUIアプリで手動（CLIなし）

1. App Store / Google Play で「Obsidian」をインストール（無料）。
2. 同じ Obsidian アカウントでログイン。
3. Sync を有効化 → リモートVault `university-courses` に接続 → **E2E暗号化パスワード**を入力
   （1Password の "Obsidian Sync - E2E (university-courses)" の値）。
4. md もスライド画像も同期されて閲覧・編集できる。

---

## 注意・トラブル時
- `ob sync-list-remote` でリモート一覧、`ob sync-status --path <vault>` で設定確認、`ob login`（引数なし）でログイン状態確認。
- E2Eパスワードを忘れると復元不可＝Vaultにアクセスできなくなる。1Password項目を消さない。
- `obsidian-headless` は open beta（v0.0.x）。不調時は GUI版 Obsidian + Obsidian Sync（同じアカウント/Vault）に切り替えても同じVaultに繋がる。
- 他教科を足すときは `university-courses/<教科名>/` に置くだけ。次回 `ob sync` で自動的に同期対象になる。
