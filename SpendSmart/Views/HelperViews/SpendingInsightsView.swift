//
//  SpendingInsightsView.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-04-17.
//

import SwiftUI

struct SpendingInsightsView: View {
    var receipts: [Receipt]
    var onReceiptTap: ((Receipt) -> Void)? = nil
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedStore: String? = nil
    @State private var showStoreReceipts = false

    // Computed properties for UI elements
    private var backgroundFill: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(colorScheme == .dark ? Color.black.opacity(0.5) : Color.white.opacity(0.9))
            .shadow(color: colorScheme == .dark ? Color.blue.opacity(0.2) : Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }

    // Helper method for insight card background
    private func insightCardBackground(color: Color) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(colorScheme == .dark ? color.opacity(0.15) : color.opacity(0.1))
    }

    // Receipt card background
    private var receiptCardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    // Calculate insights
    func calculateInsights() -> [(icon: String, title: String, description: String, color: Color)] {
        var insights: [(icon: String, title: String, description: String, color: Color)] = []

        // Need at least one receipt for insights
        guard !receipts.isEmpty else {
            return []
        }

        // Calculate total savings
        let totalSavings = receipts.reduce(0.0) { total, receipt in
            return total + receipt.savings
        }

        if totalSavings > 0 {
            insights.append((
                icon: "tag.fill",
                title: "Savings Found",
                description: "You've saved $\(String(format: "%.2f", totalSavings)) through discounts and points redemptions.",
                color: .green
            ))
        }

        // Find most frequent store
        let storeFrequency = receipts.reduce(into: [String: Int]()) { counts, receipt in
            counts[receipt.store_name, default: 0] += 1
        }

        if let (storeName, count) = storeFrequency.max(by: { $0.value < $1.value }), count > 1 {
            insights.append((
                icon: "bag.fill",
                title: "Frequent Shopping",
                description: "You've visited \(storeName) \(count) times. Tap to view receipts.",
                color: .blue
            ))
        }

        // Find largest category
        let categoryTotals = receipts.flatMap { $0.items }.reduce(into: [String: Double]()) { totals, item in
            if !item.isDiscount {
                totals[item.category, default: 0] += item.price
            }
        }

        if let (category, amount) = categoryTotals.max(by: { $0.value < $1.value }) {
            insights.append((
                icon: iconForCategory(category).name,
                title: "Top Spending Category",
                description: "You've spent $\(String(format: "%.2f", amount)) on \(category.lowercased()).",
                color: iconForCategory(category).color
            ))
        }

        // Add a tip if we have few insights
        if insights.count < 2 {
            insights.append((
                icon: "lightbulb.fill",
                title: "Spending Tip",
                description: "Add more receipts to get personalized spending insights.",
                color: .yellow
            ))
        }

        return insights
    }

    // Reuse the category icon mapping
    func iconForCategory(_ category: String) -> (name: String, color: Color) {
        switch category.lowercased() {
        case "rent", "housing":
            return ("house.fill", .red)
        case "bills", "utilities":
            return ("creditcard.fill", .blue)
        case "groceries", "food":
            return ("cart.fill", .green)
        case "internet", "wifi":
            return ("wifi", .purple)
        case "tax":
            return ("dollarsign.circle.fill", .orange)
        case "transport", "travel":
            return ("car.fill", .yellow)
        case "entertainment", "fun":
            return ("gamecontroller.fill", .pink)
        case "shopping", "clothing":
            return ("bag.fill", .cyan)
        case "health", "medical":
            return ("cross.case.fill", .mint)
        case "education", "school":
            return ("book.fill", .teal)
        case "subscriptions", "services":
            return ("person.crop.circle.fill", .indigo)
        case "dining":
            return ("fork.knife", .pink)
        case "other":
            return ("tag.fill", .gray)
        default:
            return ("tag.fill", .gray)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Insights")
                    .font(.instrumentSans(size: 24, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : .black)

                Spacer()

                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 20))
            }
            .padding(.horizontal)

            let insights = calculateInsights()

            if insights.isEmpty {
                Text("Add receipts to get personalized insights")
                    .font(.instrumentSans(size: 16))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.7))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(0..<insights.count, id: \.self) { index in
                            let insight = insights[index]

                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: insight.icon)
                                        .foregroundColor(insight.color)
                                        .font(.system(size: 18))

                                    Text(insight.title)
                                        .font(.instrumentSans(size: 16, weight: .semibold))
                                        .foregroundColor(colorScheme == .dark ? .white : .black)
                                }

                                Text(insight.description)
                                    .font(.instrumentSans(size: 14))
                                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)

                                // Add a button for frequent shopping insight
                                if insight.title == "Frequent Shopping" {
                                    Button(action: {
                                        // Extract store name from description
                                        extractStoreNameAndShowReceipts(from: insight.description)
                                    }) {
                                        Text("View Receipts")
                                            .font(.instrumentSans(size: 14, weight: .medium))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(insight.color)
                                            )
                                    }
                                    .padding(.top, 4)
                                }
                            }
                            .padding(16)
                            .frame(width: 280)
                            .background(insightCardBackground(color: insight.color))
                            .onTapGesture {
                                // If this is the frequent shopping insight, show store receipts
                                if insight.title == "Frequent Shopping" {
                                    extractStoreNameAndShowReceipts(from: insight.description)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }

            // Show store receipts if selected
            if showStoreReceipts, let storeName = selectedStore {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("\(storeName) Receipts")
                            .font(.instrumentSans(size: 18, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? .white : .black)

                        Spacer()

                        Button(action: {
                            showStoreReceipts = false
                            selectedStore = nil
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 20))
                        }
                    }
                    .padding(.horizontal)

                    let storeReceipts = receipts.filter { $0.store_name == storeName }

                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(storeReceipts) { receipt in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(receipt.receipt_name)
                                            .font(.instrumentSans(size: 16, weight: .medium))
                                            .foregroundColor(colorScheme == .dark ? .white : .black)

                                        Text(formatDate(receipt.purchase_date))
                                            .font(.instrumentSans(size: 14))
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Text("$\(receipt.total_amount, specifier: "%.2f")")
                                        .font(.spaceGrotesk(size: 18, weight: .bold))
                                        .foregroundColor(colorScheme == .dark ? .white : .black)
                                }
                                .padding()
                                .background(receiptCardBackground)
                                .onTapGesture {
                                    if let onReceiptTap = onReceiptTap {
                                        onReceiptTap(receipt)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 200)
                }
                .padding(.vertical, 12)
                .background(insightCardBackground(color: .blue))
                .padding(.horizontal)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(), value: showStoreReceipts)
            }
        }
        .padding(.vertical)
        .background(backgroundFill)
        .padding(.horizontal)
    }

    // Helper function to extract store name from insight description
    private func extractStoreNameAndShowReceipts(from description: String) {
        // Look for the pattern "You've visited [store name] times"
        if let range = description.range(of: "You've visited "),
           let endRange = description.range(of: " times") {
            let startIndex = range.upperBound
            let endIndex = endRange.lowerBound
            selectedStore = String(description[startIndex..<endIndex])
            showStoreReceipts = true
        }
    }

    // Helper function to format date
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct SpendingInsightsView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleItems = [
            ReceiptItem(id: UUID(), name: "Coffee", price: 4.99, category: "Dining"),
            ReceiptItem(id: UUID(), name: "Bagel", price: 3.49, category: "Dining"),
            ReceiptItem(id: UUID(), name: "Discount", price: -2.00, category: "Discount", isDiscount: true)
        ]

        let sampleReceipts = [
            Receipt(
                id: UUID(),
                user_id: UUID(),
                image_urls: ["https://example.com/image.jpg"],
                total_amount: 6.48,
                items: sampleItems,
                store_name: "Coffee Shop",
                store_address: "123 Main St",
                receipt_name: "Morning Coffee",
                purchase_date: Date(),
                currency: "USD",
                payment_method: "Credit Card",
                total_tax: 0.58
            ),
            Receipt(
                id: UUID(),
                user_id: UUID(),
                image_urls: ["https://example.com/image2.jpg"],
                total_amount: 12.99,
                items: sampleItems,
                store_name: "Coffee Shop",
                store_address: "123 Main St",
                receipt_name: "Lunch",
                purchase_date: Date().addingTimeInterval(-86400),
                currency: "USD",
                payment_method: "Credit Card",
                total_tax: 1.20
            )
        ]

        return SpendingInsightsView(receipts: sampleReceipts)
            .padding()
            .background(Color.gray.opacity(0.1))
    }
}
