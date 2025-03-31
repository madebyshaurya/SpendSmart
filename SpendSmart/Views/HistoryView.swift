//
//  HistoryView.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-03-22.
//

import SwiftUI

// Logo cache to prevent unnecessary API calls
class LogoCache: ObservableObject {
    static let shared = LogoCache()
    @Published var logoCache: [String: (image: UIImage, colors: [Color])] = [:]
}

// API client for Logo.dev
class LogoService {
    static let shared = LogoService()
    private let secretKey = "sk_CnGSgN-eQhaHCveI5k4LuA"
    private let publicKey = "pk_EB5BNaRARdeXj64ti60xGQ"
    
    func fetchLogo(for storeName: String) async -> (UIImage?, [Color]) {
        // Check cache first
        if let cached = LogoCache.shared.logoCache[storeName.lowercased()] {
            return (cached.image, cached.colors)
        }
        
        let formattedName = storeName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? storeName
        let urlString = "https://api.logo.dev/search?q=\(formattedName)"
        
        guard let url = URL(string: urlString) else {
            return (nil, [.gray])
        }
        
        var request = URLRequest(url: url)
        request.addValue("Bearer \(secretKey)", forHTTPHeaderField: "Authorization") // Fixed header
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Raw API Response: \(jsonString)")
            }
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("Error response: \(response)")
                return (nil, [.gray])
            }
            
            // Decode JSON as an array of dictionaries
            if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               let firstResult = jsonArray.first,
               let logoUrlString = firstResult["logo_url"] as? String,
               let logoUrl = URL(string: logoUrlString) {
                
                // Fetch the logo image
                let (imageData, _) = try await URLSession.shared.data(from: logoUrl)
                if let image = UIImage(data: imageData) {
                    let colors = image.dominantColors(count: 3)
                    
                    // Cache the result on the main thread
                    await MainActor.run {
                        LogoCache.shared.logoCache[storeName.lowercased()] = (image, colors)
                    }
                    
                    return (image, colors)
                }
            }
        } catch {
            print("Error fetching logo: \(error)")
        }
        
        return (nil, [.gray])
    }
}

struct HistoryView: View {
    @State private var receipts: [Receipt] = []
    @State private var isRefreshing = false
    @State private var selectedReceipt: Receipt? = nil
    @StateObject private var logoCache = LogoCache.shared
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
            
            // Optionally pre-fetch logos for receipts here
            for receipt in fetchedReceipts {
                Task {
                    _ = await LogoService.shared.fetchLogo(for: receipt.store_name)
                }
            }
            
            withAnimation(.easeInOut(duration: 0.5)) {
                receipts = fetchedReceipts
            }
        } catch {
            print("Error fetching receipts: \(error.localizedDescription)")
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Animated background
                BackgroundGradientView()
                
                ScrollView {
                    VStack(spacing: 20) {
                        Text("Receipt History")
                            .font(.instrumentSerif(size: 38))
                            .fontWeight(.bold)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.primary, .primary.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: colorScheme == .dark ? .white.opacity(0.1) : .black.opacity(0.1), radius: 2, y: 2)
                            .padding(.top, 20)
                        
                        // Grid layout for wider screens, list for narrow
                        if geometry.size.width > 500 {
                            receiptGridView
                        } else {
                            receiptListView
                        }
                    }
                    .padding()
                }
                .refreshable {
                    isRefreshing = true
                    await fetchReceipts()
                    isRefreshing = false
                }
            }
            // Sheet presented at the parent level
            .sheet(item: $selectedReceipt) { receipt in
                // Pass in the receipt details; you can also pass logoImage/Colors if needed.
                ReceiptDetailView(receipt: receipt)
            }
            .onAppear {
                Task {
                    await fetchReceipts()
                }
            }
        }
    }
    
    private var receiptGridView: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 300), spacing: 20)], spacing: 20) {
            if receipts.isEmpty {
                EmptyStateView()
            } else {
                ForEach(receipts) { receipt in
                    EnhancedReceiptCard(receipt: receipt)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                                selectedReceipt = receipt
                            }
                        }
                }
            }
        }
    }
    
    private var receiptListView: some View {
        LazyVStack(spacing: 16) {
            if receipts.isEmpty {
                EmptyStateView()
            } else {
                ForEach(receipts) { receipt in
                    EnhancedReceiptCard(receipt: receipt)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                                selectedReceipt = receipt
                            }
                        }
                }
            }
        }
    }
}

