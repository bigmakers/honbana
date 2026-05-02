# App Store Connect 提出用メタデータ

App Store Connect の「App 情報」「価格および配信状況」「バージョン情報」フォームにそのままコピペできるよう整理してあります。

---

## 基本情報

| 項目 | 値 |
|---|---|
| App 名 (Display Name) | ホンダナ |
| サブタイトル (30 文字まで) | バーコードで本を整理。Amazon にも飛べる |
| Bundle ID | com.bigdrives.BarcodeReview |
| プライマリカテゴリ | 仕事効率化 (Productivity) |
| セカンダリカテゴリ | ブック (Books) |
| プライマリ言語 | 日本語 |
| 価格 | 無料 |
| 配信地域 | 日本 (まずは)。後で全世界に拡大可能 |

---

## 説明文 (App Description)

```
ホンダナは、本のバーコードを読み取って書誌情報をすぐに表示し、
読書メモと写真を一緒に残せる、シンプルな書籍管理アプリです。

【主な機能】
■ バーコードでサクッと登録
本の裏表紙の ISBN バーコードをカメラで読み取るだけ。タイトル・著者・
書影が自動で表示されます。

■ 書名・著者で検索
バーコードが手元になくても、書名や著者名で検索できます。

■ 自分のメモと写真を残す
読み終わった感想や引用を自由にメモに書けます。気に入ったページは
カメラで撮影、または写真ライブラリから取り込み可能。

■ Amazon の商品ページへワンタップ
気になった本はそのまま Amazon の商品ページを Safari で開けます。

■ SNS にシェア
本のタイトル・メモ・Amazon リンクをまとめて X / LINE / メールなどへ
シェアできます。

【データの取り扱い】
書誌情報は openBD・国立国会図書館サーチ・Google Books の公開 API から
取得しています。あなたのメモや写真は端末内のみに保存され、
外部サーバーには送信されません。
```

(全角換算で 700 文字以内が目安。上記は約 350 文字)

---

## キーワード (100 文字以内、半角カンマ区切り)

```
本,読書,書籍,蔵書,管理,バーコード,ISBN,書評,メモ,本棚,読書記録,Amazon
```

---

## プロモーションテキスト (170 文字以内、審査不要で随時更新可)

```
バーコードを読み取って一瞬で本を登録。読書メモと写真も一緒に保存できる、
スッキリ使えるあなただけの本棚アプリ。
```

---

## サポート / マーケティング情報

| 項目 | 値 |
|---|---|
| サポート URL | https://github.com/bigmakers/honbana/issues |
| マーケティング URL | (任意) |
| プライバシーポリシー URL | https://bigmakers.github.io/honbana/ |
| 著作権表示 | 2026 Daisaku Harasaki |
| 連絡先メール | bigmakers@gmail.com |

---

## 年齢制限 (Age Rating)

すべての項目で「なし」を選択 → **4+** になる想定。
ただし「Web ブラウズに制限なし」: いいえ → 4+ のまま。

---

## App Privacy (プライバシーラベル)

App Store Connect の「App プライバシー」セクションで以下を申告。

| 質問 | 回答 |
|---|---|
| ユーザーから収集する情報 | **なし** |
| 第三者ライブラリで収集 | **なし** |
| トラッキング (App Tracking Transparency) | **なし** |

理由:
- ログインなし、アカウントなし
- 書誌取得時に ISBN を openBD/NDL/Google Books に送るがユーザー識別子は送らない
- メモ・画像はすべて端末内 SwiftData にのみ保存

---

## エクスポートコンプライアンス

質問: 「あなたのアプリは暗号化を使用しますか？」
回答: **はい**（HTTPS で API を呼ぶため）→ ただし Apple の例外条項に該当 → ITSAppUsesNonExemptEncryption = NO で OK

`Info.plist` に追記済みでない場合は build settings で
```
INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO
```

---

## 提出時に必要なスクリーンショット

App Store Connect のスクリーンショット要件 (2026 年現在):
- **6.9 インチ iPhone (1320 × 2868)**: 必須 1〜10 枚
- 6.5 / 5.5 インチ: 6.9 を提出していれば不要

`marketing/screenshots/` に下記ファイルを保存予定:

| 番号 | ファイル | 内容 |
|---|---|---|
| 01 | 01-scanner.png | スキャン画面 (起動直後) |
| 02 | 02-library-empty.png | ライブラリ空状態 |
| 03 | 03-search-results.png | 検索結果 (撮影予定) |
| 04 | 04-detail-with-memo.png | 詳細画面・メモ・画像つき (撮影予定) |
| 05 | 05-share-sheet.png | SNS シェアシート (撮影予定) |

撮影手順は `marketing/SubmissionChecklist.md` 参照。

---

## ビルド前 確認チェック

```bash
cd /Users/daisakuharasaki/バーコード書評
xcodegen generate
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

または Xcode で **Product > Archive** → Organizer → Distribute App → App Store Connect。
