import SwiftUI
import SwiftData
import AVFoundation

struct ScannerView: View {
    var selectedTab: Binding<AppTab>?

    @State private var detectedISBN: String?
    @State private var status: ScannerStatus = .checking

    @Query private var savedBooks: [SavedBook]

    init(selectedTab: Binding<AppTab>? = nil) {
        self.selectedTab = selectedTab
    }

    enum ScannerStatus {
        case checking
        case ready
        case noCamera
        case permissionDenied
        case mock
    }

    var body: some View {
        Group {
            switch status {
            case .checking:
                ProgressView("カメラを準備中…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .ready:
                BarcodeScannerRepresentable(detectedISBN: $detectedISBN)
                    .ignoresSafeArea(edges: .bottom)
                    .overlay(alignment: .top) {
                        VStack(spacing: 4) {
                            Text("978 / 979 で始まる本のバーコードを枠内に映してください")
                                .font(.callout.weight(.semibold))
                            Text("ピントが合うと自動で読み取ります")
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
            case .noCamera:
                ContentUnavailableView {
                    Label("カメラが使えません", systemImage: "camera.fill")
                } description: {
                    Text("このデバイスではバーコードを撮影できません。検索タブから書名・著者で検索するか、ISBN を直接入力してください。")
                } actions: {
                    if let selectedTab {
                        Button {
                            selectedTab.wrappedValue = .search
                        } label: {
                            Label("検索を開く", systemImage: "magnifyingglass")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
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
            case .mock:
                MockScannerView()
            }
        }
        .navigationTitle("スキャン")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let selectedTab {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        selectedTab.wrappedValue = .library
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "books.vertical.fill")
                            if !savedBooks.isEmpty {
                                Text("\(savedBooks.count)")
                                    .font(.caption.weight(.bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(Color.accentColor, in: Capsule())
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .accessibilityLabel(Text("ライブラリを開く"))
                }
            }
        }
        .navigationDestination(item: $detectedISBN) { isbn in
            BookDetailView(isbn13: isbn, selectedTab: selectedTab)
        }
        .task { await prepare() }
    }

    private func prepare() async {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--seed-screenshots") {
            status = .mock
            return
        }
        #endif
        // シミュレータや背面カメラがない端末
        guard AVCaptureDevice.default(for: .video) != nil else {
            status = .noCamera
            return
        }
        let auth = AVCaptureDevice.authorizationStatus(for: .video)
        switch auth {
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            status = granted ? .ready : .permissionDenied
        case .authorized:
            status = .ready
        case .denied, .restricted:
            status = .permissionDenied
        @unknown default:
            status = .permissionDenied
        }
    }
}

// MARK: - Mock scanner (シミュレータ・スクショ用)

private struct MockScannerView: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.18), Color(white: 0.05)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Text("978 / 979 で始まる本のバーコードを映してください")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(.thinMaterial.opacity(0.9), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.top, 16)

                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.95))
                        .frame(width: 320, height: 180)
                        .shadow(radius: 12)

                    VStack(spacing: 12) {
                        HStack(spacing: 2) {
                            ForEach(0..<60, id: \.self) { i in
                                Rectangle()
                                    .fill(.black)
                                    .frame(width: stripeWidth(i), height: 90)
                            }
                        }
                        Text("9 784101 001036")
                            .font(.system(size: 18, weight: .medium, design: .monospaced))
                            .foregroundStyle(.black)
                    }

                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.yellow, lineWidth: 4)
                        .frame(width: 340, height: 200)
                }

                Spacer()

                Text("ピントが合うと自動で読み取ります")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.bottom, 36)
            }
        }
    }

    private func stripeWidth(_ i: Int) -> CGFloat {
        let pattern: [CGFloat] = [1, 2, 1, 3, 1, 1, 4, 2, 1, 1, 2, 1, 3, 2, 1]
        return pattern[i % pattern.count]
    }
}

// MARK: - AVFoundation wrapper

private struct BarcodeScannerRepresentable: UIViewRepresentable {
    @Binding var detectedISBN: String?

    func makeUIView(context: Context) -> CameraBarcodeScannerView {
        let view = CameraBarcodeScannerView()
        view.onISBN = { isbn in
            DispatchQueue.main.async {
                self.detectedISBN = isbn
            }
        }
        view.startScanning()
        return view
    }

    func updateUIView(_ uiView: CameraBarcodeScannerView, context: Context) {
        if detectedISBN == nil {
            uiView.resetForNextScan()
        } else {
            uiView.stopScanning()
        }
    }
}
