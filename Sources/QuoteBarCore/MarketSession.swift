import Foundation

public enum MarketSessionPhase: Equatable, Sendable {
    case closed
    case preMarket
    case regular
    case afterHours

    public var label: String? {
        switch self {
        case .preMarket: return "盘前"
        case .afterHours: return "盘后"
        case .regular, .closed: return nil
        }
    }
}

public enum MarketSession {
    public static func isOpen(_ market: SymbolID.Market, at date: Date = Date()) -> Bool {
        phase(market, at: date) != .closed
    }

    public static func phase(_ market: SymbolID.Market, at date: Date = Date()) -> MarketSessionPhase {
        let zone = timeZone(for: market)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let weekday = calendar.component(.weekday, from: date)
        guard weekday != 1, weekday != 7 else { return .closed }

        let minutes = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        switch market {
        case .sh, .sz:
            if inRange(minutes, start: 9 * 60 + 30, end: 11 * 60 + 30)
                || inRange(minutes, start: 13 * 60, end: 15 * 60) {
                return .regular
            }
            return .closed
        case .hk:
            if inRange(minutes, start: 9 * 60 + 30, end: 12 * 60)
                || inRange(minutes, start: 13 * 60, end: 16 * 60) {
                return .regular
            }
            return .closed
        case .us:
            if inRange(minutes, start: 4 * 60, end: 9 * 60 + 30) { return .preMarket }
            if inRange(minutes, start: 9 * 60 + 30, end: 16 * 60) { return .regular }
            if inRange(minutes, start: 16 * 60, end: 20 * 60) { return .afterHours }
            return .closed
        }
    }

    public static func timeZone(for market: SymbolID.Market) -> TimeZone {
        switch market {
        case .sh, .sz:
            return TimeZone(identifier: "Asia/Shanghai") ?? .current
        case .hk:
            return TimeZone(identifier: "Asia/Hong_Kong") ?? .current
        case .us:
            return TimeZone(identifier: "America/New_York") ?? .current
        }
    }

    /// Half-open interval [start, end) in minutes from midnight.
    static func inRange(_ minutes: Int, start: Int, end: Int) -> Bool {
        minutes >= start && minutes < end
    }
}

public enum CarouselSelection {
    public static func indices(from symbols: [SymbolID], at date: Date = Date()) -> [SymbolID] {
        symbols.filter { $0.kind == .index && MarketSession.isOpen($0.market, at: date) }
    }
}
