//
//  MapSearchBar.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-05-01.
//

import SwiftUI

struct MapSearchBar: View {
    @Binding var searchText: String
    @Binding var isSearching: Bool
    @Binding var showFilters: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)

                TextField("Search stores...", text: $searchText)
                    .font(.instrumentSans(size: 16))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .onChange(of: searchText) { _, newValue in
                        isSearching = !newValue.isEmpty
                    }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        isSearching = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .transition(.opacity)
                    .animation(.easeInOut, value: searchText)
                }
            }
            .padding(10)
            .background(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.1) : Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

struct MapFilterView: View {
    @Binding var priceRange: ClosedRange<Double>
    @Binding var selectedTimeFrame: StoreLocationManager.TimeFrame
    @Binding var selectedCategory: String?
    @Binding var showListView: Bool
    var availableCategories: [String]
    var maxPrice: Double
    var onFilterApplied: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var currencyManager = CurrencyManager.shared

    var body: some View {
        VStack(spacing: 16) {
            // Price range slider
            VStack(alignment: .leading, spacing: 8) {
                Text("Price Range")
                    .font(.instrumentSans(size: 16, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white : .black)

                HStack {
                    Text(currencyManager.formatAmount(priceRange.lowerBound, currencyCode: currencyManager.preferredCurrency))
                        .font(.instrumentSans(size: 14))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(currencyManager.formatAmount(priceRange.upperBound, currencyCode: currencyManager.preferredCurrency))
                        .font(.instrumentSans(size: 14))
                        .foregroundColor(.secondary)
                }

                RangeSlider(value: $priceRange, in: 0...maxPrice)
                    .frame(height: 30)
            }
            .padding(.horizontal, 16)

            Divider()

            // Time frame selector
            VStack(alignment: .leading, spacing: 8) {
                Text("Time Period")
                    .font(.instrumentSans(size: 16, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white : .black)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(StoreLocationManager.TimeFrame.allCases) { timeFrame in
                            Button {
                                selectedTimeFrame = timeFrame
                            } label: {
                                Text(timeFrame.rawValue)
                                    .font(.instrumentSans(size: 14))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(selectedTimeFrame == timeFrame ? Color.blue : (colorScheme == .dark ? Color.black.opacity(0.3) : Color.gray.opacity(0.1)))
                                    )
                                    .foregroundColor(selectedTimeFrame == timeFrame ? .white : (colorScheme == .dark ? .white : .black))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            if !availableCategories.isEmpty {
                Divider()

                // Category selector
                VStack(alignment: .leading, spacing: 8) {
                    Text("Categories")
                        .font(.instrumentSans(size: 16, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white : .black)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            // "All" option
                            Button {
                                selectedCategory = nil
                            } label: {
                                Text("All Categories")
                                    .font(.instrumentSans(size: 14))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(selectedCategory == nil ? Color.green : (colorScheme == .dark ? Color.black.opacity(0.3) : Color.gray.opacity(0.1)))
                                    )
                                    .foregroundColor(selectedCategory == nil ? .white : (colorScheme == .dark ? .white : .black))
                            }

                            // Category options
                            ForEach(availableCategories, id: \.self) { category in
                                Button {
                                    selectedCategory = category
                                } label: {
                                    Text(category)
                                        .font(.instrumentSans(size: 14))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(selectedCategory == category ? Color.green : (colorScheme == .dark ? Color.black.opacity(0.3) : Color.gray.opacity(0.1)))
                                        )
                                        .foregroundColor(selectedCategory == category ? .white : (colorScheme == .dark ? .white : .black))
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }

            Divider()

            // View toggle
            HStack {
                Button {
                    showListView = false
                } label: {
                    HStack {
                        Image(systemName: "map")
                            .font(.system(size: 16))
                        Text("Map View")
                            .font(.instrumentSans(size: 14))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(!showListView ? Color.blue : (colorScheme == .dark ? Color.black.opacity(0.3) : Color.gray.opacity(0.1)))
                    )
                    .foregroundColor(!showListView ? .white : (colorScheme == .dark ? .white : .black))
                }

                Button {
                    showListView = true
                } label: {
                    HStack {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 16))
                        Text("List View")
                            .font(.instrumentSans(size: 14))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(showListView ? Color.blue : (colorScheme == .dark ? Color.black.opacity(0.3) : Color.gray.opacity(0.1)))
                    )
                    .foregroundColor(showListView ? .white : (colorScheme == .dark ? .white : .black))
                }

                Spacer()

                Button {
                    onFilterApplied()
                } label: {
                    Text("Apply")
                        .font(.instrumentSans(size: 14, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.blue)
                        )
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
        .background(colorScheme == .dark ? Color.black.opacity(0.7) : Color.white.opacity(0.9))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}
