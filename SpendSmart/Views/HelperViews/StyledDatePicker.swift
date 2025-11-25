import SwiftUI

struct StyledDatePicker: View {
    var title: String
    @Binding var selection: Date
    var systemImage: String

    @State private var isPresented = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: { isPresented.toggle() }) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundColor(.blue)
                Text(title)
                    .foregroundColor(.primary)
                Spacer()
                Text(selection, style: .date)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
            )
        }
        .sheet(isPresented: $isPresented) {
            NavigationView {
                VStack {
                    DatePicker(title, selection: $selection, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .padding()
                    
                    Spacer()
                }
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        IconButton(
                            icon: "xmark.circle.fill",
                            size: .medium,
                            style: .outlined
                        ) {
                            isPresented = false
                        }
                    }
                }
            }
        }
    }
}
