//
//  SettingsComponents.swift
//  SpendSmart
//
//  Enhanced settings components following UI/UX best practices:
//  - Clear labels with descriptions
//  - Visual hierarchy through grouping
//  - Icons for quick recognition
//  - Chevrons for navigation items
//

import SwiftUI

// MARK: - Settings Row

/// A standardized settings row with icon, title, description, and trailing content
struct SettingsRow<TrailingContent: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String?
    let trailingContent: () -> TrailingContent
    let action: (() -> Void)?
    
    init(
        icon: String,
        iconColor: Color = .brandVibrantBlue,
        title: String,
        description: String? = nil,
        action: (() -> Void)? = nil,
        @ViewBuilder trailingContent: @escaping () -> TrailingContent = { EmptyView() }
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.description = description
        self.action = action
        self.trailingContent = trailingContent
    }
    
    var body: some View {
        Button {
            HapticManager.shared.buttonPress()
            action?()
        } label: {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(iconColor)
                }
                
                // Title and description
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.manrope(size: 15, weight: .medium))
                        .foregroundStyle(Color.brandTextPrimary)
                    
                    if let description = description {
                        Text(description)
                            .font(.manrope(size: 12, weight: .regular))
                            .foregroundStyle(Color.brandTextSecondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // Trailing content
                trailingContent()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

// MARK: - Settings Navigation Row

/// A settings row specifically for navigation (shows chevron)
struct SettingsNavigationRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String?
    let value: String?
    let action: () -> Void
    
    init(
        icon: String,
        iconColor: Color = .brandVibrantBlue,
        title: String,
        description: String? = nil,
        value: String? = nil,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.description = description
        self.value = value
        self.action = action
    }
    
    var body: some View {
        SettingsRow(
            icon: icon,
            iconColor: iconColor,
            title: title,
            description: description,
            action: action
        ) {
            HStack(spacing: 6) {
                if let value = value {
                    Text(value)
                        .font(.manrope(size: 14, weight: .medium))
                        .foregroundStyle(Color.brandTextSecondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.brandTextTertiary)
            }
        }
    }
}

// MARK: - Settings Toggle Row

/// A settings row with a toggle switch
struct SettingsToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String?
    @Binding var isOn: Bool
    var onToggle: ((Bool) -> Void)?
    
    init(
        icon: String,
        iconColor: Color = .brandVibrantBlue,
        title: String,
        description: String? = nil,
        isOn: Binding<Bool>,
        onToggle: ((Bool) -> Void)? = nil
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.description = description
        self._isOn = isOn
        self.onToggle = onToggle
    }
    
    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(iconColor)
            }
            
            // Title and description
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.manrope(size: 15, weight: .medium))
                    .foregroundStyle(Color.brandTextPrimary)
                
                if let description = description {
                    Text(description)
                        .font(.manrope(size: 12, weight: .regular))
                        .foregroundStyle(Color.brandTextSecondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Toggle
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Color.brandVibrantBlue)
                .onChange(of: isOn) { _, newValue in
                    HapticManager.shared.selection()
                    onToggle?(newValue)
                }
        }
    }
}

// MARK: - Settings Section Header

/// Enhanced section header with optional action button
struct SettingsSectionHeader: View {
    let title: String
    var action: (() -> Void)?
    var actionTitle: String?
    
    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.manrope(size: 12, weight: .semibold))
                .foregroundStyle(Color.brandTextTertiary)
                .tracking(0.5)
            
            Spacer()
            
            if let action = action, let actionTitle = actionTitle {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.manrope(size: 12, weight: .semibold))
                        .foregroundStyle(Color.brandVibrantBlue)
                }
            }
        }
    }
}

// MARK: - Profile Header Card

/// A prominent profile header for the settings screen
struct ProfileHeaderCard: View {
    let emoji: String
    let name: String
    let email: String
    let onEditEmoji: () -> Void
    let onEditName: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Emoji avatar
            Button(action: onEditEmoji) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.brandAccentLight, Color.brandVibrantBlue.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                    
                    Text(emoji)
                        .font(.system(size: 36))
                    
                    // Edit badge
                    Circle()
                        .fill(Color.brandVibrantBlue)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: "pencil")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        )
                        .offset(x: 26, y: 26)
                }
            }
            .buttonStyle(.plain)
            
            // Name and email
            VStack(alignment: .leading, spacing: 6) {
                Button(action: onEditName) {
                    HStack(spacing: 6) {
                        Text(name)
                            .font(.manrope(size: 20, weight: .bold))
                            .foregroundStyle(Color.brandTextPrimary)
                        
                        Image(systemName: "pencil.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.brandTextTertiary)
                    }
                }
                .buttonStyle(.plain)
                
                Text(email)
                    .font(.manrope(size: 14, weight: .regular))
                    .foregroundStyle(Color.brandTextSecondary)
            }
            
            Spacer()
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
}

