import Foundation

public enum ProviderCodes {
    public static func tencentQuery(_ symbol: SymbolID) -> String {
        switch symbol.market {
        case .sh: return "sh\(symbol.code)"
        case .sz: return "sz\(symbol.code)"
        case .hk: return "hk\(symbol.code)"
        case .us: return "us\(symbol.code)"
        case .metal: return "hf_\(symbol.code)"
        case .crypto: return "crypto_\(symbol.code)"
        case .qh:
            if let hf = internationalHFCode[symbol.code.uppercased()] {
                return "hf_\(hf)"
            }
            if let hf = internationalHFCode.first(where: { $0.value == symbol.code.uppercased() })?.value {
                return "hf_\(hf)"
            }
            return "hf_\(symbol.code)"
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
            case .qh, .metal, .crypto:
                break
            }
        }
        switch symbol.market {
        case .sh: return "1.\(symbol.code)"
        case .sz: return "0.\(symbol.code)"
        case .hk: return "116.\(symbol.code)"
        case .us:
            if symbol.code == "SPY" { return "107.SPY" }
            return "105.\(symbol.code)"
        case .metal:
            return "\(symbol.quoteMarket ?? 122).\(symbol.code)"
        case .qh:
            let marketNo = symbol.quoteMarket ?? quoteMarket(forFuturesCode: symbol.code) ?? 113
            return "\(marketNo).\(symbol.code)"
        case .crypto:
            return "crypto.\(symbol.code)"
        }
    }

    public static func sinaListCode(_ symbol: SymbolID, phase: MarketSessionPhase = .regular) -> String? {
        if symbol.market == .us, symbol.kind == .index {
            switch (symbol.code, phase) {
            case ("NDX", .preMarket): return "gb_qmi"
            case ("NDX", .afterHours): return "gb_qiv"
            case ("SPX", .preMarket), ("SPX", .afterHours): return "hf_ES"
            case ("DJI", .preMarket), ("DJI", .afterHours): return "hf_YM"
            default: return nil
            }
        }
        switch symbol.market {
        case .sh: return "sh\(symbol.code)"
        case .sz: return "sz\(symbol.code)"
        case .hk: return "rt_hk\(symbol.code)"
        case .us: return "gb_\(symbol.code.lowercased())"
        case .metal:
            if tonghuashunTimeCode(symbol) != nil { return nil }
            return "hf_\(symbol.code)"
        case .qh:
            if let hf = internationalHFCode[symbol.code.uppercased()] {
                return "hf_\(hf)"
            }
            if let hf = internationalHFCode.first(where: { $0.value == symbol.code.uppercased() })?.value {
                return "hf_\(hf)"
            }
            if let nf = sinaNFCode(for: symbol.code) {
                return "nf_\(nf)"
            }
            return nil
        case .crypto:
            return nil
        }
    }

    public static func binanceSymbol(_ symbol: SymbolID) -> String? {
        guard symbol.market == .crypto else { return nil }
        return "\(symbol.code.uppercased())USDT"
    }

    public static func gateCurrencyPair(_ symbol: SymbolID) -> String? {
        guard symbol.market == .crypto else { return nil }
        return "\(symbol.code.uppercased())_USDT"
    }

    public static func cryptoCode(fromBinanceSymbol raw: String) -> String? {
        CryptoCatalog.normalizeTicker(raw)
    }

    public static func cryptoCode(fromGatePair raw: String) -> String? {
        CryptoCatalog.normalizeTicker(raw)
    }

    /// 同花顺分时代码，如伦敦金现 `218_AUUSDO`。没有对应页则返回 nil。
    public static func tonghuashunTimeCode(_ symbol: SymbolID) -> String? {
        guard symbol.market == .metal else { return nil }
        let code = symbol.code.uppercased()
        if let mapped = tonghuashunMetalCodes[code] {
            return mapped
        }
        if code.hasSuffix("USDO"), code.count >= 6 {
            return "218_\(code)"
        }
        return nil
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
        if marketNumber == 122 { return .metal }
        if futuresMarketNumbers.contains(marketNumber) { return .qh }
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

    public static func symbol(fromTencentHF code: String) -> SymbolID? {
        symbol(fromInternationalHF: code)
    }

    public static func symbol(fromSinaHF code: String) -> SymbolID? {
        symbol(fromInternationalHF: code)
    }

    public static func symbol(fromSinaNF raw: String) -> SymbolID {
        let upper = raw.uppercased()
        if let mapped = nfContinuous[upper] {
            return .future(mapped.code, quoteMarket: mapped.quoteMarket)
        }
        return .future(raw, quoteMarket: quoteMarket(forFuturesCode: raw) ?? 113)
    }

    public static func quoteMarket(forFuturesCode code: String) -> Int? {
        if let known = knownQuoteMarkets[code]
            ?? knownQuoteMarkets[code.uppercased()]
            ?? knownQuoteMarkets[code.lowercased()] {
            return known
        }
        let upper = code.uppercased()
        if upper.hasSuffix("00Y") {
            let product = String(upper.dropLast(3))
            return internationalProductMarket[product] ?? 101
        }
        let product = String(code.prefix(while: \.isLetter)).lowercased()
        return domesticProductMarket[product]
    }

    static func sinaNFCode(for code: String) -> String? {
        if let mapped = nfContinuous.first(where: { $0.value.code == code || $0.value.code.lowercased() == code.lowercased() }) {
            return mapped.key
        }
        if code.last == "m" || code.last == "M", code.count >= 2 {
            return String(code.dropLast()).uppercased() + "0"
        }
        let letters = String(code.prefix(while: \.isLetter))
        let digits = String(code.dropFirst(letters.count))
        if !letters.isEmpty, digits.count == 4, digits.allSatisfy(\.isNumber) {
            return letters.uppercased() + digits
        }
        return nil
    }

    static func symbol(fromInternationalHF code: String) -> SymbolID? {
        let upper = code.uppercased()
        if let metal = metalHFCodes[upper] {
            return .metal(metal)
        }
        if let mapped = hfCanonical[upper] {
            return .future(mapped.code, quoteMarket: mapped.quoteMarket)
        }
        if let pair = internationalHFCode.first(where: { $0.value == upper }) {
            let marketNo = internationalProductMarket[upper] ?? quoteMarket(forFuturesCode: pair.key) ?? 101
            return .future(pair.key, quoteMarket: marketNo)
        }
        return nil
    }

    static let tonghuashunMetalCodes: [String: String] = [
        "AUUSDO": "218_AUUSDO",
        "AGUSDO": "218_AGUSDO",
        "PTUSDO": "218_PTUSDO",
        "PDUSDO": "218_PDUSDO",
    ]

    /// EastMoney 期货/国际盘 market number。
    static let futuresMarketNumbers: Set<Int> = [
        101, 102, 103, 104, 108, 112, 113, 114, 115, 142, 220, 225,
    ]

    /// 东财代码 / 规范代码 → 腾讯、新浪 `hf_` 后缀。
    static let internationalHFCode: [String: String] = [
        "GC00Y": "GC",
        "SI00Y": "SI",
        "CL00Y": "CL",
        "NG00Y": "NG",
        "PL00Y": "XPT",
        "PA00Y": "XPD",
        "B00Y": "OIL",
        "HG00Y": "CAD",
    ]

    static let metalHFCodes: [String: String] = [
        "XAU": "XAU",
        "XAG": "XAG",
    ]

    static let hfCanonical: [String: (code: String, quoteMarket: Int)] = [
        "GC": ("GC00Y", 101),
        "SI": ("SI00Y", 101),
        "CL": ("CL00Y", 102),
        "NG": ("NG00Y", 102),
        "XPT": ("PL00Y", 102),
        "XPD": ("PA00Y", 102),
        "OIL": ("B00Y", 112),
        "CAD": ("HG00Y", 101),
    ]

    static let nfContinuous: [String: (code: String, quoteMarket: Int)] = [
        "AU0": ("aum", 113),
        "AG0": ("agm", 113),
        "RB0": ("rbm", 113),
        "CU0": ("cum", 113),
        "FU0": ("fum", 113),
        "HC0": ("hcm", 113),
        "BU0": ("bum", 113),
        "AL0": ("alm", 113),
        "ZN0": ("znm", 113),
        "NI0": ("nim", 113),
        "SN0": ("snm", 113),
        "SS0": ("ssm", 113),
        "RU0": ("rum", 113),
        "SC0": ("scm", 142),
        "I0": ("im", 114),
        "M0": ("mm", 114),
        "C0": ("cm", 114),
        "Y0": ("ym", 114),
        "P0": ("pm", 114),
        "J0": ("jm", 114),
        "JM0": ("jmm", 114),
        "TA0": ("TAM", 115),
        "CF0": ("CFM", 115),
        "SR0": ("SRM", 115),
        "MA0": ("MAM", 115),
        "IF0": ("IFM", 220),
        "IH0": ("IHM", 220),
        "IC0": ("ICM", 220),
        "IM0": ("IMM", 220),
        "SI0": ("sim", 225),
        "LC0": ("lcm", 225),
    ]

    static let knownQuoteMarkets: [String: Int] = [
        "XAU": 122, "XAG": 122,
        "GC00Y": 101, "SI00Y": 101, "HG00Y": 101,
        "CL00Y": 102, "NG00Y": 102, "PL00Y": 102, "PA00Y": 102,
        "B00Y": 112,
        "aum": 113, "agm": 113, "rbm": 113, "cum": 113,
        "fum": 113, "hcm": 113, "bum": 113, "alm": 113, "znm": 113,
        "nim": 113, "snm": 113, "ssm": 113, "rum": 113,
        "im": 114, "mm": 114, "cm": 114, "ym": 114, "pm": 114, "jm": 114, "jmm": 114,
        "TAM": 115, "CFM": 115, "SRM": 115, "MAM": 115,
        "scm": 142,
        "IFM": 220, "IHM": 220, "ICM": 220, "IMM": 220,
        "sim": 225, "lcm": 225,
    ]

    static let internationalProductMarket: [String: Int] = [
        "GC": 101, "SI": 101, "HG": 101,
        "CL": 102, "NG": 102, "PL": 102, "PA": 102,
        "B": 112,
    ]

    static let domesticProductMarket: [String: Int] = [
        "au": 113, "ag": 113, "rb": 113, "cu": 113, "fu": 113, "hc": 113,
        "bu": 113, "al": 113, "zn": 113, "pb": 113, "ni": 113, "sn": 113,
        "ss": 113, "ru": 113, "sp": 113, "br": 113, "wr": 113, "ao": 113,
        "sc": 142, "nr": 142, "lu": 142, "bc": 142, "ec": 142,
        "i": 114, "j": 114, "jm": 114, "m": 114, "y": 114, "a": 114,
        "b": 114, "p": 114, "c": 114, "cs": 114, "l": 114, "v": 114,
        "pp": 114, "eg": 114, "eb": 114, "pg": 114, "rr": 114, "lh": 114,
        "ta": 115, "cf": 115, "sr": 115, "ma": 115, "oi": 115, "rm": 115,
        "fg": 115, "sa": 115, "ur": 115, "zc": 115, "sm": 115, "sf": 115,
        "cy": 115, "ap": 115, "pk": 115, "pf": 115, "sh": 115,
        "if": 220, "ih": 220, "ic": 220, "im": 220, "t": 220, "tf": 220, "ts": 220, "tl": 220,
        "si": 225, "lc": 225, "ps": 225, "pt": 225,
    ]
}
