//
//  HistoryView.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-03-22.
//

import SwiftUI

struct HistoryView: View {
    @State private var receipts: [Receipt] = []
    @State private var isRefreshing = false
    @State private var selectedReceipt: Receipt? = nil
    @Environment(\.colorScheme) private var colorScheme

    // Fetch receipts from Supabase using supabaseClient
    func fetchReceipts() async {
        do {
            let response = try await supabase
                .from("receipts")
                .select()
                .execute()
            
            // Debug: Print fetched JSON data
            print("Fetched Data: \(String(data: response.data, encoding: .utf8) ?? "No Data")")
            
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
            
            let fetchedReceipts = try decoder.decode([Receipt].self, from: response.data)
            print("Decoded Receipts: \(fetchedReceipts.count)")
            withAnimation(.easeInOut(duration: 0.5)) {
                receipts = fetchedReceipts
            }
        } catch {
            print("Error fetching receipts: \(error.localizedDescription)")
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 20)], spacing: 20) {
                    if receipts.isEmpty {
                        Text("No receipts found.")
                            .font(.instrumentSans(size: 16))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                            .padding()
                            .transition(.opacity)
                    } else {
                        ForEach(receipts) { receipt in
                            ReceiptStickyNoteView(receipt: receipt)
                                .onTapGesture {
                                    selectedReceipt = receipt
                                }
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                }
                .padding()
                .refreshable {
                    isRefreshing = true
                    await fetchReceipts()
                    isRefreshing = false
                }
            }
            .navigationTitle("Receipt History")
            .sheet(item: $selectedReceipt) { receipt in
                ReceiptDetailView(receipt: receipt)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .onAppear {
                Task {
                    await fetchReceipts()
                }
            }
        }
    }
}

struct ReceiptStickyNoteView: View {
    let receipt: Receipt
    @Environment(\.colorScheme) private var colorScheme
    @State private var appearAnimation: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(receipt.receipt_name)
                .font(.instrumentSerif(size: 18))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text(receipt.store_name)
                .font(.instrumentSans(size: 14))
                .foregroundColor(.secondary)
            Text("$\(receipt.total_amount, specifier: "%.2f")")
                .font(.spaceGrotesk(size: 20, weight: .bold))
            Text(receipt.purchase_date, style: .date)
                .font(.instrumentSans(size: 12))
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 140)
        .background(
            Group {
                if colorScheme == .dark {
                    LinearGradient(gradient: Gradient(colors: [Color.gray.opacity(0.3), Color.black.opacity(0.5)]),
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing)
                } else {
                    LinearGradient(gradient: Gradient(colors: [Color.yellow.opacity(0.7), Color.orange.opacity(0.4)]),
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing)
                }
            }
        )
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.3), radius: 4, x: 2, y: 2)
        .scaleEffect(appearAnimation ? 1 : 0.8)
        .opacity(appearAnimation ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                appearAnimation = true
            }
        }
    }
}

struct ReceiptDetailView: View {
    let receipt: Receipt
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let url = URL(string: receipt.image_url),
                   receipt.image_url != "placeholder_url" {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView().frame(height: 200)
                        case .success(let image):
                            image.resizable()
                                .aspectRatio(contentMode: .fit)
                                .cornerRadius(10)
                        case .failure:
                            Color.red.frame(height: 200)
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
                
                Text(receipt.receipt_name)
                    .font(.instrumentSerif(size: 32))
                    .bold()
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Store:")
                            .font(.instrumentSans(size: 16, weight: .semibold))
                        Text(receipt.store_name)
                    }
                    HStack {
                        Text("Address:")
                            .font(.instrumentSans(size: 16, weight: .semibold))
                        Text(receipt.store_address)
                    }
                    HStack {
                        Text("Purchased on:")
                            .font(.instrumentSans(size: 16, weight: .semibold))
                        Text(receipt.purchase_date, style: .date)
                    }
                    HStack {
                        Text("Total:")
                            .font(.instrumentSans(size: 16, weight: .semibold))
                        Text("$\(receipt.total_amount, specifier: "%.2f")")
                    }
                    HStack {
                        Text("Tax:")
                            .font(.instrumentSans(size: 16, weight: .semibold))
                        Text("$\(receipt.total_tax, specifier: "%.2f")")
                    }
                    HStack {
                        Text("Payment:")
                            .font(.instrumentSans(size: 16, weight: .semibold))
                        Text(receipt.payment_method)
                    }
                    HStack {
                        Text("Currency:")
                            .font(.instrumentSans(size: 16, weight: .semibold))
                        Text(receipt.currency)
                    }
                }
                .padding()
                .background(colorScheme == .dark ? Color.gray.opacity(0.2) : Color.gray.opacity(0.1))
                .cornerRadius(10)
                
                Divider()
                
                Text("Items")
                    .font(.instrumentSerif(size: 24))
                    .bold()
                    .padding(.bottom, 5)
                
                ForEach(receipt.items) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.name)
                                .font(.instrumentSans(size: 16, weight: .semibold))
                            Text(item.category)
                                .font(.instrumentSans(size: 14))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("$\(item.price, specifier: "%.2f")")
                            .font(.spaceGrotesk(size: 18, weight: .bold))
                    }
                    .padding()
                    .background(colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.15))
                    .cornerRadius(10)
                    .transition(.opacity)
                }
            }
            .padding()
        }
        .background(colorScheme == .dark ? Color.black.opacity(0.85) : Color.white.opacity(0.95))
        .ignoresSafeArea()
    }
}

#Preview {
    NavigationView {
        HistoryView()
    }
}
