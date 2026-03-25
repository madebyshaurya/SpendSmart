import SwiftUI

struct ReceiptItemRow: View {
    let item: ReceiptItem
    let useEmoji: Bool
    let emoji: String?

    init(item: ReceiptItem, useEmoji: Bool = false, emoji: String? = nil) {
        self.item = item
        self.useEmoji = useEmoji
        self.emoji = emoji
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Category Icon
            ZStack {
                if useEmoji, let emoji {
                    Text(emoji)
                        .font(.system(size: 20))
                } else {
                    Image(systemName: iconForCategory(item.category))
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 40, height: 40)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.manrope(size: 16, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(item.category)
                    .font(.manrope(size: 12))
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.2f", item.price))
                    .font(.ibmPlexMono(size: 15))
                
                if item.isDiscount {
                    Text("Discount")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.1))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground).opacity(0.3))
        )
    }
    
    private func iconForCategory(_ category: String) -> String {
        switch category.lowercased() {
        case "groceries": return "carrot.fill"
        case "dining": return "fork.knife"
        case "shopping": return "bag.fill"
        case "health": return "heart.fill"
        case "transport": return "car.fill"
        case "services": return "wrench.and.screwdriver.fill"
        case "entertainment": return "film.fill"
        case "other": return "tag.fill"
        default: return "cart.fill"
        }
    }
}
