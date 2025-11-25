//
//  DataExportView.swift
//  SpendSmart
//
//  Created by Shaurya Gupta on 2025-01-15.
//

import SwiftUI

struct DataExportView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    @StateObject private var exportService = DataExportService.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared

    // Export configuration
    @State private var configuration = ExportConfiguration()

    // UI state
    @State private var showingFormatPicker = false
    @State private var showingDatePicker = false
    @State private var showingShareSheet = false
    @State private var exportedFileURL: URL?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""

    // Animation states
    @State private var isButtonPressed = false
    @State private var showSuccessAnimation = false
    @State private var progressOpacity: Double = 0.0

    var body: some View {
        ZStack {
            BackgroundGradientView()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Export format selection
                    formatSelectionSection

                    // Data type selection
                    dataTypeSelectionSection

                    // Date range selection
                    dateRangeSelectionSection

                    // Additional options
                    additionalOptionsSection

                    // Export button
                    exportButtonSection
                }
                .padding(.horizontal)
                .padding(.vertical, 20)
            }
        }
        .navigationTitle("Export Data")
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog("Select Export Format", isPresented: $showingFormatPicker) {
            ForEach(ExportFormat.allCases, id: \.self) { format in
                Button(format.rawValue) {
                    configuration.format = format
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportedFileURL {
                ShareSheet(activityItems: [url])
            }
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export your financial data in various formats. Choose what to include and how far back to go.")
                .font(.instrumentSans(size: 16))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Format Selection Section

    private var formatSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(title: "Export Format", icon: "doc.fill")

            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showingFormatPicker = true
                }
            }) {
                HStack {
                    // Format icon
                    Image(systemName: formatIcon(for: configuration.format))
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.blue)
                        .frame(width: 24, height: 24)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(configuration.format.rawValue)
                            .font(.instrumentSans(size: 18, weight: .medium))
                            .foregroundColor(colorScheme == .dark ? .white : .black)

                        Text(formatDescription(for: configuration.format))
                            .font(.instrumentSans(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .foregroundColor(.blue)
                        .font(.system(size: 14, weight: .medium))
                        .rotationEffect(.degrees(showingFormatPicker ? 180 : 0))
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showingFormatPicker)
            }
            .padding()
        }
        .glassCompatRect(cornerRadius: 12)
        .buttonStyle(ExportButtonStyle())
        }
    }

    // MARK: - Data Type Selection Section

    private var dataTypeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(title: "Data to Export", icon: "list.bullet.rectangle")

            VStack(spacing: 12) {
                ForEach(ExportDataType.allCases, id: \.self) { dataType in
                    dataTypeRow(dataType)
                }
            }
        }
    }

    private func dataTypeRow(_ dataType: ExportDataType) -> some View {
        let isSelected = configuration.dataTypes.contains(dataType)

        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                toggleDataType(dataType)
            }
        }) {
            HStack {
                // Data type icon
                Image(systemName: dataTypeIcon(for: dataType))
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .frame(width: 24, height: 24)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)

                VStack(alignment: .leading, spacing: 4) {
                    Text(dataType.rawValue)
                        .font(.instrumentSans(size: 16, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white : .black)

                    Text(dataType.description)
                        .font(.instrumentSans(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.blue : Color.secondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.blue)
                            .scaleEffect(isSelected ? 1.0 : 0.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                    }
                }
            }
            .padding()
        }
        .glassCompatRect(
            cornerRadius: 12,
            tint: isSelected ? .blue : nil
        )
        .buttonStyle(ExportButtonStyle())
    }

    // MARK: - Date Range Selection Section

    private var dateRangeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(title: "Date Range", icon: "calendar")

            VStack(spacing: 12) {
                ForEach(ExportDateRange.allCases, id: \.self) { range in
                    dateRangeRow(range)
                }

                if configuration.dateRange == .custom {
                    customDateRangeSection
                }
            }
        }
    }

    private func dateRangeRow(_ range: ExportDateRange) -> some View {
        let isSelected = configuration.dateRange == range

        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                configuration.dateRange = range
                if range != .custom {
                    configuration.customStartDate = nil
                    configuration.customEndDate = nil
                }
            }
        }) {
            HStack {
                // Date range icon
                Image(systemName: dateRangeIcon(for: range))
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .frame(width: 24, height: 24)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)

                Text(range.rawValue)
                    .font(.instrumentSans(size: 16, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white : .black)

                Spacer()

                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.blue : Color.secondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.blue)
                            .scaleEffect(isSelected ? 1.0 : 0.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                    }
                }
            }
            .padding()
        }
        .glassCompatRect(
            cornerRadius: 12,
            tint: isSelected ? .blue : nil
        )
        .buttonStyle(ExportButtonStyle())
    }

    private var customDateRangeSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue)

                        Text("Start Date")
                            .font(.instrumentSans(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    DatePicker("", selection: Binding(
                        get: { configuration.customStartDate ?? Date() },
                        set: { configuration.customStartDate = $0 }
                    ), displayedComponents: .date)
                    .datePickerStyle(CompactDatePickerStyle())
                    .accentColor(.blue)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "calendar.badge.minus")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue)

                        Text("End Date")
                            .font(.instrumentSans(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    DatePicker("", selection: Binding(
                        get: { configuration.customEndDate ?? Date() },
                        set: { configuration.customEndDate = $0 }
                    ), displayedComponents: .date)
                    .datePickerStyle(CompactDatePickerStyle())
                    .accentColor(.blue)
                }
            }
        }
        .padding()
        .glassCompatRect(cornerRadius: 12)
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        ))
    }

    // MARK: - Additional Options Section

    private var additionalOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(title: "Options", icon: "gearshape.fill")

            VStack(spacing: 12) {
                optionToggle(
                    title: "Convert to Preferred Currency",
                    description: "Convert all amounts to \(currencyManager.preferredCurrency)",
                    isOn: $configuration.convertCurrency
                )
            }
        }
    }

    private func optionToggle(title: String, description: String, isOn: Binding<Bool>) -> some View {
        return HStack {
            // Option icon
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(isOn.wrappedValue ? .blue : .secondary)
                .frame(width: 24, height: 24)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isOn.wrappedValue)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.instrumentSans(size: 16, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white : .black)

                Text(description)
                    .font(.instrumentSans(size: 14))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .toggleStyle(SwitchToggleStyle(tint: .blue))
        }
        .padding()
        .glassCompatRect(
            cornerRadius: 12,
            tint: isOn.wrappedValue ? .blue : nil
        )
    }

    // MARK: - Export Button Section

    private var exportButtonSection: some View {
        VStack(spacing: 16) {
            if exportService.isExporting {
                VStack(spacing: 16) {
                    // Animated progress ring
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 8)
                            .frame(width: 80, height: 80)

                        Circle()
                            .trim(from: 0, to: exportService.exportProgress)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.blue, Color.blue.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.3), value: exportService.exportProgress)

                        Text("\(Int(exportService.exportProgress * 100))%")
                            .font(.instrumentSans(size: 18, weight: .bold))
                            .foregroundColor(.blue)
                    }

                    VStack(spacing: 4) {
                        Text("Exporting your data...")
                            .font(.instrumentSans(size: 16, weight: .medium))
                            .foregroundColor(colorScheme == .dark ? .white : .black)

                        Text("This may take a moment")
                            .font(.instrumentSans(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .opacity(progressOpacity)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        progressOpacity = 1.0
                    }
                }
            } else {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isButtonPressed = true
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isButtonPressed = false
                        }
                        performExport()
                    }
                }) {
                    HStack(spacing: 12) {
                        if showSuccessAnimation {
                            Image(systemName: "checkmark")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .scaleEffect(showSuccessAnimation ? 1.2 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showSuccessAnimation)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                        }

                        Text("Export Data")
                            .font(.instrumentSans(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                }
                .glassCompatRect(cornerRadius: 16, tint: .blue, interactive: true)
                .scaleEffect(isButtonPressed ? 0.98 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isButtonPressed)
                .disabled(!isExportButtonEnabled)
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    // MARK: - Helper Properties

    private var isExportButtonEnabled: Bool {
        !configuration.dataTypes.isEmpty && !exportService.isExporting
    }

    // MARK: - Helper Methods

    private func formatDescription(for format: ExportFormat) -> String {
        switch format {
        case .csv:
            return "Comma-separated values, perfect for spreadsheets"
        case .json:
            return "Structured data format, ideal for developers"
        case .pdf:
            return "Formatted document, great for sharing and printing"
        }
    }

    private func toggleDataType(_ dataType: ExportDataType) {
        if dataType == .allData {
            // If "All Data" is selected, clear other selections and add all
            configuration.dataTypes = [.allData]
        } else {
            // Remove "All Data" if it was selected
            configuration.dataTypes.remove(.allData)

            // Toggle the selected data type
            if configuration.dataTypes.contains(dataType) {
                configuration.dataTypes.remove(dataType)
            } else {
                configuration.dataTypes.insert(dataType)
            }
        }
    }

    private func performExport() {
        // Validate configuration
        guard !configuration.dataTypes.isEmpty else {
            showAlert(title: "No Data Selected", message: "Please select at least one type of data to export.")
            return
        }

        if configuration.dateRange == .custom {
            guard let startDate = configuration.customStartDate,
                  let endDate = configuration.customEndDate,
                  startDate <= endDate else {
                showAlert(title: "Invalid Date Range", message: "Please select a valid date range.")
                return
            }
        }

        // Update target currency
        configuration.targetCurrency = currencyManager.preferredCurrency

        // Reset progress opacity for animation
        progressOpacity = 0.0

        // Perform export
        Task {
            let result = await exportService.exportData(configuration: configuration, appState: appState)

            await MainActor.run {
                switch result {
                case .success(let url):
                    // Show success animation briefly
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        showSuccessAnimation = true
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            showSuccessAnimation = false
                        }
                        exportedFileURL = url
                        showingShareSheet = true
                    }
                case .failure(let error):
                    showAlert(title: "Export Failed", message: error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Icon Helper Methods

    private func formatIcon(for format: ExportFormat) -> String {
        switch format {
        case .csv: return "tablecells"
        case .json: return "curlybraces"
        case .pdf: return "doc.richtext"
        }
    }

    private func dataTypeIcon(for dataType: ExportDataType) -> String {
        switch dataType {
        case .transactions: return "creditcard"
        case .categories: return "chart.pie"
        case .accountInfo: return "person.circle"
        case .allData: return "externaldrive.fill"
        }
    }

    private func dateRangeIcon(for range: ExportDateRange) -> String {
        switch range {
        case .last30Days: return "calendar.badge.clock"
        case .last6Months: return "calendar"
        case .lastYear: return "calendar.badge.minus"
        case .allTime: return "infinity"
        case .custom: return "calendar.badge.plus"
        }
    }

    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Custom Button Style

struct ExportButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
