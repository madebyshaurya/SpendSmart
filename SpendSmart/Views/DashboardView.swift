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
    @State private var isRefreshing = false // For refresh control
    
    // MARK: - Fetch Receipts
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
                withAnimation {
                    currentUserReceipts = receipts
                }
            } catch let error as DecodingError {
                print("❌ Decoding Error fetching receipts: \(error)")
            } catch {
                print("❌ General Error fetching receipts: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Insert Receipt
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
    
    // MARK: - Calculate Costs By Category (Including Tax)
    func calculateCostByCategory(receipts: [Receipt]) -> [(category: String, total: Double)] {
        var categoryTotals: [String: Double] = [:]
        
        for receipt in receipts {
            // Sum each item's price by category.
            for item in receipt.items {
                categoryTotals[item.category, default: 0] += item.price
            }
            // Add the receipt's tax to the "Tax" category.
            categoryTotals["Tax", default: 0] += receipt.total_tax
        }
        
        return categoryTotals.map { (category: $0.key, total: $0.value) }
    }
    
    // MARK: - Calculate Summary Data
    func calculateSummary(receipts: [Receipt]) -> (totalExpense: Double, totalTax: Double) {
        var totalExpense = 0.0
        var totalTax = 0.0
        
        for receipt in receipts {
            totalExpense += receipt.total_amount
            totalTax += receipt.total_tax
        }
        
        return (totalExpense, totalTax)
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            // Background Color
            colorScheme == .dark ? Color(hex: "121212").ignoresSafeArea() : Color(hex: "F4F4F4").ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Summary Card
                    if currentUserReceipts.count > 0 {
                        let summary = calculateSummary(receipts: currentUserReceipts)
                        SummaryCardView(totalExpense: summary.totalExpense,
                                        totalTax: summary.totalTax,
                                        receiptCount: currentUserReceipts.count)
                            .padding(.top, 20)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // Chart & List of Costs by Category
                    if currentUserReceipts.isEmpty {
                        Text("No receipts found.")
                            .font(.instrumentSans(size: 16))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                            .transition(.opacity)
                            .padding()
                    } else {
                        let costByCategory = calculateCostByCategory(receipts: currentUserReceipts)
                        
                        // Donut Chart with animation
                        Chart(costByCategory, id: \.category) { item in
                            SectorMark(
                                angle: .value("Total", item.total),
                                innerRadius: .ratio(0.65),
                                angularInset: 2.0
                            )
                            .cornerRadius(12)
                            .foregroundStyle(by: .value("Category", item.category))
                            .annotation(position: .overlay) {
                                Text("$\(item.total, specifier: "%.2f")")
                                    .font(.spaceGrotesk(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(Color.black.opacity(0.7))
                                    .cornerRadius(8)
                            }
                        }
                        .chartLegend(.visible)
                        .frame(height: 300)
                        .padding(.horizontal)
                        .transition(.slide)
                        
                        // List of category totals
                        ForEach(costByCategory, id: \.category) { item in
                            HStack {
                                Text("\(item.category):")
                                    .font(.instrumentSans(size: 16))
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                                Spacer()
                                Text("$\(item.total, specifier: "%.2f")")
                                    .font(.instrumentSans(size: 16, weight: .semibold))
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                            }
                            .padding(.horizontal)
                            .transition(.move(edge: .leading))
                        }
                    }
                }
                .padding(.horizontal)
            }
            .refreshable {
                isRefreshing = true
                await fetchUserReceipts()
                isRefreshing = false
            }
            
            // New Expense Button with Animation
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
                    .scaleEffect(showNewExpenseSheet ? 1.05 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: showNewExpenseSheet)
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
}

// MARK: - Summary Card View
struct SummaryCardView: View {
    var totalExpense: Double
    var totalTax: Double
    var receiptCount: Int
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Home")
                .font(.instrumentSerif(size: 36))
                .foregroundColor(colorScheme == .dark ? .white : .black)
            
            HStack {
                SummaryItemView(title: "Total Expenses", amount: totalExpense)
                Divider()
                    .frame(height: 50)
                    .background(colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.5))
                SummaryItemView(title: "Tax Paid", amount: totalTax)
            }
            
            Text(receiptCount == 1 ? "1 receipt" : "\(receiptCount) receipts")
                .font(.instrumentSans(size: 16, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.7))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(colorScheme == .dark ? Color(hex: "282828") : Color.white)
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal)
        .transition(.opacity)
    }
}

struct SummaryItemView: View {
    var title: String
    var amount: Double
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack {
            Text(title)
                .font(.instrumentSans(size: 14))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
            Text("$\(amount, specifier: "%.2f")")
                .font(.spaceGrotesk(size: 20, weight: .semibold))
                .foregroundColor(colorScheme == .dark ? .white : .black)
        }
        .frame(maxWidth: .infinity)
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView(email: "user@example.com")
            .preferredColorScheme(.dark)
    }
}
