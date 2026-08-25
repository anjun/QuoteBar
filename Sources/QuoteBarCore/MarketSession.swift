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
        let minutes = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        switch market {
        case .sh, .sz:
            guard weekday != 1, weekday != 7 else { return .closed }
            if inRange(minutes, start: 9 * 60 + 30, end: 11 * 60 + 30)
                || inRange(minutes, start: 13 * 60, end: 15 * 60) {
                return .regular
            }
            return .closed
        case .hk:
            guard weekday != 1, weekday != 7 else { return .closed }
            if inRange(minutes, start: 9 * 60 + 30, end: 12 * 60)
                || inRange(minutes, start: 13 * 60, end: 16 * 60) {
                return .regular
            }
            return .closed
        case .us:
            guard weekday != 1, weekday != 7 else { return .closed }
            if inRange(minutes, start: 4 * 60, end: 9 * 60 + 30) { return .preMarket }
            if inRange(minutes, start: 9 * 60 + 30, end: 16 * 60) { return .regular }
            if inRange(minutes, start: 16 * 60, end: 20 * 60) { return .afterHours }
            return .closed
        case .qh:
            return domesticFuturesPhase(weekday: weekday, minutes: minutes)
        case .metal:
            return metalPhase(weekday: weekday, minutes: minutes)
        }
    }

    public static func timeZone(for market: SymbolID.Market) -> TimeZone {
        switch market {
        case .sh, .sz, .qh:
            return TimeZone(identifier: "Asia/Shanghai") ?? .current
        case .hk:
            return TimeZone(identifier: "Asia/Hong_Kong") ?? .current
        case .us, .metal:
            return TimeZone(identifier: "America/New_York") ?? .current
        }
    }

    /// 国内商品：日盘 09:00–11:30 / 13:30–15:15，夜盘 21:00–02:30；周日 21:00 开周。
    static func domesticFuturesPhase(weekday: Int, minutes: Int) -> MarketSessionPhase {
        if weekday == 1 {
            return minutes >= 21 * 60 ? .regular : .closed
        }
        if weekday == 7 {
            return inRange(minutes, start: 0, end: 2 * 60 + 30) ? .regular : .closed
        }
        if inRange(minutes, start: 0, end: 2 * 60 + 30)
            || inRange(minutes, start: 9 * 60, end: 11 * 60 + 30)
            || inRange(minutes, start: 13 * 60 + 30, end: 15 * 60 + 15)
            || minutes >= 21 * 60 {
            return .regular
        }
        return .closed
    }

    /// 伦敦金等贵金属现货：纽约时间周日 18:00 至周五 17:00，其间每日 17:00–18:00 休息。
    static func metalPhase(weekday: Int, minutes: Int) -> MarketSessionPhase {
        if weekday == 7 { return .closed }
        if weekday == 1 {
            return minutes >= 18 * 60 ? .regular : .closed
        }
        if weekday == 6 {
            return minutes < 17 * 60 ? .regular : .closed
        }
        if inRange(minutes, start: 17 * 60, end: 18 * 60) { return .closed }
        return .regular
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
