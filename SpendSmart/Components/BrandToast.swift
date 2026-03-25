//
//  BrandToast.swift
//  SpendSmart
//
//  A delightful toast notification system with animations and haptics.
//  Supports success, error, warning, and info variants.
//

import SwiftUI

// MARK: - Toast Type

enum ToastType {
    case success
    case error
    case warning
    case info
    case loading
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        case .loading: return "arrow.triangle.2.circlepath"
        }
    }
    
    var color: Color {
        switch self {
        case .success: return .brandSuccess
        case .error: return .brandError
        case .warning: return .brandWarning
        case .info: return .brandVibrantBlue
        case .loading: return .brandVibrantBlue
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .success: return .brandSuccessLight
        case .error: return .brandErrorLight
        case .warning: return .brandWarningLight
        case .info: return .brandAccentLight
        case .loading: return .brandAccentLight
        }
    }
}

// MARK: - Toast Data

struct ToastData: Equatable {
    let id = UUID()
    let type: ToastType
    let title: String
    var message: String? = nil
    var duration: Double = 3.0
    
    static func == (lhs: ToastData, rhs: ToastData) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Toast View

struct BrandToast: View {
    let toast: ToastData
    let onDismiss: () -> Void
    
    @State private var isVisible = false
    @State private var rotation: Double = 0
    
    var body: some View {
        HStack(spacing: 14) {
            // Icon with animation
            ZStack {
                Circle()
                    .fill(toast.type.color.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                if toast.type == .loading {
                    Image(systemName: toast.type.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(toast.type.color)
                        .rotationEffect(.degrees(rotation))
                        .onAppear {
                            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                                rotation = 360
                            }
                        }
                } else {
                    Image(systemName: toast.type.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(toast.type.color)
                        .symbolEffect(.bounce, value: isVisible)
                }
            }
            
            // Text content
            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title)
                    .font(.manrope(size: 15, weight: .semibold))
                    .foregroundStyle(Color.brandTextPrimary)
                
                if let message = toast.message {
                    Text(message)
                        .font(.manrope(size: 13))
                        .foregroundStyle(Color.brandTextSecondary)
                        .lineLimit(2)
                }
            }
            
            Spacer(minLength: 8)
            
            // Dismiss button
            if toast.type != .loading {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.brandTextTertiary)
                        .frame(width: 28, height: 28)
                        .background(Color.brandBorder.opacity(0.5))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.brandSurface)
                .shadow(color: Color.black.opacity(0.1), radius: 16, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(toast.type.color.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .offset(y: isVisible ? 0 : -100)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.brandBouncy) {
                isVisible = true
            }
            
            // Haptic feedback
            switch toast.type {
            case .success: HapticManager.shared.success()
            case .error: HapticManager.shared.error()
            case .warning: HapticManager.shared.warning()
            case .info, .loading: HapticManager.shared.light()
            }
            
            // Auto dismiss
            if toast.type != .loading && toast.duration > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + toast.duration) {
                    dismiss()
                }
            }
        }
        .gesture(
            DragGesture()
                .onEnded { (value: DragGesture.Value) in
                    if value.translation.height < -20 {
                        dismiss()
                    }
                }
        )
    }
    
    private func dismiss() {
        withAnimation(.brandEaseOut) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

// MARK: - Toast Manager

@MainActor
class ToastManager: ObservableObject {
    static let shared = ToastManager()
    
    @Published var currentToast: ToastData?
    
    private init() {}
    
    func show(_ toast: ToastData) {
        currentToast = toast
    }
    
    func success(_ title: String, message: String? = nil) {
        show(ToastData(type: .success, title: title, message: message))
    }
    
    func error(_ title: String, message: String? = nil) {
        show(ToastData(type: .error, title: title, message: message))
    }
    
    func warning(_ title: String, message: String? = nil) {
        show(ToastData(type: .warning, title: title, message: message))
    }
    
    func info(_ title: String, message: String? = nil) {
        show(ToastData(type: .info, title: title, message: message))
    }
    
    func loading(_ title: String, message: String? = nil) {
        show(ToastData(type: .loading, title: title, message: message, duration: 0))
    }
    
    func dismiss() {
        currentToast = nil
    }
}

// MARK: - Toast Container Modifier

struct ToastContainerModifier: ViewModifier {
    @ObservedObject var toastManager = ToastManager.shared
    
    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            
            if let toast = toastManager.currentToast {
                BrandToast(toast: toast) {
                    toastManager.dismiss()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(1000)
            }
        }
    }
}

extension View {
    /// Add toast container to view hierarchy
    func withToasts() -> some View {
        modifier(ToastContainerModifier())
    }
}

// MARK: - Inline Success Banner

struct SuccessBanner: View {
    let message: String
    var icon: String = "checkmark.circle.fill"
    @Binding var isVisible: Bool
    
    var body: some View {
        if isVisible {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce.up, value: isVisible)

                Text(message)
                    .font(.manrope(size: 15, weight: .medium))
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    withAnimation(.brandEaseOut) {
                        isVisible = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [Color.brandSuccess, Color.brandSuccessDark],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.brandSuccess.opacity(0.3), radius: 8, y: 4)
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .opacity
            ))
        }
    }
}

// MARK: - Previews

#Preview("Toasts") {
    VStack(spacing: 20) {
        BrandToast(toast: ToastData(type: .success, title: "Receipt Saved!", message: "Your receipt has been saved")) {}
        BrandToast(toast: ToastData(type: .error, title: "Upload Failed", message: "Please check your connection")) {}
        BrandToast(toast: ToastData(type: .warning, title: "Low Storage", message: "Consider upgrading to Plus")) {}
        BrandToast(toast: ToastData(type: .info, title: "Tip", message: "Swipe up to dismiss")) {}
        BrandToast(toast: ToastData(type: .loading, title: "Processing...")) {}
    }
    .padding()
    .background(Color.brandBackground)
}

#Preview("Success Banner") {
    VStack {
        SuccessBanner(message: "Receipt saved successfully!", isVisible: .constant(true))
            .padding()
        Spacer()
    }
}
