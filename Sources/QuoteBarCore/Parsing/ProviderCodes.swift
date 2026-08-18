import Foundation

public enum ProviderCodes {
    public static func tencentQuery(_ symbol: SymbolID) -> String {
        switch symbol.market {
        case .sh: return "sh\(symbol.code)"
        case .sz: return "sz\(symbol.code)"
        case .hk: return "hk\(symbol.code)"
        case .us: return "us\(symbol.code)"
        }
    }

    public static func eastMoneySecID(_ symbol: SymbolID) -> String {
        if symbol.kind == .index {
            switch symbol.market {
            case .sh: return "1.\(symbol.code)"
            case .sz: return "0.\(symbol.code)"
            case .hk: return "100.\(symbol.code)"
            case .us:
                let code = symbol.code == "DJI" ? "DJIA" : symbol.code
                return "100.\(code)"
            }
        }
        switch symbol.market {
        case .sh: return "1.\(symbol.code)"
        case .sz: return "0.\(symbol.code)"
        case .hk: return "116.\(symbol.code)"
        case .us:
            if symbol.code == "SPY" { return "107.SPY" }
            return "105.\(symbol.code)"
        }
    }

    public static func sinaListCode(_ symbol: SymbolID) -> String? {
        if symbol.isUSIndex { return nil }
        switch symbol.market {
        case .sh: return "sh\(symbol.code)"
        case .sz: return "sz\(symbol.code)"
        case .hk: return "rt_hk\(symbol.code)"
        case .us: return "gb_\(symbol.code.lowercased())"
        }
    }

    public static func market(fromTencentPrefix prefix: String) -> SymbolID.Market? {
        switch prefix.lowercased() {
        case "sh": return .sh
        case "sz": return .sz
        case "hk": return .hk
        case "us": return .us
        default: return nil
        }
    }

    public static func market(fromEastMoney marketNumber: Int, code: String) -> SymbolID.Market {
        switch marketNumber {
        case 1: return .sh
        case 0: return .sz
        case 116: return .hk
        case 105, 106, 107: return .us
        case 100:
            let normalized = SymbolID.normalize(code, market: .us)
            if SymbolID.hkIndexCodes.contains(normalized) { return .hk }
            return .us
        default:
            return .sh
        }
    }
}
