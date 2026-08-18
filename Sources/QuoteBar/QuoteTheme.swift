import QuoteBarCore
import SwiftUI

enum QuoteTheme {
    static let panelWidth: CGFloat = 400
    static let radius: CGFloat = 8
    static let nameWidth: CGFloat = 118
    static let priceWidth: CGFloat = 76
    static let changeWidth: CGFloat = 62
    static let percentWidth: CGFloat = 64

    static func signed(_ sign: QuoteColorSign, scheme: ColorScheme) -> Color {
        switch sign {
        case .up:
            return scheme == .dark
                ? Color(red: 1.00, green: 0.38, blue: 0.40)
                : Color(red: 0.72, green: 0.06, blue: 0.13)
        case .down:
            return scheme == .dark
                ? Color(red: 0.28, green: 0.86, blue: 0.54)
                : Color(red: 0.04, green: 0.45, blue: 0.24)
        case .flat:
            return Color.primary.opacity(0.72)
        }
    }

    static func tick(_ sign: QuoteColorSign, scheme: ColorScheme) -> Color {
        signed(sign, scheme: scheme).opacity(scheme == .dark ? 0.95 : 0.9)
    }
}

extension SymbolID.Market {
    var familyTitle: String { family.title }
}
