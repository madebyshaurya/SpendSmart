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
            .sheet(item: $selectedReceipt) { receipt in
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

struct BackgroundGradientView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var animationPhase: Double = 0
    
    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let phase = now.truncatingRemainder(dividingBy: 10) / 10
            
            Canvas { context, size in
                context.addFilter(.blur(radius: 60))
                
                let gradientColors: [Color] = colorScheme == .dark
                ? [.blue.opacity(0.2), .purple.opacity(0.2), .indigo.opacity(0.2)]
                : [.blue.opacity(0.1), .teal.opacity(0.1), .mint.opacity(0.1)]
                
                for i in 0..<3 {
                    var path = Path()
                    let centerX = size.width * 0.5 + sin(phase * .pi * 2 + Double(i) * 2) * size.width * 0.3
                    let centerY = size.height * 0.5 + cos(phase * .pi * 2 + Double(i) * 1.5) * size.height * 0.3
                    let radius = min(size.width, size.height) * 0.3
                    
                    path.addEllipse(in: CGRect(x: centerX - radius, y: centerY - radius,
                                               width: radius * 2, height: radius * 2))
                    
                    context.fill(path, with: .color(gradientColors[i]))
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct EmptyStateView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "receipt")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
                .opacity(isAnimating ? 1 : 0.5)
                .scaleEffect(isAnimating ? 1.1 : 0.9)
                .animation(
                    Animation.easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )
            
            Text("No receipts found")
                .font(.instrumentSerif(size: 24))
                .foregroundColor(.secondary)
            
            Text("Pull down to refresh or add a new receipt")
                .font(.instrumentSans(size: 16))
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white.opacity(0.7))
                .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.1),
                        radius: 10, x: 0, y: 5)
        )
        .onAppear {
            isAnimating = true
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
                .fill(
                    backgroundGradient
                )
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
            
            // Logo watermark in the background (if available)
            if let logo = logoImage {
                Image(uiImage: logo)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .opacity(0.07)
                    .blendMode(colorScheme == .dark ? .plusLighter : .multiply)
                    .position(x: 200, y: 80)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    // Logo
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
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(receipt.store_name.capitalized)
                        .font(.instrumentSans(size: 18, weight: .semibold))
                        .lineLimit(1)
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    
                    Text(receipt.receipt_name)
                        .font(.instrumentSans(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    HStack {
                        Image(systemName: "calendar")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(0.7))
                        
                        Text(formatDate(receipt.purchase_date))
                            .font(.instrumentSans(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    // Items preview
                    if !receipt.items.isEmpty {
                        HStack {
                            Text("\(receipt.items.count) item\(receipt.items.count == 1 ? "" : "s")")
                                .font(.instrumentSans(size: 12))
                                .foregroundColor(.secondary.opacity(0.8))
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(6)
                            
                            if receipt.items.count > 0 {
                                Text(receipt.items[0].name)
                                    .font(.instrumentSans(size: 12))
                                    .foregroundColor(.secondary.opacity(0.8))
                                    .lineLimit(1)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(6)
                            }
                            
                            if receipt.items.count > 1 {
                                Text("+\(receipt.items.count - 1)")
                                    .font(.instrumentSans(size: 12))
                                    .foregroundColor(.secondary.opacity(0.8))
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .frame(height: 170)
        .scaleEffect(isHovered ? 1.02 : 1)
        .opacity(isLoaded ? 1 : 0)
        .offset(y: isLoaded ? 0 : 20)
        .onAppear {
            // Staggered appearance animation
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double.random(in: 0.1...0.3))) {
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
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct ReceiptDetailView: View {
    let receipt: Receipt
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var logoImage: UIImage? = nil
    @State private var logoColors: [Color] = [.gray]
    @State private var animateContent = false
    
    var body: some View {
        ZStack {
            // Background based on logo colors
            backgroundGradient
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header with logo and store info
                    HStack(alignment: .top, spacing: 16) {
                        if let logo = logoImage {
                            Image(uiImage: logo)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(primaryLogoColor.opacity(0.2))
                                    .frame(width: 80, height: 80)
                                
                                Text(String(receipt.store_name.prefix(1)).uppercased())
                                    .font(.spaceGrotesk(size: 36, weight: .bold))
                                    .foregroundColor(primaryLogoColor)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(receipt.store_name.capitalized)
                                .font(.instrumentSerif(size: 28))
                                .bold()
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                            
                            Text(receipt.receipt_name)
                                .font(.instrumentSans(size: 16))
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(.secondary)
                                Text(receipt.purchase_date, style: .date)
                                    .font(.instrumentSans(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.bottom, 8)
                    
                    // Receipt image if available
                    if let url = URL(string: receipt.image_url),
                       receipt.image_url != "placeholder_url" {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView().frame(height: 200)
                            case .success(let image):
                                image.resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .cornerRadius(16)
                                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                            case .failure:
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.red.opacity(0.1))
                                        .frame(height: 120)
                                    
                                    VStack {
                                        Image(systemName: "exclamationmark.triangle")
                                            .font(.system(size: 24))
                                            .foregroundColor(.red.opacity(0.8))
                                        
                                        Text("Failed to load receipt image")
                                            .font(.instrumentSans(size: 14))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .transition(.opacity)
                    }
                    
                    // Summary card
                    VStack {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Total Amount")
                                    .font(.instrumentSans(size: 14))
                                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.9) : .black.opacity(0.8))
                                
                                Text("$\(receipt.total_amount, specifier: "%.2f")")
                                    .font(.spaceGrotesk(size: 32, weight: .bold))
                                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.9) : .black.opacity(0.8))
                            } 
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text("Tax")
                                    .font(.instrumentSans(size: 14))
                                    .foregroundColor(.secondary)
                                
                                Text("$\(receipt.total_tax, specifier: "%.2f")")
                                    .font(.spaceGrotesk(size: 22, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Divider()
                            .padding(.vertical, 12)
                        
                        HStack(spacing: 16) {
                            IconDetailView(
                                icon: "creditcard.fill",
                                title: "Payment",
                                detail: receipt.payment_method,
                                color: primaryLogoColor
                            )
                            
                            IconDetailView(
                                icon: "dollarsign.circle.fill",
                                title: "Currency",
                                detail: receipt.currency,
                                color: secondaryLogoColor
                            )
                            
                            if !receipt.store_address.isEmpty {
                                IconDetailView(
                                    icon: "mappin.circle.fill",
                                    title: "Location",
                                    detail: formatAddress(receipt.store_address),
                                    color: tertiaryLogoColor
                                )
                            }
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white.opacity(0.7))
                            .shadow(color: colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    )
                    .offset(y: animateContent ? 0 : 20)
                    .opacity(animateContent ? 1 : 0)
                    
                    // Items section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Items")
                            .font(.instrumentSerif(size: 24))
                            .fontWeight(.bold)
                            .padding(.bottom, 5)
                        
                        ForEach(Array(receipt.items.enumerated()), id: \.element.id) { index, item in
                            ItemCard(item: item, logoColors: logoColors, index: index)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.9)).combined(with: .offset(y: 20)),
                                    removal: .opacity.combined(with: .scale(scale: 0.9))
                                ))
                                .offset(y: animateContent ? 0 : 20)
                                .opacity(animateContent ? 1 : 0)
                                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1 + Double(index) * 0.05), value: animateContent)
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(20)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 24))
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                animateContent = true
            }
        }
    }
    
    private var backgroundGradient: some View {
        ZStack {
            Rectangle()
                .fill(colorScheme == .dark ? Color.black : Color.white)
            
            GeometryReader { geometry in
                // Adding subtle color accents based on the logo
                ForEach(0..<min(logoColors.count, 3), id: \.self) { i in
                    Circle()
                        .fill(logoColors[i].opacity(colorScheme == .dark ? 0.15 : 0.1))
                        .frame(width: geometry.size.width * 0.7)
                        .offset(
                            x: geometry.size.width * (i == 0 ? 0.4 : i == 1 ? -0.3 : 0.2),
                            y: geometry.size.height * (i == 0 ? -0.3 : i == 1 ? 0.4 : 0.1)
                        )
                        .blur(radius: 100)
                }
            }
        }
    }
    
    private var primaryLogoColor: Color {
        logoColors.first ?? (colorScheme == .dark ? .white : .black)
    }
    
    private var secondaryLogoColor: Color {
        logoColors.count > 1 ? logoColors[1] : primaryLogoColor.opacity(0.7)
    }
    
    private var tertiaryLogoColor: Color {
        logoColors.count > 2 ? logoColors[2] : secondaryLogoColor.opacity(0.8)
    }
    
    private func formatAddress(_ address: String) -> String {
        let components = address.components(separatedBy: ",")
        return components.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? address
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
            // Category icon or first letter
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
