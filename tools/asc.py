#!/usr/bin/env python3
"""
App Store Connect API ヘルパー
使い方: python3 tools/asc.py <subcommand> [args]
サブコマンド:
  jwt                                  JWT を表示
  app                                  com.bigdrives.BarcodeReview の App ID を表示
  builds                               ホンダナの最新ビルド一覧
  build-status                         最新ビルド処理状態
  set-compliance                       最新ビルドに暗号化申告 (false) を設定
  versions                             AppStoreVersion 一覧
  ensure-version 1.0.0                 1.0.0 のバージョンを作成 or 取得
  set-localization                     1.0.0 の説明文/キーワード等を設定
  attach-build 1.0.0                   最新ビルドを 1.0.0 に紐付け
  set-privacy-url                      アプリのプライバシー URL を設定
  status                               全体ステータスを表示
"""
from __future__ import annotations
import json
import os
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

import jwt as pyjwt

KEY_ID = "NGW8VHC97B"
ISSUER_ID = "69a6de92-2040-47e3-e053-5b8c7c11a4d1"
KEY_PATH = Path.home() / ".appstoreconnect/private_keys" / f"AuthKey_{KEY_ID}.p8"
BUNDLE_ID = "com.bigdrives.BarcodeReview"

BASE = "https://api.appstoreconnect.apple.com/v1"

def make_jwt() -> str:
    private_key = KEY_PATH.read_text()
    now = int(time.time())
    headers = {"kid": KEY_ID, "typ": "JWT"}
    payload = {
        "iss": ISSUER_ID,
        "iat": now,
        "exp": now + 19 * 60,  # 20 分上限
        "aud": "appstoreconnect-v1",
    }
    return pyjwt.encode(payload, private_key, algorithm="ES256", headers=headers)

def request(method: str, path: str, query: dict | None = None, body: dict | None = None):
    url = BASE + path
    if query:
        url += "?" + urllib.parse.urlencode(query, safe=",[]")
    data = json.dumps(body).encode() if body is not None else None
    headers = {
        "Authorization": f"Bearer {make_jwt()}",
        "Content-Type": "application/json",
    }
    req = urllib.request.Request(url, method=method, data=data, headers=headers)
    try:
        with urllib.request.urlopen(req) as r:
            txt = r.read().decode()
            return r.status, json.loads(txt) if txt else None
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        try:
            parsed = json.loads(body)
        except json.JSONDecodeError:
            parsed = {"raw": body}
        return e.code, parsed

def get_app_id() -> str | None:
    status, data = request("GET", "/apps", query={"filter[bundleId]": BUNDLE_ID})
    if status == 200 and data and data.get("data"):
        return data["data"][0]["id"]
    print(json.dumps(data, indent=2, ensure_ascii=False))
    return None

def cmd_jwt(_args):
    print(make_jwt())

def cmd_app(_args):
    app_id = get_app_id()
    print(app_id)

def cmd_builds(_args):
    app_id = get_app_id()
    if not app_id:
        sys.exit("App not found")
    status, data = request("GET", f"/builds", query={
        "filter[app]": app_id,
        "sort": "-uploadedDate",
        "limit": "10"
    })
    print(json.dumps(data, indent=2, ensure_ascii=False))

def latest_build():
    app_id = get_app_id()
    if not app_id:
        return None
    status, data = request("GET", "/builds", query={
        "filter[app]": app_id,
        "sort": "-uploadedDate",
        "limit": "1"
    })
    if status == 200 and data and data.get("data"):
        return data["data"][0]
    return None

def cmd_build_status(_args):
    b = latest_build()
    if not b:
        print("(no build yet)")
        return
    a = b["attributes"]
    print(f"version={a.get('version')} processingState={a.get('processingState')} uploaded={a.get('uploadedDate')} expired={a.get('expired')}")
    print(f"build_id={b['id']}")

def cmd_set_compliance(_args):
    b = latest_build()
    if not b:
        sys.exit("(no build)")
    a = b["attributes"]
    if a.get("usesNonExemptEncryption") in (False,):
        print("Already set: usesNonExemptEncryption=false")
        return
    body = {
        "data": {
            "type": "builds",
            "id": b["id"],
            "attributes": {
                "usesNonExemptEncryption": False
            }
        }
    }
    status, data = request("PATCH", f"/builds/{b['id']}", body=body)
    print(status, json.dumps(data, indent=2, ensure_ascii=False))

