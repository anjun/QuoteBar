import Foundation

public struct SymbolID: Hashable, Codable, Sendable {
    public var market: Market
    public var code: String
    public var kind: Kind
    /// EastMoney `f13` / `MktNum`. Needed so 期货合约在刷新时仍能拼出 `113.aum` 这类 secid。
    public var quoteMarket: Int?

    public enum Market: String, Codable, Sendable {
        case sh, sz, hk, us
        case qh
        case metal
    }

    public enum Kind: String, Codable, Sendable {
        case stock, etf, index, future, spot
    }

    public init(market: Market, code: String, kind: Kind, quoteMarket: Int? = nil) {
        self.market = market
        self.code = SymbolID.normalize(code, market: market)
        self.kind = kind
        self.quoteMarket = quoteMarket
    }

    public static func == (lhs: SymbolID, rhs: SymbolID) -> Bool {
        lhs.market == rhs.market && lhs.code == rhs.code && lhs.kind == rhs.kind
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(market)
        hasher.combine(code)
        hasher.combine(kind)
    }

    public var isUSIndex: Bool { market == .us && kind == .index }

    public static func shIndex(_ code: String) -> SymbolID { SymbolID(market: .sh, code: code, kind: .index) }
    public static func szIndex(_ code: String) -> SymbolID { SymbolID(market: .sz, code: code, kind: .index) }
    public static func shStock(_ code: String) -> SymbolID { SymbolID(market: .sh, code: code, kind: .stock) }
    public static func szStock(_ code: String) -> SymbolID { SymbolID(market: .sz, code: code, kind: .stock) }
    public static func shETF(_ code: String) -> SymbolID { SymbolID(market: .sh, code: code, kind: .etf) }
    public static func szETF(_ code: String) -> SymbolID { SymbolID(market: .sz, code: code, kind: .etf) }
    public static func hkStock(_ code: String) -> SymbolID { SymbolID(market: .hk, code: code, kind: .stock) }
    public static func hkIndex(_ code: String) -> SymbolID { SymbolID(market: .hk, code: code, kind: .index) }
    public static func usStock(_ code: String) -> SymbolID { SymbolID(market: .us, code: code, kind: .stock) }
    public static func usETF(_ code: String) -> SymbolID { SymbolID(market: .us, code: code, kind: .etf) }
    public static func usIndex(_ code: String) -> SymbolID { SymbolID(market: .us, code: code, kind: .index) }
    public static func metal(_ code: String) -> SymbolID {
        SymbolID(market: .metal, code: code, kind: .spot, quoteMarket: 122)
    }
    public static func future(_ code: String, quoteMarket: Int) -> SymbolID {
        SymbolID(market: .qh, code: code, kind: .future, quoteMarket: quoteMarket)
    }

    public var isFuturesOrMetal: Bool { market == .qh || market == .metal }

    public static func classify(market: Market, code: String, quoteMarket: Int? = nil) -> SymbolID {
        let normalized = normalize(code, market: market)
        if market == .metal {
            return .metal(normalized)
        }
        if market == .qh {
            return .future(normalized, quoteMarket: quoteMarket ?? 113)
        }
        if market == .us, usIndexCodes.contains(normalized) {
            return .usIndex(normalized)
        }
        if market == .hk, hkIndexCodes.contains(normalized) {
            return .hkIndex(normalized)
        }
        if market == .sh, shIndexCodes.contains(normalized) {
            return .shIndex(normalized)
        }
        if market == .sz, szIndexCodes.contains(normalized) {
            return .szIndex(normalized)
        }
        if market == .us, usETFCodes.contains(normalized) {
            return .usETF(normalized)
        }
        if isCNETF(normalized) {
            return SymbolID(market: market, code: normalized, kind: .etf)
        }
        return SymbolID(market: market, code: normalized, kind: .stock)
    }

    public var shortNameHint: String { code }

    static let usIndexCodes: Set<String> = ["NDX", "SPX", "DJI", "IXIC"]
    static let hkIndexCodes: Set<String> = ["HSI", "HSTECH", "HSCEI"]
    static let shIndexCodes: Set<String> = ["000001", "000300", "000016", "000688", "000852"]
    static let szIndexCodes: Set<String> = ["399001", "399006", "399673"]
    static let usETFCodes: Set<String> = ["SPY", "QQQ", "IWM", "VOO", "DIA"]

    static func normalize(_ code: String, market: Market) -> String {
        var value = code.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix(".") {
            value = String(value.dropFirst())
        }
        if let dot = value.firstIndex(of: ".") {
            value = String(value[..<dot])
        }
        if value.uppercased() == "DJIA" {
            return "DJI"
        }
        if market == .metal {
            return value.uppercased()
        }
        if market == .us || hkIndexCodes.contains(value.uppercased()) || usIndexCodes.contains(value.uppercased()) {
            return value.uppercased()
        }
        return value
    }

    static func isCNETF(_ code: String) -> Bool {
        guard code.count == 6, code.allSatisfy(\.isNumber) else { return false }
        let prefix = String(code.prefix(2))
        return ["51", "56", "58", "15", "16", "18"].contains(prefix)
    }
}

public enum QuoteSource: String, Codable, Sendable {
    case tencent
    case eastMoney
    case sina
    case tonghuashun
}

public struct Quote: Equatable, Sendable {
    public var symbol: SymbolID
    public var name: String
    public var last: Double
    public var change: Double
    public var changePercent: Double
    public var source: QuoteSource

    public init(symbol: SymbolID, name: String, last: Double, change: Double, changePercent: Double, source: QuoteSource) {
        self.symbol = symbol
        self.name = name
        self.last = last
        self.change = change
        self.changePercent = changePercent
        self.source = source
    }

    public var shortDisplayName: String {
        switch name {
        case "上证指数": return "上证"
        case "深证成指": return "深成"
        case "沪深300": return "沪深"
        case "恒生指数": return "恒指"
        case "恒生科技指数", "恒生科技": return "恒科"
        case "纳斯达克100", "纳斯达克": return "纳指"
        case "标普500": return "标普"
        case "道琼斯": return "道指"
        case "伦敦金现": return "伦敦金现"
        case "伦敦金（现货黄金）", "黄金/美元": return "伦敦金"
        case "伦敦银现": return "伦敦银现"
        case "伦敦银（现货白银）", "白银/美元": return "伦敦银"
        case "沪金主连", "黄金连续": return "沪金"
        case "沪银主连", "白银连续": return "沪银"
        case "COMEX黄金", "纽约黄金": return "美黄金"
        default:
            if name.count <= 4 { return name }
            return String(name.prefix(4))
        }
    }
}

public struct SearchHit: Equatable, Sendable {
    public var symbol: SymbolID
    public var name: String
    public var pinyin: String

    public init(symbol: SymbolID, name: String, pinyin: String) {
        self.symbol = symbol
        self.name = name
        self.pinyin = pinyin
    }
}
