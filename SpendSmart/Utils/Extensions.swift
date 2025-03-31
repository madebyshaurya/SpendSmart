//
//  Extensions.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-03-14.
//

import SwiftUI

extension Font {
    static func spaceGrotesk(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .medium:
            return Font.custom("SpaceGrotesk-Light_Medium", size: size)
        case .bold:
            return Font.custom("SpaceGrotesk-Light_Bold", size: size)
        default:
            return Font.custom("SpaceGrotesk-Light_Regular", size: size)
        }
    }
    
    static func instrumentSans(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .medium:
            return Font.custom("InstrumentSans-Regular_Medium", size: size)
        case .semibold:
            return Font.custom("InstrumentSans-Regular_SemiBold", size: size)
        case .bold:
            return Font.custom("InstrumentSans-Regular_Bold", size: size)
        default:
            return Font.custom("InstrumentSans-Regular", size: size)
        }
    }
    
    static func instrumentSerif(size: CGFloat) -> Font {
        Font.custom("InstrumentSerif-Regular", size: size)
    }
    
    static func instrumentSerifItalic(size: CGFloat) -> Font {
        Font.custom("InstrumentSerif-Italic", size: size)
    }
}

// Extension for hex color support
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension UIImage {
    func dominantColors(count: Int = 3) -> [Color] {
        guard let cgImage = self.cgImage else { return [.gray] }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        // Create a thumbnail to speed up processing
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
        
        // Get pixel data
        for y in 0..<Int(thumbnailSize.height) {
            for x in 0..<Int(thumbnailSize.width) {
                let offset = y * Int(thumbnailSize.width) + x
                pixelData[offset] = thumbnailData.load(fromByteOffset: offset * 4, as: UInt32.self)
            }
        }
        
        // Convert pixel data to RGB values
        var colorCounts: [UInt32: Int] = [:]
        for pixel in pixelData {
            colorCounts[pixel, default: 0] += 1
        }
        
        // Sort by frequency
        let sortedColors = colorCounts.sorted { $0.value > $1.value }
        
        // Convert to SwiftUI colors, skipping purely black/white
        var colors: [Color] = []
        for (pixel, _) in sortedColors.prefix(count * 2) {
            let r = CGFloat((pixel & 0x00FF0000) >> 16) / 255
            let g = CGFloat((pixel & 0x0000FF00) >> 8) / 255
            let b = CGFloat(pixel & 0x000000FF) / 255
            
            // Skip colors that are too close to black or white
            if (r + g + b > 0.2 && r + g + b < 2.7) {
                colors.append(Color(red: r, green: g, blue: b))
                if colors.count >= count {
                    break
                }
            }
        }
        
        return colors.isEmpty ? [.gray] : colors
    }
}
