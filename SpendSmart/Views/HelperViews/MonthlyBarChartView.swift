import SwiftUI
import Charts

struct MonthlyBarChartView: View {
	var receipts: [Receipt]
	@Environment(\.colorScheme) private var colorScheme
	@StateObject private var currencyManager = CurrencyManager.shared
	@State private var selectedIndex: Int? = nil
	@EnvironmentObject var appState: AppState

	struct MonthlyDataPoint: Identifiable {
		let id: String
		let index: Int
		let month: String
		let total: Double
		let count: Int
	}

	func receiptsByMonth() -> [(month: String, total: Double, count: Int)] {
		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "MMM"

		let calendar = Calendar.current
		let currentDate = Date()

		// Build last 8 months list in chronological order (oldest -> newest)
		let lastEightMonths: [String] = (0..<8).compactMap { offset in
			guard let date = calendar.date(byAdding: .month, value: -(7 - offset), to: currentDate) else { return nil }
			return dateFormatter.string(from: date)
		}

		var monthlyTotals: [String: Double] = Dictionary(uniqueKeysWithValues: lastEightMonths.map { ($0, 0) })
		var monthlyCounts: [String: Int] = Dictionary(uniqueKeysWithValues: lastEightMonths.map { ($0, 0) })
		let allowedMonths = Set(lastEightMonths)

		let currencyManager = CurrencyManager.shared
		let preferredCurrency = currencyManager.preferredCurrency

		for receipt in receipts {
			let monthStr = dateFormatter.string(from: receipt.purchase_date)
			guard allowedMonths.contains(monthStr) else { continue }
			let convertedAmount = currencyManager.convertAmountSync(
				receipt.actualAmountSpent,
				from: receipt.currency,
				to: preferredCurrency
			)
			monthlyTotals[monthStr, default: 0] += convertedAmount
			monthlyCounts[monthStr, default: 0] += 1
		}

		return lastEightMonths.map { month in
			(month: month, total: monthlyTotals[month] ?? 0, count: monthlyCounts[month] ?? 0)
		}
	}

	private var monthlyDataPoints: [MonthlyDataPoint] {
		let base = receiptsByMonth()
		return base.enumerated().map { idx, item in
			MonthlyDataPoint(id: item.month, index: idx, month: item.month, total: item.total, count: item.count)
		}
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			HStack {
				Text("Monthly")
					.font(.instrumentSans(size: 24))
					.foregroundColor(colorScheme == .dark ? .white : .black)
				Spacer()
			}

			let dataPoints = monthlyDataPoints
			let dataCount = dataPoints.count
			if dataCount > 0 {
				let yMax = max(dataPoints.map { $0.total }.max() ?? 0, 1)
				Chart(dataPoints) { point in
					let isSelected = (selectedIndex == nil) || (selectedIndex == point.index)
					BarMark(
						x: .value("Month", point.month),
						y: .value("Amount", point.total)
					)
					.cornerRadius(6)
					.foregroundStyle(Color.blue.gradient)
					.opacity(isSelected ? 1.0 : 0.4)
				}
				.chartYScale(domain: 0...(yMax * 1.1))
				.chartYAxis {
					AxisMarks(preset: .extended, position: .leading) { value in
						if let doubleValue = value.as(Double.self) {
							AxisGridLine()
							AxisValueLabel {
								Text(currencyAxisLabel(doubleValue))
									.font(.instrumentSans(size: 12))
									.foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.7))
							}
						}
					}
				}
				.chartXAxis {
					AxisMarks { value in
						AxisValueLabel {
							if let month = value.as(String.self) {
								Text(month)
									.font(.instrumentSans(size: 12))
									.foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.7))
							}
						}
					}
				}
				.chartOverlay { proxy in
					GeometryReader { geometry in
						let plotRect: CGRect = {
							if #available(iOS 17.0, *) {
								if let anchor = proxy.plotFrame {
									return geometry[anchor]
								} else {
									return geometry.frame(in: .local)
								}
							} else {
								return geometry[proxy.plotAreaFrame]
							}
						}()
						let plotOrigin = plotRect.origin

						ZStack(alignment: .topLeading) {
							// Animated highlight that moves to the selected bar
							if let idx = selectedIndex, dataPoints.indices.contains(idx) {
								highlightRect(idx: idx, proxy: proxy, geometry: geometry, dataPoints: dataPoints)
									.allowsHitTesting(false)
								// Gliding info card positioned above the selected bar
								let currentMonth = dataPoints[idx].month
								let xCurrent = (proxy.position(forX: currentMonth) ?? 0) + plotOrigin.x
								ChartInfoOverlayCard(
									month: currentMonth,
									amountLabel: currencyAxisLabel(dataPoints[idx].total),
									count: dataPoints[idx].count,
									onClose: { selectedIndex = nil }
								)
									.fixedSize()
									.position(x: xCurrent, y: max(0, plotOrigin.y - 20))
									.transition(.opacity)
							}

							// Transparent layer to capture taps only (no drags to avoid scroll interference)
							Rectangle()
								.fill(Color.clear)
								.contentShape(Rectangle())
								.onTapGesture { location in
									let adjustedLocation = CGPoint(
										x: location.x - plotOrigin.x,
										y: location.y - plotOrigin.y
									)
									if let (category, _): (String, Double) = proxy.value(at: adjustedLocation) {
										if let idx = dataPoints.firstIndex(where: { $0.month == category }) {
											if selectedIndex != idx { 
												selectedIndex = idx
												if appState.isHapticsEnabled {
													let impact = UIImpactFeedbackGenerator(style: .light)
													impact.impactOccurred()
												}
											}
										}
									}
								}
						}
						.animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedIndex)
					}
				}
				.frame(height: 200)
				.onTapGesture {
					selectedIndex = nil
				}
			}
		}
		.padding()
		.background(
			RoundedRectangle(cornerRadius: 20)
				.fill(colorScheme == .dark ?
						Color.black.opacity(0.5) :
						Color.white.opacity(0.9))
				.shadow(color: colorScheme == .dark ?
							Color.blue.opacity(0.2) :
							Color.black.opacity(0.1),
						radius: 8, x: 0, y: 4)
		)
		.padding(.horizontal)
	}
}

