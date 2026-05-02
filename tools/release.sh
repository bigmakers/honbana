#!/usr/bin/env bash
# ホンダナ App Store 用 Release ビルド & ipa エクスポート
# 使い方: ./tools/release.sh
# 出力: build/Export/BarcodeReview.ipa
set -euo pipefail
cd "$(dirname "$0")/.."

TEAM_ID="4666YH8WY2"

echo "==> XcodeGen でプロジェクト再生成"
xcodegen generate >/dev/null

echo "==> Release archive を作成"
rm -rf ./build/BarcodeReview.xcarchive
xcodebuild -project BarcodeReview.xcodeproj \
  -scheme BarcodeReview \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath ./build/BarcodeReview.xcarchive \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  archive >/dev/null

echo "==> ipa をエクスポート"
rm -rf ./build/Export
xcodebuild -exportArchive \
  -archivePath ./build/BarcodeReview.xcarchive \
  -exportOptionsPlist marketing/ExportOptions.plist \
  -exportPath ./build/Export \
  -allowProvisioningUpdates >/dev/null

echo ""
echo "✅ 完了: build/Export/BarcodeReview.ipa"
ls -lh ./build/Export/BarcodeReview.ipa
echo ""
echo "次のステップ — TestFlight にアップロード:"
echo "  xcrun altool --upload-app \\"
echo "    -f build/Export/BarcodeReview.ipa \\"
echo "    -t ios \\"
echo "    --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>"
echo ""
echo "(API キーは https://appstoreconnect.apple.com → Users and Access → Keys から発行)"
