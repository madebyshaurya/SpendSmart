//
//  SkeletonView.swift
//  SpendSmart
//
//  Skeleton loading components with shimmer animation.
//  Research shows skeleton screens feel 36% faster than spinners.
//

import SwiftUI

// MARK: - Shimmer Modifier

/// Adds a shimmer animation effect to any view (for skeleton loading)
private struct SkeletonShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    let duration: Double
    let delay: Double
    
    init(duration: Double = 1.5, delay: Double = 0) {
        self.duration = duration
        self.delay = delay
    }
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0),
                            .init(color: Color.white.opacity(0.4), location: 0.3),
                            .init(color: Color.white.opacity(0.6), location: 0.5),
                            .init(color: Color.white.opacity(0.4), location: 0.7),
                            .init(color: .clear, location: 1)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (geometry.size.width * 2 * phase))
                }
                .mask(content)
            )
            .onAppear {
                withAnimation(
                    .linear(duration: duration)
                    .repeatForever(autoreverses: false)
                    .delay(delay)
                ) {
                    phase = 1
                }
            }
    }
}

extension View {
    /// Adds a shimmer loading effect
    func shimmer(duration: Double = 1.5, delay: Double = 0) -> some View {
        modifier(SkeletonShimmerModifier(duration: duration, delay: delay))
    }
}

// MARK: - Base Skeleton Shapes

/// A rectangular skeleton placeholder
struct SkeletonRect: View {
    var width: CGFloat? = nil
    var height: CGFloat = 16
    var cornerRadius: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.brandBorder.opacity(0.4))
            .frame(width: width, height: height)
                        .shimmer()
    }
}

/// A circular skeleton placeholder
struct SkeletonCircle: View {
    var size: CGFloat = 44

    var body: some View {
        Circle()
            .fill(Color.brandBorder.opacity(0.4))
            .frame(width: size, height: size)
                        .shimmer()
    }
}

/// A card-shaped skeleton placeholder
struct SkeletonCard: View {
    var height: CGFloat = 120
    
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.brandSurface)
            .frame(height: height)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.brandBorder, lineWidth: 1)
            )
            .shimmer()
    }
}

// MARK: - Dashboard Skeleton View

/// Skeleton loading state for the Dashboard view
struct DashboardSkeletonView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header skeleton
                headerSkeleton
                    .animateEntrance(index: 0)
                
                // Hero card skeleton
                heroCardSkeleton
                    .animateEntrance(index: 1)
                
                // Quick stats skeleton
                quickStatsSkeleton
                    .animateEntrance(index: 2)
                
                // Insights skeleton
                insightsSkeleton
                    .animateEntrance(index: 3)
                
                // Chart card skeleton
                chartCardSkeleton
                    .animateEntrance(index: 4)
                
                // Recent transactions skeleton
                transactionsCardSkeleton
                    .animateEntrance(index: 5)
            }
            .padding()
        }
        .background(Color.brandBackground)
    }
    
    // MARK: - Header Skeleton
    
    private var headerSkeleton: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                SkeletonRect(width: 140, height: 18)
                SkeletonRect(width: 80, height: 12)
            }
            Spacer()
            SkeletonRect(width: 100, height: 36, cornerRadius: 10)
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Hero Card Skeleton
    
    private var heroCardSkeleton: some View {
        VStack(alignment: .leading, spacing: 16) {
            SkeletonRect(width: 80, height: 14)
            
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                SkeletonRect(width: 50, height: 14)
                    .padding(.trailing, 6)
                SkeletonRect(width: 180, height: 48, cornerRadius: 12)
            }
            
            // Percentage change pill
            SkeletonRect(width: 200, height: 32, cornerRadius: 16)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.brandSurfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.brandBorder, lineWidth: 1)
                )
        )
    }
    
    // MARK: - Quick Stats Skeleton
    
    private var quickStatsSkeleton: some View {
        HStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                VStack(spacing: 8) {
                    SkeletonCircle(size: 24)
                    SkeletonRect(width: 50, height: 16)
                    SkeletonRect(width: 60, height: 11)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.brandSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.brandBorder, lineWidth: 1)
                        )
                )
            }
        }
    }
    
    // MARK: - Insights Skeleton
    
    private var insightsSkeleton: some View {
        HStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 6) {
                    SkeletonRect(width: 40, height: 11)
                    SkeletonRect(width: 70, height: 14)
                    SkeletonRect(width: 50, height: 12)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.brandSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.brandBorder, lineWidth: 1)
                        )
                )
            }
        }
    }
    
    // MARK: - Chart Card Skeleton
    
    private var chartCardSkeleton: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SkeletonRect(width: 60, height: 16)
                Spacer()
            }
            
            // Segmented picker skeleton
            SkeletonRect(height: 32, cornerRadius: 8)
            
            // Chart area skeleton
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<7, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.brandBorder.opacity(0.4))
                        .frame(height: CGFloat.random(in: 40...140))
                                                .shimmer(delay: Double(index) * 0.1)
                }
            }
            .frame(height: 150)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.brandSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.brandBorder, lineWidth: 1)
                )
        )
    }
    
    // MARK: - Transactions Card Skeleton
    
    private var transactionsCardSkeleton: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonRect(width: 140, height: 16)
            
            VStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    transactionRowSkeleton
                        .shimmer(delay: Double(index) * 0.15)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.brandSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.brandBorder, lineWidth: 1)
                )
        )
    }
    
    private var transactionRowSkeleton: some View {
        HStack(spacing: 12) {
            SkeletonCircle(size: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                SkeletonRect(width: 100, height: 14)
                SkeletonRect(width: 70, height: 12)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                SkeletonRect(width: 60, height: 14)
                SkeletonRect(width: 40, height: 11)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.brandBackground)
        )
    }
}

