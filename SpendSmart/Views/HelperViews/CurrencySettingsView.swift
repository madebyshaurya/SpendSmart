//
//  CurrencySettingsView.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-05-01.
//

import SwiftUI

struct CurrencySettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @StateObject private var currencyManager = CurrencyManager.shared
    @State private var selectedCurrency: String {
        didSet {
            // Auto-save when currency changes
            currencyManager.preferredCurrency = selectedCurrency
        }
    }
    @State private var showPreview = true
    @State private var searchText: String = ""
    @State private var isSearching: Bool = false
    @State private var showRefreshAlert: Bool = false
    @State private var isRefreshing: Bool = false

    // Sample amount for preview
    private let previewAmount = 1234.56

    init() {
        // Initialize state with current preference
        _selectedCurrency = State(initialValue: CurrencyManager.shared.preferredCurrency)
    }

    var body: some View {
        ZStack {
            BackgroundGradientView()

            ScrollView {
                VStack(spacing: 24) {
                    // Header with explanation
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Currency Settings")
                            .font(.instrumentSans(size: 24, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? .white : .black)

                        Text("Select your preferred currency for displaying amounts throughout the app. Receipts in other currencies will be converted for display purposes.")
                            .font(.instrumentSans(size: 16))
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal)

                    // Preview section
                    if showPreview {
                        previewCard
                    }

                    // Currency selection
                    currencySelectionSection
                }
                .padding(.vertical)
            }
            .navigationTitle("Currency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.instrumentSans(size: 16, weight: .medium))
                    .foregroundColor(.blue)
                }
            }
        }
        .alert(isPresented: $showRefreshAlert) {
            Alert(
                title: Text("Exchange Rates Updated"),
                message: Text(currencyManager.conversionError == nil ?
                              "Exchange rates have been refreshed successfully." :
                              "Could not refresh exchange rates. Using cached rates."),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // Preview card showing how the selected currency will look
    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preview")
                .font(.instrumentSans(size: 18, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white : .black)

            VStack(spacing: 12) {
                // Preview of a receipt total
                HStack {
                    Text("Receipt Total")
                        .font(.instrumentSans(size: 16))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))

                    Spacer()

                    Text(currencyManager.formatAmount(previewAmount, currencyCode: selectedCurrency))
                        .font(.spaceGrotesk(size: 20, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                }

                Divider()

                // Preview of savings
                HStack {
                    Text("Savings")
                        .font(.instrumentSans(size: 16))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))

                    Spacer()

                    Text(currencyManager.formatAmount(previewAmount * 0.15, currencyCode: selectedCurrency))
                        .font(.spaceGrotesk(size: 20, weight: .bold))
                        .foregroundColor(.green)
                }

                Divider()

                // Preview of a negative amount
                HStack {
                    Text("Refund")
                        .font(.instrumentSans(size: 16))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))

                    Spacer()

                    Text(currencyManager.formatAmount(-previewAmount * 0.5, currencyCode: selectedCurrency))
                        .font(.spaceGrotesk(size: 20, weight: .bold))
                        .foregroundColor(.red)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(colorScheme == .dark ? Color.black.opacity(0.5) : Color.white.opacity(0.9))
                    .shadow(color: colorScheme == .dark ? Color.blue.opacity(0.2) : Color.black.opacity(0.1),
                            radius: 8, x: 0, y: 4)
            )
        }
        .padding(.horizontal)
    }

    // Currency selection section
    private var currencySelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Select Currency")
                    .font(.instrumentSans(size: 18, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white : .black)

                Spacer()

                // Refresh button
                Button {
                    refreshExchangeRates()
                } label: {
                    HStack(spacing: 4) {
                        Text("Refresh Rates")
                            .font(.instrumentSans(size: 14))

                        Image(systemName: isRefreshing ? "arrow.triangle.2.circlepath.circle.fill" : "arrow.triangle.2.circlepath.circle")
                            .rotationEffect(Angle(degrees: isRefreshing ? 360 : 0))
                            .animation(isRefreshing ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                    }
                    .foregroundColor(.blue)
                }
                .disabled(isRefreshing)
            }
            .padding(.horizontal)

            // Search bar with improved functionality
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search currencies", text: $searchText)
                    .font(.instrumentSans(size: 16))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onChange(of: searchText) { oldValue, newValue in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isSearching = !newValue.isEmpty
                        }
                    }
                    .onSubmit {
                        // If there's exactly one search result, select it automatically
                        let results = currencyManager.searchCurrencies(query: searchText)
                        if results.count == 1 {
                            selectedCurrency = results[0].code
                            searchText = ""
                            isSearching = false
                        }
                    }

                if !searchText.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            searchText = ""
                            isSearching = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .transition(.opacity)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray5).opacity(0.5))
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
            .padding(.horizontal)

            // Recently used currencies section
            if !currencyManager.recentCurrencies.isEmpty && !isSearching {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recently Used")
                        .font(.instrumentSans(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(currencyManager.recentCurrencies, id: \.self) { code in
                                if let currency = currencyManager.getCurrencyInfo(for: code) {
                                    recentCurrencyButton(currency)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }

            // All currencies or search results in a list view
            VStack(alignment: .leading, spacing: 8) {
                let filteredCurrencies = isSearching ?
                    currencyManager.searchCurrencies(query: searchText) :
                    currencyManager.supportedCurrencies

                if filteredCurrencies.isEmpty {
                    Text("No currencies found")
                        .font(.instrumentSans(size: 16))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    // Group currencies by region if not searching
                    if !isSearching {
                        currencyListByRegion(currencies: filteredCurrencies)
                    } else {
                        // When searching, show a flat list
                        ForEach(filteredCurrencies, id: \.code) { currency in
                            currencyListItem(currency)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // Individual currency selection button
    private func currencyButton(_ currency: CurrencyManager.CurrencyInfo) -> some View {
        Button(action: {
            selectedCurrency = currency.code
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(currency.code)
                        .font(.instrumentSans(size: 16, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white : .black)

                    Text(currency.name)
                        .font(.instrumentSans(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if selectedCurrency == currency.code {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 20))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedCurrency == currency.code ?
                          (colorScheme == .dark ? Color.blue.opacity(0.2) : Color.blue.opacity(0.1)) :
                          (colorScheme == .dark ? Color.black.opacity(0.3) : Color.white.opacity(0.7)))
                    .shadow(color: selectedCurrency == currency.code ?
                            Color.blue.opacity(0.3) : Color.black.opacity(0.05),
                            radius: 4, x: 0, y: 2)
            )
        }
    }

    // Recent currency button (more compact)
    private func recentCurrencyButton(_ currency: CurrencyManager.CurrencyInfo) -> some View {
        Button(action: {
            selectedCurrency = currency.code
        }) {
            HStack(spacing: 6) {
                Text(currency.code)
                    .font(.instrumentSans(size: 14, weight: .medium))

                Text(currency.symbol)
                    .font(.instrumentSans(size: 14))
                    .foregroundColor(.secondary)

                if selectedCurrency == currency.code {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedCurrency == currency.code ?
                          (colorScheme == .dark ? Color.blue.opacity(0.2) : Color.blue.opacity(0.1)) :
                          (colorScheme == .dark ? Color.black.opacity(0.3) : Color.white.opacity(0.7)))
                    .shadow(color: selectedCurrency == currency.code ?
                            Color.blue.opacity(0.3) : Color.black.opacity(0.05),
                            radius: 4, x: 0, y: 2)
            )
        }
    }

    // Currency list item (more compact than the button)
    private func currencyListItem(_ currency: CurrencyManager.CurrencyInfo) -> some View {
        Button(action: {
            selectedCurrency = currency.code
        }) {
            HStack {
                // Currency code and symbol
                HStack(spacing: 8) {
                    Text(currency.code)
                        .font(.instrumentSans(size: 16, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white : .black)

                    Text(currency.symbol)
                        .font(.instrumentSans(size: 16))
                        .foregroundColor(.secondary)
                }
                .frame(width: 80, alignment: .leading)

                // Currency name
                Text(currency.name)
                    .font(.instrumentSans(size: 16))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
                    .lineLimit(1)

                Spacer()

                // Example format
                Text(currency.exampleFormat)
                    .font(.instrumentSans(size: 14))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)

                // Selection indicator
                if selectedCurrency == currency.code {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 18))
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selectedCurrency == currency.code ?
                          (colorScheme == .dark ? Color.blue.opacity(0.15) : Color.blue.opacity(0.08)) :
                          (colorScheme == .dark ? Color.black.opacity(0.2) : Color.white.opacity(0.6)))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // Group currencies by region
    private func currencyListByRegion(currencies: [CurrencyManager.CurrencyInfo]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Major currencies section
            currencySection(
                title: "Major Currencies",
                currencies: currencies.filter {
                    ["USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF"].contains($0.code)
                }
            )

            // Asian currencies section
            currencySection(
                title: "Asian Currencies",
                currencies: currencies.filter {
                    ["CNY", "HKD", "SGD", "INR", "KRW", "MYR", "THB", "IDR", "PHP", "TWD"].contains($0.code)
                }
            )

            // European currencies section
            currencySection(
                title: "European Currencies",
                currencies: currencies.filter {
                    ["SEK", "NOK", "DKK", "PLN", "CZK", "HUF", "RON", "BGN", "HRK", "RUB", "TRY"].contains($0.code)
                }
            )

            // Americas section
            currencySection(
                title: "Americas",
                currencies: currencies.filter {
                    ["BRL", "MXN", "ARS", "CLP", "COP", "PEN"].contains($0.code)
                }
            )

            // Oceania section
            currencySection(
                title: "Oceania",
                currencies: currencies.filter {
                    ["NZD", "FJD"].contains($0.code)
                }
            )

            // Middle East & Africa section
            currencySection(
                title: "Middle East & Africa",
                currencies: currencies.filter {
                    ["AED", "SAR", "ILS", "EGP", "ZAR", "NGN", "KES"].contains($0.code)
                }
            )
        }
    }

    // Currency section with title and list of currencies
    private func currencySection(title: String, currencies: [CurrencyManager.CurrencyInfo]) -> some View {
        if currencies.isEmpty {
            return AnyView(EmptyView())
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.instrumentSans(size: 16, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.9) : .black.opacity(0.9))
                    .padding(.top, 8)

                VStack(spacing: 6) {
                    ForEach(currencies, id: \.code) { currency in
                        currencyListItem(currency)
                    }
                }
            }
        )
    }

    // Function to refresh exchange rates
    private func refreshExchangeRates() {
        // Set loading state
        isRefreshing = true

        // Refresh rates asynchronously
        Task {
            await currencyManager.refreshExchangeRates()

            // Update UI on main thread
            await MainActor.run {
                isRefreshing = false
                showRefreshAlert = true
            }
        }
    }
}

#Preview {
    NavigationView {
        CurrencySettingsView()
    }
}
