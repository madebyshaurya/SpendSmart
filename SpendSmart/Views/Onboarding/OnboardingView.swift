//
//  OnboardingView.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-05-01.
//

import SwiftUI

struct OnboardingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appState: AppState

    // Onboarding state
    @State private var showCurrencySelection = false

    // Currency selection
    @StateObject private var currencyManager = CurrencyManager.shared
    @State private var selectedCurrency = CurrencyManager.shared.preferredCurrency
    @State private var searchText = ""

    // Filtered currencies based on search
    private var filteredCurrencies: [CurrencyManager.CurrencyInfo] {
        if searchText.isEmpty {
            return currencyManager.supportedCurrencies
        } else {
            return currencyManager.searchCurrencies(query: searchText)
        }
    }

    var body: some View {
        ZStack {
            // Background
            BackgroundGradientView()

            VStack(spacing: 0) {
                // Header
                Text("SpendSmart")
                    .font(.instrumentSerifItalic(size: 42))
                    .bold()
                    .foregroundColor(colorScheme == .dark ? .white : Color(hex: "1E293B"))
                    .padding(.top, 60)
                    .padding(.bottom, 20)

                if showCurrencySelection {
                    // Currency selection screen
                    currencySelectionView
                } else {
                    // Feature overview screen
                    featureOverviewView
                }

                Spacer()

                // Navigation
                if showCurrencySelection {
                    // Complete button
                    Button {
                        // Save currency preference
                        currencyManager.preferredCurrency = selectedCurrency

                        // Complete onboarding
                        completeOnboarding()
                    } label: {
                        Text("Get Started")
                            .font(.instrumentSans(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue)
                            )
                            .padding(.horizontal, 40)
                    }
                    .padding(.bottom, 30)
                } else {
                    // Continue to currency selection button
                    Button {
                        withAnimation {
                            showCurrencySelection = true
                        }
                    } label: {
                        Text("Continue")
                            .font(.instrumentSans(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue)
                            )
                            .padding(.horizontal, 40)
                    }
                    .padding(.bottom, 30)
                }
            }
        }
    }

    // Feature overview view
    private var featureOverviewView: some View {
        VStack(spacing: 30) {
            // App icon
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .padding()
                .background(
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 150, height: 150)
                )

            // Title
            Text("Welcome to SpendSmart")
                .font(.instrumentSans(size: 28, weight: .semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Features description
            VStack(alignment: .leading, spacing: 16) {
                OnboardingFeatureRow(icon: "chart.bar.fill", title: "Track Your Spending", description: "Monitor your expenses and understand your spending habits with intuitive visualizations.")

                OnboardingFeatureRow(icon: "doc.text.viewfinder", title: "Manage Receipts", description: "Capture and organize receipts in one place for easy access and reference.")

                OnboardingFeatureRow(icon: "map.fill", title: "Spending Map", description: "Visualize where your money goes with an interactive map of your purchase locations.")
            }
            .padding(.horizontal, 30)

            Spacer()
        }
        .transition(.opacity)
    }

    // Currency selection view
    private var currencySelectionView: some View {
        VStack(spacing: 20) {
            Text("Select Your Currency")
                .font(.instrumentSans(size: 24, weight: .semibold))
                .padding(.bottom, 5)

            Text("Choose the currency you use most often")
                .font(.instrumentSans(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 10)

            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search currencies", text: $searchText)
                    .font(.instrumentSans(size: 16))

                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white.opacity(0.8))
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            )
            .padding(.horizontal, 20)

            // Currency list
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredCurrencies, id: \.code) { currencyInfo in
                        currencyListItem(currencyInfo)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.top, 10)
        }
        .transition(.opacity)
    }

    // Currency list item
    private func currencyListItem(_ currencyInfo: CurrencyManager.CurrencyInfo) -> some View {
        Button(action: {
            selectedCurrency = currencyInfo.code
        }) {
            HStack {
                // Currency code and symbol
                HStack(spacing: 8) {
                    Text(currencyInfo.code)
                        .font(.instrumentSans(size: 16, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white : .black)

                    Text(currencyInfo.symbol)
                        .font(.instrumentSans(size: 16))
                        .foregroundColor(.secondary)
                }
                .frame(width: 80, alignment: .leading)

                // Currency name
                Text(currencyInfo.name)
                    .font(.instrumentSans(size: 16))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.8))
                    .lineLimit(1)

                Spacer()

                // Selection indicator
                if selectedCurrency == currencyInfo.code {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 20))
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selectedCurrency == currencyInfo.code ?
                          (colorScheme == .dark ? Color.blue.opacity(0.2) : Color.blue.opacity(0.1)) :
                          Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // Complete onboarding
    private func completeOnboarding() {
        // Save onboarding completion status
        UserDefaults.standard.set(true, forKey: "isOnboardingComplete")

        // Update app state
        withAnimation {
            appState.isOnboardingComplete = true
        }
    }
}

// Feature row component for onboarding
struct OnboardingFeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.instrumentSans(size: 18, weight: .medium))

                Text(description)
                    .font(.instrumentSans(size: 14))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
            .environmentObject(AppState())
    }
}
