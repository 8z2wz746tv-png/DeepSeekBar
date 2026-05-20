import SwiftUI

enum AppTheme {
    // MARK: - Core colors
    static let primary = Color.accentColor
    static let background = Color(nsColor: .controlBackgroundColor)
    static let secondaryBackground = Color(nsColor: .quaternaryLabelColor).opacity(0.08)
    static let cardBackground = Color(nsColor: .textBackgroundColor)
    static let border = Color(nsColor: .separatorColor)
    static let secondaryText = Color(nsColor: .secondaryLabelColor)
    static let primaryText = Color(nsColor: .labelColor)

    // MARK: - Model colors
    static func modelColor(for index: Int) -> Color {
        let colors: [Color] = [.blue, .purple, .orange, .green, .pink, .teal, .mint, .indigo]
        return colors[index % colors.count]
    }

    // MARK: - Sizes
    static let panelWidth: CGFloat = 390
    static let panelHeight: CGFloat = 540
    static let cornerRadius: CGFloat = 10
    static let cardCornerRadius: CGFloat = 8
    static let chartHeight: CGFloat = 200

}
