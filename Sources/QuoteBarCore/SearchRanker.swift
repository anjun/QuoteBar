import Foundation

public enum SearchRanker {
    public static let aliases: [String: SymbolID] = [
        "腾讯": .hkStock("00700"),
        "腾讯控股": .hkStock("00700"),
        "茅台": .shStock("600519"),
        "贵州茅台": .shStock("600519"),
        "苹果": .usStock("AAPL"),
        "apple": .usStock("AAPL"),
        "特斯拉": .usStock("TSLA"),
        "tesla": .usStock("TSLA"),
        "亚马逊": .usStock("AMZN"),
        "amazon": .usStock("AMZN"),
        "微软": .usStock("MSFT"),
        "microsoft": .usStock("MSFT"),
        "英伟达": .usStock("NVDA"),
        "nvidia": .usStock("NVDA"),
        "纳斯达克100": .usIndex("NDX"),
        "纳指": .usIndex("NDX"),
        "ndx": .usIndex("NDX"),
        "标普500": .usIndex("SPX"),
        "spx": .usIndex("SPX"),
        "道指": .usIndex("DJI"),
        "道琼斯": .usIndex("DJI"),
        "dji": .usIndex("DJI"),
        "djia": .usIndex("DJI"),
        "伦敦金现": .metal("AUUSDO"),
        "auusdo": .metal("AUUSDO"),
        "伦敦金": .metal("AUUSDO"),
        "现货黄金": .metal("AUUSDO"),
        "伦敦金（现货黄金）": .metal("XAU"),
        "黄金/美元": .metal("XAU"),
        "xau": .metal("XAU"),
        "伦敦银现": .metal("AGUSDO"),
        "agusdo": .metal("AGUSDO"),
        "伦敦银": .metal("AGUSDO"),
        "现货白银": .metal("AGUSDO"),
        "白银/美元": .metal("XAG"),
        "xag": .metal("XAG"),
        "沪金": .future("aum", quoteMarket: 113),
        "沪金主连": .future("aum", quoteMarket: 113),
        "黄金连续": .future("aum", quoteMarket: 113),
        "纽约黄金": .future("GC00Y", quoteMarket: 101),
        "comex黄金": .future("GC00Y", quoteMarket: 101),
        "gc00y": .future("GC00Y", quoteMarket: 101),
    ]

    static let secondaryAliases: [String: Set<SymbolID>] = [
        "伦敦金": [.metal("XAU")],
        "现货黄金": [.metal("XAU")],
        "伦敦银": [.metal("XAG")],
        "现货白银": [.metal("XAG")],
    ]

    public static let aliasHits: [String: SearchHit] = [
        "标普500": SearchHit(symbol: .usIndex("SPX"), name: "标普500"),
        "spx": SearchHit(symbol: .usIndex("SPX"), name: "标普500"),
        "伦敦金现": SearchHit(symbol: .metal("AUUSDO"), name: "伦敦金现"),
        "auusdo": SearchHit(symbol: .metal("AUUSDO"), name: "伦敦金现"),
        "伦敦金": SearchHit(symbol: .metal("AUUSDO"), name: "伦敦金现"),
        "现货黄金": SearchHit(symbol: .metal("AUUSDO"), name: "伦敦金现"),
        "xau": SearchHit(symbol: .metal("XAU"), name: "黄金/美元"),
        "黄金/美元": SearchHit(symbol: .metal("XAU"), name: "黄金/美元"),
        "伦敦银现": SearchHit(symbol: .metal("AGUSDO"), name: "伦敦银现"),
        "agusdo": SearchHit(symbol: .metal("AGUSDO"), name: "伦敦银现"),
        "伦敦银": SearchHit(symbol: .metal("AGUSDO"), name: "伦敦银现"),
        "现货白银": SearchHit(symbol: .metal("AGUSDO"), name: "伦敦银现"),
        "xag": SearchHit(symbol: .metal("XAG"), name: "白银/美元"),
        "白银/美元": SearchHit(symbol: .metal("XAG"), name: "白银/美元"),
        "沪金": SearchHit(symbol: .future("aum", quoteMarket: 113), name: "沪金主连"),
        "沪金主连": SearchHit(symbol: .future("aum", quoteMarket: 113), name: "沪金主连"),
        "黄金连续": SearchHit(symbol: .future("aum", quoteMarket: 113), name: "沪金主连"),
        "纽约黄金": SearchHit(symbol: .future("GC00Y", quoteMarket: 101), name: "COMEX黄金"),
        "comex黄金": SearchHit(symbol: .future("GC00Y", quoteMarket: 101), name: "COMEX黄金"),
        "gc00y": SearchHit(symbol: .future("GC00Y", quoteMarket: 101), name: "COMEX黄金"),
    ]

    public static func aliasHit(for query: String) -> SearchHit? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let coin = CryptoCatalog.match(trimmed) {
            return SearchHit(symbol: .crypto(coin.code), name: coin.name)
        }
        return aliasHits[trimmed.lowercased()]
    }

    public static func matches(_ hit: SearchHit, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let q = trimmed.lowercased()
        let code = hit.symbol.code.lowercased()
        if code == q || code.hasPrefix(q) { return true }
        let normalizedCode = SymbolID.normalize(trimmed, market: hit.symbol.market).lowercased()
        if !normalizedCode.isEmpty, code == normalizedCode { return true }
        if hit.name.lowercased().contains(q) { return true }
        if CryptoCatalog.matches(hit.symbol, query: trimmed) { return true }
        if aliases[q] == hit.symbol { return true }
        if secondaryAliases[q]?.contains(hit.symbol) == true { return true }
        return false
    }

    public static func rank(_ hits: [SearchHit], query: String) -> [SearchHit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return hits }
        let filtered = hits.filter { matches($0, query: trimmed) }
        let alias = CryptoCatalog.match(trimmed).map { SymbolID.crypto($0.code) }
            ?? aliases[trimmed.lowercased()]
        return filtered.enumerated().sorted { lhs, rhs in
            let l = score(lhs.element, query: trimmed, alias: alias)
            let r = score(rhs.element, query: trimmed, alias: alias)
            if l != r { return l > r }
            return lhs.offset < rhs.offset
        }.map(\.element)
    }

    static func score(_ hit: SearchHit, query: String, alias: SymbolID?) -> Int {
        let q = query.lowercased()
        let code = hit.symbol.code.lowercased()
        let name = hit.name.lowercased()
        let normalizedCode = SymbolID.normalize(query, market: hit.symbol.market).lowercased()

        var value = 0
        if let alias, hit.symbol == alias { value += 2000 }
        let codeScore: Int
        if code == q || (!normalizedCode.isEmpty && code == normalizedCode) {
            codeScore = 1000
        } else if code.hasPrefix(q) {
            codeScore = 300
        } else {
            codeScore = 0
        }
        let nameScore: Int
        if name == q {
            nameScore = 900
        } else if name.hasPrefix(q) {
            nameScore = 400
        } else if name.contains(q) {
            nameScore = 150
        } else {
            nameScore = 0
        }
        value += max(codeScore, nameScore)
        if codeScore > 0, nameScore > 0, name != code {
            value += 50
        }
        return value
    }
}
