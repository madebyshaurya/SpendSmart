import SwiftUI

// MARK: - Chat Chart Response Models

/// Represents a chart returned by the AI in a chat response
struct ChatChart: Codable, Equatable {
    let type: ChartType
    let title: String?
    let data: [Double]?
    let labeledData: [LabeledDataPoint]?
    let labels: [String]?
    
    enum ChartType: String, Codable {
        case line
        case bar
        case pie
    }
    
    /// Convenience initializer for line charts
    static func line(title: String? = nil, data: [Double], labels: [String]? = nil) -> ChatChart {
        ChatChart(type: .line, title: title, data: data, labeledData: nil, labels: labels)
    }
    
    /// Convenience initializer for bar charts with labeled data
    static func bar(title: String? = nil, labeledData: [LabeledDataPoint]) -> ChatChart {
        ChatChart(type: .bar, title: title, data: nil, labeledData: labeledData, labels: nil)
    }
    
    /// Convenience initializer for bar charts with simple data and labels
    static func bar(title: String? = nil, data: [Double], labels: [String]) -> ChatChart {
        ChatChart(type: .bar, title: title, data: data, labeledData: nil, labels: labels)
    }
    
    /// Convenience initializer for pie charts
    static func pie(title: String? = nil, data: [Double], labels: [String]? = nil) -> ChatChart {
        ChatChart(type: .pie, title: title, data: data, labeledData: nil, labels: labels)
    }
    
    /// Check if this chart has valid data to display
    var hasValidData: Bool {
        if let data = data, !data.isEmpty {
            return true
        }
        if let labeledData = labeledData, !labeledData.isEmpty {
            return true
        }
        return false
    }
    
    /// Get data as doubles (either from data or labeledData)
    var dataPoints: [Double] {
        if let data = data {
            return data
        }
        if let labeledData = labeledData {
            return labeledData.map { $0.value }
        }
        return []
    }
    
    /// Get labels (either from labels or labeledData)
    var dataLabels: [String] {
        if let labels = labels {
            return labels
        }
        if let labeledData = labeledData {
            return labeledData.map { $0.label }
        }
        return []
    }
}

/// A labeled data point for bar/pie charts
struct LabeledDataPoint: Codable, Equatable {
    let label: String
    let value: Double
    
    init(label: String, value: Double) {
        self.label = label
        self.value = value
    }
}

// MARK: - Chat Response Models

/// Full response from the chat API including optional chart
struct ChatAPIResponse: Codable {
    let text: String
    let chart: ChatChart?
    
    /// Decode from API response, handling both old and new formats
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Text is always required
        self.text = try container.decode(String.self, forKey: .text)
        
        // Chart is optional
        self.chart = try container.decodeIfPresent(ChatChart.self, forKey: .chart)
    }
    
    init(text: String, chart: ChatChart? = nil) {
        self.text = text
        self.chart = chart
    }
    
    private enum CodingKeys: String, CodingKey {
        case text
        case chart
    }
}

// MARK: - Chat Message Model

/// Enhanced chat message model that can contain charts
struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: MessageRole
    let content: String
    let chart: ChatChart?
    let date: Date
    
    enum MessageRole: Equatable {
        case user
        case assistant
    }
    
    init(role: MessageRole, content: String, chart: ChatChart? = nil, date: Date = Date()) {
        self.role = role
        self.content = content
        self.chart = chart
        self.date = date
    }
    
    /// Create a user message
    static func user(_ content: String) -> ChatMessage {
        ChatMessage(role: .user, content: content)
    }
    
    /// Create an assistant message with optional chart
    static func assistant(_ content: String, chart: ChatChart? = nil) -> ChatMessage {
        ChatMessage(role: .assistant, content: content, chart: chart)
    }
    
    /// Create an error message
    static func error(_ errorMessage: String) -> ChatMessage {
        ChatMessage(role: .assistant, content: "Sorry, I encountered an error: \(errorMessage)")
    }
}

// MARK: - Sample Data for Previews

extension ChatChart {
    /// Sample line chart for previews
    static let sampleLine = ChatChart.line(
        title: "Monthly Spending",
        data: [120, 250, 180, 320, 190, 280, 220],
        labels: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    )
    
    /// Sample bar chart for previews
    static let sampleBar = ChatChart.bar(
        title: "Spending by Category",
        labeledData: [
            LabeledDataPoint(label: "Food", value: 450),
            LabeledDataPoint(label: "Transport", value: 280),
            LabeledDataPoint(label: "Shopping", value: 320),
            LabeledDataPoint(label: "Entertainment", value: 150)
        ]
    )
    
    /// Sample pie chart for previews
    static let samplePie = ChatChart.pie(
        title: "Budget Breakdown",
        data: [35, 28, 20, 12, 5],
        labels: ["Food", "Bills", "Transport", "Shopping", "Other"]
    )
}

extension ChatMessage {
    /// Sample messages for previews
    static let sampleUserMessage = ChatMessage.user("How much did I spend this month?")
    
    static let sampleAssistantMessage = ChatMessage.assistant(
        "Your total spending this month is **$1,247.32**. Here's the breakdown by day:",
        chart: .sampleLine
    )
    
    static let sampleBarChartMessage = ChatMessage.assistant(
        "Here's your spending by category this month:",
        chart: .sampleBar
    )
    
    static let samplePieChartMessage = ChatMessage.assistant(
        "Your budget breakdown looks like this:",
        chart: .samplePie
    )
}
