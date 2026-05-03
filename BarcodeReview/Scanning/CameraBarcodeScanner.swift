import AVFoundation
import UIKit

/// AVFoundation ベースの ISBN(EAN-13) 読み取り器。
/// VisionKit DataScannerViewController は iPad の iPhone 互換モードで安定しないため、
/// 全 iOS デバイスでテストされている AVCaptureMetadataOutput をプライマリとして使う。
final class CameraBarcodeScannerView: UIView, AVCaptureMetadataOutputObjectsDelegate {

    var onISBN: ((String) -> Void)?

    private let session = AVCaptureSession()
    private lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }()

    private var hasFiredISBN = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        layer.addSublayer(previewLayer)
        configureSession()
        addOverlay()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
        if let connection = previewLayer.connection,
           connection.isVideoOrientationSupported {
            connection.videoOrientation = currentVideoOrientation()
        }
    }

    func startScanning() {
        guard !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    func stopScanning() {
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
        }
    }

    func resetForNextScan() {
        hasFiredISBN = false
        startScanning()
    }

    // MARK: - Setup

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        // 入力: 背面ワイドカメラ (取れなければデフォルト)
        let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(for: .video)
        guard let device, let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        // 出力: メタデータ (バーコード)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)

        // 利用可能なシンボロジーから ISBN/EAN 系をすべて指定
        let supported = output.availableMetadataObjectTypes
        let want: [AVMetadataObject.ObjectType] = [.ean13, .ean8, .upce, .code39, .code128]
        output.metadataObjectTypes = want.filter { supported.contains($0) }

        session.commitConfiguration()
    }

    private func addOverlay() {
        let frame = CAShapeLayer()
        frame.strokeColor = UIColor.systemYellow.cgColor
        frame.fillColor = UIColor.clear.cgColor
        frame.lineWidth = 4
        frame.lineDashPattern = nil
        frame.cornerRadius = 12
        frame.borderColor = UIColor.systemYellow.cgColor
        frame.frame = bounds.insetBy(dx: 40, dy: bounds.midY - 80)
            .offsetBy(dx: 0, dy: 0)
        layer.addSublayer(frame)
        // 後で layoutSubviews で update したいが今回は省略
    }

    private func currentVideoOrientation() -> AVCaptureVideoOrientation {
        switch UIDevice.current.orientation {
        case .landscapeLeft: return .landscapeRight
        case .landscapeRight: return .landscapeLeft
        case .portraitUpsideDown: return .portraitUpsideDown
        default: return .portrait
        }
    }

    // MARK: - Delegate

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !hasFiredISBN else { return }
        for object in metadataObjects {
            guard let code = object as? AVMetadataMachineReadableCodeObject,
                  let value = code.stringValue else { continue }
            let digits = value.filter(\.isNumber)
            guard digits.count == 13,
                  digits.hasPrefix("978") || digits.hasPrefix("979") else { continue }
            hasFiredISBN = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            stopScanning()
            onISBN?(digits)
            return
        }
    }
}