// MARK: - Receipt List Skeleton View

/// Skeleton loading state for the Receipts list view
struct ReceiptListSkeletonView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Results count skeleton
                HStack {
                    SkeletonRect(width: 80, height: 13)
                    Spacer()
                    SkeletonRect(width: 100, height: 12)
                }
                .padding(.horizontal)
                
                // Receipt cards
                ForEach(0..<5, id: \.self) { index in
                    receiptCardSkeleton
                        .padding(.horizontal)
                        .animateEntrance(index: index)
                }
            }
            .padding(.vertical)
        }
    }
    
    private var receiptCardSkeleton: some View {
        HStack(spacing: 14) {
            // Store logo
            SkeletonRect(width: 50, height: 50, cornerRadius: 12)
            
            // Receipt info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    SkeletonRect(width: 120, height: 15)
                    SkeletonRect(width: 40, height: 16, cornerRadius: 4)
                }
                
                HStack(spacing: 6) {
                    SkeletonRect(width: 80, height: 12)
                    SkeletonRect(width: 50, height: 12)
                }
            }
            
            Spacer()
            
            // Amount
            VStack(alignment: .trailing, spacing: 2) {
                SkeletonRect(width: 70, height: 16)
                SkeletonRect(width: 40, height: 11)
            }
            
            // Chevron
            SkeletonRect(width: 8, height: 14, cornerRadius: 2)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.brandSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.brandBorder, lineWidth: 1)
                )
        )
    }
}

// MARK: - Settings Skeleton View

/// Skeleton loading state for Settings sections
struct SettingsSkeletonView: View {
    var body: some View {
        List {
            // Profile section skeleton
            Section {
                HStack(spacing: 16) {
                    SkeletonCircle(size: 60)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        SkeletonRect(width: 120, height: 16)
                        SkeletonRect(width: 160, height: 14)
                    }
                }
                .padding(.vertical, 8)
            }
            
            // Other sections
            ForEach(0..<4, id: \.self) { sectionIndex in
                Section {
                    ForEach(0..<3, id: \.self) { rowIndex in
                        settingsRowSkeleton
                            .shimmer(delay: Double(sectionIndex * 3 + rowIndex) * 0.08)
                    }
                } header: {
                    SkeletonRect(width: 80, height: 12)
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
    
    private var settingsRowSkeleton: some View {
        HStack(spacing: 12) {
            SkeletonCircle(size: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                SkeletonRect(width: 100, height: 15)
                SkeletonRect(width: 140, height: 12)
            }
            
            Spacer()
            
            SkeletonRect(width: 8, height: 14, cornerRadius: 2)
        }
    }
}

// MARK: - Preview

#Preview("Dashboard Skeleton") {
    DashboardSkeletonView()
}

#Preview("Receipt List Skeleton") {
    ReceiptListSkeletonView()
}

#Preview("Settings Skeleton") {
    SettingsSkeletonView()
}

#Preview("Skeleton Shapes") {
    VStack(spacing: 20) {
        SkeletonRect(width: 200, height: 20)
        SkeletonCircle(size: 60)
        SkeletonCard(height: 100)
    }
    .padding()
}
