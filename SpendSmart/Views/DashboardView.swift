//
//  DashboardView.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-03-14.
//

import SwiftUI
import AuthenticationServices
import Supabase

struct DashboardView: View {
    var email: String
    @EnvironmentObject var appState: AppState
    @State private var currentUserReceipts: [Receipt] = []
//    @State private var userId: UUID?
    
    func fetchUserReceipts() async {
        if let userId = supabase.auth.currentUser?.id {
            do {
                let response = try await supabase
                    .from("receipts")
                    .select()
                    .eq("user_id", value: userId)
                    .execute()
                
                let decoder = JSONDecoder()
                
                // Create a custom date decoding strategy specifically for your format
                decoder.dateDecodingStrategy = .custom { decoder in
                    let container = try decoder.singleValueContainer()
                    let dateString = try container.decode(String.self)
                    
                    // Create a formatter specifically for "2025-03-22T22:39:19" format
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
                print("Receipts 🧾: ", receipts)
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
            
            // Match the date format used by Supabase
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
        VStack(spacing: 20) {
            if let userId = supabase.auth.currentUser?.id {
                VStack {
                    if currentUserReceipts.count == 0 {
                        Text("No receipts found.")
                            .font(.instrumentSans(size: 16))
                            .foregroundColor(.gray)
                    } else {
                        ForEach(currentUserReceipts, id: \.id) { receipt in
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Receipt ID: \(receipt.store_name)")
                                    .font(.instrumentSans(size: 16))
                                    .bold()
                                
                                Text("Amount: $\(receipt.total_amount)")
                                    .font(.instrumentSans(size: 16))
                                
                                Text("Category: \(receipt.items[0].category)")
                                    .font(.instrumentSans(size: 16))
                                
                                Text("Date: \(receipt.purchase_date)")
                                    .font(.instrumentSans(size: 16))
                            }
                            .padding()
                            .cornerRadius(10)
                        }
                    }
                }
            }
        }
        .onAppear {
            Task {
                await fetchUserReceipts()
            }
        }
        .padding()
    }
}
