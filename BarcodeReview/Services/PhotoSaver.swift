import Foundation
import Photos
import UIKit

enum PhotoSaver {
    enum SaveError: LocalizedError {
        case permissionDenied
        case underlying(Error)
        var errorDescription: String? {
            switch self {
            case .permissionDenied: return "写真へのアクセスが許可されていません"
            case .underlying(let e): return e.localizedDescription
            }
        }
    }

    /// 指定したJPEGデータを写真ライブラリに保存する。
    /// 必要に応じて NSPhotoLibraryAddUsageDescription の権限ダイアログを出す。
    static func save(_ data: Data) async throws {
        let granted = await ensureAddOnlyPermission()
        guard granted else { throw SaveError.permissionDenied }

        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: data, options: nil)
        }
    }

    /// 複数枚をまとめて保存。1枚でも失敗したら最後にまとめて報告。
    static func saveAll(_ datas: [Data]) async throws -> Int {
        let granted = await ensureAddOnlyPermission()
        guard granted else { throw SaveError.permissionDenied }

        var saved = 0
        try await PHPhotoLibrary.shared().performChanges {
            for d in datas {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: d, options: nil)
                saved += 1
            }
        }
        return saved
    }

    private static func ensureAddOnlyPermission() async -> Bool {
        let current = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch current {
        case .authorized, .limited:
            return true
        case .notDetermined:
            return await withCheckedContinuation { cont in
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                    cont.resume(returning: newStatus == .authorized || newStatus == .limited)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
}
