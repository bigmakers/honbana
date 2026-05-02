# App Store 提出 — ステップ・バイ・ステップ手順

「ホンダナ」を Apple に審査提出するまでの実行可能なチェックリスト。

---

## 0. 事前準備

- [ ] **Apple Developer Program** に登録 (年 12,800 円) → https://developer.apple.com/jp/programs/
   - 登録には 2〜3 営業日かかる場合あり
- [ ] App Store Connect に組織または個人として参加
- [ ] Bundle ID `com.bigdrives.BarcodeReview` がまだ取得されていなければ Apple Developer のアカウント設定 → Identifiers から登録

---

## 1. App Store Connect でアプリのレコードを作成

1. https://appstoreconnect.apple.com にログイン
2. 「マイ App」→ 「+」→ 「新規 App」
3. 入力:
   - プラットフォーム: iOS
   - 名前: **ホンダナ**
   - プライマリ言語: 日本語
   - Bundle ID: com.bigdrives.BarcodeReview (Xcode に登録したもの)
   - SKU: barcodereview-001 など任意
   - ユーザーアクセス: フルアクセス

---

## 2. プライバシーポリシーを GitHub に公開

1. リポジトリを作成 (例: `honbana` という public リポジトリ)
2. `marketing/legal/PrivacyPolicy.md` をリポジトリにプッシュ
3. **方式A: 直接 raw URL を使う**
   - URL 例: `https://raw.githubusercontent.com/<ユーザー名>/honbana/main/PrivacyPolicy.md`
   - Markdown のままだが App Store 審査では受理される
4. **方式B: GitHub Pages で HTML 化（より見栄え良し）**
   - リポジトリの Settings → Pages → Source: `main / docs`
   - `docs/index.md` にプライバシーポリシーを配置 → URL: `https://<ユーザー名>.github.io/honbana/`
5. App Store Connect の「App 情報」→ 「プライバシーポリシー URL」に貼り付け

---

## 3. アプリビルドのアーカイブと TestFlight アップロード

Xcode を使う方法（推奨）:

```
cd /Users/daisakuharasaki/バーコード書評
xcodegen generate
open BarcodeReview.xcodeproj
```

1. ターゲット = BarcodeReview を選択、デバイス = **Any iOS Device (arm64)**
2. メニュー: **Product > Archive**
3. アーカイブ完了 → Organizer が開く
4. **Distribute App > App Store Connect > Upload**
5. Signing は Automatic、Upload Symbols = チェックON
6. 完了後、App Store Connect の **TestFlight** タブにビルドが反映される (10〜30 分後)

CLI を使う方法:

```
xcodebuild -project BarcodeReview.xcodeproj \
  -scheme BarcodeReview \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -allowProvisioningUpdates \
  archive -archivePath ./build/BarcodeReview.xcarchive

xcodebuild -exportArchive \
  -archivePath ./build/BarcodeReview.xcarchive \
  -exportOptionsPlist marketing/ExportOptions.plist \
  -exportPath ./build/Export \
  -allowProvisioningUpdates
```

---

## 4. App Store Connect で情報を入力

`marketing/AppStoreMetadata.md` の値を以下の場所にコピペ。

### App 情報
- 名前 / サブタイトル / プライマリカテゴリ / セカンダリカテゴリ
- プライバシーポリシー URL
- 著作権

### 価格および配信状況
- 価格: 無料
- 配信地域: 日本（または全世界）

### App プライバシー
- 「データを収集しない」を選択

### バージョン情報 (1.0.0)
- 説明 (`AppStoreMetadata.md` の「説明文」)
- キーワード
- プロモーションテキスト
- サポート URL
- スクリーンショット (6.9 インチ): 5 枚アップロード
- ビルド: TestFlight でアップロード済みのものを選択

### 年齢制限
- すべて「なし」を選択 → 4+

### App Review に関する情報
- 連絡先: 名前 / 電話 / メール
- 「メモ」: 「審査担当者様、本アプリは ISBN によるバーコード読み取りと書誌取得、読書メモのローカル保存を行います。アカウント機能はなく、ログイン情報の入力は不要です」と書く
- デモアカウント: 不要

### バージョンのリリース
- 自動でリリース or 手動でリリース、どちらでも

---

## 5. スクリーンショットを撮る (6.9 インチ iPhone 17 Pro Max シミュレータ)

事前に以下のシミュレータが起動済み:
```
xcrun simctl boot "iPhone 17 Pro Max"
open -a Simulator
```

ビルドしてインストール:
```
cd /Users/daisakuharasaki/バーコード書評
xcodebuild -project BarcodeReview.xcodeproj -scheme BarcodeReview \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -configuration Debug -derivedDataPath ./build build
xcrun simctl install booted ./build/Build/Products/Debug-iphonesimulator/BarcodeReview.app
xcrun simctl launch booted com.bigdrives.BarcodeReview
```

スクリーンショットコマンド:
```
xcrun simctl io booted screenshot marketing/screenshots/03-search-results.png
```

撮影リスト (5 枚):
- [x] 01-scanner.png — スキャン画面 (起動直後)
- [x] 02-library-empty.png — ライブラリ空状態
- [ ] 03-search-results.png — 検索タブで「夏目漱石」と入力 → リターン → 結果が出た状態
- [ ] 04-detail-with-memo.png — 詳細画面で書影・タイトル・メモ・画像つきの状態 (ライブラリに追加してメモを書く)
- [ ] 05-share-sheet.png — 「SNS にシェア」をタップ → シェアシートが開いた状態

---

## 6. 審査提出

1. App Store Connect で全項目入力完了 → 右上の「審査へ提出」
2. 審査期間: 通常 24〜48 時間
3. リジェクトされた場合は理由が来るので修正して再提出
4. 承認されたらリリース日時に App Store に表示される

---

## 7. リジェクト対策メモ

過去によくあるリジェクト理由:
- スクリーンショットが実機画面と一致しない → 必ず最新ビルドの実画面で
- プライバシーポリシー URL が 404 → GitHub Pages の URL を必ず Web で開いて確認
- 「Web ビューアの利用」で外部 URL を開くだけのアプリは Guideline 4.2 違反 → 本アプリは Safari で外部に開くのみで、アプリ内でレビューを表示しないので OK
- アフィリエイト URL のみが目的の「Web shortcut」と判定されるリスク → 主機能はバーコード読み取り + ローカルメモなので、説明文では「読書管理ツール」を強調

---

## 8. 提出後の運用

- TestFlight で家族・友人に β 配信して感想を集める (最大 10,000 名まで無料)
- クラッシュレポート: Xcode Organizer の Crashes セクションを定期チェック
- アップデート: Marketing Version を `1.0.1` などに上げて再アーカイブ → アップロード → 「+ バージョン」追加 → 同じフローで提出
