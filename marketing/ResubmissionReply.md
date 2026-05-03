# Resolution Center への返信 (1.0(2) → 1.0(4))

## Resolution Center に貼り付けるテキスト

Hello App Review Team,

Thank you for the detailed report on Submission ID 3f7575c3-b2a3-4ec7-a129-2b5e19525e25 (1.0 build 2 reviewed on iPad Air 11-inch (M3), iPadOS 26.4.2).

We have reproduced the unresponsive scanner issue when running the iPhone-only build in iPad compatibility mode. The root cause was that the previous version used VisionKit's `DataScannerViewController`, which is not reliable when an iPhone-only app is run on iPad.

In build 1.0 (4) we have replaced the scanner implementation with `AVFoundation` (`AVCaptureSession` + `AVCaptureMetadataOutput` for `.ean13` / `.ean8` / `.upce`). This is the canonical, well-tested barcode pipeline that has been stable on every iPhone and iPad since iOS 7. We have verified the new implementation runs without freezing on the iPad Air 11-inch (M3) simulator.

Additional notes:
- The app contains no login, no account, and no authentication of any kind. All features are available immediately on first launch with no demo account required (see App Review Information notes).
- If the camera is genuinely unavailable on a device, the scanner tab now shows a clear "カメラが使えません" empty state with a button to open the Search tab, so the app remains usable.
- Camera permission is requested on first scan via `AVCaptureDevice.requestAccess(for: .video)` with a localized `NSCameraUsageDescription`.

Please review build 1.0 (4). Thank you for your time.

---

## 提出手順

1. App Store Connect → ホンダナ → **App Review** → 「Resolution Center」を開く
2. 上記テキストを貼り付けて送信
3. その後、左の **App Store** タブ → **1.0** → ビルドが「1.0 (4)」に変わっていることを確認 → **「審査へ提出」**

これで再審査が走ります（通常 24〜48 時間）。
