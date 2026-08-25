import Foundation

public struct QuoteService: Sendable {
    public var session: URLSession
    public var timeout: TimeInterval

    public init(session: URLSession = .shared, timeout: TimeInterval = 8) {
        self.session = session
        self.timeout = timeout
    }

    public func quotes(for symbols: [SymbolID]) async -> [SymbolID: Quote] {
        guard !symbols.isEmpty else { return [:] }
        let usPhase = MarketSession.phase(.us)
        let overlayExtended = usPhase == .preMarket || usPhase == .afterHours
        let tencent = try? await fetchTencent(symbols)
        let missingAfterTencent = symbols.filter { tencent?[$0] == nil }
        let eastMoney = missingAfterTencent.isEmpty ? nil : try? await fetchEastMoney(missingAfterTencent)
        let sinaTargets = symbols.filter { id in
            if overlayExtended, id.market == .us {
                return ProviderCodes.sinaListCode(id, phase: usPhase) != nil
            }
            return tencent?[id] == nil && eastMoney?[id] == nil && !id.isUSIndex
        }
        let sina = sinaTargets.isEmpty ? nil : try? await fetchSina(sinaTargets, phase: usPhase)
        return QuoteBatchResolver.resolve(
            symbols: symbols,
            tencent: tencent,
            eastMoney: eastMoney,
            sina: sina,
            sinaOverlaysExisting: overlayExtended
        )
    }

    public func search(_ query: String) async -> [SearchHit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        async let tencentResult = fetchTencentSearch(trimmed)
        async let eastMoneyResult = fetchEastMoneySearch(trimmed)
        let tencent = try? await tencentResult
        let eastMoney = try? await eastMoneyResult
        return SearchResolver.resolve(query: trimmed, tencent: tencent, eastMoney: eastMoney)
    }

    func fetchTencent(_ symbols: [SymbolID]) async throws -> [SymbolID: Quote] {
        let codes = symbols.map(ProviderCodes.tencentQuery).joined(separator: ",")
        let url = try url("https://qt.gtimg.cn/q=\(codes)")
        let data = try await get(url, headers: [:])
        guard let body = TextDecode.string(from: data, preferringGBK: true) else {
            throw QuoteServiceError.decode
        }
        return rekey(TencentQuoteParser.parse(body), to: symbols) { ProviderCodes.tencentQuery($0) }
    }

    func fetchEastMoney(_ symbols: [SymbolID]) async throws -> [SymbolID: Quote] {
        let secids = symbols.map(ProviderCodes.eastMoneySecID).joined(separator: ",")
        let hosts = [
            "https://push2.eastmoney.com",
            "https://82.push2.eastmoney.com",
            "https://80.push2.eastmoney.com",
        ]
        var lastError: Error = QuoteServiceError.empty
        for host in hosts {
            do {
                let url = try url("\(host)/api/qt/ulist.np/get?fltt=2&invt=2&fields=f12,f13,f14,f2,f3,f4&secids=\(secids)")
                let data = try await get(url, headers: [:])
                let parsed = try EastMoneyQuoteParser.parse(data)
                let keyed = rekey(parsed, to: symbols) { ProviderCodes.eastMoneySecID($0) }
                if !keyed.isEmpty {
                    return keyed
                }
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    func fetchSina(_ symbols: [SymbolID], phase: MarketSessionPhase = .regular) async throws -> [SymbolID: Quote] {
        let codes = symbols.compactMap { ProviderCodes.sinaListCode($0, phase: phase) }
        guard !codes.isEmpty else { return [:] }
        let url = try url("https://hq.sinajs.cn/list=\(codes.joined(separator: ","))")
        let data = try await get(url, headers: ["Referer": "https://finance.sina.com.cn"])
        guard let body = TextDecode.string(from: data, preferringGBK: true) else {
            throw QuoteServiceError.decode
        }
        return rekey(SinaQuoteParser.parse(body), to: symbols) {
            ProviderCodes.sinaListCode($0, phase: phase)
        }
    }

    func fetchTencentSearch(_ query: String) async throws -> [SearchHit] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = try url("https://smartbox.gtimg.cn/s3/?v=2&q=\(encoded)&t=all")
        let data = try await get(url, headers: [:])
        guard let body = TextDecode.string(from: data, preferringGBK: true) else {
            throw QuoteServiceError.decode
        }
        return TencentSearchParser.parse(body)
    }

    func fetchEastMoneySearch(_ query: String) async throws -> [SearchHit] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = try url("https://searchapi.eastmoney.com/api/suggest/get?input=\(encoded)&type=14&token=D43BF722C8E33BDC906FB84D85E326E8")
        let data = try await get(url, headers: [:])
        return try EastMoneySearchParser.parse(data)
    }

    func get(_ url: URL, headers: [String: String]) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw QuoteServiceError.http(http.statusCode)
        }
        return data
    }

    func url(_ string: String) throws -> URL {
        guard let url = URL(string: string) else { throw QuoteServiceError.badURL }
        return url
    }

    func rekey(_ quotes: [Quote], to symbols: [SymbolID], code: (SymbolID) -> String?) -> [SymbolID: Quote] {
        var byCode: [String: Quote] = [:]
        for quote in quotes {
            if let key = code(quote.symbol) {
                byCode[key] = quote
            }
        }
        var result: [SymbolID: Quote] = [:]
        for symbol in symbols {
            guard let key = code(symbol), var quote = byCode[key] else { continue }
            if quote.symbol != symbol {
                quote.symbol = symbol
            }
            result[symbol] = quote
        }
        return result
    }
}

public enum QuoteServiceError: Error {
    case badURL
    case decode
    case empty
    case http(Int)
}