struct EnhancedReceiptCard: View {
    let receipt: Receipt
    @Environment(\.colorScheme) private var colorScheme
    @State private var logoImage: UIImage? = nil
    @State private var logoColors: [Color] = [.gray]
    @State private var isLoaded = false
    @State private var isHovered = false
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Card background
            RoundedRectangle(cornerRadius: 16)
                .fill(backgroundGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    primaryLogoColor.opacity(0.7),
                                    primaryLogoColor.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: shadowColor, radius: isHovered ? 12 : 6, x: 0, y: isHovered ? 5 : 3)
            
            // Logo watermark in the background
            if let logo = logoImage {
                Image(uiImage: logo)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .opacity(0.05)
                    .blendMode(colorScheme == .dark ? .plusLighter : .overlay)
                    .rotationEffect(Angle(degrees: -5))
                    .position(x: 250, y: 100)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    // Store info with integrated logo
                    HStack(spacing: 10) {
                        if let logo = logoImage {
                            Image(uiImage: logo)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                                .shadow(color: primaryLogoColor.opacity(0.5), radius: 4, x: 0, y: 2)
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(primaryLogoColor.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                
                                Text(String(receipt.store_name.prefix(1)).uppercased())
                                    .font(.spaceGrotesk(size: 20, weight: .bold))
                                    .foregroundColor(primaryLogoColor)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(receipt.store_name.capitalized)
                                .font(.instrumentSans(size: 18, weight: .semibold))
                                .lineLimit(1)
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                            
                            Text(receipt.receipt_name)
                                .font(.instrumentSans(size: 14))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    // Price tag
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(primaryLogoColor.opacity(colorScheme == .dark ? 0.25 : 0.15))
                            .frame(height: 32)
                        
                        Text("$\(receipt.total_amount, specifier: "%.2f")")
                            .font(.spaceGrotesk(size: 20, weight: .bold))
                            .foregroundColor(primaryLogoColor)
                            .padding(.horizontal, 12)
                    }
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundColor(secondaryLogoColor.opacity(0.8))
                    
                    Text(formatDate(receipt.purchase_date))
                        .font(.instrumentSans(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 2)
                
                Rectangle()
                    .fill(LinearGradient(
                        colors: [primaryLogoColor.opacity(0.3), primaryLogoColor.opacity(0.1)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(height: 1)
                    .padding(.vertical, 6)
                
                if !receipt.items.isEmpty {
                    VStack(spacing: 8) {
                        HStack {
                            Text("ITEMS")
                                .font(.instrumentSans(size: 11, weight: .semibold))
                                .foregroundColor(secondaryLogoColor)
                                .tracking(1)
                            
                            Spacer()
                            
                            Text("\(receipt.items.count) item\(receipt.items.count == 1 ? "" : "s")")
                                .font(.instrumentSans(size: 11))
                                .foregroundColor(.secondary.opacity(0.8))
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(receipt.items.prefix(3).enumerated()), id: \.element.id) { index, item in
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(logoColors[index % max(1, logoColors.count)])
                                            .frame(width: 8, height: 8)
                                        
                                        Text(item.name)
                                            .font(.instrumentSans(size: 13))
                                            .foregroundColor(.primary.opacity(0.8))
                                        
                                        Text("$\(item.price, specifier: "%.2f")")
                                            .font(.instrumentSans(size: 13, weight: .medium))
                                            .foregroundColor(logoColors[index % max(1, logoColors.count)])
                                    }
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(colorScheme == .dark ?
                                                  logoColors[index % max(1, logoColors.count)].opacity(0.15) :
                                                  logoColors[index % max(1, logoColors.count)].opacity(0.08))
                                    )
                                }
                                
                                if receipt.items.count > 3 {
                                    HStack {
                                        Text("+\(receipt.items.count - 3) more")
                                            .font(.instrumentSans(size: 13))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.secondary.opacity(0.1))
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .frame(height: 200)
        .scaleEffect(isHovered ? 1.02 : 1)
        .opacity(isLoaded ? 1 : 0)
        .offset(y: isLoaded ? 0 : 20)
        .onAppear {
            loadLogo()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)
                .delay(Double.random(in: 0.1...0.3))) {
                isLoaded = true
            }
        }
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
    }
    
    private var primaryLogoColor: Color {
        logoColors.first ?? (colorScheme == .dark ? .white : .black)
    }
    
    private var secondaryLogoColor: Color {
        logoColors.count > 1 ? logoColors[1] : primaryLogoColor.opacity(0.7)
    }
    
    private var backgroundGradient: some ShapeStyle {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color.black.opacity(0.8),
                    Color(UIColor.systemBackground).opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color.white,
                    Color.white.opacity(0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var shadowColor: Color {
        colorScheme == .dark
        ? primaryLogoColor.opacity(0.3)
        : primaryLogoColor.opacity(0.2)
    }
    
    private func loadLogo() {
        Task {
            let (image, colors) = await LogoService.shared.fetchLogo(for: receipt.store_name)
            await MainActor.run {
                logoImage = image
                logoColors = colors
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct IconDetailView: View {
    let icon: String
    let title: String
    let detail: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.instrumentSans(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Text(detail)
                .font(.instrumentSans(size: 14, weight: .semibold))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ItemCard: View {
    let item: ReceiptItem
    let logoColors: [Color]
    let index: Int
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 40, height: 40)
                
                if let iconName = categoryIcon(for: item.category) {
                    Image(systemName: iconName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(getLogoColor(at: index % logoColors.count))
                } else {
                    Text(String(item.category.prefix(1)).uppercased())
                        .font(.spaceGrotesk(size: 18, weight: .bold))
                        .foregroundColor(getLogoColor(at: index % logoColors.count))
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.instrumentSans(size: 16, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                Text(item.category)
                    .font(.instrumentSans(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("$\(item.price, specifier: "%.2f")")
                .font(.spaceGrotesk(size: 18, weight: .bold))
                .foregroundColor(getLogoColor(at: index % logoColors.count))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white.opacity(0.7))
                .shadow(
                    color: getLogoColor(at: index % logoColors.count).opacity(isHovered ? 0.15 : 0.05),
                    radius: isHovered ? 8 : 4,
                    x: 0,
                    y: isHovered ? 4 : 2
                )
        )
        .scaleEffect(isHovered ? 1.02 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark
        ? getLogoColor(at: index % logoColors.count).opacity(0.15)
        : getLogoColor(at: index % logoColors.count).opacity(0.1)
    }
    
    private func getLogoColor(at index: Int) -> Color {
        guard index < logoColors.count, !logoColors.isEmpty else {
            return colorScheme == .dark ? .white : .black
        }
        return logoColors[index]
    }
    
    private func categoryIcon(for category: String) -> String? {
        let normalized = category.lowercased()
        if normalized.contains("food") || normalized.contains("grocery") {
            return "cart.fill"
        } else if normalized.contains("electronics") || normalized.contains("tech") {
            return "laptopcomputer"
        } else if normalized.contains("clothing") || normalized.contains("apparel") {
            return "tshirt.fill"
        } else if normalized.contains("restaurant") || normalized.contains("dining") {
            return "fork.knife"
        } else if normalized.contains("transport") || normalized.contains("travel") {
            return "car.fill"
        } else if normalized.contains("entertainment") {
            return "film.fill"
        } else if normalized.contains("health") || normalized.contains("medical") {
            return "cross.fill"
        } else {
            return nil
        }
    }
}

// Preview
#Preview {
    NavigationView {
        HistoryView()
    }
}
