import SwiftUI
import UIKit

extension UIImage {
    /// Extracts dominant colors from the image
    func dominantColors(count: Int = 3) -> [Color] {
        guard let cgImage = self.cgImage else { return [.gray] }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let thumbnailSize = CGSize(width: 50, height: 50)
        
        let thumbnailContext = CGContext(
            data: nil,
            width: Int(thumbnailSize.width),
            height: Int(thumbnailSize.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(thumbnailSize.width) * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        )

        thumbnailContext?.draw(cgImage, in: CGRect(origin: .zero, size: thumbnailSize))

        guard let thumbnailData = thumbnailContext?.data else { return [.gray] }
        var pixelData = [UInt32](repeating: 0, count: Int(thumbnailSize.width * thumbnailSize.height))

        for y in 0..<Int(thumbnailSize.height) {
            for x in 0..<Int(thumbnailSize.width) {
                let offset = y * Int(thumbnailSize.width) + x
                pixelData[offset] = thumbnailData.load(fromByteOffset: offset * 4, as: UInt32.self)
            }
        }

        var colorCounts: [UInt32: Int] = [:]
        for pixel in pixelData { colorCounts[pixel, default: 0] += 1 }

        let sortedColors = colorCounts.sorted { $0.value > $1.value }
        var colors: [Color] = []
        
        for (pixel, _) in sortedColors.prefix(count * 2) {
            let r = CGFloat((pixel & 0x00FF0000) >> 16) / 255
            let g = CGFloat((pixel & 0x0000FF00) >> 8) / 255
            let b = CGFloat(pixel & 0x000000FF) / 255

            // Skip colors too close to black/white
            if (r + g + b > 0.2 && r + g + b < 2.7) {
                colors.append(Color(red: r, green: g, blue: b))
                if colors.count >= count { break }
            }
        }

        return colors.isEmpty ? [.gray] : colors
    }
    
    /// Estimated file size in MB (using JPEG compression)
    var fileSizeMB: String {
        guard let data = self.jpegData(compressionQuality: 0.8) else { return "0.0 MB" }
        let mb = Double(data.count) / 1024.0 / 1024.0
        return String(format: "%.1f MB", mb)
    }
}
