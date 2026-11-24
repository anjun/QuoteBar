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
        var selected: [(Quote, SinaDarkPoolSnapshot)] = []
        for quote in targets {
            let available = (candidates[quote.symbol] ?? []).compactMap { snapshots[$0.code] }
                .filter { SinaDarkPool.matches(name: $0.info.name, code: $0.info.code, quote: quote, last: $0.last) }
            if let best = SinaDarkPool.best(available, at: date) {
                selected.append((quote, best))
            }
        }
        let needBaseline = Array(Set(selected.compactMap { $0.1.info.isUTC0Baseline ? nil : $0.1.info.code })).sorted()
        var utc0Baselines: [String: Double] = [:]
        for offset in stride(from: 0, to: needBaseline.count, by: 4) {
            let batch = Array(needBaseline[offset..<min(offset + 4, needBaseline.count)])
            await withTaskGroup(of: (String, Double?).self) { group in
                for code in batch {
                    group.addTask { (code, await darkPoolUTC0Baseline(for: code, at: date)) }
                }
                for await (code, price) in group {
                    if let price { utc0Baselines[code] = price }
                }
            }
        }
        var result = regular
        for (quote, var best) in selected {
            if !best.info.isUTC0Baseline, let baseline = utc0Baselines[best.info.code] {
                best.previous = baseline
                best.info.isUTC0Baseline = true
            }
            result[quote.symbol] = best.overlay(quote)
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
            var found = SinaDarkPool.candidates(body, matching: quote)
            // Short US tickers (e.g. MU) can crowd out btc_btc<ticker>usdt from Sina's top-50 search hits.
            if !found.isEmpty, let usdtCode = SinaDarkPool.usdtProbeCode(for: quote.symbol),
               !found.contains(where: { $0.code.caseInsensitiveCompare(usdtCode) == .orderedSame }) {
                found.append(SinaDarkPoolCandidate(code: usdtCode, name: quote.name))
            }
            await darkPoolCache.set(found, key: key, at: date)
            return found
        } catch {
            await darkPoolCache.set([], key: key, at: date, failed: true)
            return []
        }
    }

    func darkPoolUTC0Baseline(for code: String, at date: Date) async -> Double? {
        let dayStart = SinaDarkPool.utcDayStart(for: date)
        let cacheKey = "\(code)|\(Int(dayStart.timeIntervalSince1970))"
        if let cached = await darkPoolCache.baseline(for: cacheKey, at: date) {
            return cached.price
        }
        let symbol = code.hasPrefix("btc_") ? String(code.dropFirst(4)) : code
        do {
            let url = try urlWithQuery(
                "https://quotes.sina.cn/fx/api/openapi.php/BtcService.getMinKline",
                items: [("symbol", symbol), ("scale", "60"), ("datalen", "36")]
            )
            let data = try await get(url, headers: ["Referer": "https://finance.sina.com.cn/"])
            guard let parsed = SinaDarkPool.parseUTC0Baseline(data, at: date) else {
                await darkPoolCache.setBaseline(nil, key: cacheKey, expiresAt: date.addingTimeInterval(60), at: date)
                return nil
            }
            let nextRollover = dayStart.addingTimeInterval(86_400)
            let expiresAt = (parsed.exact || date.timeIntervalSince(dayStart) >= 600)
                ? nextRollover
                : min(nextRollover, date.addingTimeInterval(60))
            await darkPoolCache.setBaseline(parsed.price, key: cacheKey, expiresAt: expiresAt, at: date)
            return parsed.price
        } catch {
            await darkPoolCache.setBaseline(nil, key: cacheKey, expiresAt: date.addingTimeInterval(60), at: date)
            return nil
        }
    }
}