def cmd_versions(_args):
    app_id = get_app_id()
    if not app_id:
        sys.exit("App not found")
    status, data = request("GET", f"/apps/{app_id}/appStoreVersions")
    print(json.dumps(data, indent=2, ensure_ascii=False))

def find_version(app_id: str, version: str):
    status, data = request("GET", f"/apps/{app_id}/appStoreVersions",
                           query={"filter[versionString]": version})
    if status == 200 and data and data.get("data"):
        return data["data"][0]
    return None

def cmd_ensure_version(args):
    if not args:
        sys.exit("usage: ensure-version <versionString>")
    version_str = args[0]
    app_id = get_app_id()
    if not app_id:
        sys.exit("App not found")
    existing = find_version(app_id, version_str)
    if existing:
        print(f"Existing version {version_str}: {existing['id']} state={existing['attributes'].get('appStoreState')}")
        return existing["id"]
    body = {
        "data": {
            "type": "appStoreVersions",
            "attributes": {
                "platform": "IOS",
                "versionString": version_str
            },
            "relationships": {
                "app": {"data": {"type": "apps", "id": app_id}}
            }
        }
    }
    status, data = request("POST", "/appStoreVersions", body=body)
    print(status, json.dumps(data, indent=2, ensure_ascii=False))
    return data["data"]["id"] if data.get("data") else None

DESCRIPTION = """ホンダナは、本のバーコードを読み取って書誌情報をすぐに表示し、読書メモと写真を一緒に残せる、シンプルな書籍管理アプリです。

【主な機能】
■ バーコードでサクッと登録
本の裏表紙の ISBN バーコードをカメラで読み取るだけ。タイトル・著者・書影が自動で表示されます。

■ 書名・著者で検索
バーコードが手元になくても、書名や著者名で検索できます。

■ 自分のメモと写真を残す
読み終わった感想や引用を自由にメモに書けます。気に入ったページはカメラで撮影、または写真ライブラリから取り込み可能。

■ Amazon の商品ページへワンタップ
気になった本はそのまま Amazon の商品ページを Safari で開けます。

■ SNS にシェア
本のタイトル・メモ・Amazon リンクをまとめて X / LINE / メールなどへシェアできます。

【データの取り扱い】
書誌情報は openBD・国立国会図書館サーチ・Google Books の公開 API から取得しています。あなたのメモや写真は端末内のみに保存され、外部サーバーには送信されません。"""

KEYWORDS = "本,読書,書籍,蔵書,管理,バーコード,ISBN,書評,メモ,本棚,読書記録,Amazon"
PROMO = "バーコードを読み取って一瞬で本を登録。読書メモと写真も一緒に保存できる、スッキリ使えるあなただけの本棚アプリ。"
SUPPORT_URL = "https://github.com/bigmakers/honbana/issues"
MARKETING_URL = "https://github.com/bigmakers/honbana"

WHATS_NEW_BY_VERSION = {
    "1.1": (
        "新機能:\n"
        "・メモ画像のフルスクリーン拡大表示。ピンチでズーム、ダブルタップでトグル、複数枚は左右スワイプで切替\n"
        "・「すべて写真に保存」ボタンで、本に紐づけた画像をまとめて写真ライブラリへ書き出せます\n"
        "・ライブラリの「本棚ビュー」(書影グリッド) を追加。リスト表示と切替可能\n"
        "・検索結果に「ライブラリにあり」バッジを表示。重複追加を防げます\n"
        "・ISBN を直接入力して詳細画面を開けるように\n"
        "・スキャン後に保存すると「ライブラリで見る」「続けてスキャン」のCTAバナーが表示されます\n"
        "・スキャン画面右上にライブラリへのクイックアクセスボタンを追加\n"
        "・ライブラリ内全文検索 (書名 / 著者 / メモ) を追加\n"
    )
}

