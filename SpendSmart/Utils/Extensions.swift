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
