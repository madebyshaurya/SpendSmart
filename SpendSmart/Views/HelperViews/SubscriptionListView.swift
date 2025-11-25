import SwiftUI

struct SubscriptionListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var currencyManager = CurrencyManager.shared
    @StateObject private var subscriptionService = SubscriptionService.shared
    @State private var showingAddSheet = false
    @Environment(\.colorScheme) private var colorScheme
    @State private var isSyncing = false
    @State private var animateCards = false
    @State private var selectedSubscription: Subscription?
    @Namespace private var subscriptionsNamespace

    // Toast manager removed for now due to compilation issues


    private enum Filter { case all, active, trials, paused }
    @State private var selectedFilter: Filter = .all
    @State private var searchText: String = ""
    private enum SortOption { case nextRenewal, amount, name }
    @State private var sortOption: SortOption = .nextRenewal
    @State private var isMultiSelectMode = false
    @State private var selectedSubscriptions: Set<UUID> = []

    var body: some View {
        ZStack {
            BackgroundGradientView()

            VStack(spacing: 0) {
                // Title with improved spacing
                Text("Subscriptions")
                    .font(.instrumentSerifItalic(size: 36))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                
                totals
                    .opacity(animateCards ? 1 : 0)
                    .offset(y: animateCards ? 0 : 20)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateCards)
                
                controls
                    .opacity(animateCards ? 1 : 0)
                    .offset(y: animateCards ? 0 : 20)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: animateCards)
                
                if subscriptionService.subscriptions.isEmpty {
                    VStack(spacing: 32) {
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 120, height: 120)
                                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                                
                                Image(systemName: "calendar.badge.plus")
                                    .font(.system(size: 40, weight: .light))
                                    .foregroundColor(.blue)
                            }
                            
                            VStack(spacing: 8) {
                                Text("Ready to Track")
                                    .font(.instrumentSans(size: 24, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Text("Add subscriptions to monitor your recurring expenses")
                                    .font(.instrumentSans(size: 16))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                        }
                        
                        // Prominent Add Subscription Button
                        Button {
                            hapticFeedback(.medium)
                            showingAddSheet = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.white)
                                
                                Text("Add Subscription")
                                    .font(.instrumentSans(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .padding(.vertical, 16)
                            .padding(.horizontal, 40)
                        }
                        .buttonStyle(.glassProminent)
                        .scaleEffect(showingAddSheet ? 1.05 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: showingAddSheet)
                    }
                    .padding(.horizontal)
                    .padding(.top, 60)
                    .opacity(animateCards ? 1 : 0)
                    .scaleEffect(animateCards ? 1 : 0.8)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: animateCards)
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 16) {
                            ForEach(Array(sortedFilteredSubscriptions.enumerated()), id: \.element.id) { index, sub in
                                SubscriptionRow(
                                    subscription: sub,
                                    isMultiSelectMode: isMultiSelectMode,
                                    isSelected: selectedSubscriptions.contains(sub.id),
                                    onToggleSelection: { subscriptionId in
                                        hapticFeedback(.light)
                                        if selectedSubscriptions.contains(subscriptionId) {
                                            selectedSubscriptions.remove(subscriptionId)
                                        } else {
                                            selectedSubscriptions.insert(subscriptionId)
                                        }
                                    },
                                    onEdit: { subscription in
                                        selectedSubscription = subscription
                                    },
                                    onDelete: { subscriptionId in
                                        hapticFeedback(.medium)
                                        if appState.useLocalStorage {
                                            subscriptionService.delete(id: subscriptionId)
                                        } else {
                                            Task { try? await BackendAPIService.shared.deleteSubscription(id: subscriptionId); await MainActor.run { subscriptionService.delete(id: subscriptionId) } }
                                        }
                                    },
                                    onTogglePause: { subscription in
                                        hapticFeedback(.light)
                                        var updated = subscription
                                        updated.is_active.toggle()
                                        if appState.useLocalStorage {
                                            subscriptionService.upsert(updated)
                                        } else {
                                            Task { let _ = try? await BackendAPIService.shared.upsertSubscription(updated); await MainActor.run { subscriptionService.upsert(updated) } }
                                        }
                                    }
                                )
                                .opacity(animateCards ? 1 : 0)
                                .offset(x: animateCards ? 0 : -50)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(index) * 0.06), value: animateCards)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                        .padding(.bottom, 80)
                        .refreshable {
                            guard !appState.useLocalStorage else { return }
                            await BackendAPIService.shared.syncAuthTokenFromSupabase()
                            do {
                                let cloud = try await BackendAPIService.shared.fetchSubscriptions()
                                await MainActor.run { subscriptionService.overwrite(with: cloud) }
                            } catch { }
                        }
                    }
                }
            }
            
            // Floating Add Button (only when subscriptions exist)
            if !subscriptionService.subscriptions.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            print("➕ [SubscriptionListView] Add subscription button tapped")
                            hapticFeedback(.medium)
                            showingAddSheet = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                                
                                Text("Add Subscription")
                                    .font(.instrumentSans(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 24)
                        }
                        .buttonStyle(.glassProminent)
                        .scaleEffect(showingAddSheet ? 1.05 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: showingAddSheet)
                        Spacer()
                    }
                    .padding(.bottom, 20)
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if !subscriptionService.subscriptions.isEmpty {
                    Button {
                        hapticFeedback(.light)
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            isMultiSelectMode.toggle()
                            if !isMultiSelectMode {
                                selectedSubscriptions.removeAll()
                            }
                        }
                    } label: {
                        Image(systemName: isMultiSelectMode ? "checkmark.circle.fill" : "checkmark.circle")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(isMultiSelectMode ? .green : .blue)
                            .glassCompatRect(cornerRadius: 8)
                    }
                }
            }
            // Sorting moved next to search; no trailing toolbar item needed
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    if isMultiSelectMode && !selectedSubscriptions.isEmpty {
                        Button {
                            hapticFeedback(.medium)
                            // Delete selected subscriptions
                            for subscriptionId in selectedSubscriptions {
                                if appState.useLocalStorage {
                                    subscriptionService.delete(id: subscriptionId)
                                } else {
                                    Task {
                                        do {
                                            print("🗑️ [SubscriptionListView] Deleting subscription from backend: \(subscriptionId)")
                                            // Ensure we have fresh auth token
                                            await BackendAPIService.shared.syncAuthTokenFromSupabase()
                                            try await BackendAPIService.shared.deleteSubscription(id: subscriptionId)
                                            print("✅ [SubscriptionListView] Successfully deleted subscription from backend")
                                            await MainActor.run { subscriptionService.delete(id: subscriptionId) }
                                        } catch {
                                            print("❌ [SubscriptionListView] Failed to delete subscription from backend: \(error)")
                                            print("💾 [SubscriptionListView] Deleting locally as fallback")
                                            await MainActor.run { subscriptionService.delete(id: subscriptionId) }
                                        }
                                    }
                                }
                            }
                            selectedSubscriptions.removeAll()
                            isMultiSelectMode = false
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.red)
                                .glassCompatRect(cornerRadius: 8)
                        }
                    }
                    

                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddEditSubscriptionView { newSub in
                hapticSuccess()
                if appState.useLocalStorage {
                    subscriptionService.upsert(newSub)
                } else {
                    Task {
                        isSyncing = true
                        defer { isSyncing = false }
                        do {
                            print("🔄 [SubscriptionListView] Attempting to save subscription to backend...")
                            print("📝 [SubscriptionListView] Subscription: \(newSub.name) - \(newSub.service_name)")
                            
                            // Ensure we have fresh auth token
                            await BackendAPIService.shared.syncAuthTokenFromSupabase()
                            
                            let saved = try await BackendAPIService.shared.upsertSubscription(newSub)
                            print("✅ [SubscriptionListView] Successfully saved subscription to backend")
                            await MainActor.run { 
                                subscriptionService.upsert(saved)
                                // Success notification would go here
                            }
                        } catch {
                            print("❌ [SubscriptionListView] Failed to save subscription to backend: \(error)")
                            print("💾 [SubscriptionListView] Saving locally as fallback")
                            await MainActor.run { subscriptionService.upsert(newSub) }
                            
                            // Show error to user
                            await MainActor.run {
                                // Error notification would go here  
                                print("⚠️ [SubscriptionListView] Subscription saved locally only due to sync error")
                            }
                        }
                    }
                }
            }
            .environmentObject(appState)
        }
        .sheet(item: Binding<Subscription?>(
            get: { selectedSubscription },
            set: { selectedSubscription = $0 }
        )) { subscription in
            AddEditSubscriptionView(
                onSave: { updatedSubscription in
                    hapticSuccess()
                    if appState.useLocalStorage {
                        subscriptionService.upsert(updatedSubscription)
                    } else {
                        Task {
                            isSyncing = true
                            defer { isSyncing = false }
                            do {
                                print("🔄 [SubscriptionListView] Attempting to update subscription in backend...")
                                print("📝 [SubscriptionListView] Subscription: \(updatedSubscription.name) - \(updatedSubscription.service_name)")
                                
                                // Ensure we have fresh auth token
                                await BackendAPIService.shared.syncAuthTokenFromSupabase()
                                
                                let saved = try await BackendAPIService.shared.upsertSubscription(updatedSubscription)
                                print("✅ [SubscriptionListView] Successfully updated subscription in backend")
                                await MainActor.run { subscriptionService.upsert(saved) }
                            } catch {
                                print("❌ [SubscriptionListView] Failed to update subscription in backend: \(error)")
                                print("💾 [SubscriptionListView] Saving locally as fallback")
                                await MainActor.run { subscriptionService.upsert(updatedSubscription) }
                            }
                        }
                    }
                    selectedSubscription = nil
                },
                editing: subscription
            )
            .environmentObject(appState)
        }

        // Toast integration removed for now
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animateCards = true
            }
        }
        .task {
            await SubscriptionService.shared.requestNotificationPermission()
            if !appState.useLocalStorage {
                // Test backend connection and authentication
                let (isConnected, isAuthenticated, error) = await BackendAPIService.shared.testBackendConnection()
                print("🔍 [SubscriptionListView] Backend status - Connected: \(isConnected), Authenticated: \(isAuthenticated)")
                if let error = error {
                    print("❌ [SubscriptionListView] Backend connection issue: \(error)")
                }
                
                // Removed debug authentication check - using production auth flow
                
                // Ensure our backend has the freshest Supabase auth token
                await BackendAPIService.shared.syncAuthTokenFromSupabase()
                do {
                    let cloud = try await BackendAPIService.shared.fetchSubscriptions()
                    await MainActor.run { subscriptionService.overwrite(with: cloud) }
                    print("✅ [SubscriptionListView] Successfully synced \(cloud.count) subscriptions from backend")
                } catch { 
                    print("❌ [SubscriptionListView] Failed to sync subscriptions from backend: \(error)")
                    /* ignore, keep local */ 
                }
            }
        }
    }
    
    private var controls: some View {
        VStack(spacing: 16) {
            // Search bar with sorting beside it
            HStack(spacing: 12) {
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.blue)
                        .font(.system(size: 16, weight: .medium))
                    TextField("Search subscriptions...", text: $searchText)
                        .font(.instrumentSans(size: 16))
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                    if !searchText.isEmpty {
                        Button {
                            hapticFeedback(.light)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { searchText = "" }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 16))
                        }
                    }
                }
                .padding(14)
                .glassCompatRect(cornerRadius: 14)
                
                // Sort menu (moved next to search)
                Menu {
                    Button {
                        hapticFeedback(.light)
                        sortOption = .nextRenewal
                    } label: {
                        Label("Next Renewal", systemImage: sortOption == .nextRenewal ? "checkmark" : "calendar")
                    }
                    Button {
                        hapticFeedback(.light)
                        sortOption = .amount
                    } label: {
                        Label("Amount", systemImage: sortOption == .amount ? "checkmark" : "dollarsign.circle")
                    }
                    Button {
                        hapticFeedback(.light)
                        sortOption = .name
                    } label: {
                        Label("Name", systemImage: sortOption == .name ? "checkmark" : "textformat")
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.blue)
                        .padding(6)
                }
            }
            .padding(.horizontal)
            
            // Filter chips below search
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    filterChip(title: "All", color: .blue, filter: .all, count: subscriptionService.subscriptions.count)
                    filterChip(title: "Active", color: .green, filter: .active, count: subscriptionService.subscriptions.filter { $0.is_active }.count)
                    filterChip(title: "Trials", color: .orange, filter: .trials, count: subscriptionService.subscriptions.filter { $0.is_trial }.count)
                    filterChip(title: "Paused", color: .purple, filter: .paused, count: subscriptionService.subscriptions.filter { !$0.is_active }.count)
                }
                .padding(.horizontal)
            }
        }
        .padding(.top, 8)
    }

    private func filterChip(title: String, color: Color, filter: Filter, count: Int) -> some View {
        let isSelected = selectedFilter == filter
        return Button {
            hapticFeedback(.light)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { selectedFilter = filter }
        } label: {
            HStack(spacing: 6) {
                Text(title)
                    .font(.instrumentSans(size: 14, weight: isSelected ? .semibold : .medium))
                Text("\(count)")
                    .font(.instrumentSans(size: 12, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .glassCompatCapsule(tint: isSelected ? color : nil, interactive: isSelected)
    }
    
    private var filteredSubscriptions: [Subscription] {
        var subs = subscriptionService.subscriptions
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty {
            subs = subs.filter { s in
                s.service_name.localizedCaseInsensitiveContains(q) || s.name.localizedCaseInsensitiveContains(q)
            }
        }
        switch selectedFilter {
        case .all: break
        case .active:
            subs = subs.filter { $0.is_active }
        case .trials:
            subs = subs.filter { $0.is_trial }
        case .paused:
            subs = subs.filter { !$0.is_active }
        }
        return subs
    }

    private var sortedFilteredSubscriptions: [Subscription] {
        let subs = filteredSubscriptions
        switch sortOption {
        case .nextRenewal:
            return subs.sorted { $0.next_renewal_date < $1.next_renewal_date }
        case .amount:
            return subs.sorted {
                let a = SubscriptionService.proratedMonthlyAmount(for: $0)
                let b = SubscriptionService.proratedMonthlyAmount(for: $1)
                let aConv = currencyManager.convertAmountSync(a, from: $0.currency, to: currencyManager.preferredCurrency)
                let bConv = currencyManager.convertAmountSync(b, from: $1.currency, to: currencyManager.preferredCurrency)
                return aConv > bConv
            }
        case .name:
            return subs.sorted {
                let n0 = $0.name.isEmpty ? $0.service_name : $0.name
                let n1 = $1.name.isEmpty ? $1.service_name : $1.name
                return n0.localizedCaseInsensitiveCompare(n1) == .orderedAscending
            }
        }
    }
    
    private func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard appState.isHapticsEnabled else { return }
        let impact = UIImpactFeedbackGenerator(style: style)
        impact.impactOccurred()
    }
    
    private func hapticSuccess() {
        guard appState.isHapticsEnabled else { return }
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)
    }

    private var header: some View {
        HStack {
            Text("Subscriptions")
                .font(.instrumentSans(size: 28, weight: .semibold))
                .foregroundColor(colorScheme == .dark ? .white : .black)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var totals: some View {
        let monthly = subscriptionService.monthlyCost(inPreferredCurrency: currencyManager.preferredCurrency, converter: currencyManager.convertAmountSync)
        let yearly = subscriptionService.yearlyCost(inPreferredCurrency: currencyManager.preferredCurrency, converter: currencyManager.convertAmountSync)
        let isTintedGlassActive: Bool
        if #available(iOS 26.0, *) {
            isTintedGlassActive = true
        } else {
            isTintedGlassActive = false
        }

        return HStack(spacing: 16) {
            // Monthly card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isTintedGlassActive ? .white.opacity(0.85) : .blue)
                    Text("Monthly")
                        .font(.instrumentSans(size: 14, weight: .medium))
                        .foregroundColor(isTintedGlassActive ? .white.opacity(0.75) : .secondary)
                }
                
                Text(currencyManager.formatAmount(monthly, currencyCode: currencyManager.preferredCurrency))
                    .font(.spaceGrotesk(size: 26, weight: .bold))
                    .foregroundColor(isTintedGlassActive ? .white : .blue)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCompatRect(cornerRadius: 16, tint: .blue)

            // Yearly card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isTintedGlassActive ? .white.opacity(0.85) : .green)
                    Text("Yearly")
                        .font(.instrumentSans(size: 14, weight: .medium))
                        .foregroundColor(isTintedGlassActive ? .white.opacity(0.75) : .secondary)
                }
                
                Text(currencyManager.formatAmount(yearly, currencyCode: currencyManager.preferredCurrency))
                    .font(.spaceGrotesk(size: 26, weight: .bold))
                    .foregroundColor(isTintedGlassActive ? .white : .green)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCompatRect(cornerRadius: 16, tint: .green)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

private struct SubscriptionRow: View {
    let subscription: Subscription
    let isMultiSelectMode: Bool
    let isSelected: Bool
    let onToggleSelection: (UUID) -> Void
    let onEdit: (Subscription) -> Void
    let onDelete: (UUID) -> Void
    let onTogglePause: (Subscription) -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var currencyManager = CurrencyManager.shared
    @State private var isPressed = false
    @State private var showPulse = false
    @State private var progress: CGFloat = 0

    var body: some View {
        ZStack {
            // Main content
            HStack(spacing: 16) {
                // Multi-select checkbox
                if isMultiSelectMode {
                    Button(action: {
                        onToggleSelection(subscription.id)
                    }) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(isSelected ? .blue : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                // Logo with animated renewal ring and pulse for trials
                ZStack {
                    RenewalProgressRing(progress: progress, colors: tintColors(for: subscription.service_name))
                        .frame(width: 60, height: 60)
                        .opacity(0.9)
                    LogoView(name: subscription.service_name, url: subscription.logo_url)
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .shadow(color: tintColors(for: subscription.service_name).first?.opacity(0.25) ?? .blue.opacity(0.25), radius: 8, x: 0, y: 4)
                    
                    if subscription.is_trial {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                            .offset(x: 18, y: -18)
                            .scaleEffect(showPulse ? 1.2 : 1.0)
                            .opacity(showPulse ? 0.7 : 1.0)
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: showPulse)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(subscription.name.isEmpty ? subscription.service_name : subscription.name)
                            .font(.instrumentSans(size: 18, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .layoutPriority(1)
                        
                        if subscription.is_trial {
                            Text("TRIAL")
                                .font(.instrumentSans(size: 10, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(LinearGradient(colors: [Color.orange.opacity(0.8), Color.orange.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                )
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(currencyManager.formatAmount(subscription.amount, currencyCode: subscription.currency))
                                .font(.spaceGrotesk(size: 18, weight: .bold))
                                .foregroundColor(.blue)
                                .lineLimit(1)
                                .minimumScaleFactor(0.9)
                            
                            Text(subscription.billing_cycle.rawValue.capitalized)
                                .font(.instrumentSans(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Text("Renews: \(formatDate(subscription.next_renewal_date))")
                                .font(.instrumentSans(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        if !subscription.is_active {
                            HStack(spacing: 4) {
                                Image(systemName: "pause.circle")
                                    .font(.system(size: 12))
                                    .foregroundColor(.orange)
                                Text("Paused")
                                    .font(.instrumentSans(size: 12))
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .glassCompatRect(cornerRadius: 16)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            .onTapGesture {
                if !isMultiSelectMode {
                    onEdit(subscription)
                }
            }
            .contextMenu {
                Button(action: {
                    hapticFeedback(.light)
                    onEdit(subscription)
                }) {
                    Label("Edit", systemImage: "pencil")
                }
                
                Button(action: {
                    hapticFeedback(.light)
                    onTogglePause(subscription)
                }) {
                    Label(subscription.is_active ? "Pause" : "Resume", 
                          systemImage: subscription.is_active ? "pause.circle" : "play.circle")
                }
                
                if subscription.is_trial {
                    Button(action: {
                        hapticFeedback(.light)
                        // Convert trial to regular subscription
                        var updated = subscription
                        updated.is_trial = false
                        updated.trial_end_date = nil
                        onTogglePause(updated) // Reuse the toggle function to update
                    }) {
                        Label("Convert to Regular", systemImage: "star.slash")
                    }
                }
                
                Divider()
                
                Button(role: .destructive, action: {
                    hapticFeedback(.medium)
                    onDelete(subscription.id)
                }) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .onAppear {
            if subscription.is_trial {
                showPulse = true
            }
            // Compute and animate renewal progress
            let p = renewalProgress(for: subscription)
            withAnimation(.spring(response: 0.8, dampingFraction: 0.9)) {
                progress = CGFloat(p)
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        return df.string(from: date)
    }

    private func renewalProgress(for sub: Subscription) -> Double {
        let now = Date()
        let daysTotal: Double
        switch sub.billing_cycle {
        case .weekly: daysTotal = 7
        case .monthly: daysTotal = 30
        case .quarterly: daysTotal = 90
        case .semiannual: daysTotal = 180
        case .annual: daysTotal = 365
        case .custom:
            let interval = max(1, sub.interval_count ?? 1)
            daysTotal = Double(interval * 30)
        }
        let daysRemaining = max(0, Calendar.current.dateComponents([.day], from: now, to: sub.next_renewal_date).day ?? 0)
        let progress = 1.0 - min(1.0, max(0.0, Double(daysRemaining) / daysTotal))
        return progress
    }
    
    private func tintColors(for name: String) -> [Color] {
        // Deterministic gradient colors based on service name hash
        let base = abs(name.hashValue)
        let r = Double((base % 256)) / 255.0
        let g = Double((base / 3 % 256)) / 255.0
        let b = Double((base / 7 % 256)) / 255.0
        let c1 = Color(red: r, green: g, blue: b).opacity(0.9)
        let c2 = Color(red: min(1, r + 0.2), green: min(1, g + 0.2), blue: min(1, b + 0.2)).opacity(0.9)
        return [c1, c2]
    }
    
    private func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let impactFeedback = UIImpactFeedbackGenerator(style: style)
        impactFeedback.impactOccurred()
    }
    

}

private struct LogoView: View {
    let name: String
    let url: String?
    var body: some View {
        ZStack {
            if let url = url, let remote = URL(string: url) {
                CustomAsyncImage(url: remote) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    placeholder
                }
            } else {
                placeholder
            }
        }
        .background(Color.gray.opacity(0.15))
    }

    private var placeholder: some View {
        ZStack {
            Color.gray.opacity(0.15)
            Text(String(name.prefix(1)).uppercased())
                .font(.spaceGrotesk(size: 20, weight: .bold))
                .foregroundColor(.secondary)
        }
    }
}

private struct RenewalProgressRing: View {
    var progress: CGFloat
    var colors: [Color] = [Color.blue, Color.purple]
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 5)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(gradient: Gradient(colors: colors), center: .center, startAngle: .degrees(0), endAngle: .degrees(360))
                    , style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: colors.first?.opacity(0.25) ?? .blue.opacity(0.25), radius: 4, x: 0, y: 0)
        }
        .animation(.spring(response: 0.8, dampingFraction: 0.9), value: progress)
    }
}
