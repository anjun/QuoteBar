import Foundation
import Testing
@testable import QuoteBarCore

@Test func binanceTickerArrayMapsUSDTPairsToCryptoSpot() throws {
    let quotes = try BinanceQuoteParser.parse(FixtureLoader.data("binance-ticker.json"))
    let btc = try #require(quotes.first { $0.symbol == SymbolID.crypto("BTC") })
    #expect(btc.name == "比特币")
    #expect(btc.last == 80000)
    #expect(btc.change == 2000)
    #expect(btc.changePercent == 2.564)
    #expect(btc.source == .binance)
    #expect(btc.symbol.market == .crypto)
    #expect(btc.symbol.kind == .spot)
    #expect(btc.shortDisplayName == "比特币")

    let eth = try #require(quotes.first { $0.symbol == SymbolID.crypto("ETH") })
    #expect(eth.name == "以太坊")
    #expect(eth.last == 2500)
}

@Test func binanceTickerObjectMapsMemeCoin() throws {
    let quotes = try BinanceQuoteParser.parse(FixtureLoader.data("binance-ticker-pepe.json"))
    let pepe = try #require(quotes.first)
    #expect(pepe.symbol == SymbolID.crypto("PEPE"))
    #expect(pepe.last == 0.00000409)
    #expect(pepe.changePercent == 1.489)
    #expect(pepe.source == .binance)
}

@Test func gateTickerDerivesChangeFromPercent() throws {
    let quotes = try GateQuoteParser.parse(FixtureLoader.data("gate-ticker-btc.json"))
    let btc = try #require(quotes.first)
    #expect(btc.symbol == SymbolID.crypto("BTC"))
    #expect(btc.last == 100)
    #expect(btc.changePercent == 25)
    #expect(abs(btc.change - 20) < 0.0001)
    #expect(btc.source == .gate)
    #expect(btc.name == "比特币")
}

@Test func cryptoTickerNormalizationStripsPairSuffix() {
    #expect(CryptoCatalog.normalizeTicker("btc") == "BTC")
    #expect(CryptoCatalog.normalizeTicker("BTCUSDT") == "BTC")
    #expect(CryptoCatalog.normalizeTicker("eth-usd") == "ETH")
    #expect(CryptoCatalog.normalizeTicker("sol_usdt") == "SOL")
    #expect(CryptoCatalog.normalizeTicker("比特币") == nil)
    #expect(SymbolID.crypto("btcusdt").code == "BTC")
}

@Test func searchBitcoinAliasPrefersCryptoOverUSETF() {
    let etf = SearchHit(symbol: .usStock("BTC"), name: "Grayscale Bitcoin Mini Trust ET")
    let ranked = SearchResolver.resolve(
        query: "btc",
        tencent: [],
        eastMoney: [etf],
        crypto: CryptoCatalog.hits(matching: "btc")
    )
    let first = ranked.first
    #expect(first?.symbol == SymbolID.crypto("BTC"))
    #expect(first?.name == "比特币")
    #expect(ranked.contains { $0.symbol == etf.symbol })
}

@Test func searchChineseAndEnglishBitcoinNameHitsCryptoCaseInsensitively() {
    for query in ["比特币", "bitcoin", "Bitcoin", "BITCOIN", "BTC", "btc"] {
        let ranked = SearchResolver.resolve(query: query, tencent: [], eastMoney: [])
        #expect(ranked.first?.symbol == SymbolID.crypto("BTC"))
        #expect(ranked.first?.name == "比特币")
    }
    #expect(CryptoCatalog.hits(matching: "btb").isEmpty)
    #expect(CryptoCatalog.hits(matching: "bk").isEmpty)
}

@Test func searchEthereumFullNameAndTickerWithoutJianpin() {
    #expect(SearchResolver.resolve(query: "eth", tencent: [], eastMoney: []).first?.symbol == SymbolID.crypto("ETH"))
    #expect(SearchResolver.resolve(query: "ETH", tencent: [], eastMoney: []).first?.symbol == SymbolID.crypto("ETH"))
    #expect(SearchResolver.resolve(query: "以太坊", tencent: [], eastMoney: []).first?.symbol == SymbolID.crypto("ETH"))
    #expect(SearchResolver.resolve(query: "Ethereum", tencent: [], eastMoney: []).first?.symbol == SymbolID.crypto("ETH"))
    #expect(SearchResolver.resolve(query: "ytf", tencent: [], eastMoney: []).isEmpty)
}

@Test func providerCodesForCryptoPairs() {
    let btc = SymbolID.crypto("BTC")
    #expect(ProviderCodes.binanceSymbol(btc) == "BTCUSDT")
    #expect(ProviderCodes.gateCurrencyPair(btc) == "BTC_USDT")
    #expect(ProviderCodes.sinaListCode(btc) == nil)
    #expect(ProviderCodes.tonghuashunTimeCode(btc) == nil)
}

@Test func cryptoStaysOnBinanceThenGate() {
    #expect(QuoteSourceChain.sources(for: .crypto("BTC")) == [.binance, .gate])
}

