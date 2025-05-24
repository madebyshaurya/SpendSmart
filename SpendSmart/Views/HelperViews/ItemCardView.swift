//
//  ItemCardView.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-04-17.
//

import SwiftUI
import Foundation

struct ReceiptItemCard: View {
    let item: ReceiptItem
    let logoColors: [Color]
    let index: Int
    let currencyCode: String
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var currencyManager = CurrencyManager.shared

    // Initialize with default currency code if not provided
    init(item: ReceiptItem, logoColors: [Color], index: Int, currencyCode: String = "USD") {
        self.item = item
        self.logoColors = logoColors
        self.index = index
        self.currencyCode = currencyCode
    }

    var body: some View {
        VStack(spacing: 8) {
            // Item name and price on the same line
            HStack {
                // Item name with optional discount tag
                HStack(spacing: 4) {
                    Text(item.name)
                        .font(.instrumentSans(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    // Small discount tag if needed
                    if item.isDiscount {
                        Text("DISCOUNT")
                            .font(.instrumentSans(size: 8))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                Capsule()
                                    .fill(Color.green)
                            )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 8)

                // Price display
                HStack(spacing: 4) {
                    // Only show original price for items with a valid original price that's greater than the current price
                    if let originalPrice = item.originalPrice, originalPrice > item.price, originalPrice > 0 {
                        // Always show original price in receipt's currency
                        Text(currencyManager.formatAmount(originalPrice, currencyCode: currencyCode))
                            .font(.instrumentSans(size: 14))
                            .foregroundColor(.secondary)
                            .strikethrough(true, color: .green.opacity(0.7))
                    }

                    // Show original currency as primary and preferred as secondary
                    VStack(alignment: .trailing, spacing: 2) {
                        // Always show original currency amount as primary
                        Text(currencyManager.formatAmount(item.price, currencyCode: currencyCode))
                            .font(.instrumentSans(size: 18, weight: .medium))
                            .foregroundColor(item.isDiscount ? .green : .primary)

                        // Show converted price ONLY if:
                        // 1. The receipt currency is different from preferred currency
                        // 2. The item price is not zero (no need to show conversion for free items)
                        if currencyCode != currencyManager.preferredCurrency && item.price != 0 {
                            HStack(spacing: 2) {
                                Text("≈")
                                    .font(.instrumentSans(size: 10))
                                    .foregroundColor(.secondary)

                                Text(currencyManager.formatAmount(
                                    currencyManager.convertAmountSync(item.price,
                                                                   from: currencyCode,
                                                                   to: currencyManager.preferredCurrency),
                                    currencyCode: currencyManager.preferredCurrency))
                                    .font(.instrumentSans(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }

            HStack {
                // Category pill
                Text(item.category)
                    .font(.instrumentSans(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(categoryColor.opacity(0.1))
                    )

                Spacer()

                // Discount description if available
                if item.isDiscount, let description = item.discountDescription {
                    Text(description)
                        .font(.instrumentSans(size: 12))
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    colorScheme == .dark
                    ? LinearGradient(
                        colors: [Color(.systemGray6), Color(.systemGray6).opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                      )
                    : LinearGradient(
                        colors: [Color.white, Color.white.opacity(0.95)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                      )
                )
                .shadow(
                    color: colorScheme == .dark
                        ? categoryColor.opacity(0.2)
                        : Color.black.opacity(0.08),
                    radius: 8,
                    x: 0,
                    y: 3
                )
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: colorScheme)
    }

    private var categoryColor: Color {
        if logoColors.count > 0 {
            return logoColors[index % logoColors.count]
        }
        return .blue
    }

    // Helper function to get the currency code
    private func getCurrencyCode() -> String {
        return currencyCode
    }
}

struct ReceiptItemCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Regular item
            ReceiptItemCard(
                item: ReceiptItem(
                    id: UUID(),
                    name: "Coffee",
                    price: 4.99,
                    category: "Dining"
                ),
                logoColors: [.blue, .green],
                index: 0,
                currencyCode: "USD"
            )

            // Discount item
            ReceiptItemCard(
                item: ReceiptItem(
                    id: UUID(),
                    name: "Discount",
                    price: -2.00,
                    category: "Discount",
                    originalPrice: 2.00,
                    discountDescription: "Member Discount",
                    isDiscount: true
                ),
                logoColors: [.blue, .green],
                index: 1,
                currencyCode: "USD"
            )

            // Free item
            ReceiptItemCard(
                item: ReceiptItem(
                    id: UUID(),
                    name: "Free Bagel",
                    price: 0.00,
                    category: "Dining",
                    originalPrice: 3.49,
                    discountDescription: "Loyalty Reward",
                    isDiscount: true
                ),
                logoColors: [.blue, .green],
                index: 2,
                currencyCode: "USD"
            )
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
}
