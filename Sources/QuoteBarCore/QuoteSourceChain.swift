import Foundation

public enum QuoteSourceChain {
    public static func sources(for symbol: SymbolID) -> [QuoteSource] {
        if symbol.market == .crypto {
            return [.binance, .gate]
        }
        if ProviderCodes.tonghuashunTimeCode(symbol) != nil {
            return [.tonghuashun]
        }
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
        sina: [SymbolID: Quote]?,
        tonghuashun: [SymbolID: Quote]? = nil,
        binance: [SymbolID: Quote]? = nil,
        gate: [SymbolID: Quote]? = nil,
        sinaOverlaysExisting: Bool = false
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
            if sinaOverlaysExisting {
                for id in symbols {
                    guard let quote = sina[id] else { continue }
                    if let existing = result[id] {
                        result[id] = Quote(
                            symbol: existing.symbol,
                            name: existing.name,
                            last: quote.last,
                            change: quote.change,
                            changePercent: quote.changePercent,
                            source: quote.source
                        )
                    } else {
                        result[id] = quote
                    }
                    remaining.remove(id)
                }
            } else {
                for id in remaining where !id.isUSIndex {
                    if let quote = sina[id] {
                        result[id] = quote
                        remaining.remove(id)
                    }
                }
            }
        }
        absorb(tonghuashun)
        absorb(binance)
        absorb(gate)
        return result
    }
}

public enum SearchResolver {
    public static func resolve(
        query: String,
        tencent: [SearchHit]?,
        eastMoney: [SearchHit]?,
        crypto: [SearchHit]? = nil
    ) -> [SearchHit] {
        var hits: [SearchHit] = []
        var seen = Set<SymbolID>()
        func absorb(_ batch: [SearchHit]?) {
            guard let batch else { return }
            for hit in batch where seen.insert(hit.symbol).inserted {
                hits.append(hit)
            }
        }
        absorb(tencent)
        absorb(eastMoney)
        absorb(crypto)
        if let alias = SearchRanker.aliasHit(for: query) {
            absorb([alias])
        }
        return SearchRanker.rank(hits, query: query)
    }
}