def cmd_set_localization(args):
    version = args[0] if args else "1.0.0"
    app_id = get_app_id()
    v = find_version(app_id, version)
    if not v:
        sys.exit(f"Version {version} not found, run ensure-version first")
    version_id = v["id"]
    # Get the existing JA localization if any
    status, data = request("GET", f"/appStoreVersions/{version_id}/appStoreVersionLocalizations")
    locs = data.get("data", []) if data else []
    ja = next((l for l in locs if l["attributes"]["locale"] == "ja"), None)
    body_attrs = {
        "description": DESCRIPTION,
        "keywords": KEYWORDS,
        "promotionalText": PROMO,
        "supportUrl": SUPPORT_URL,
        "marketingUrl": MARKETING_URL,
    }
    if version in WHATS_NEW_BY_VERSION:
        body_attrs["whatsNew"] = WHATS_NEW_BY_VERSION[version]
    if ja:
        body = {
            "data": {
                "type": "appStoreVersionLocalizations",
                "id": ja["id"],
                "attributes": body_attrs,
            }
        }
        status, data = request("PATCH", f"/appStoreVersionLocalizations/{ja['id']}", body=body)
    else:
        body_attrs["locale"] = "ja"
        body = {
            "data": {
                "type": "appStoreVersionLocalizations",
                "attributes": body_attrs,
                "relationships": {
                    "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}
                }
            }
        }
        status, data = request("POST", "/appStoreVersionLocalizations", body=body)
    print(status, json.dumps(data, indent=2, ensure_ascii=False))

def cmd_attach_build(args):
    version = args[0] if args else "1.0.0"
    app_id = get_app_id()
    v = find_version(app_id, version)
    if not v:
        sys.exit(f"Version {version} not found")
    b = latest_build()
    if not b:
        sys.exit("No build")
    body = {
        "data": {"type": "builds", "id": b["id"]}
    }
    status, data = request("PATCH",
                           f"/appStoreVersions/{v['id']}/relationships/build",
                           body=body)
    print(status, "OK" if status in (204, 200) else data)

def cmd_set_privacy_url(_args):
    app_id = get_app_id()
    # Need appInfo (latest editable)
    status, data = request("GET", f"/apps/{app_id}/appInfos")
    infos = data.get("data", []) if data else []
    # editable one is state PREPARE_FOR_SUBMISSION or DEVELOPER_REJECTED etc.
    editable = next(
        (i for i in infos if i["attributes"]["appStoreState"] in (
            "PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED",
            "REJECTED", "INVALID_BINARY", "WAITING_FOR_REVIEW",
            "METADATA_REJECTED", "READY_FOR_REVIEW"
        )),
        infos[0] if infos else None
    )
    if not editable:
        sys.exit("No editable AppInfo")
    info_id = editable["id"]
    # AppInfo has localizations; privacy policy URL is per-locale
    status, data = request("GET", f"/appInfos/{info_id}/appInfoLocalizations")
    locs = data.get("data", []) if data else []
    ja = next((l for l in locs if l["attributes"]["locale"] == "ja"), None)
    body_attrs = {
        "privacyPolicyUrl": "https://bigmakers.github.io/honbana/",
    }
    if ja:
        body = {
            "data": {
                "type": "appInfoLocalizations",
                "id": ja["id"],
                "attributes": body_attrs,
            }
        }
        status, data = request("PATCH", f"/appInfoLocalizations/{ja['id']}", body=body)
    else:
        body_attrs["locale"] = "ja"
        body_attrs["name"] = "ホンダナ"
        body = {
            "data": {
                "type": "appInfoLocalizations",
                "attributes": body_attrs,
                "relationships": {
                    "appInfo": {"data": {"type": "appInfos", "id": info_id}}
                }
            }
        }
        status, data = request("POST", "/appInfoLocalizations", body=body)
    print(status, json.dumps(data, indent=2, ensure_ascii=False))

def cmd_set_copyright(args):
    version = args[0] if args else "1.0"
    app_id = get_app_id()
    v = find_version(app_id, version)
    if not v:
        sys.exit(f"Version {version} not found")
    body = {
        "data": {
            "type": "appStoreVersions",
            "id": v["id"],
            "attributes": {
                "copyright": "2026 Daisaku Harasaki"
            }
        }
    }
    status, data = request("PATCH", f"/appStoreVersions/{v['id']}", body=body)
    print(status, "OK" if status == 200 else json.dumps(data, indent=2, ensure_ascii=False))

