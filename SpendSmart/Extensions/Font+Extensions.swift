import SwiftUI

extension Font {
    // MARK: - Manrope
    /// Returns the Manrope font with the specified size and weight.
    /// - Parameters:
    ///   - size: The size of the font.
    ///   - weight: The weight of the font (default is .regular).
    static func manrope(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        // Manrope is a variable font, so we use the base name "Manrope" and let SwiftUI apply the weight.
        // If specific weight files were used, we would switch on them here.
        // Assuming "Manrope-Variable" is registered as "Manrope" or "Manrope-Regular" family.
        // Usually variable fonts are registered as just the family name.
        // Let's try "Manrope-Regular" if "Manrope" fails, but valid PostScript name for variable font is often just "Manrope" or specific instance.
        // Given filename "Manrope-Variable.ttf", checking the PostScript name is ideal, but we'll try standard SwiftUI weight modifier first.
        return Font.custom("Manrope-Regular", size: size).weight(weight)
    }
    
    // MARK: - Instrument Serif
    /// Returns the Instrument Serif font with the specified size.
    /// - Parameter size: The size of the font.
    static func instrumentSerif(size: CGFloat) -> Font {
        return Font.custom("InstrumentSerif-Regular", size: size)
    }
    
    /// Returns the Instrument Serif Italic font with the specified size.
    /// - Parameter size: The size of the font.
    static func instrumentSerifItalic(size: CGFloat) -> Font {
        return Font.custom("InstrumentSerif-Italic", size: size)
    }
    
    // MARK: - IBM Plex Mono
    /// Returns the IBM Plex Mono font with the specified size.
    /// - Parameter size: The size of the font.
    static func ibmPlexMono(size: CGFloat) -> Font {
        return Font.custom("IBMPlexMono-Regular", size: size)
    }
}
