//
//  Extensions.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-03-14.
//

import SwiftUI

extension Font {
    static func spaceGrotesk(size: CGFloat) -> Font {
        Font.custom("SpaceGrotesk-Variable", size: size)
    }
    
    static func instrumentSans(size: CGFloat) -> Font {
        Font.custom("InstrumentSans-Variable", size: size)
    }
    
    static func instrumentSerif(size: CGFloat) -> Font {
        Font.custom("InstrumentSerif-Regular", size: size)
    }
    
    static func instrumentSerifItalic(size: CGFloat) -> Font {
        Font.custom("InstrumentSerif-Italic", size: size)
    }
}
