# プライバシーポリシー / Privacy Policy — ホンダナ (Bookshelf)

最終更新日: 2026年7月22日 / Last updated: July 22, 2026

このページは、iOS アプリ「ホンダナ」（以下「本アプリ」）のプライバシーポリシーです。本アプリの開発者（以下「開発者」）はあなたのプライバシーを尊重し、できるだけ少ない情報のみを取り扱います。

---

## 1. 開発者が収集しない情報

本アプリは、以下の情報を **収集しません**。

- 氏名、メールアドレス、電話番号などの個人情報
- アカウント情報（ログイン機能はありません）
- 位置情報
- 広告識別子 (IDFA) などのトラッキング情報
- 端末内の連絡先・写真ライブラリ全体

---

## 2. 端末内に保存される情報

以下の情報は **あなたの端末内にのみ** 保存され、開発者のサーバーや第三者に送信されることはありません。

- 保存した本（ISBN、タイトル、著者、出版社、書影URL）
- 本に対するあなたのメモ（テキスト）
- 本に紐づけて添付した画像

これらは Apple の SwiftData フレームワークを通じて端末内に保存され、アプリを削除すると消去されます。

---

## 3. 外部 API への送信情報

本アプリは、書誌情報の取得と表示のために、以下の公開 API へ ISBN や検索キーワードを送信します。これらの送信に **あなたの個人を識別する情報は含まれません**。

| 送信先 | 送信されるデータ | 用途 |
|---|---|---|
| openBD (https://api.openbd.jp) | ISBN | 日本語書籍の書誌取得 |
| 国立国会図書館サーチ (https://ndlsearch.ndl.go.jp) | 検索キーワード（書名・著者など） | 検索 |
| Google Books API (https://www.googleapis.com) | ISBN | openBD で見つからない書籍のフォールバック取得 |
| Amazon (https://www.amazon.co.jp) | ISBN（あなたが「Safari で開く」をタップした時のみ） | Amazon 商品ページの表示 |

これらの送信には HTTPS を使用しています。

---

## 3.5 「みんなの図書館」（公開コメント機能）について

バージョン 1.2.0 以降、本アプリには任意で使える「みんなの図書館」機能があります。この機能を使って本にコメントを投稿すると、以下の情報が Apple の iCloud (CloudKit) パブリックデータベースに保存され、**本アプリの全ユーザーに公開されます**。

- あなたが設定したニックネーム（本名である必要はありません）
- 投稿したコメントの本文と対象書籍（ISBN・タイトル）
- フォロー関係（どのユーザーをフォローしているか）

この機能に関する留意点:

- 投稿には iCloud アカウントへのサインインが必要です。ただし、開発者があなたの Apple ID・氏名・メールアドレスを知ることはありません（CloudKit が発行する匿名のユーザー識別子のみを利用します）
- 投稿しない限り、何も送信・公開されません。閲覧のみの利用も可能です
- 自分の投稿はいつでもアプリ内から削除できます
- 不適切な投稿は各コメントの長押しメニューから通報でき、通報された内容は開発者が確認のうえ削除します。特定のユーザーをブロックして非表示にすることもできます
- あなたの読書メモ・写真（第2条）はこの機能とは無関係で、引き続き端末内にのみ保存されます

---

## 4. Amazon アソシエイトプログラムについて

本アプリの「Amazon を Safari で開く」「SNS にシェア」機能から生成される Amazon の URL には、開発者の Amazon アソシエイト ID (`bigdrives-22`) が含まれています。あなたがそのリンク経由で Amazon で商品を購入された場合、開発者は Amazon から紹介料を受け取ります。リンクの仕組み上、Amazon 側がクッキー等を使ってあなたのブラウザを追跡する可能性があります。詳細は [Amazon.co.jp のプライバシー規約](https://www.amazon.co.jp/gp/help/customer/display.html?nodeId=GX7NJQ4ZB8MHFRNJ) をご確認ください。

---

## 5. カメラと写真ライブラリの利用

本アプリは以下の目的でデバイスのカメラ・写真ライブラリへのアクセスを求めます。

- **カメラ**: 本のバーコード(ISBN)読み取り、メモに添付する写真の撮影
- **写真ライブラリ**: メモに添付する画像の選択

これらの画像は端末内にのみ保存され、外部に送信されることはありません。アクセスはいつでも iOS の「設定」アプリから取り消せます。

---

## 6. 子どものプライバシー

本アプリは年齢制限なく利用できますが、13 歳未満のお子様が利用される場合は保護者の方の責任のもとでご利用ください。本アプリが特に子どもから情報を収集することはありません。

---

## 7. ポリシーの変更

このプライバシーポリシーは、必要に応じて改定されることがあります。重要な変更がある場合はリポジトリ ( https://github.com/<ユーザー名>/honbana ) でお知らせします。

---

## 8. お問い合わせ

ご質問やご意見は下記までお寄せください。

- 開発者: Daisaku Harasaki
- メール: bigmakers@gmail.com

---

## English summary

The "ホンダナ (Bookshelf)" iOS app does not collect any personal information such as your name or email address. It sends only ISBN numbers or search keywords to public APIs (openBD, NDL Search, Google Books) over HTTPS to retrieve book metadata; no user identifiers are sent. Your private notes, photos and saved books are stored only on your device using Apple's SwiftData and are not transmitted to any server. As of version 1.2.0, the optional "Everyone's Library" feature lets you post public comments on books: if you choose to post, your nickname, comment text, the book's ISBN/title, and your follow relationships are stored in Apple's CloudKit public database and are visible to all users of the app. Posting requires an iCloud account, but the developer only receives CloudKit's anonymous user identifier — never your Apple ID, name, or email. You can delete your own posts at any time, report inappropriate content, and block users in the app. The app generates Amazon URLs that include the developer's Amazon Associate tag (bigdrives-22); purchases made through these links may earn the developer a commission. Camera and photo library access are used solely for ISBN scanning, taking memo photos, and selecting images. Contact: bigmakers@gmail.com.
