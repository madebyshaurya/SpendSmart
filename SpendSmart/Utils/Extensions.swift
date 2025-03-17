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