// MARK: - Delete Account Sheet

/// A visual warning sheet for account deletion
struct DeleteAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var confirmationText: String = ""
    @State private var isDeleting: Bool = false
    let onDelete: () -> Void
    
    private var isConfirmed: Bool {
        confirmationText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "DELETE ACCOUNT"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(Color.brandBorder)
                .frame(width: 36, height: 4)
                .padding(.top, 12)
            
            ScrollView {
                VStack(spacing: 24) {
                    // Warning icon
                    ZStack {
                        Circle()
                            .fill(Color.brandError.opacity(0.1))
                            .frame(width: 100, height: 100)
                        
                        Circle()
                            .fill(Color.brandError.opacity(0.15))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.brandError)
                    }
                    .padding(.top, 24)
                    
                    // Title
                    Text("Delete Your Account?")
                        .font(.instrumentSerifItalic(size: 28))
                        .foregroundStyle(Color.brandTextPrimary)
                    
                    // Warning message
                    VStack(spacing: 16) {
                        warningItem(
                            icon: "xmark.icloud.fill",
                            text: "All cloud receipts will be permanently deleted"
                        )
                        
                        warningItem(
                            icon: "iphone.slash",
                            text: "Local receipts on this device will be cleared"
                        )
                        
                        warningItem(
                            icon: "person.crop.circle.badge.minus",
                            text: "Your SpendSmart access will be removed"
                        )
                        
                        warningItem(
                            icon: "arrow.counterclockwise.circle",
                            text: "This action cannot be undone"
                        )
                    }
                    .padding(.horizontal, 24)
                    
                    // Subscription note
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.brandWarning)
                        
                        Text("If you have an active subscription, please cancel it in the App Store before deleting your account.")
                            .font(.manrope(size: 13, weight: .regular))
                            .foregroundStyle(Color.brandTextSecondary)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.brandWarning.opacity(0.1))
                    )
                    .padding(.horizontal, 20)
                    
                    // Confirmation input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Type DELETE ACCOUNT to confirm")
                            .font(.manrope(size: 13, weight: .semibold))
                            .foregroundStyle(Color.brandTextSecondary)
                        
                        TextField("DELETE ACCOUNT", text: $confirmationText)
                            .font(.manrope(size: 16, weight: .medium))
                            .foregroundStyle(Color.brandTextPrimary)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isConfirmed ? Color.brandError : Color.brandBorder, lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 20)
                    
                    // Buttons
                    VStack(spacing: 12) {
                        Button {
                            HapticManager.shared.destructive()
                            isDeleting = true
                            onDelete()
                        } label: {
                            HStack(spacing: 8) {
                                if isDeleting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "trash.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Delete My Account")
                                        .font(.manrope(size: 16, weight: .bold))
                                }
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(isConfirmed ? Color.brandError : Color.brandError.opacity(0.4))
                            )
                        }
                        .disabled(!isConfirmed || isDeleting)
                        
                        Button {
                            HapticManager.shared.buttonPress()
                            dismiss()
                        } label: {
                            Text("Cancel")
                                .font(.manrope(size: 16, weight: .semibold))
                                .foregroundStyle(Color.brandTextSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .background(Color.brandBackground)
    }
    
    private func warningItem(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.brandError)
                .frame(width: 24)
            
            Text(text)
                .font(.manrope(size: 14, weight: .regular))
                .foregroundStyle(Color.brandTextSecondary)
            
            Spacer()
        }
    }
}

// MARK: - Previews

#Preview("Settings Row") {
    VStack(spacing: 16) {
        SettingsNavigationRow(
            icon: "bell.badge.fill",
            iconColor: .brandWarning,
            title: "Notifications",
            description: "Spending alerts & reminders",
            action: {}
        )
        
        SettingsToggleRow(
            icon: "waveform",
            iconColor: .brandVibrantBlue,
            title: "Haptic Feedback",
            description: "Feel taps and vibrations",
            isOn: .constant(true)
        )
        
        SettingsNavigationRow(
            icon: "dollarsign.circle",
            iconColor: .brandVibrantBlue,
            title: "Currency",
            description: "Your default currency",
            value: "USD",
            action: {}
        )
    }
    .padding()
}

#Preview("Profile Header") {
    ProfileHeaderCard(
        emoji: "😊",
        name: "John Doe",
        email: "john@example.com",
        onEditEmoji: {},
        onEditName: {}
    )
    .padding()
}

#Preview("Delete Account Sheet") {
    DeleteAccountSheet(onDelete: {})
}
