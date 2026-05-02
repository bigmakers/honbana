import SwiftUI
import VisionKit
import AVFoundation

struct ScannerView: View {
    @State private var detectedISBN: String?
    @State private var status: ScannerStatus = .checking

    enum ScannerStatus {
        case checking
        case ready
        case unsupportedHardware
        case permissionDenied
        case unavailable
    }

    var body: some View {
        Group {
            switch status {
            case .checking:
                ProgressView("カメラを準備中…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .ready:
                DataScannerRepresentable(detectedISBN: $detectedISBN)
                    .ignoresSafeArea(edges: .bottom)
                    .overlay(alignment: .top) {
                        VStack(spacing: 4) {
                            Text("978 / 979 で始まる本のバーコードを映してください")
                                .font(.callout.weight(.semibold))
                            Text("黄色い枠が出たらタップでも確定できます")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.top, 12)
                        .padding(.horizontal, 12)
                    }
            case .unsupportedHardware:
                ContentUnavailableView(
                    "このデバイスではバーコード読み取りが使えません",
                    systemImage: "barcode.viewfinder",
                    description: Text("VisionKit のスキャナに対応していません")
                )
            case .permissionDenied:
                VStack(spacing: 16) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("カメラへのアクセスが許可されていません")
                        .font(.headline)
                    Text("設定アプリの「ホンダナ」からカメラを許可してください")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("設定を開く") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .unavailable:
                ContentUnavailableView(
                    "スキャナを起動できません",
                    systemImage: "exclamationmark.triangle",
                    description: Text("シミュレータでは使えません。実機で試してください")
                )
            }
        }
        .navigationTitle("スキャン")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $detectedISBN) { isbn in
            BookDetailView(isbn13: isbn)
        }
        .task { await prepare() }
    }

    private func prepare() async {
        guard DataScannerViewController.isSupported else {
            status = .unsupportedHardware
            return
        }
        let auth = AVCaptureDevice.authorizationStatus(for: .video)
        switch auth {
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            status = granted ? readyOrUnavailable() : .permissionDenied
        case .authorized:
            status = readyOrUnavailable()
        case .denied, .restricted:
            status = .permissionDenied
        @unknown default:
            status = .permissionDenied
        }
    }

    private func readyOrUnavailable() -> ScannerStatus {
        DataScannerViewController.isAvailable ? .ready : .unavailable
    }
}

private struct DataScannerRepresentable: UIViewControllerRepresentable {
    @Binding var detectedISBN: String?

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce])],
            qualityLevel: .accurate,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        if detectedISBN == nil {
            if !uiViewController.isScanning {
                try? uiViewController.startScanning()
            }
        } else {
            if uiViewController.isScanning {
                uiViewController.stopScanning()
            }
        }
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let parent: DataScannerRepresentable

        init(parent: DataScannerRepresentable) {
            self.parent = parent
        }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didTapOn item: RecognizedItem) {
            handle(item)
        }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            for item in addedItems where handle(item) { return }
        }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didUpdate updatedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            for item in updatedItems where handle(item) { return }
        }

        @discardableResult
        private func handle(_ item: RecognizedItem) -> Bool {
            guard parent.detectedISBN == nil else { return false }
            guard case .barcode(let barcode) = item,
                  let payload = barcode.payloadStringValue else { return false }
            let digits = payload.filter(\.isNumber)
            guard digits.count == 13,
                  digits.hasPrefix("978") || digits.hasPrefix("979") else { return false }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            DispatchQueue.main.async {
                self.parent.detectedISBN = digits
            }
            return true
        }
    }
}
