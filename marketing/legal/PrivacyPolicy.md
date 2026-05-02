# プライバシーポリシー / Privacy Policy — ホンダナ (Bookshelf)

最終更新日: 2026年5月2日 / Last updated: May 2, 2026

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

The "ホンダナ (Bookshelf)" iOS app does not collect any personal information. It sends only ISBN numbers or search keywords to public APIs (openBD, NDL Search, Google Books) over HTTPS to retrieve book metadata; no user identifiers are sent. Your notes, photos and saved books are stored only on your device using Apple's SwiftData and are not transmitted to any server. The app generates Amazon URLs that include the developer's Amazon Associate tag (bigdrives-22); purchases made through these links may earn the developer a commission. Camera and photo library access are used solely for ISBN scanning, taking memo photos, and selecting images. Contact: bigmakers@gmail.com.
