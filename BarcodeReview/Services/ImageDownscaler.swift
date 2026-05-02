import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

enum ImageDownscaler {
    /// 端末ストレージを圧迫しないよう、長辺最大 1280px の JPEG に落として返す。
    static func downscaleToJPEG(_ data: Data, maxPixel: CGFloat = 1280, quality: CGFloat = 0.85) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cg).jpegData(compressionQuality: quality)
    }
}