@Test func binanceFillsCryptoThenGateCoversTheRest() {
    let btc = SymbolID.crypto("BTC")
    let eth = SymbolID.crypto("ETH")
    let binance = Quote(symbol: btc, name: "比特币", last: 80000, change: 2000, changePercent: 2.5, source: .binance)
    let gate = Quote(symbol: eth, name: "以太坊", last: 2500, change: 50, changePercent: 2, source: .gate)
    let resolved = QuoteBatchResolver.resolve(
        symbols: [btc, eth],
        tencent: nil,
        eastMoney: nil,
        sina: nil,
        binance: [btc: binance],
        gate: [eth: gate, btc: Quote(symbol: btc, name: "忽略", last: 1, change: 0, changePercent: 0, source: .gate)]
    )
    #expect(resolved[btc]?.source == .binance)
    #expect(resolved[btc]?.last == 80000)
    #expect(resolved[eth]?.source == .gate)
    #expect(resolved[eth]?.last == 2500)
}

@Test func watchlistGroupsCryptoSeparately() {
    var list = Watchlist(items: [
        .shIndex("000001"),
        .metal("AUUSDO"),
        .crypto("BTC"),
        .future("aum", quoteMarket: 113),
    ])
    let groups = list.groups()
    #expect(groups.map(\.family) == [.cn, .futures, .metal, .crypto])
    #expect(groups.first { $0.family == .crypto }?.items == [.crypto("BTC")])

    list.move(.crypto("BTC"), by: -1)
    #expect(list.groups().first { $0.family == .crypto }?.items == [.crypto("BTC")])
}

@Test func cryptoSessionIsAlwaysOpenIncludingWeekend() {
    #expect(MarketSession.isOpen(.crypto, at: weekday(tz: utc, hour: 10, minute: 0)))
    #expect(MarketSession.isOpen(.crypto, at: weekday(tz: utc, hour: 3, minute: 0)))
    #expect(MarketSession.isOpen(.crypto, at: saturday(tz: utc, hour: 10, minute: 0)))
    #expect(MarketSession.phase(.crypto, at: saturday(tz: utc, hour: 10, minute: 0)) == .regular)
}

@Test func cryptoCatalogHitsPrefixForBitcoinCash() {
    let hits = CryptoCatalog.hits(matching: "比特")
    #expect(hits.contains { $0.symbol == SymbolID.crypto("BTC") })
    #expect(hits.contains { $0.symbol == SymbolID.crypto("BCH") })
}

@Suite(.serialized)
struct CryptoQuoteServiceUTC0Tests {
    @Test func binanceAndGateFallbackUseUTC0TradingDayEndpoints() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [CryptoUTC0MockProtocol.self]
        let service = QuoteService(session: URLSession(configuration: config), timeout: 2)
        defer { service.session.invalidateAndCancel() }
        CryptoUTC0MockProtocol.state.reset()

        let quotes = await service.quotes(for: [.crypto("BTC"), .crypto("ETH")])

        let btc = try #require(quotes[.crypto("BTC")])
        #expect(btc.source == .binance)
        #expect(btc.last == 55916.75)
        #expect(btc.changePercent == -5.148)

        let eth = try #require(quotes[.crypto("ETH")])
        #expect(eth.source == .gate)
        #expect(eth.last == 1566.03)
        #expect(eth.changePercent == -5.16)

        let urls = CryptoUTC0MockProtocol.state.capturedURLs()
        let binanceURL = try #require(urls.first { $0.host == "data-api.binance.vision" })
        let binanceItems = URLComponents(url: binanceURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(binanceURL.path == "/api/v3/ticker/tradingDay")
        #expect(binanceItems.first { $0.name == "timeZone" }?.value == "0")

        let gateURL = try #require(urls.first { $0.host == "api.gateio.ws" })
        let gateItems = URLComponents(url: gateURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(gateURL.path == "/api/v4/spot/tickers")
        #expect(gateItems.first { $0.name == "currency_pair" }?.value == "ETH_USDT")
        #expect(gateItems.first { $0.name == "timezone" }?.value == "utc0")
    }
}

private final class CryptoUTC0MockProtocol: URLProtocol, @unchecked Sendable {
    static let state = State()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let url = request.url!
        let (status, body) = Self.state.handle(url: url)
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    final class State: @unchecked Sendable {
        private let lock = NSLock()
        private var urls: [URL] = []

        func reset() { lock.withLock { urls = [] } }
        func capturedURLs() -> [URL] { lock.withLock { urls } }

        func handle(url: URL) -> (Int, String) {
            lock.withLock { urls.append(url) }
            switch url.host {
            case "data-api.binance.vision":
                return (200, #"[{"symbol":"BTCUSDT","priceChange":"-3034.76","priceChangePercent":"-5.148","lastPrice":"55916.75"}]"#)
            case "api.gateio.ws":
                return (200, #"[{"currency_pair":"ETH_USDT","last":"1566.03","change_percentage":"-5.16"}]"#)
            default:
                return (404, "")
            }
        }
    }
}

private let utc = TimeZone(identifier: "UTC")!

private func weekday(tz: TimeZone, hour: Int, minute: Int) -> Date {
    date(tz: tz, year: 2026, month: 8, day: 18, hour: hour, minute: minute)
}

private func saturday(tz: TimeZone, hour: Int, minute: Int) -> Date {
    date(tz: tz, year: 2026, month: 8, day: 22, hour: hour, minute: minute)
}

private func date(tz: TimeZone, year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = tz
    return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}
