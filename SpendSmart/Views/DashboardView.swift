//
//  DashboardView.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-03-14.
//

import SwiftUI
import AuthenticationServices
import Supabase
import Charts

struct DashboardView: View {
    var email: String
    @EnvironmentObject var appState: AppState
    @State private var currentUserReceipts: [Receipt] = []
    @Environment(\.colorScheme) private var colorScheme
    @State private var showNewExpenseSheet = false
    @State private var isRefreshing = false // Added state for refresh control

    func fetchUserReceipts() async {
        if let userId = supabase.auth.currentUser?.id {
            do {
                let response = try await supabase
                    .from("receipts")
                    .select()
                    .eq("user_id", value: userId)
                    .execute()

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .custom { decoder in
                    let container = try decoder.singleValueContainer()
                    let dateString = try container.decode(String.self)

                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    formatter.timeZone = TimeZone(secondsFromGMT: 0)

                    if let date = formatter.date(from: dateString) {
                        return date
                    }

                    throw DecodingError.dataCorruptedError(
                        in: container,
                        debugDescription: "Cannot decode date: \(dateString)"
                    )
                }

                let receipts = try decoder.decode([Receipt].self, from: response.data)
                currentUserReceipts = receipts
                // print("Receipts 🧾: ", receipts)
            } catch let error as DecodingError {
                print("❌ Decoding Error fetching receipts: \(error)")
            } catch {
                print("❌ General Error fetching receipts: \(error.localizedDescription)")
            }
        }
    }

    func insertReceipt(newReceipt: Receipt) async {
        do {
            let encoder = JSONEncoder()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            encoder.dateEncodingStrategy = .formatted(dateFormatter)

            try await supabase
                .from("receipts")
                .insert(newReceipt)
                .execute()

            print("✅ Receipt inserted successfully!")
        } catch {
            print("❌ Error inserting receipt: \(error.localizedDescription)")
        }
    }

    var body: some View {
        ZStack {
            colorScheme == .dark ? Color(hex: "121212").ignoresSafeArea() : Color(hex: "F4F4F4").ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    if (supabase.auth.currentUser?.id) != nil {
                        VStack {
                            if currentUserReceipts.count == 0 {
                                Text("No receipts found.")
                                    .font(.instrumentSans(size: 16))
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                                    .transition(.opacity)
                            } else {
                                let costByCategory = calculateCostByCategory(receipts: currentUserReceipts)

                                // Donut Chart!
                                Chart(costByCategory, id: \.category) { item in
                                    SectorMark(
                                        angle: .value("Total", item.total),
                                        innerRadius: .ratio(0.65) // Make it a donut
                                    )
                                    .cornerRadius(5)
                                    .foregroundStyle(by: .value("Category", item.category))
                                    .annotation(position: .overlay) {
                                        Text("$\(item.total, specifier: "%.2f")")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    }
                                }
                                .chartLegend(.visible)
                                .frame(height: 300) // Adjust size as needed

                                // Optional: Text list below the chart
                                ForEach(costByCategory, id: \.category) { item in
                                    Text("\(item.category): $\(item.total, specifier: "%.2f")")
                                        .font(.instrumentSans(size: 16))
                                        .foregroundColor(colorScheme == .dark ? .white : .black)
                                }
                            }
                        }
                        .padding(.top, 20)
                    }
                }
                .padding(.horizontal)
            }
            .refreshable { // Added refreshable modifier
                isRefreshing = true
                await fetchUserReceipts()
                isRefreshing = false
            }

            VStack {
                Spacer()
                Button {
                    showNewExpenseSheet.toggle()
                } label: {
                    HStack {
                        Image(systemName: "plus")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .padding(.leading, 10)

                        Text("New Expense")
                            .font(.instrumentSans(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 15)
                    .padding(.horizontal, 60)
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.blue.gradient)
                            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                    )
                }
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)

            .sheet(isPresented: $showNewExpenseSheet) {
                NewExpenseView(onReceiptAdded: { newReceipt in
                    Task {
                        await insertReceipt(newReceipt: newReceipt)
                        await fetchUserReceipts()
                    }
                })
            }
        }
        .animation(.easeInOut, value: currentUserReceipts)
        .onAppear {
            Task {
                await fetchUserReceipts()
            }
        }
    }

    func calculateCostByCategory(receipts: [Receipt]) -> [(category: String, total: Double)] {
        var categoryTotals: [String: Double] = [:]

        for receipt in receipts {
            for item in receipt.items {
                categoryTotals[item.category, default: 0] += item.price
            }
        }

        return categoryTotals.map { (category: $0.key, total: $0.value) }
    }
}

struct ReceiptCardView: View {
    let receipt: Receipt
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(receipt.store_name)
                .font(.instrumentSans(size: 18, weight: .bold))
                .foregroundColor(colorScheme == .dark ? .white : .black)
            Text("Amount: $\(receipt.total_amount, specifier: "%.2f")")
                .font(.instrumentSans(size: 16))
                .foregroundColor(colorScheme == .dark ? .gray : .secondary)
            Text("Category: \(receipt.items.first?.category ?? "Unknown")")
                .font(.instrumentSans(size: 16))
                .foregroundColor(colorScheme == .dark ? .gray : .secondary)
            Text("Date: \(receipt.purchase_date, style: .date)")
                .font(.instrumentSans(size: 16))
                .foregroundColor(colorScheme == .dark ? .gray : .secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(colorScheme == .dark ? Color(hex: "282828") : Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
}