def cmd_set_age_rating(_args):
    app_id = get_app_id()
    # ageRatingDeclaration is owned by appInfo
    status, data = request("GET", f"/apps/{app_id}/appInfos")
    infos = data.get("data", []) if data else []
    editable = next(
        (i for i in infos if i["attributes"]["appStoreState"] in (
            "PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED",
            "REJECTED", "INVALID_BINARY", "WAITING_FOR_REVIEW",
            "METADATA_REJECTED", "READY_FOR_REVIEW"
        )),
        infos[0] if infos else None
    )
    info_id = editable["id"]
    # Get existing ageRatingDeclaration
    status, data = request("GET", f"/appInfos/{info_id}", query={"include": "ageRatingDeclaration"})
    existing_rating_id = None
    rels = data.get("data", {}).get("relationships", {}) if data else {}
    if rels.get("ageRatingDeclaration", {}).get("data"):
        existing_rating_id = rels["ageRatingDeclaration"]["data"]["id"]

    rating_attrs = {
        "alcoholTobaccoOrDrugUseOrReferences": "NONE",
        "contests": "NONE",
        "gamblingSimulated": "NONE",
        "medicalOrTreatmentInformation": "NONE",
        "profanityOrCrudeHumor": "NONE",
        "sexualContentGraphicAndNudity": "NONE",
        "sexualContentOrNudity": "NONE",
        "horrorOrFearThemes": "NONE",
        "matureOrSuggestiveThemes": "NONE",
        "unrestrictedWebAccess": False,
        "gambling": False,
        "violenceCartoonOrFantasy": "NONE",
        "violenceRealistic": "NONE",
        "violenceRealisticProlongedGraphicOrSadistic": "NONE",
        "ageAssurance": False,
        "lootBox": False,
        "userGeneratedContent": False,
        "healthOrWellnessTopics": False,
        "advertising": False,
        "gunsOrOtherWeapons": "NONE",
        "messagingAndChat": False,
        "parentalControls": False,
        "kidsAgeBand": None
    }
    if existing_rating_id:
        body = {"data": {"type": "ageRatingDeclarations",
                          "id": existing_rating_id,
                          "attributes": rating_attrs}}
        status, data = request("PATCH",
                               f"/ageRatingDeclarations/{existing_rating_id}",
                               body=body)
    else:
        body = {"data": {"type": "ageRatingDeclarations",
                          "attributes": rating_attrs,
                          "relationships": {
                              "appInfo": {"data": {"type": "appInfos", "id": info_id}}
                          }}}
        status, data = request("POST", "/ageRatingDeclarations", body=body)
    print(status, "OK" if status in (200, 201) else json.dumps(data, indent=2, ensure_ascii=False))

def upload_screenshot(version_id: str, image_path: Path, sequence_index: int = 0):
    """指定の AppStoreVersion に screenshot 1 枚をアップロードする。"""
    image_data = image_path.read_bytes()
    file_size = len(image_data)
    file_name = image_path.name

    # 1. ScreenshotSet (display type ごとに 1 件) を取得 or 作成
    display_type = "APP_IPHONE_67"  # 1290×2796 (iPhone 15/16 Pro Max)
    status, data = request("GET",
                           f"/appStoreVersionLocalizations/{version_id}/appScreenshotSets")
    sets = data.get("data", []) if data else []
    target = next((s for s in sets
                   if s["attributes"]["screenshotDisplayType"] == display_type), None)
    if not target:
        body = {
            "data": {
                "type": "appScreenshotSets",
                "attributes": {"screenshotDisplayType": display_type},
                "relationships": {
                    "appStoreVersionLocalization": {
                        "data": {"type": "appStoreVersionLocalizations", "id": version_id}
                    }
                }
            }
        }
        status, data = request("POST", "/appScreenshotSets", body=body)
        target = data["data"]
    set_id = target["id"]

    # 2. AppScreenshot を作成 (uploadOperations を取得)
    body = {
        "data": {
            "type": "appScreenshots",
            "attributes": {
                "fileName": file_name,
                "fileSize": file_size
            },
            "relationships": {
                "appScreenshotSet": {
                    "data": {"type": "appScreenshotSets", "id": set_id}
                }
            }
        }
    }
    status, data = request("POST", "/appScreenshots", body=body)
    if status not in (200, 201):
        print("Create failed:", status, data)
        return None
    screenshot_id = data["data"]["id"]
    upload_ops = data["data"]["attributes"]["uploadOperations"]

    # 3. 各 chunk を PUT
    for op in upload_ops:
        offset = op["offset"]
        length = op["length"]
        url = op["url"]
        method = op["method"]
        headers = {h["name"]: h["value"] for h in op["requestHeaders"]}
        chunk = image_data[offset:offset + length]
        req = urllib.request.Request(url, method=method, data=chunk, headers=headers)
        with urllib.request.urlopen(req) as r:
            assert r.status in (200, 201, 204), r.status

    # 4. uploaded=true へ PATCH
    import hashlib
    md5 = hashlib.md5(image_data).hexdigest()
    body = {
        "data": {
            "type": "appScreenshots",
            "id": screenshot_id,
            "attributes": {
                "uploaded": True,
                "sourceFileChecksum": md5
            }
        }
    }
    status, data = request("PATCH", f"/appScreenshots/{screenshot_id}", body=body)
    return screenshot_id

