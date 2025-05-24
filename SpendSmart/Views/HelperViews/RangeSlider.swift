//
//  RangeSlider.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-05-01.
//

import SwiftUI

struct RangeSlider: View {
    @Binding var value: ClosedRange<Double>
    let bounds: ClosedRange<Double>
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var isDraggingMin = false
    @State private var isDraggingMax = false
    
    init(value: Binding<ClosedRange<Double>>, in bounds: ClosedRange<Double>) {
        self._value = value
        self.bounds = bounds
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 2)
                    .fill(colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2))
                    .frame(height: 4)
                
                // Selected range
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue)
                    .frame(width: width(for: value.upperBound, in: geometry) - width(for: value.lowerBound, in: geometry), height: 4)
                    .offset(x: width(for: value.lowerBound, in: geometry))
                
                // Lower thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: 24, height: 24)
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                    .offset(x: width(for: value.lowerBound, in: geometry) - 12)
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                isDraggingMin = true
                                let newValue = valueFrom(dragLocation: gesture.location.x, in: geometry)
                                if newValue < value.upperBound {
                                    value = newValue...value.upperBound
                                }
                            }
                            .onEnded { _ in
                                isDraggingMin = false
                            }
                    )
                    .scaleEffect(isDraggingMin ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDraggingMin)
                
                // Upper thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: 24, height: 24)
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                    .offset(x: width(for: value.upperBound, in: geometry) - 12)
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                isDraggingMax = true
                                let newValue = valueFrom(dragLocation: gesture.location.x, in: geometry)
                                if newValue > value.lowerBound {
                                    value = value.lowerBound...newValue
                                }
                            }
                            .onEnded { _ in
                                isDraggingMax = false
                            }
                    )
                    .scaleEffect(isDraggingMax ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDraggingMax)
            }
            .frame(height: 24)
            .padding(.horizontal, 12)
        }
    }
    
    private func width(for value: Double, in geometry: GeometryProxy) -> CGFloat {
        let availableWidth = geometry.size.width - 24 // Accounting for padding
        let range = bounds.upperBound - bounds.lowerBound
        let normalizedValue = (value - bounds.lowerBound) / range
        return CGFloat(normalizedValue) * availableWidth
    }
    
    private func valueFrom(dragLocation: CGFloat, in geometry: GeometryProxy) -> Double {
        let availableWidth = geometry.size.width - 24 // Accounting for padding
        let normalizedValue = max(0, min(1, dragLocation / availableWidth))
        let range = bounds.upperBound - bounds.lowerBound
        return bounds.lowerBound + (Double(normalizedValue) * range)
    }
}

struct StoreListView: View {
    var locations: [StoreLocation]
    var onSelectLocation: (StoreLocation) -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var currencyManager = CurrencyManager.shared
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(locations) { location in
                    storeListItem(location)
                        .onTapGesture {
                            onSelectLocation(location)
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(colorScheme == .dark ? Color.black.opacity(0.7) : Color.white.opacity(0.9))
    }
    
    private func storeListItem(_ location: StoreLocation) -> some View {
        HStack(spacing: 12) {
            // Store initial or logo
            Circle()
                .fill(location.markerTint.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(location.name.prefix(1)))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(location.markerTint)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(location.name)
                    .font(.instrumentSans(size: 16, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .lineLimit(1)
                
                Text(location.address.components(separatedBy: ",").first ?? "")
                    .font(.instrumentSans(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(currencyManager.formatAmount(location.totalSpent, currencyCode: currencyManager.preferredCurrency, compact: true))
                    .font(.instrumentSans(size: 16, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .lineLimit(1)
                
                Text("\(location.visitCount) visits")
                    .font(.instrumentSans(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}
