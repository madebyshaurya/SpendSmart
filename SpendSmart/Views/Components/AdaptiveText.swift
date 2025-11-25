import SwiftUI
import UIKit

struct AdaptiveText: View {
    let text: String
    var font: Font = .body
    var minimumScaleFactor: CGFloat = 0.5
    var lineLimit: Int = 1
    var multilineTextAlignment: TextAlignment = .leading
    var color: Color = .primary
    var priority: TextPriority = .normal
    
    enum TextPriority {
        case low
        case normal
        case high
        case critical
        
        var scaleFactor: CGFloat {
            switch self {
            case .low: return 0.3
            case .normal: return 0.5
            case .high: return 0.7
            case .critical: return 0.8
            }
        }
    }
    
    var body: some View {
        Text(text)
            .font(font)
            .foregroundColor(color)
            .multilineTextAlignment(multilineTextAlignment)
            .lineLimit(lineLimit)
            .minimumScaleFactor(priority.scaleFactor)
            .allowsTightening(true)
    }
}

struct AdaptiveUIKitText: UIViewRepresentable {
    let text: String
    var font: UIFont = .systemFont(ofSize: 17)
    var textColor: UIColor = .label
    var textAlignment: NSTextAlignment = .left
    var minimumScaleFactor: CGFloat = 0.5
    var numberOfLines: Int = 1
    var priority: AdaptiveText.TextPriority = .normal
    
    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.adjustsFontSizeToFitWidth = true
        label.allowsDefaultTighteningForTruncation = true
        label.lineBreakMode = .byTruncatingTail
        return label
    }
    
    func updateUIView(_ uiView: UILabel, context: Context) {
        uiView.text = text
        uiView.font = font
        uiView.textColor = textColor
        uiView.textAlignment = textAlignment
        uiView.numberOfLines = numberOfLines
        uiView.minimumScaleFactor = priority.scaleFactor
        
        // Calculate optimal font size
        if !text.isEmpty {
            let containerSize = uiView.bounds.size
            if containerSize.width > 0 && containerSize.height > 0 {
                let optimalSize = calculateOptimalFontSize(
                    text: text,
                    containerSize: containerSize,
                    originalFont: font,
                    minimumScale: priority.scaleFactor
                )
                uiView.font = font.withSize(optimalSize)
            }
        }
    }
    
    private func calculateOptimalFontSize(
        text: String,
        containerSize: CGSize,
        originalFont: UIFont,
        minimumScale: CGFloat
    ) -> CGFloat {
        let originalSize = originalFont.pointSize
        let minimumSize = originalSize * minimumScale
        
        var currentSize = originalSize
        let options: NSStringDrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
        
        while currentSize >= minimumSize {
            let testFont = originalFont.withSize(currentSize)
            let attributes = [NSAttributedString.Key.font: testFont]
            let textRect = text.boundingRect(
                with: CGSize(width: containerSize.width, height: .greatestFiniteMagnitude),
                options: options,
                attributes: attributes,
                context: nil
            )
            
            if textRect.height <= containerSize.height && textRect.width <= containerSize.width {
                return currentSize
            }
            
            currentSize -= 0.5
        }
        
        return minimumSize
    }
}

extension AdaptiveText {
    static func title(_ text: String, priority: TextPriority = .high) -> AdaptiveText {
        AdaptiveText(
            text: text,
            font: DesignTokens.Typography.title3(),
            minimumScaleFactor: priority.scaleFactor,
            color: DesignTokens.Colors.Neutral.primary,
            priority: priority
        )
    }
    
    static func headline(_ text: String, priority: TextPriority = .normal) -> AdaptiveText {
        AdaptiveText(
            text: text,
            font: DesignTokens.Typography.headline(),
            minimumScaleFactor: priority.scaleFactor,
            color: DesignTokens.Colors.Neutral.primary,
            priority: priority
        )
    }
    
    static func body(_ text: String, priority: TextPriority = .normal) -> AdaptiveText {
        AdaptiveText(
            text: text,
            font: DesignTokens.Typography.body(),
            minimumScaleFactor: priority.scaleFactor,
            color: DesignTokens.Colors.Neutral.primary,
            priority: priority
        )
    }
    
    static func caption(_ text: String, priority: TextPriority = .low) -> AdaptiveText {
        AdaptiveText(
            text: text,
            font: DesignTokens.Typography.caption1(),
            minimumScaleFactor: priority.scaleFactor,
            color: DesignTokens.Colors.Neutral.secondary,
            priority: priority
        )
    }
}