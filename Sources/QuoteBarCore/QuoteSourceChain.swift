import Foundation

public enum QuoteSourceChain {
    public static func sources(for symbol: SymbolID) -> [QuoteSource] {
        if symbol.market == .crypto {
            return [.binance, .gate]
        }
        if ProviderCodes.tonghuashunTimeCode(symbol) != nil {
            return [.tonghuashun]
        }
        if symbol.market == .hk {
            return [.sina]
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

        func absorb(_ batch: [SymbolID: Quote]?, source: QuoteSource) {
            guard let batch else { return }
            for id in remaining where QuoteSourceChain.sources(for: id).contains(source) {
                if let quote = batch[id] {
                    result[id] = quote
                    remaining.remove(id)
                }
            }
        }

        absorb(tencent, source: .tencent)
        absorb(eastMoney, source: .eastMoney)
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
                    } else if QuoteSourceChain.sources(for: id).contains(.sina) || id.isUSIndex {
                        result[id] = quote
                    }
                    remaining.remove(id)
                }
            } else {
                absorb(sina, source: .sina)
            }
        }
        absorb(tonghuashun, source: .tonghuashun)
        absorb(binance, source: .binance)
        absorb(gate, source: .gate)
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
        var indexBySymbol: [SymbolID: Int] = [:]
        func absorb(_ batch: [SearchHit]?) {
            guard let batch else { return }
            for hit in batch where SearchRanker.matches(hit, query: query) {
                if let existingIndex = indexBySymbol[hit.symbol] {
                    let existing = hits[existingIndex]
                    if existing.name.lowercased() == hit.name.lowercased(),
                       existing.name == existing.name.lowercased(),
                       hit.name != hit.name.lowercased() {
                        hits[existingIndex] = hit
                    }
                    continue
                }
                indexBySymbol[hit.symbol] = hits.count
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
