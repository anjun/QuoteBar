import Foundation

public enum QuoteSourceChain {
    public static func sources(for symbol: SymbolID) -> [QuoteSource] {
        if symbol.isUSIndex {
            return [.tencent, .eastMoney]
        }
        return [.tencent, .eastMoney, .sina]
    }
}

public enum QuoteBatchResolver {
    public static func resolve(
        symbols: [SymbolID],
        tencent: [SymbolID: Quote]?,
        eastMoney: [SymbolID: Quote]?,
        sina: [SymbolID: Quote]?
    ) -> [SymbolID: Quote] {
        var remaining = Set(symbols)
        var result: [SymbolID: Quote] = [:]

        func absorb(_ batch: [SymbolID: Quote]?) {
            guard let batch else { return }
            for id in remaining {
                if let quote = batch[id] {
                    result[id] = quote
                    remaining.remove(id)
                }
            }
        }

        absorb(tencent)
        absorb(eastMoney)
        if let sina {
            for id in remaining where !id.isUSIndex {
                if let quote = sina[id] {
                    result[id] = quote
                    remaining.remove(id)
                }
            }
        }
        return result
    }
}

public enum SearchResolver {
    public static func resolve(
        query: String,
        tencent: [SearchHit]?,
        eastMoney: [SearchHit]?
    ) -> [SearchHit] {
        if let tencent, !tencent.isEmpty {
            return SearchRanker.rank(tencent, query: query)
        }
        if let eastMoney, !eastMoney.isEmpty {
            return SearchRanker.rank(eastMoney, query: query)
        }
        return []
    }
}
