import SwiftUI

struct InlineDateSelector: View {
    var title: String
    @Binding var date: Date
    var minDate: Date? = nil
    var tint: Color = .blue
    var showValidationIcon: Bool = false
    var validationColor: Color = .red

    @State private var isOpen: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.instrumentSans(size: 13))
                    .foregroundColor(.secondary)
                if showValidationIcon {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(validationColor)
                }
            }

            Button(action: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    isOpen.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.secondary)
                    Text(date, style: .date)
                        .font(.instrumentSans(size: 16))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .padding(.horizontal, 12)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
                )
            }

            if isOpen {
                DatePicker("", selection: $date, in: (minDate ?? Date.distantPast)..., displayedComponents: .date)
                    .datePickerStyle(GraphicalDatePickerStyle())
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}


