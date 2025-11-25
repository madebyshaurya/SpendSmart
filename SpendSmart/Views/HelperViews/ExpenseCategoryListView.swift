import SwiftUI

struct ExpenseCategoryListView: View {
	var categoryCosts: [(category: String, total: Double)]
	@Environment(\.colorScheme) private var colorScheme
	@StateObject private var currencyManager = CurrencyManager.shared

	func iconForCategory(_ category: String) -> (name: String, color: Color) {
		switch category.lowercased() {
		case "rent", "housing":
			return ("house.fill", .red)
		case "bills", "utilities":
			return ("creditcard.fill", .blue)
		case "groceries", "food":
			return ("cart.fill", .green)
		case "internet", "wifi":
			return ("wifi", .purple)
		case "tax":
			return ("dollarsign.circle.fill", .orange)
		case "transport", "travel":
			return ("car.fill", .yellow)
		case "entertainment", "fun":
			return ("gamecontroller.fill", .pink)
		case "shopping", "clothing":
			return ("bag.fill", .cyan)
		case "health", "medical":
			return ("cross.case.fill", .mint)
		case "education", "school":
			return ("book.fill", .teal)
		case "subscriptions", "services":
			return ("person.crop.circle.fill", .indigo)
		case "dining":
			return ("fork.knife", .pink)
		case "other":
			return ("tag.fill", .gray)
		default:
			return ("tag.fill", .gray)
		}
	}

	var body: some View {
		VStack(spacing: 0) {
			ForEach(sortedCategoriesForDisplay.indices, id: \.self) { index in
				categoryRow(
					item: sortedCategoriesForDisplay[index],
					isFirst: index == 0,
					isLast: index == sortedCategoriesForDisplay.count - 1
				)
			}
		}
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
		.overlay(
			RoundedRectangle(cornerRadius: 20)
				.strokeBorder(
					LinearGradient(
						colors: [
							Color.blue.opacity(0.5),
							Color.blue.opacity(0.2)
						],
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					),
					lineWidth: 1
				)
		)
		.padding(.horizontal)
	}

	private func categoryRow(item: (category: String, total: Double), isFirst: Bool, isLast: Bool) -> some View {
		let iconInfo = iconForCategory(item.category)

		let rowContent = HStack {
			ZStack {
				RoundedRectangle(cornerRadius: 8)
					.fill(iconInfo.color.opacity(0.2))
					.frame(width: 36, height: 36)
				Image(systemName: iconInfo.name)
					.foregroundColor(iconInfo.color)
					.font(.system(size: 18))
			}
			VStack(alignment: .leading, spacing: 4) {
				Text(item.category)
					.font(.instrumentSans(size: 16, weight: .semibold))
					.foregroundColor(colorScheme == .dark ? .white : .black)
				Text("\(item.category.lowercased()) and related expenses")
					.font(.instrumentSans(size: 12))
					.foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.6))
			}
			.padding(.leading, 8)
			Spacer()
			Text(currencyManager.formatAmount(item.total, currencyCode: currencyManager.preferredCurrency))
				.font(.spaceGrotesk(size: 18, weight: .bold))
				.foregroundColor(colorScheme == .dark ? .white : .black)
		}
		.padding()
		.background(colorScheme == .dark ? Color.black.opacity(0.5) : Color.white.opacity(0.9))
		.cornerRadius(isFirst ? 20 : 0)

		return VStack(spacing: 0) {
			rowContent
			if !isLast {
				Divider()
					.padding(.horizontal)
					.background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
			}
		}
	}

	private var sortedCategoriesForDisplay: [(category: String, total: Double)] {
		var sorted = categoryCosts.sorted(by: { $0.total > $1.total })
		if let taxIndex = sorted.firstIndex(where: { $0.category.lowercased() == "tax" }) {
			let taxItem = sorted.remove(at: taxIndex)
			sorted.append(taxItem)
		}
		return sorted
	}
}


