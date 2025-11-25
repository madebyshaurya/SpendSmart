//
//  EditReceiptComponents.swift
//  SpendSmart
//
//  Modular components for EditReceiptView to eliminate type ambiguity
//

import SwiftUI

// MARK: - Form Section Container
struct ReceiptFormSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.instrumentSans(size: 20, weight: .semibold))
                .foregroundColor(.primary)
            
            VStack(spacing: 14) {
                content
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

// MARK: - Item Row Component
struct ItemRowView: View {
    let item: ReceiptItem
    let currency: String
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name.isEmpty ? "Untitled Item" : item.name)
                    .font(.instrumentSans(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(item.category)
                    .font(.instrumentSans(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(CurrencyManager.shared.formatAmount(item.price, currencyCode: currency))
                .font(.instrumentSans(size: 16, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .onTapGesture(perform: onTap)
        .contextMenu {
            Button("Delete", role: .destructive, action: onDelete)
        }
    }
}

// MARK: - Add Item Button
struct AddItemButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Label("Add Item", systemImage: "plus.circle.fill")
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
        }
    }
}

// MARK: - Items List Component
struct ReceiptItemsList: View {
    @Binding var items: [ReceiptItem]
    let currency: String
    let onItemTap: (ReceiptItem) -> Void
    let onItemDelete: (Int) -> Void
    let onAddItem: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                ItemRowView(
                    item: item,
                    currency: currency,
                    onTap: { onItemTap(item) },
                    onDelete: { onItemDelete(index) }
                )
            }
            
            AddItemButton(action: onAddItem)
        }
    }
}