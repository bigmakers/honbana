import SwiftUI
import SwiftData

/// メモ画像のフルスクリーン拡大ビュー。
/// 複数枚あれば横スワイプで切替、ピンチでズーム、ダブルタップでトグル、
/// 縮小状態で下にスワイプすると閉じる。
struct PhotoGalleryView: View {
    let images: [MemoImage]
    @State private var selectedID: PersistentIdentifier?
    @State private var savingState: SavingState = .idle

    @Environment(\.dismiss) private var dismiss

    enum SavingState: Equatable {
        case idle
        case saving
        case saved
        case failed(String)
    }

    init(images: [MemoImage], initialID: PersistentIdentifier? = nil) {
        self.images = images
        _selectedID = State(initialValue: initialID ?? images.first?.persistentModelID)
    }

    private var currentImage: MemoImage? {
        images.first { $0.persistentModelID == selectedID }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $selectedID) {
                ForEach(images) { memoImage in
                    if let ui = UIImage(data: memoImage.data) {
                        ZoomableImage(image: ui, onSwipeDown: { dismiss() })
                            .tag(Optional(memoImage.persistentModelID))
                    }
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            VStack {
                HStack {
                    Button {
                        Task { await saveCurrent() }
                    } label: {
                        savingButtonLabel
                    }
                    .disabled(savingState == .saving || currentImage == nil)
                    .padding(.top, 8)
                    .padding(.leading, 16)

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white, .black.opacity(0.5))
                    }
                    .padding(.top, 8)
                    .padding(.trailing, 16)
                }
                Spacer()
            }
        }
        .statusBarHidden()
        .animation(.easeInOut(duration: 0.2), value: savingState)
    }

    @ViewBuilder
    private var savingButtonLabel: some View {
        switch savingState {
        case .idle:
            Label("写真に保存", systemImage: "square.and.arrow.down")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(.black.opacity(0.5), in: Capsule())
        case .saving:
            HStack(spacing: 6) {
                ProgressView().tint(.white)
                Text("保存中").foregroundStyle(.white)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(.black.opacity(0.5), in: Capsule())
        case .saved:
            Label("保存しました", systemImage: "checkmark.circle.fill")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white, .green)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(.black.opacity(0.5), in: Capsule())
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white, .yellow)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(.black.opacity(0.5), in: Capsule())
        }
    }

    private func saveCurrent() async {
        guard let img = currentImage else { return }
        savingState = .saving
        do {
            try await PhotoSaver.save(img.data)
            savingState = .saved
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch let e as PhotoSaver.SaveError {
            savingState = .failed(e.errorDescription ?? "保存に失敗しました")
        } catch {
            savingState = .failed(error.localizedDescription)
        }
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        if savingState != .saving {
            savingState = .idle
        }
    }
}

/// ピンチズーム + ダブルタップ + ドラッグ + 縮小時のスワイプダウンで閉じる挙動を持つ画像ビュー。
private struct ZoomableImage: View {
    let image: UIImage
    let onSwipeDown: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 5.0

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .scaleEffect(scale)
            .offset(offset)
            .gesture(magnification)
            .simultaneousGesture(drag)
            .onTapGesture(count: 2) {
                withAnimation(.spring(duration: 0.3)) {
                    if scale > minScale {
                        reset()
                    } else {
                        scale = 2.5
                        lastScale = 2.5
                    }
                }
            }
    }

    private var magnification: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = max(minScale, min(lastScale * value, maxScale))
            }
            .onEnded { _ in
                if scale < minScale {
                    withAnimation(.spring(duration: 0.3)) { reset() }
                } else {
                    lastScale = scale
                }
            }
    }

    private var drag: some Gesture {
        DragGesture()
            .onChanged { value in
                if scale > minScale {
                    // ズーム中はパン
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                } else {
                    // 等倍時の下方向スワイプは閉じる準備
                    offset = CGSize(width: 0, height: max(0, value.translation.height))
                }
            }
            .onEnded { value in
                if scale <= minScale {
                    if value.translation.height > 120 {
                        onSwipeDown()
                    } else {
                        withAnimation(.spring(duration: 0.3)) {
                            offset = .zero
                        }
                    }
                } else {
                    lastOffset = offset
                }
            }
    }

    private func reset() {
        scale = minScale
        lastScale = minScale
        offset = .zero
        lastOffset = .zero
    }
}
