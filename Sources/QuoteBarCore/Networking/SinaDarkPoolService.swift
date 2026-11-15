import Foundation

extension QuoteService {
    func overlayDarkPool(on regular: [SymbolID: Quote], at date: Date) async -> [SymbolID: Quote] {
        let targets = regular.values.filter { SinaDarkPool.eligible($0.symbol, at: date) }
        guard !targets.isEmpty else { return regular }
        var candidates: [SymbolID: [SinaDarkPoolCandidate]] = [:]
        // Bound search concurrency; cache discoveries, but compare fresh volumes every refresh.
        for offset in stride(from: 0, to: targets.count, by: 4) {
            let batch = Array(targets[offset..<min(offset + 4, targets.count)])
            await withTaskGroup(of: (SymbolID, [SinaDarkPoolCandidate]).self) { group in
                for quote in batch {
                    group.addTask { (quote.symbol, await darkPoolCandidates(for: quote, at: date)) }
                }
                for await (symbol, found) in group { candidates[symbol] = found }
            }
        }
        let codes = Set(candidates.values.flatMap { $0.map(\.code) }).sorted()
        guard !codes.isEmpty else { return regular }
        var snapshots: [String: SinaDarkPoolSnapshot] = [:]
        for offset in stride(from: 0, to: codes.count, by: 50) {
            let batch = codes[offset..<min(offset + 50, codes.count)]
            do {
                let url = try url("https://hq.sinajs.cn/list=\(batch.joined(separator: ","))")
                let data = try await get(url, headers: ["Referer": "https://finance.sina.com.cn/"])
                guard let body = TextDecode.string(from: data, preferringGBK: true) else { continue }
                snapshots.merge(SinaDarkPool.parse(body)) { _, new in new }
            } catch { continue }
        }
        var result = regular
        for quote in targets {
            let available = (candidates[quote.symbol] ?? []).compactMap { snapshots[$0.code] }
                .filter { SinaDarkPool.matches(name: $0.info.name, code: $0.info.code, quote: quote) }
            if let best = SinaDarkPool.best(available, at: date) {
                result[quote.symbol] = best.overlay(quote)
            }
        }
        return result
    }

    func darkPoolCandidates(for quote: Quote, at date: Date) async -> [SinaDarkPoolCandidate] {
        let key = "\(quote.symbol.market.rawValue):\(quote.symbol.code):\(quote.name)"
        if let cached = await darkPoolCache.get(key, at: date) { return cached }
        do {
            // US ticker searches find wrappers even when Tencent and Sina use different names.
            let query = quote.symbol.market == .us ? quote.symbol.code : quote.name
            let url = try urlWithQuery("https://suggest3.sinajs.cn/suggest/", query: [
                "type": "71", "key": query, "name": "suggestdata",
            ])
            let data = try await get(url, headers: ["Referer": "https://finance.sina.com.cn/"])
            guard let body = TextDecode.string(from: data, preferringGBK: true),
                  body.contains("var suggestdata=") else { throw QuoteServiceError.decode }
            let found = SinaDarkPool.candidates(body, matching: quote)
            await darkPoolCache.set(found, key: key, at: date)
            return found
        } catch {
            await darkPoolCache.set([], key: key, at: date, failed: true)
            return []
        }
    }
}
