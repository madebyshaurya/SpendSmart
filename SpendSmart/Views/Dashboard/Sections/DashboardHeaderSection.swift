import SwiftUI

struct DashboardHeaderSection: View {
    let greetingMessage: String
    let welcomeName: String
    let userEmoji: String
    let onProfileTap: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greetingMessage)
                    .font(.manrope(size: 14, weight: .regular))
                    .foregroundStyle(Color.brandTextSecondary)

                Text(welcomeName)
                    .font(.manrope(size: 24, weight: .bold))
                    .foregroundStyle(Color.brandTextPrimary)
            }

            Spacer()

            Button(action: onProfileTap) {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(Color.brandAccentLight)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text(userEmoji)
                                .font(.system(size: 22))
                        )

                    Circle()
                        .fill(Color.brandSuccess)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.brandBackground, lineWidth: 2)
                        )
                        .offset(x: 2, y: -2)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
    }
}
