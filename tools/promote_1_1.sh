#!/usr/bin/env bash
# 1.0 が承認 or 不承認されて次バージョン枠が解禁されたら実行する用。
# - ASC で AppStoreVersion 1.1 を作成
# - 既存の 1.0 と同じローカライゼーション + 1.1 の What's New を投入
# - Copyright を引き継ぎ
# - 最新ビルド (1.1.0 build 3) を 1.1 へ紐付ける
# 使い方:
#   ./tools/promote_1_1.sh
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> 現状ステータス"
python3 tools/asc.py status

echo ""
echo "==> 1.1 バージョンレコードを作成"
python3 tools/asc.py ensure-version 1.1

echo ""
echo "==> ローカライゼーション (説明文 + What's New) を 1.1 に投入"
python3 tools/asc.py set-localization 1.1

echo ""
echo "==> Copyright を 1.1 に設定"
python3 tools/asc.py set-copyright 1.1

echo ""
echo "==> 最新ビルドを 1.1 に紐付け"
python3 tools/asc.py attach-build 1.1

echo ""
echo "==> 完了後ステータス"
python3 tools/asc.py status

echo ""
echo "✅ 1.1 レコードの自動生成が完了しました。"
echo ""
echo "残りは Web UI で:"
echo "  1. App Store Connect → ホンダナ → 1.1 → 「審査へ提出」"
echo "  2. 審査メモ・連絡先は 1.0 と同じものが引き継がれます"
