//
//  AdvancedToastView.swift
//  SpendSmart
//
//  Created by AI Assistant on 2025-01-19.
//

import SwiftUI

/// Enhanced toast notification with better UX
struct AdvancedToastView: View {
    let message: String
    let type: ToastType
    let duration: Double
    @Binding var isShowing: Bool
    
    enum ToastType {
        case success, error, warning, info
        
        var color: Color {
            switch self {
            case .success: return .green
            case .error: return .red
            case .warning: return .orange
            case .info: return .blue
            }
        }
        
        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "xmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            }
        }
    }
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 12) {
                Image(systemName: type.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(type.color)
                
                Text(message)
                    .font(.instrumentSans(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isShowing = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(type.color.opacity(0.3), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            .padding(.horizontal, 16)
            .padding(.bottom, 100) // Above tab bar
        }
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        ))
        .onAppear {
            if duration > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isShowing = false
                    }
                }
            }
        }
    }
}

/// Enhanced toast manager for better UX
class AdvancedToastManager: ObservableObject {
    @Published var isShowing = false
    @Published var message = ""
    @Published var type: AdvancedToastView.ToastType = .info
    @Published var duration: Double = 3.0
    
    func show(_ message: String, type: AdvancedToastView.ToastType = .info, duration: Double = 3.0) {
        DispatchQueue.main.async {
            self.message = message
            self.type = type
            self.duration = duration
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                self.isShowing = true
            }
            
            // Auto-hide after duration
            if duration > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        self.isShowing = false
                    }
                }
            }
        }
    }
    
    func hide() {
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                self.isShowing = false
            }
        }
    }
}

/// View modifier for easy toast integration
struct AdvancedToastModifier: ViewModifier {
    @ObservedObject var toastManager: AdvancedToastManager
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if toastManager.isShowing {
                AdvancedToastView(
                    message: toastManager.message,
                    type: toastManager.type,
                    duration: toastManager.duration,
                    isShowing: $toastManager.isShowing
                )
                .zIndex(1000)
            }
        }
    }
}

extension View {
    func advancedToast(manager: AdvancedToastManager) -> some View {
        modifier(AdvancedToastModifier(toastManager: manager))
    }
}