def cmd_upload_screenshots(_args):
    version = "1.0"
    app_id = get_app_id()
    v = find_version(app_id, version)
    if not v:
        sys.exit("version not found")
    # Get the ja localization
    status, data = request("GET",
                           f"/appStoreVersions/{v['id']}/appStoreVersionLocalizations")
    locs = data.get("data", [])
    ja = next((l for l in locs if l["attributes"]["locale"] == "ja"), locs[0] if locs else None)
    if not ja:
        sys.exit("localization not found")
    version_loc_id = ja["id"]

    screenshot_dir = Path(__file__).parent.parent / "marketing" / "screenshots"
    files = sorted(p for p in screenshot_dir.glob("*.png") if not p.name.startswith("."))
    if not files:
        sys.exit("No screenshots found in marketing/screenshots/")
    for i, f in enumerate(files):
        # 1320x2868 (APP_IPHONE_69) 専用にフィルタ
        from struct import unpack
        with open(f, "rb") as fp:
            sig = fp.read(8)
            assert sig == b"\x89PNG\r\n\x1a\n"
            chunk_len = unpack(">I", fp.read(4))[0]
            chunk_type = fp.read(4)
            assert chunk_type == b"IHDR"
            w, h = unpack(">II", fp.read(8))
        if (w, h) != (1290, 2796):
            print(f"  skip {f.name}: size {w}x{h} != 1290x2796")
            continue
        print(f"Uploading {f.name} ({f.stat().st_size:,} bytes) ...")
        sid = upload_screenshot(version_loc_id, f, i)
        print(f"  done id={sid}")

def cmd_set_content_rights(_args):
    """サードパーティコンテンツを使用していない宣言。"""
    app_id = get_app_id()
    body = {
        "data": {
            "type": "apps",
            "id": app_id,
            "attributes": {
                "contentRightsDeclaration": "DOES_NOT_USE_THIRD_PARTY_CONTENT"
            }
        }
    }
    status, data = request("PATCH", f"/apps/{app_id}", body=body)
    print(status, "OK" if status == 200 else json.dumps(data, indent=2, ensure_ascii=False))

def cmd_set_price_free(_args):
    """価格を無料に設定する (JPN, customerPrice=0)。"""
    app_id = get_app_id()
    # まず JPN 領土での free price point ID を取得
    status, data = request("GET", f"/apps/{app_id}/appPricePoints",
                           query={"filter[territory]": "JPN", "limit": "1"})
    if status != 200 or not data.get("data"):
        print("Failed to find price points:", data)
        return
    free_price_point = data["data"][0]
    if free_price_point["attributes"]["customerPrice"] != "0":
        print("First price point is not free, customerPrice=",
              free_price_point["attributes"]["customerPrice"])
    pp_id = free_price_point["id"]

    body = {
        "data": {
            "type": "appPriceSchedules",
            "relationships": {
                "app": {"data": {"type": "apps", "id": app_id}},
                "baseTerritory": {"data": {"type": "territories", "id": "JPN"}},
                "manualPrices": {
                    "data": [{"type": "appPrices", "id": "${price0}"}]
                }
            }
        },
        "included": [
            {
                "type": "appPrices",
                "id": "${price0}",
                "attributes": {"startDate": None},
                "relationships": {
                    "appPricePoint": {
                        "data": {"type": "appPricePoints", "id": pp_id}
                    },
                    "territory": {"data": {"type": "territories", "id": "JPN"}}
                }
            }
        ]
    }
    status, data = request("POST", "/appPriceSchedules", body=body)
    print(status, "OK" if status in (200, 201) else json.dumps(data, indent=2, ensure_ascii=False))

