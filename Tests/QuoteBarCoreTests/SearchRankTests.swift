import Foundation
import Testing
@testable import QuoteBarCore

@Test func tencentSearchUnescapesUnicodeName() throws {
    let parsed = TencentSearchParser.parse(try FixtureLoader.string("tencent-search-tx.txt"))
    let hit = try #require(parsed.first { $0.symbol.code == "00700" })
    #expect(hit.name == "腾讯控股")
}

@Test func searchMatchesFullNameAndCodeCaseInsensitivelyForAnthropic() {
    let tencent = TencentSearchParser.parse(
        #"v_hint="us~ant.oq~anthropic~anthropic~GP^us~antw.am~anthropic ai lab ecosystem etf~*~GP""#
    )
    let eastMoneyData = Data(#"""
    {"QuotationCodeTable":{"Data":[{"Code":"ANT","Name":"Anthropic","PinYin":"ANTHROPIC","MktNum":"105","QuoteID":"105.ANT","SecurityTypeName":"美股","Classify":"UsStock"}]}}
    """#.utf8)
    let eastMoney = try? EastMoneySearchParser.parse(eastMoneyData)

    for query in ["anthropic", "Anthropic", "ANTHROPIC", "ant", "ANT"] {
        let resolved = SearchResolver.resolve(query: query, tencent: tencent, eastMoney: eastMoney)
        #expect(resolved.first?.symbol == SymbolID.usStock("ANT"))
        #expect(resolved.first?.name == "Anthropic")
    }
}

@Test func searchRemovesJianpinAndMatchesCodeCaseInsensitively() throws {
    let txHits = [
        SearchHit(symbol: SymbolID.shStock("600556"), name: "天下秀"),
        SearchHit(symbol: SymbolID.hkStock("00700"), name: "腾讯控股"),
        SearchHit(symbol: SymbolID.usStock("TX"), name: "特尔尼翁钢铁"),
    ]
    let byCode = SearchRanker.rank(txHits, query: "00700")
    #expect(byCode.map(\.symbol) == [.hkStock("00700")])

    let byName = SearchRanker.rank(txHits, query: "腾讯控股")
    #expect(byName.map(\.symbol) == [.hkStock("00700")])

    let byTx = SearchRanker.rank(txHits, query: "tx")
    #expect(byTx.map(\.symbol) == [.usStock("TX")])

    let parsedTencent = TencentSearchParser.parse(try FixtureLoader.string("tencent-search-tx.txt"))
    let rankedTencent = SearchRanker.rank(parsedTencent, query: "tx")
    #expect(!rankedTencent.contains { $0.symbol == .hkStock("00700") })

    let parsedEM = try EastMoneySearchParser.parse(FixtureLoader.data("eastmoney-search-tx.json"))
    #expect(SearchRanker.rank(parsedEM, query: "tx").isEmpty)
    #expect(SearchRanker.rank(parsedEM, query: "腾讯").first?.symbol == .hkStock("00700"))
}

@Test func searchPgMatchesProcterNotAppleJianpin() {
    let body = #"v_hint="us~aapl.oq~\u82f9\u679c~pg~GP^us~pg.n~\u5b9d\u6d01~bj~GP^sh~600312~\u5e73\u9ad8\u7535\u6c14~pgdq~GP-A""#
    let parsed = TencentSearchParser.parse(body)

    for query in ["pg", "PG"] {
        let ranked = SearchRanker.rank(parsed, query: query)
        #expect(ranked.map(\.symbol) == [.usStock("PG")])
    }
    for query in ["aapl", "AAPL", "苹果"] {
        let ranked = SearchRanker.rank(parsed, query: query)
        #expect(ranked.map(\.symbol) == [.usStock("AAPL")])
    }
}

@Test func searchAntAndTslFilterOutChineseJianpinPollution() {
    let antHits = [
        SearchHit(symbol: .usStock("ANT"), name: "Anthropic"),
        SearchHit(symbol: .crypto("ANT"), name: "ANT"),
        SearchHit(symbol: .szStock("000969"), name: "安泰科技"),
        SearchHit(symbol: .hkStock("02020"), name: "安踏体育"),
    ]
    #expect(SearchRanker.rank(antHits, query: "ant").map(\.symbol) == [.usStock("ANT"), .crypto("ANT")])

    let tslHits = [
        SearchHit(symbol: .shStock("600535"), name: "天士力"),
        SearchHit(symbol: .usStock("TSLA"), name: "特斯拉"),
    ]
    #expect(SearchRanker.rank(tslHits, query: "tsl").map(\.symbol) == [.usStock("TSLA")])
}

@Test func eastMoneySearchDropsUnsupportedForeignMarkets() throws {
    let json = Data(#"""
    {"QuotationCodeTable":{"Data":[
      {"Code":"0R0X","Name":"TESLA INC COM USD0.001","SecurityTypeName":"英股","MktNum":"155","QuoteID":"155.0R0X","Classify":"LSE"},
      {"Code":"H50027","Name":"沪金融红","SecurityTypeName":"指数","MktNum":"2","QuoteID":"2.H50027","Classify":"24"},
      {"Code":"ANT","Name":"Anthropic","SecurityTypeName":"美股","MktNum":"105","QuoteID":"105.ANT","Classify":"UsStock"}
    ]}}
    """#.utf8)
    let parsed = try EastMoneySearchParser.parse(json)
    #expect(parsed.map(\.symbol) == [.usStock("ANT")])
}

@Suite(.serialized)
struct QuoteServiceSearchTests {
    @Test func searchAnthropicShortCircuitsInvalidBinance400AndNeverRetriesFallbackHost() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [SearchMockProtocol.self]
        let service = QuoteService(session: URLSession(configuration: config), timeout: 2)
        defer { service.session.invalidateAndCancel() }
        SearchMockProtocol.state.reset()

        let hits = await service.search("anthropic")
        let first = try #require(hits.first)
        #expect(first.symbol == .usStock("ANT"))
        #expect(first.name == "Anthropic")
        #expect(SearchMockProtocol.state.hostHits("data-api.binance.vision") == 1)
        #expect(SearchMockProtocol.state.hostHits("api.binance.com") == 0)
    }
}

private final class SearchMockProtocol: URLProtocol, @unchecked Sendable {
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
        private var counts: [String: Int] = [:]

        func reset() { lock.withLock { counts = [:] } }
        func hostHits(_ host: String) -> Int { lock.withLock { counts[host, default: 0] } }

        func handle(url: URL) -> (Int, String) {
            let host = url.host ?? ""
            lock.withLock { counts[host, default: 0] += 1 }
            switch host {
            case "smartbox.gtimg.cn":
                return (200, #"v_hint="us~ant.oq~anthropic~anthropic~GP^us~antw.am~anthropic ai lab ecosystem etf~*~GP""#)
            case "searchapi.eastmoney.com":
                return (200, #"{"QuotationCodeTable":{"Data":[{"Code":"ANT","Name":"Anthropic","MktNum":"105","QuoteID":"105.ANT","SecurityTypeName":"美股","Classify":"UsStock"}]}}"#)
            case "data-api.binance.vision":
                return (400, #"{"code":-1121,"msg":"Invalid symbol."}"#)
            case "api.gateio.ws":
                return (400, #"{"label":"INVALID_CURRENCY_PAIR"}"#)
            default:
                return (500, "")
            }
        }
    }
}
