//
//  ToastView.swift
//  SpendSmart
//
//  Created by SpendSmart Team on 2025-01-06.
//

import SwiftUI

// MARK: - Toast Model
struct Toast: Equatable {
    let id = UUID()
    let message: String
    let type: ToastType
    let duration: TimeInterval

    init(message: String, type: ToastType = .error, duration: TimeInterval = 4.0) {
        self.message = message
        self.type = type
        self.duration = duration
    }

    static func == (lhs: Toast, rhs: Toast) -> Bool {
        return lhs.id == rhs.id
    }
}

enum ToastType {
    case success
    case error
    case warning
    case info
    
    var color: Color {
        switch self {
        case .success:
            return .green
        case .error:
            return .red
        case .warning:
            return .orange
        case .info:
            return .blue
        }
    }
    
    var icon: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        case .warning:
            return "exclamationmark.circle.fill"
        case .info:
            return "info.circle.fill"
        }
    }
}

// MARK: - Toast View
struct ToastView: View {
    let toast: Toast
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: toast.type.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(toast.type.color)
            
            // Message
            Text(toast.message)
                .font(.instrumentSans(size: 16, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(hex: "2C2C2E") : Color.white)
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(toast.type.color.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
}

// MARK: - Toast Manager
class ToastManager: ObservableObject {
    @Published var toasts: [Toast] = []
    
    func show(_ toast: Toast) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            toasts.append(toast)
        }
        
        // Auto-dismiss after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + toast.duration) {
            self.dismiss(toast)
        }
    }
    
    func show(message: String, type: ToastType = .error, duration: TimeInterval = 4.0) {
        let toast = Toast(message: message, type: type, duration: duration)
        show(toast)
    }
    
    func dismiss(_ toast: Toast) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            toasts.removeAll { $0.id == toast.id }
        }
    }
    
    func dismissAll() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            toasts.removeAll()
        }
    }
}

// MARK: - Toast Container View
struct ToastContainer: View {
    @ObservedObject var toastManager: ToastManager
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(toastManager.toasts, id: \.id) { toast in
                ToastView(toast: toast)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                    .onTapGesture {
                        toastManager.dismiss(toast)
                    }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: toastManager.toasts)
    }
}

// MARK: - View Extension
extension View {
    func toast(toastManager: ToastManager) -> some View {
        self.overlay(
            VStack {
                ToastContainer(toastManager: toastManager)
                Spacer()
            }
            .allowsHitTesting(false),
            alignment: .top
        )
    }
}

// MARK: - Preview
struct ToastView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ToastView(toast: Toast(message: "Receipt processed successfully!", type: .success))
            ToastView(toast: Toast(message: "Error processing receipt. Please try again.", type: .error))
            ToastView(toast: Toast(message: "API rate limit exceeded. Trying backup server...", type: .warning))
            ToastView(toast: Toast(message: "Processing receipt with AI...", type: .info))
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .preferredColorScheme(.dark)
    }
}