def cmd_set_review_details(_args):
    version = "1.0"
    app_id = get_app_id()
    v = find_version(app_id, version)
    if not v:
        sys.exit("version not found")
    # Check existing review detail
    status, data = request("GET", f"/appStoreVersions/{v['id']}/appStoreReviewDetail")
    existing_id = data.get("data", {}).get("id") if data and data.get("data") else None
    attrs = {
        "contactFirstName": "Daisaku",
        "contactLastName": "Harasaki",
        "contactPhone": "+819012345678",  # placeholder — please update with real one
        "contactEmail": "bigmakers@gmail.com",
        "demoAccountRequired": False,
        "notes": (
            "===== NO LOGIN / NO ACCOUNT =====\n"
            "This app does NOT have any login screen, sign-in, sign-up, "
            "authentication, or account-based feature. There is no demo "
            "account because no account is required to use any feature.\n\n"
            "All features are available immediately on first launch:\n"
            "- Tab 1 (スキャン): scan a book ISBN barcode with the camera\n"
            "- Tab 2 (検索): search book title/author via NDL public API\n"
            "- Tab 3 (ライブラリ): list of books the user has saved locally\n\n"
            "Tap a book → see details fetched from openBD or Google Books "
            "(public APIs, no auth) → optionally save it to the local "
            "SwiftData store with personal memo and photos. Amazon link "
            "uses Amazon Associate tag bigdrives-22.\n\n"
            "Please disregard any automated detection of a login — there "
            "is none. All data is stored on-device only; no server is "
            "operated by the developer."
        )
    }
    if existing_id:
        body = {"data": {"type": "appStoreReviewDetails", "id": existing_id, "attributes": attrs}}
        status, data = request("PATCH", f"/appStoreReviewDetails/{existing_id}", body=body)
    else:
        body = {"data": {"type": "appStoreReviewDetails",
                          "attributes": attrs,
                          "relationships": {
                              "appStoreVersion": {"data": {"type": "appStoreVersions", "id": v["id"]}}
                          }}}
        status, data = request("POST", "/appStoreReviewDetails", body=body)
    print(status, "OK" if status in (200, 201) else json.dumps(data, indent=2, ensure_ascii=False))

def cmd_status(_args):
    app_id = get_app_id()
    if not app_id:
        print("App not registered yet in App Store Connect")
        return
    print(f"App ID: {app_id}")
    b = latest_build()
    if b:
        a = b["attributes"]
        print(f"Latest build: v{a.get('version')} ({a.get('uploadedDate')}) state={a.get('processingState')} usesNonExemptEncryption={a.get('usesNonExemptEncryption')}")
    else:
        print("No build yet")
    status, data = request("GET", f"/apps/{app_id}/appStoreVersions")
    for v in data.get("data", []):
        attrs = v["attributes"]
        print(f"Version {attrs['versionString']}: state={attrs.get('appStoreState')}")

COMMANDS = {
    "jwt": cmd_jwt,
    "app": cmd_app,
    "builds": cmd_builds,
    "build-status": cmd_build_status,
    "set-compliance": cmd_set_compliance,
    "versions": cmd_versions,
    "ensure-version": cmd_ensure_version,
    "set-localization": cmd_set_localization,
    "attach-build": cmd_attach_build,
    "set-privacy-url": cmd_set_privacy_url,
    "set-copyright": cmd_set_copyright,
    "set-age-rating": cmd_set_age_rating,
    "set-review-details": cmd_set_review_details,
    "set-content-rights": cmd_set_content_rights,
    "set-price-free": cmd_set_price_free,
    "upload-screenshots": cmd_upload_screenshots,
    "status": cmd_status,
}

if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] not in COMMANDS:
        print(__doc__)
        sys.exit(1)
    COMMANDS[sys.argv[1]](sys.argv[2:])
