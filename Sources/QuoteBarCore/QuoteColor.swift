import Foundation

public enum QuoteColorSign: Equatable, Sendable {
    case up
    case down
    case flat

    public static func of(change: Double) -> QuoteColorSign {
        if change > 0 { return .up }
        if change < 0 { return .down }
        return .flat
    }

    public static func of(changePercent: Double) -> QuoteColorSign {
        of(change: changePercent)
    }
}
