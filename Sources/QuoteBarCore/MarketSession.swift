import Foundation

public enum MarketSession {
    public static func isOpen(_ market: SymbolID.Market, at date: Date = Date()) -> Bool {
        let zone = timeZone(for: market)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let weekday = calendar.component(.weekday, from: date)
        guard weekday != 1, weekday != 7 else { return false }

        let minutes = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        switch market {
        case .sh, .sz:
            return inRange(minutes, start: 9 * 60 + 30, end: 11 * 60 + 30)
                || inRange(minutes, start: 13 * 60, end: 15 * 60)
        case .hk:
            return inRange(minutes, start: 9 * 60 + 30, end: 12 * 60)
                || inRange(minutes, start: 13 * 60, end: 16 * 60)
        case .us:
            return inRange(minutes, start: 9 * 60 + 30, end: 16 * 60)
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
