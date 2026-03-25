import SwiftUI

/// A text view that counts up from 0 to a target number with animation.
/// Use for dashboard totals, receipt amounts, and other money displays.
struct CountingText: View {
    let targetValue: Double
    let format: String
    let prefix: String
    let font: Font
    let color: Color

    @State private var displayValue: Double = 0
    @State private var hasAppeared = false

    init(
        _ value: Double,
        format: String = "%.2f",
        prefix: String = "$",
        font: Font = .ibmPlexMono(size: 32),
        color: Color = .brandTextPrimary
    ) {
        self.targetValue = value
        self.format = format
        self.prefix = prefix
        self.font = font
        self.color = color
    }

    var body: some View {
        Text("\(prefix)\(String(format: format, displayValue))")
            .font(font)
            .foregroundColor(color)
            .monospacedDigit()
            .contentTransition(.numericText(value: displayValue))
            .onAppear {
                guard !hasAppeared else { return }
                hasAppeared = true
                withAnimation(.easeOut(duration: 0.8)) {
                    displayValue = targetValue
                }
            }
            .onChange(of: targetValue) { _, newValue in
                withAnimation(.brandSnappy) {
                    displayValue = newValue
                }
            }
    }
}
