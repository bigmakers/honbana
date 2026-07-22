# バーコード書評

本のバーコード(ISBN)をスキャンしたり、書名・著者で検索して、ネイティブ画面で書誌情報を見ながらメモを残せる iOS アプリ。Amazon へは Amazon アソシエイト ID `bigdrives-22` 付き URL を Safari で開く。

## 機能

- バーコード(EAN-13 / ISBN)スキャン (`AVCaptureSession` + `AVCaptureMetadataOutput`)
- 書名・著者の全文検索（国立国会図書館サーチ OpenSearch API）
- 書誌情報の表示（openBD: タイトル / 著者 / 出版社 / 発売日 / 書影 / 内容紹介）
- ライブラリへの保存とメモ記入（SwiftData で永続化）
- **みんなの図書館**（CloudKit パブリックDB）— 書籍への公開コメント投稿・閲覧、全体タイムライン、ユーザーフォロー（フォロー中フィード）、通報・ブロック。セットアップは `docs/CloudKitSetup.md` 参照
- Amazon へのアフィリエイトリンク生成（`tag=bigdrives-22`、ISBN-13 → ISBN-10 変換にも対応）

## 必要環境

- macOS / Xcode 15 以上
- 実機 iPhone（iOS 17 以上）— `DataScannerViewController` はシミュレータ非対応のためスキャン動作確認には実機が必須
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)（推奨）または手動で Xcode プロジェクト作成

## ビルド手順

### 推奨：XcodeGen で `.xcodeproj` を生成

```sh
cd /path/to/バーコード書評
brew install xcodegen        # 未インストールの場合
xcodegen generate
open BarcodeReview.xcodeproj
```

Xcode が開いたら、`BarcodeReview` ターゲットの **Signing & Capabilities** で自分の Apple ID（Personal Team で可）を選び、実機に Run。

### 手動作成（XcodeGen を使わない場合）

1. Xcode で **File > New > Project... > iOS > App** を選び、Product Name を `BarcodeReview`、Interface を `SwiftUI`、Language を `Swift`、Storage を `None` で作成
2. 生成されたテンプレートの `ContentView.swift` と `App.swift` を削除
3. 本リポジトリの `BarcodeReview/` 配下の `.swift` ファイル（および `Info.plist`）をすべて Xcode のプロジェクトナビゲータにドラッグ＆ドロップして **Copy items if needed** で追加
4. ターゲットの `Info.plist` を本リポジトリの `BarcodeReview/Info.plist` に差し替え
5. 最低 iOS デプロイメントターゲットを `17.0` に設定

## 動作確認

1. アプリ起動 → タブが3つ表示される（スキャン / 検索 / ライブラリ）
2. **スキャン**: 書籍のバーコード（978/979 始まり）にカメラを向ける → 詳細画面へ遷移
3. **検索**: 書名や著者名で検索 → 結果を選んで詳細画面へ
4. 詳細画面で **「ライブラリに追加」** → メモを記入。アプリを kill しても残る
5. **「Amazon を Safari で開く」** で Safari が起動し、URL に `tag=bigdrives-22` が含まれる

## 使用 API（すべて無料・APIキー不要）

- [openBD](https://openbd.jp/) — 書誌情報取得
- [国立国会図書館サーチ OpenSearch API](https://ndlsearch.ndl.go.jp/help/api/specifications) — 全文検索

## ファイル構成

```
BarcodeReview/
├── BarcodeReviewApp.swift        @main + SwiftData モデルコンテナ
├── ContentView.swift             TabView ルート
├── Info.plist                    NSCameraUsageDescription
├── Models/
│   ├── Book.swift                値型 + openBD JSON デコーダ
│   └── SavedBook.swift           SwiftData @Model
├── Services/
│   ├── BookService.swift         openBD クライアント
│   └── AmazonAffiliateURL.swift  ISBN→アフィリエイトURL生成
├── Scanning/
│   └── ScannerView.swift         AVFoundation スキャナラッパー
├── Search/
│   ├── SearchView.swift          検索画面
│   └── NDLSearchService.swift    NDL OpenSearch (XML)
├── Library/
│   └── LibraryView.swift         保存済み一覧
├── Social/
│   ├── SocialModels.swift        CloudKit スキーマ + コメント/プロフィール型
│   ├── SocialService.swift       パブリックDBクライアント（投稿/フォロー/通報）
│   ├── SocialFeedView.swift      「みんなの図書館」タブ（全体/フォロー中）
│   ├── BookCommentsSection.swift 書籍詳細のコメント欄
│   ├── UserProfileView.swift     ユーザーページ + フォローボタン
│   ├── CommentRow.swift          コメント行（通報/ブロック/削除メニュー）
│   └── NicknameSheet.swift       ニックネーム設定シート
└── Detail/
    └── BookDetailView.swift      書誌詳細 + メモ + みんなのコメント + Safari ボタン
```