private extension MonthlyBarChartView {
	func currencyAxisLabel(_ value: Double) -> String {
		let formatted = currencyManager.formatAmount(value, currencyCode: currencyManager.preferredCurrency, compact: true)
		// Remove trailing .00 when present (e.g., CA$250.00 -> CA$250)
		if formatted.hasSuffix(".00") {
			return String(formatted.dropLast(3))
		}
		return formatted
	}

	func highlightRect(idx: Int, proxy: ChartProxy, geometry: GeometryProxy, dataPoints: [MonthlyDataPoint]) -> some View {
		let plotRect: CGRect = {
			if #available(iOS 17.0, *) {
				if let anchor = proxy.plotFrame {
					return geometry[anchor]
				} else {
					return geometry.frame(in: .local)
				}
			} else {
				return geometry[proxy.plotAreaFrame]
			}
		}()
		let plotOrigin = plotRect.origin
		let currentMonth = dataPoints[idx].month
		let xCurrent = proxy.position(forX: currentMonth) ?? 0

		var spacing: CGFloat = 24
		if idx > 0 {
			if let prevX = proxy.position(forX: dataPoints[idx - 1].month) {
				spacing = abs(xCurrent - prevX)
			}
		}
		if idx < dataPoints.count - 1 {
			if let nextX = proxy.position(forX: dataPoints[idx + 1].month) {
				spacing = min(spacing, abs(nextX - xCurrent))
			}
		}
		let highlightWidth = max(18, spacing * 0.7)

		return RoundedRectangle(cornerRadius: 10)
			.fill(Color.blue.opacity(0.18))
			.overlay(
				RoundedRectangle(cornerRadius: 10)
					.stroke(Color.blue.opacity(0.45), lineWidth: 1)
			)
			.frame(width: highlightWidth, height: plotRect.size.height)
			.position(x: xCurrent + plotOrigin.x, y: plotOrigin.y + plotRect.size.height / 2)
	}
}

private struct ChartSelectionAnnotationView: View {
	let amountLabel: String
	let count: Int

	var body: some View {
		VStack(spacing: 4) {
			Text(amountLabel)
				.font(.instrumentSans(size: 12, weight: .semibold))
				.padding(6)
				.background(Capsule().fill(Color.black.opacity(0.65)))
				.foregroundColor(.white)
			Text("\(count) receipt\(count == 1 ? "" : "s")")
				.font(.instrumentSans(size: 10))
				.foregroundColor(.secondary)
				.padding(.bottom, 6)
		}
	}
}


private struct ChartInfoOverlayCard: View {
	let month: String
	let amountLabel: String
	let count: Int
	let onClose: () -> Void

	@Environment(\.colorScheme) private var colorScheme

	var body: some View {
		HStack(alignment: .top, spacing: 10) {
			VStack(alignment: .leading, spacing: 6) {
				Text(month)
					.font(.instrumentSans(size: 12, weight: .semibold))
					.foregroundColor(colorScheme == .dark ? .white : .black)
				Text(amountLabel)
					.font(.instrumentSans(size: 16, weight: .bold))
					.foregroundColor(colorScheme == .dark ? .white : .black)
				Text("\(count) receipt\(count == 1 ? "" : "s")")
					.font(.instrumentSans(size: 12))
					.foregroundColor(.secondary)
			}
			Button(action: onClose) {
				Image(systemName: "xmark")
					.font(.system(size: 12, weight: .bold))
					.foregroundColor(.secondary)
			}
		}
		.padding(10)
		.background(
			RoundedRectangle(cornerRadius: 12)
				.fill(colorScheme == .dark ? Color.black.opacity(0.75) : Color.white)
		)
		.overlay(
			RoundedRectangle(cornerRadius: 12)
				.stroke(Color.blue.opacity(0.3), lineWidth: 1)
		)
		.shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
	}
}


