import Foundation

public enum SearchRanker {
    public static let aliases: [String: SymbolID] = [
        "tx": .hkStock("00700"),
        "txkg": .hkStock("00700"),
        "腾讯": .hkStock("00700"),
        "腾讯控股": .hkStock("00700"),
        "mt": .shStock("600519"),
        "gzmt": .shStock("600519"),
        "茅台": .shStock("600519"),
        "贵州茅台": .shStock("600519"),
        "pg": .usStock("AAPL"),
        "苹果": .usStock("AAPL"),
        "tsl": .usStock("TSLA"),
        "特斯拉": .usStock("TSLA"),
        "ymx": .usStock("AMZN"),
        "亚马逊": .usStock("AMZN"),
        "wr": .usStock("MSFT"),
        "微软": .usStock("MSFT"),
        "ywd": .usStock("NVDA"),
        "英伟达": .usStock("NVDA"),
        "nsdk100": .usIndex("NDX"),
        "纳指": .usIndex("NDX"),
        "dqs": .usIndex("DJI"),
        "道指": .usIndex("DJI"),
        "道琼斯": .usIndex("DJI"),
        "伦敦金现": .metal("AUUSDO"),
        "auusdo": .metal("AUUSDO"),
        "伦敦金": .metal("AUUSDO"),
        "现货黄金": .metal("AUUSDO"),
        "ldj": .metal("AUUSDO"),
        "ldjx": .metal("AUUSDO"),
        "伦敦金（现货黄金）": .metal("XAU"),
        "黄金/美元": .metal("XAU"),
        "xau": .metal("XAU"),
        "伦敦银现": .metal("AGUSDO"),
        "agusdo": .metal("AGUSDO"),
        "伦敦银": .metal("AGUSDO"),
        "现货白银": .metal("AGUSDO"),
        "xag": .metal("XAG"),
        "沪金": .future("aum", quoteMarket: 113),
        "沪金主连": .future("aum", quoteMarket: 113),
        "黄金连续": .future("aum", quoteMarket: 113),
        "纽约黄金": .future("GC00Y", quoteMarket: 101),
        "comex黄金": .future("GC00Y", quoteMarket: 101),
    ]

    public static let aliasHits: [String: SearchHit] = [
        "伦敦金现": SearchHit(symbol: .metal("AUUSDO"), name: "伦敦金现", pinyin: "ldjx"),
        "auusdo": SearchHit(symbol: .metal("AUUSDO"), name: "伦敦金现", pinyin: "auusdo"),
        "伦敦金": SearchHit(symbol: .metal("AUUSDO"), name: "伦敦金现", pinyin: "ldj"),
        "现货黄金": SearchHit(symbol: .metal("AUUSDO"), name: "伦敦金现", pinyin: "xhhj"),
        "ldj": SearchHit(symbol: .metal("AUUSDO"), name: "伦敦金现", pinyin: "ldj"),
        "ldjx": SearchHit(symbol: .metal("AUUSDO"), name: "伦敦金现", pinyin: "ldjx"),
        "xau": SearchHit(symbol: .metal("XAU"), name: "黄金/美元", pinyin: "xau"),
        "伦敦银现": SearchHit(symbol: .metal("AGUSDO"), name: "伦敦银现", pinyin: "ldyx"),
        "agusdo": SearchHit(symbol: .metal("AGUSDO"), name: "伦敦银现", pinyin: "agusdo"),
        "伦敦银": SearchHit(symbol: .metal("AGUSDO"), name: "伦敦银现", pinyin: "ldy"),
        "现货白银": SearchHit(symbol: .metal("AGUSDO"), name: "伦敦银现", pinyin: "xhby"),
        "xag": SearchHit(symbol: .metal("XAG"), name: "白银/美元", pinyin: "xag"),
        "沪金": SearchHit(symbol: .future("aum", quoteMarket: 113), name: "沪金主连", pinyin: "hj"),
        "沪金主连": SearchHit(symbol: .future("aum", quoteMarket: 113), name: "沪金主连", pinyin: "hjzl"),
        "黄金连续": SearchHit(symbol: .future("aum", quoteMarket: 113), name: "沪金主连", pinyin: "hjlx"),
        "纽约黄金": SearchHit(symbol: .future("GC00Y", quoteMarket: 101), name: "COMEX黄金", pinyin: "nyhj"),
        "comex黄金": SearchHit(symbol: .future("GC00Y", quoteMarket: 101), name: "COMEX黄金", pinyin: "comexhj"),
    ]

    public static func aliasHit(for query: String) -> SearchHit? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if let coin = CryptoCatalog.match(trimmed) {
            return SearchHit(symbol: .crypto(coin.code), name: coin.name, pinyin: coin.pinyin)
        }
        return aliasHits[trimmed.lowercased()] ?? aliasHits[trimmed]
    }

    public static func rank(_ hits: [SearchHit], query: String) -> [SearchHit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return hits }
        let alias = CryptoCatalog.match(trimmed).map { SymbolID.crypto($0.code) }
            ?? aliases[trimmed.lowercased()]
            ?? aliases[trimmed]
        return hits.enumerated().sorted { lhs, rhs in
            let l = score(lhs.element, query: trimmed, alias: alias)
            let r = score(rhs.element, query: trimmed, alias: alias)
            if l != r { return l > r }
            return lhs.offset < rhs.offset
        }.map(\.element)
    }

    static func score(_ hit: SearchHit, query: String, alias: SymbolID?) -> Int {
        let q = query.lowercased()
        var value = 0
        if let alias, hit.symbol == alias { value += 2000 }
        if hit.symbol.code.lowercased() == q { value += 1000 }
        if hit.name == query { value += 900 }
        if hit.pinyin.lowercased() == q { value += 400 }
        if hit.pinyin.lowercased().hasPrefix(q) { value += 200 }
        if hit.name.contains(query) { value += 150 }
        if hit.symbol.code.lowercased().hasPrefix(q) { value += 80 }
        return value
    }
}
