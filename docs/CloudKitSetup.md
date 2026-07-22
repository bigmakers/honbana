# CloudKit セットアップ手順（みんなの図書館機能）

1.2.0 で追加された「みんなの図書館」（書籍コメント共有・フォロー）は CloudKit **パブリックデータベース**を使う。
コードは `BarcodeReview/Social/` にあり、スキーマ名は `SocialModels.swift` の `SocialSchema` に一元化されている。

## 1. コンテナの作成

1. Xcode でターゲット `BarcodeReview` → **Signing & Capabilities** を開く
   （`xcodegen generate` 済みなら iCloud/CloudKit capability とコンテナ
   `iCloud.com.bigdrives.BarcodeReview` は entitlements に設定済み）
2. コンテナが赤字表示なら「+」→ `iCloud.com.bigdrives.BarcodeReview` を作成
   - Apple Developer Program のアカウントで作成される（Personal Team では CloudKit は使えないので注意）

## 2. レコード型の作成（Development 環境）

開発ビルドの実機/シミュレータで一度投稿・フォロー操作をすると、Development 環境に
レコード型が自動作成される。手動で作る場合は https://icloud.developer.apple.com/ → 対象コンテナ → Schema:

| レコード型 | フィールド | 型 |
|---|---|---|
| `BookComment` | `isbn`, `bookTitle`, `bookAuthor`, `text`, `authorID`, `authorNickname` | String |
| `UserProfile` | `userID`, `nickname` | String |
| `Follow` | `followerID`, `followeeID` | String |
| `CommentReport` | `commentID`, `commentAuthorID`, `reporterID`, `reason` | String |

## 3. インデックスの設定（必須・自動では付かない）

CloudKit Dashboard → Schema → Indexes で以下を追加しないとクエリが失敗する:

- `BookComment`
  - `isbn` — **Queryable**
  - `authorID` — **Queryable**
  - `createdTimestamp`（システムフィールド）— **Sortable**（全体フィードの新着順ソートに必要）
  - `recordName` — **Queryable**（`TRUEPREDICATE` の全体フィードクエリに必要）
- `Follow`
  - `followerID` — **Queryable**
- `CommentReport` — インデックス不要（書き込みのみ）
- `UserProfile` — インデックス不要（recordName 直接フェッチのみ）

## 4. セキュリティロール

Schema → Security Roles で既定のままで良い:

- `World`: Read（全員が読める = 巨大な図書館）
- `Authenticated`: Create（iCloud サインインユーザーが投稿できる）
- `Creator`: Write（自分の投稿だけ編集・削除できる）

## 5. Production へのデプロイ

TestFlight / App Store ビルドは **Production 環境**を見るため、審査提出前に必ず:

1. CloudKit Dashboard → 対象コンテナ → **Deploy Schema Changes...**
2. Development → Production にスキーマ（レコード型 + インデックス）を反映

これを忘れると本番ビルドでコメント欄が「読み込めませんでした」になる。

## 6. App Review（UGC）対応メモ

ユーザー生成コンテンツ（Guideline 1.2）対応としてアプリ内に実装済み:

- 通報: コメント長押し → 「通報する」→ `CommentReport` レコードが作成され、ローカルでも即非表示
- ブロック: コメント長押し / ユーザーページの「…」→ ブロック（そのユーザーの投稿を全て非表示）
- ニックネーム必須・投稿は 1000 文字まで・利用注意文をコンポーザー下に常時表示

通報されたコメントは CloudKit Dashboard の `CommentReport` を定期的に確認し、
問題があれば該当 `BookComment` レコードを Dashboard から削除する（運営者の対応）。
