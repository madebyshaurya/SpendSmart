import SwiftUI

struct StepperRow: View {
    var title: String
    @Binding var value: Int
    var range: ClosedRange<Int>
    var tint: Color = .blue

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.instrumentSans(size: 13))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(value)")
                    .font(.instrumentSans(size: 13))
                    .foregroundColor(tint)
            }
            Stepper("", value: $value, in: range)
                .solidCard()
        }
    }
}


