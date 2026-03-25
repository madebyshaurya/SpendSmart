import SwiftUI

struct MainTabView: View {
    @State var selectedTab: Int = 0
    @State private var previousTab: Int = 0
    @State private var showScanner = false
    @State private var showSettings = false
    @State private var showPaywallFromSettings = false

    @EnvironmentObject var appState: AppState
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var haptics = HapticManager.shared
    @AppStorage("appOpenCount") private var appOpenCount = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("", systemImage: "chart.pie", value: 0) {
                DashboardView(showSettings: $showSettings)
            }
            Tab("", systemImage: "book.pages.fill", value: 1) {
                ReceiptsView()
            }
            // Camera tab - tapping opens scanner directly
            Tab("", systemImage: "camera.fill", value: 2, role: .search) {
                // Empty view - we intercept this tap
                Color.clear
            }
            Tab("", systemImage: "map.fill", value: 3) {
                StoreMapView()
            }
            Tab("", systemImage: "bubble.left.and.bubble.right.fill", value: 4) {
                ChatView()
            }
        }
        // .tabBarMinimizeBehavior and .tabViewBottomAccessory require iOS 26
        .onChange(of: selectedTab) { oldValue, newValue in
            // Haptic on tab change
            haptics.tabTapped()

            // Intercept camera tab (value 2) - open scanner immediately
            if newValue == 2 {
                // Revert to previous tab
                selectedTab = oldValue
                // Open scanner
                showScanner = true
                haptics.cameraShutter()
            } else {
                previousTab = newValue
            }
        }
        .sheet(isPresented: $showScanner) {
            ScannerSheetView()
        }
        .onChange(of: appState.shouldLaunchScanner) { _, shouldLaunch in
            if shouldLaunch {
                showScanner = true
                appState.shouldLaunchScanner = false
            }
        }
        .sheet(isPresented: $showSettings) {
            haptics.sheetPresented()
        } content: {
            SettingsView(onUpgradeTapped: {
                // Dismiss settings first, then show paywall
                showSettings = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showPaywallFromSettings = true
                }
            })
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPaywallFromSettings) {
            PaywallView()
        }
        .onAppear {
            appOpenCount += 1
        }
    }
}

// MARK: - Scan Limit Accessory

struct ScanLimitAccessory: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var haptics = HapticManager.shared

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "camera.fill")
                .font(.system(size: 11, weight: .medium))
            Text(subscriptionManager.scansUsedText)
                .font(.manrope(size: 12, weight: .medium))
                .contentTransition(.numericText())
            Text("•")
                .foregroundStyle(.tertiary)
            Button("Upgrade") {
                haptics.buttonPress()
                subscriptionManager.presentPaywall(trigger: .settingsUpgrade)
            }
            .font(.manrope(size: 12, weight: .bold))
            .foregroundStyle(Color.brandVibrantBlue)
        }
        .foregroundStyle(Color.brandTextSecondary)
    }
}

#Preview {
    MainTabView()
}
