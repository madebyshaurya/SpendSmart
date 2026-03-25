//
//  SyncConfirmationView.swift
//  SpendSmart
//
//  Created by Claude on 2026-01-19.
//
//  Shows after user subscribes to Plus, offering to sync local receipts to cloud.
//

import SwiftUI
import ConfettiSwiftUI

struct SyncConfirmationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var localStorage = LocalReceiptStorage.shared
    @StateObject private var haptics = HapticManager.shared
    
    @State private var isSyncing = false
    @State private var syncComplete = false
    @State private var syncError: String?
    @State private var syncedCount = 0
    @State private var confettiCounter = 0
    @State private var syncProgress: Double = 0
    
    var onComplete: () -> Void
    
    private var localReceiptCount: Int {
        localStorage.localReceipts.count
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.brandBackground
                    .ignoresSafeArea()
                
                if syncComplete {
                    syncCompleteView
                } else if isSyncing {
                    syncingView
                } else {
                    welcomeView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isSyncing {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Skip") {
                            haptics.buttonPress()
                            onComplete()
                            dismiss()
                        }
                        .font(.manrope(size: 16, weight: .medium))
                        .foregroundStyle(Color.brandTextSecondary)
                    }
                }
            }
            .confettiCannon(
                trigger: $confettiCounter,
                num: 50,
                colors: [.brandVibrantBlue, .brandSkyBlue, .brandSuccess, .white],
                rainHeight: 800,
                radius: 400
            )
        }
    }
    
    // MARK: - Welcome View
    
    private var welcomeView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 40)
                
                // Hero icon
                ZStack {
                    Circle()
                        .fill(LinearGradient.brandPrimary)
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48, weight: .medium))
                        .foregroundStyle(.white)
                }
                .shadow(color: Color.brandVibrantBlue.opacity(0.3), radius: 20, x: 0, y: 10)
                
                // Title
                VStack(spacing: 12) {
                    Text("Welcome to Plus!")
                        .font(.instrumentSerifItalic(size: 32))
                        .foregroundStyle(Color.brandTextPrimary)
                    
                    Text("You now have unlimited scans and cloud sync")
                        .font(.manrope(size: 16))
                        .foregroundStyle(Color.brandTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                
                // Local receipts info card
                if localReceiptCount > 0 {
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.brandWarning.opacity(0.15))
                                    .frame(width: 50, height: 50)
                                
                                Image(systemName: "iphone")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundStyle(Color.brandWarning)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(localReceiptCount) Local Receipt\(localReceiptCount == 1 ? "" : "s")")
                                    .font(.manrope(size: 18, weight: .bold))
                                    .foregroundStyle(Color.brandTextPrimary)
                                
                                Text("Saved on this device only")
                                    .font(.manrope(size: 14))
                                    .foregroundStyle(Color.brandTextSecondary)
                            }
                            
                            Spacer()
                        }
                        
                        Divider()
                        
                        // Sync explanation
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(Color.brandVibrantBlue)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Sync to Cloud")
                                    .font(.manrope(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.brandTextPrimary)
                                
                                Text("Move your local receipts to the cloud so they're backed up and accessible everywhere.")
                                    .font(.manrope(size: 13))
                                    .foregroundStyle(Color.brandTextSecondary)
                                    .lineSpacing(2)
                            }
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.brandSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.brandBorder, lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    
                    // Sync Button
                    VStack(spacing: 12) {
                        Brand3DButton(
                            title: "Sync \(localReceiptCount) Receipt\(localReceiptCount == 1 ? "" : "s") Now",
                            icon: "cloud.fill",
                            style: .primary
                        ) {
                            startSync()
                        }
                        
                        Button {
                            haptics.buttonPress()
                            onComplete()
                            dismiss()
                        } label: {
                            Text("Maybe Later")
                                .font(.manrope(size: 15, weight: .medium))
                                .foregroundStyle(Color.brandTextSecondary)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                } else {
                    // No local receipts - just show celebration
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.brandSuccess.opacity(0.15))
                                    .frame(width: 50, height: 50)
                                
                                Image(systemName: "cloud.fill")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundStyle(Color.brandSuccess)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("You're All Set!")
                                    .font(.manrope(size: 18, weight: .bold))
                                    .foregroundStyle(Color.brandTextPrimary)
                                
                                Text("All your receipts will sync to the cloud automatically")
                                    .font(.manrope(size: 14))
                                    .foregroundStyle(Color.brandTextSecondary)
                            }
                            
                            Spacer()
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.brandSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.brandBorder, lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    
                    Brand3DButton(
                        title: "Start Scanning",
                        icon: "camera.fill",
                        style: .primary
                    ) {
                        haptics.buttonPress()
                        onComplete()
                        dismiss()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                }
                
                // Features list
                VStack(spacing: 12) {
                    FeatureRow(icon: "infinity", text: "Unlimited receipt scans")
                    FeatureRow(icon: "cloud.fill", text: "Cloud backup & sync")
                    FeatureRow(icon: "iphone.and.arrow.forward", text: "Access from any device")
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                Spacer(minLength: 40)
            }
        }
    }
    
    // MARK: - Syncing View
    
    private var syncingView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Animated sync icon
            ZStack {
                Circle()
                    .fill(Color.brandAccentLight)
                    .frame(width: 100, height: 100)
                
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(Color.brandVibrantBlue)
                    .symbolEffect(.rotate)
            }
            
            VStack(spacing: 12) {
                Text("Syncing to Cloud...")
                    .font(.instrumentSerifItalic(size: 28))
                    .foregroundStyle(Color.brandTextPrimary)
                
                Text("Uploading \(syncedCount) of \(localReceiptCount) receipts")
                    .font(.manrope(size: 15))
                    .foregroundStyle(Color.brandTextSecondary)
            }
            
            // Progress bar
            VStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.brandBorder)
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient.brandPrimary)
                            .frame(width: geo.size.width * syncProgress, height: 8)
                            .animation(.easeInOut(duration: 0.3), value: syncProgress)
                    }
                }
                .frame(height: 8)
                
                Text("\(Int(syncProgress * 100))%")
                    .font(.ibmPlexMono(size: 14))
                    .foregroundStyle(Color.brandTextTertiary)
            }
            .padding(.horizontal, 60)
            
            Spacer()
        }
    }
    
    // MARK: - Sync Complete View
    
    private var syncCompleteView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Success icon
            ZStack {
                Circle()
                    .fill(Color.brandSuccess.opacity(0.15))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(Color.brandSuccess)
            }
            
            VStack(spacing: 12) {
                Text("Sync Complete!")
                    .font(.instrumentSerifItalic(size: 28))
                    .foregroundStyle(Color.brandTextPrimary)
                
                Text("\(syncedCount) receipt\(syncedCount == 1 ? "" : "s") synced to the cloud")
                    .font(.manrope(size: 15))
                    .foregroundStyle(Color.brandTextSecondary)
            }
            
            // Success card
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.brandSuccess.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Color.brandSuccess)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("All Receipts in Cloud")
                        .font(.manrope(size: 16, weight: .bold))
                        .foregroundStyle(Color.brandTextPrimary)
                    
                    Text("Backed up and accessible everywhere")
                        .font(.manrope(size: 13))
                        .foregroundStyle(Color.brandTextSecondary)
                }
                
                Spacer()
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.brandSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.brandSuccess.opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 24)
            
            Brand3DButton(
                title: "Continue",
                icon: "arrow.right",
                style: .primary
            ) {
                haptics.buttonPress()
                onComplete()
                dismiss()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            
            Spacer()
        }
    }
    
    // MARK: - Actions
    
    private func startSync() {
        haptics.buttonPress()
        isSyncing = true
        syncedCount = 0
        syncProgress = 0
        
        Task {
            do {
                let receipts = localStorage.localReceipts
                let total = receipts.count
                
                for (index, receipt) in receipts.enumerated() {
                    // Upload to Supabase
                    _ = try await SupabaseManager.shared.createReceipt(receipt)
                    
                    await MainActor.run {
                        syncedCount = index + 1
                        syncProgress = Double(index + 1) / Double(total)
                    }
                    
                    // Small delay for visual feedback
                    try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                }
                
                // Clear local receipts after successful sync
                await MainActor.run {
                    localStorage.clearAllReceipts()
                }
                
                // Success!
                haptics.ascendingSuccess()
                await MainActor.run {
                    syncComplete = true
                    confettiCounter += 1
                }
            } catch {
                haptics.error()
                await MainActor.run {
                    syncError = error.localizedDescription
                    isSyncing = false
                }
            }
        }
    }
}

// MARK: - Feature Row

private struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.brandVibrantBlue)
                .frame(width: 24)
            
            Text(text)
                .font(.manrope(size: 14, weight: .medium))
                .foregroundStyle(Color.brandTextSecondary)
            
            Spacer()
        }
    }
}

#Preview {
    SyncConfirmationView(onComplete: {})
}
