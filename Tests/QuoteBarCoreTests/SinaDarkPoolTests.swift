import Foundation
import Testing
@testable import QuoteBarCore

private let weekend = ISO8601DateFormatter().date(from: "2026-11-15T08:10:00Z")!
private let nvda = Quote(symbol: .usStock("NVDA"), name: "英伟达", last: 162.85,
                         change: -3.34, changePercent: -2.01, source: .tencent)
private let zhongji = Quote(symbol: .szStock("300308"), name: "中际旭创", last: 466.2,
                            change: -42.7, changePercent: -8.39, source: .tencent)

private let darkSearch = """
var suggestdata="NVDA,41,nvda,nvda,英伟达;BTCNVDA,71,btcnvda,btcnvda,NVDA（英伟达暗盘）;BTCNVDAUSDT,71,btcnvdausdt,btcnvdausdt,英伟达（暗盘）;BTCNVDAX,71,btcnvdax,btcnvdax,NVDAx（英伟达暗盘）;IPO,71,btcipo,btcipo,英伟达（暗盘ipo）;ETF,71,btcother,btcother,英伟达杠杆ETF（暗盘）";
"""

// Fields and layout from Sina's public response; volumes intentionally differ from turnover.
private let darkQuotes = """
var hq_str_btc_btcnvda="16:09:02,0,0,160.4013,0,160.4013,164.2955,155.0326,159.4951,NVDA（英伟达暗盘）,115735,2026-11-15,100,0,USD,数据来源OKX DEX,0";
var hq_str_btc_btcnvdausdt="16:09:02,0,0,159.9800,0,159.9700,161.6100,157.6500,159.7800,英伟达（暗盘）,0,2026-11-15,999999999,0,USD,,0";
var hq_str_btc_btcnvdax="16:09:02,0,0,160,0,160,164,155,159,NVDAx（英伟达暗盘）,50,2026-11-15,900000000,0,USD,,0";
var hq_str_btc_btczhongjiusdt="16:09:02,0,0,495.8192,0,465.4139,472.0865,462.4779,467.6158,中际旭创（暗盘）,0,2026-11-15,0,0,USD,,0";
var hq_str_btc_btcanthropicba="16:09:02,0,0,1345.49,0,1345.49,1349.99,1320,1334.23,ANTHROPIC（暗盘ipo）,10000,2026-11-15,0,825000000,USD,,0";
"""

@Test func darkSearchMatchesWholeCompanyOrUSTickerAndExcludesIPO() {
    #expect(SinaDarkPool.candidates(darkSearch, matching: nvda).map(\.code) == [
        "btc_btcnvda", "btc_btcnvdausdt", "btc_btcnvdax",
    ])
    let search = "var suggestdata=\"中际旭创,71,btczhongjiusdt,btczhongjiusdt,中际旭创（暗盘）;其他,71,btcother,btcother,中际旭创概念（暗盘）\";"
    #expect(SinaDarkPool.candidates(search, matching: zhongji).map(\.code) == ["btc_btczhongjiusdt"])
    var hShare = zhongji
    hShare.symbol = .hkStock("03308")
    #expect(SinaDarkPool.candidates(search, matching: hShare).isEmpty)
    var englishName = nvda
    englishName.name = "NVIDIA Corp"
    #expect(SinaDarkPool.candidates(darkSearch, matching: englishName).contains { $0.code == "btc_btcnvdax" })
    #expect(SinaDarkPool.candidates(darkSearch, matching: englishName).contains { $0.code == "btc_btcnvdausdt" })

    // Sina intermittently names US *usdt dark pools "<TICKER>USDT" with category 5 (never crypto category 1).
    let flappedSearch = """
    var suggestdata="BTCNVDAUSDT,71,btcnvdausdt,btcnvdausdt,NVDAUSDT,,NVDAUSDT,99,1,,165.41,,5;BTCNVDAUSDT1,71,btcnvdausdt,btcnvdausdt,NVDAUSDT,,NVDAUSDT,99,1,,165.41,,1";
    """
    #expect(SinaDarkPool.candidates(flappedSearch, matching: nvda).map(\.code) == ["btc_btcnvdausdt"])
    let cryptoCategoryOnly = """
    var suggestdata="BTCNVDAUSDT,71,btcnvdausdt,btcnvdausdt,NVDAUSDT,,NVDAUSDT,99,1,,165.41,,1";
    """
    #expect(SinaDarkPool.candidates(cryptoCategoryOnly, matching: nvda).isEmpty)

    let flappedQuote = """
    var hq_str_btc_btcnvdausdt="16:09:02,0,0,159.9800,0,159.9700,161.6100,157.6500,159.7800,NVDAUSDT,0,2026-11-15,0,0,USD,,0";
    var hq_str_btc_btcatomusdt="16:09:02,0,0,1.284,0,1.284,1.3,1.2,1.25,阿童木,0,2026-11-15,0,0,USD,,0";
    """
    let parsedFlapped = SinaDarkPool.parse(flappedQuote)
    #expect(parsedFlapped["btc_btcnvdausdt"]?.info.isUTC0Baseline == true)
    #expect(parsedFlapped["btc_btcatomusdt"] == nil)
    #expect(SinaDarkPool.matches(name: "NVDAUSDT", code: "btc_btcnvdausdt", quote: nvda, last: 159.78))
    #expect(!SinaDarkPool.matches(name: "NVDAUSDT", code: "btc_btcnvdausdt", quote: nvda, last: 5.0))
}

@Test func darkParserUsesLatestRatherThanSearchReferenceAndKeepsMetadata() throws {
    let parsed = SinaDarkPool.parse(darkQuotes)
    let snapshot = try #require(parsed["btc_btczhongjiusdt"])
    let quote = snapshot.overlay(zhongji)
    #expect(quote.last == 467.6158)
    #expect(abs(quote.change - (467.6158 - 495.8192)) < 0.000001)
    #expect(abs(quote.changePercent - (467.6158 / 495.8192 - 1) * 100) < 0.000001)
    #expect(quote.symbol == zhongji.symbol)
    #expect(quote.name == zhongji.name)
    #expect(quote.darkPool?.volume == 0)
    #expect(quote.darkPool?.currency == "USD")
    #expect(quote.darkPool?.quotedAt == weekend.addingTimeInterval(-58))
    #expect(parsed["btc_btcanthropicba"] == nil)
}

@Test func darkPrefersFreshUSDTFeedThenLargestVolumeAndRejectsStalePrices() throws {
    let parsed = SinaDarkPool.parse(darkQuotes)
    let snapshots = ["btc_btcnvda", "btc_btcnvdausdt", "btc_btcnvdax"].compactMap { parsed[$0] }
    #expect(SinaDarkPool.best(snapshots, at: weekend)?.info.code == "btc_btcnvdausdt")
    #expect(SinaDarkPool.best(snapshots, at: weekend)?.info.isUTC0Baseline == true)
    #expect(SinaDarkPool.best(snapshots, at: weekend.addingTimeInterval(901)) == nil)
    #expect(SinaDarkPool.best(snapshots, at: weekend.addingTimeInterval(-120)) == nil)

    // Without a fresh *usdt feed, prefer largest volume (not turnover).
    let dexOnly = ["btc_btcnvda", "btc_btcnvdax"].compactMap { parsed[$0] }
    #expect(SinaDarkPool.best(dexOnly, at: weekend)?.info.code == "btc_btcnvda")
    #expect(SinaDarkPool.best(dexOnly, at: weekend)?.info.isUTC0Baseline == false)

    var staleUSDT = try #require(parsed["btc_btcnvdausdt"])
    staleUSDT.info.quotedAt = weekend.addingTimeInterval(-1800)
    #expect(SinaDarkPool.best([staleUSDT, dexOnly[0], dexOnly[1]], at: weekend)?.info.code == "btc_btcnvda")

    var staleDex = try #require(parsed["btc_btcnvda"])
    staleDex.info.quotedAt = weekend.addingTimeInterval(-1800)
    #expect(SinaDarkPool.best([staleDex, dexOnly[1]], at: weekend)?.info.code == "btc_btcnvdax")

    var a = dexOnly[0]
    var b = dexOnly[1]
    a.info.volume = 0
    b.info.volume = 0
    #expect(SinaDarkPool.best([a, b], at: weekend)?.info.code == SinaDarkPool.best([b, a], at: weekend)?.info.code)
}

@Test func utc0BaselineParserMatchesShanghai0800BoundaryAndHandlesPreRollover() throws {
    let json = """
    {"result":{"status":{"code":0},"data":[
      {"d":"2026-11-15 00:00:00","o":"160","h":"162","l":"159","c":"161.50","v":"10","a":"1600"},
      {"d":"2026-11-15 07:00:00","o":"161","h":"162","l":"160","c":"160.20","v":"10","a":"1600"},
      {"d":"2026-11-15 08:00:00","o":"160.20","h":"161","l":"159.5","c":"159.98","v":"10","a":"1600"},
      {"d":"2026-11-15 09:00:00","o":"159.98","h":"161","l":"159","c":"160.40","v":"10","a":"1600"}
    ]}}
    """.data(using: .utf8)!
    let exact = try #require(SinaDarkPool.parseUTC0Baseline(json, at: weekend))
    #expect(exact.price == 159.98)
    #expect(exact.exact == true)

    // 2026-11-16 03:00 CST == 2026-11-15 19:00 UTC still belongs to the 2026-11-15 UTC+0 day.
    let preRollover = ISO8601DateFormatter().date(from: "2026-11-15T19:00:00Z")!
    let stillSameDay = try #require(SinaDarkPool.parseUTC0Baseline(json, at: preRollover))
    #expect(stillSameDay.price == 159.98)
    #expect(stillSameDay.exact == true)

    let sparseJson = """
    {"result":{"status":{"code":0},"data":[
      {"d":"2026-11-15 07:00:00","o":"161","h":"162","l":"160","c":"160.20","v":"10","a":"1600"},
      {"d":"2026-11-15 09:00:00","o":"159.98","h":"161","l":"159","c":"160.40","v":"10","a":"1600"}
    ]}}
    """.data(using: .utf8)!
    let sparse = try #require(SinaDarkPool.parseUTC0Baseline(sparseJson, at: weekend))
    #expect(sparse.price == 160.20)
    #expect(sparse.exact == false)

    for invalid in ["", "{}", #"{"result":{"data":[]}}"#, #"{"result":{"data":[{"d":"2026-11-15 08:00:00","c":"0"}]}}"#] {
        #expect(SinaDarkPool.parseUTC0Baseline(invalid.data(using: .utf8)!, at: weekend) == nil)
    }
}

@Test func malformedDarkPricesAndMissingVolumesCannotReplaceNormalQuotes() {
    let valid = "16:09:02,0,0,160,0,160,170,150,159,英伟达（暗盘）,10,2026-11-15"
    for payload in ["", valid.replacingOccurrences(of: ",159,", with: ",nan,"),
                    valid.replacingOccurrences(of: ",159,", with: ",0,"),
                    valid.replacingOccurrences(of: ",160,", with: ",0,"),
                    valid.replacingOccurrences(of: ",10,2026", with: ",,2026"),
                    valid.replacingOccurrences(of: ",10,2026", with: ",-1,2026"),
                    valid.replacingOccurrences(of: "2026-11-15", with: "invalid")] {
        #expect(SinaDarkPool.parse("var hq_str_btc_btcnvda=\"\(payload)\";").isEmpty)
    }
}

@Test func darkEligibilityPreservesRegularPreAndPostMarketAndExcludesOtherAssets() {
    #expect(SinaDarkPool.eligible(nvda.symbol, at: weekend))
    #expect(SinaDarkPool.eligible(zhongji.symbol, at: weekend))
    for hour in [9, 15, 22] { // New York 04:00, 10:00, 17:00 in November.
        let date = ISO8601DateFormatter().date(from: String(format: "2026-11-16T%02d:00:00Z", hour))!
        #expect(!SinaDarkPool.eligible(nvda.symbol, at: date))
    }
    for symbol in [SymbolID.usETF("SPY"), .usIndex("NDX"), .crypto("BTC"), .metal("AUUSDO")] {
        #expect(!SinaDarkPool.eligible(symbol, at: weekend))
    }
}

@Test func darkMarkSurvivesCompactMenuBarTitle() {
    for style in [MenuBarTitleStyle.full, .compact] {
        let title = MenuBarTitle.text(name: "中际旭创", changePercent: -5.66, style: style, isDarkPool: true)
        #expect(title.contains("暗盘"))
        #expect(!MenuBarTitle.text(name: "中际旭创", changePercent: -5.66, style: style).contains("暗盘"))
    }
}

private let dexKline = """
{"result":{"status":{"code":0},"data":[{"d":"2026-11-15 00:00:00","c":"160.4013"},{"d":"2026-11-15 08:00:00","c":"159.0000"},{"d":"2026-11-15 09:00:00","c":"159.4951"}]}}
"""

@Suite(.serialized)
struct SinaDarkPoolServiceTests {
    @Test func refreshPrefersUsdtFeedFallsBackToAlignedDexAndReturnsToRegularAtOpen() async throws {
        let service = makeService()
        defer { service.session.invalidateAndCancel() }
        DarkPoolProtocol.state.configure(search: darkSearch, quotes: darkQuotes, kline: dexKline)

        // Fresh *usdt feed wins immediately and needs zero kline calls.
        let first = await service.quotes(for: [nvda.symbol], at: weekend)
        let firstQuote = try #require(first[nvda.symbol])
        #expect(firstQuote.darkPool?.code == "btc_btcnvdausdt")
        #expect(firstQuote.darkPool?.isUTC0Baseline == true)
        #expect(firstQuote.darkPool?.detail.contains("UTC+0") == true)
        #expect(DarkPoolProtocol.state.klineCount == 0)

        // When *usdt goes stale, fall back to highest-volume DEX and align baseline via 08:00 kline.
        let staleUsdtQuotes = darkQuotes.replacingOccurrences(of: "英伟达（暗盘）,0,2026-11-15", with: "英伟达（暗盘）,0,2026-11-14")
        DarkPoolProtocol.state.updateQuotes(staleUsdtQuotes)
        let second = await service.quotes(for: [nvda.symbol], at: weekend)
        let secondQuote = try #require(second[nvda.symbol])
        #expect(secondQuote.darkPool?.code == "btc_btcnvda")
        #expect(secondQuote.darkPool?.isUTC0Baseline == true)
        #expect(abs(secondQuote.change - (159.4951 - 159.0)) < 0.0001)
        #expect(abs(secondQuote.changePercent - (159.4951 / 159.0 - 1) * 100) < 0.0001)
        #expect(DarkPoolProtocol.state.klineCount == 1)

        // Cached baseline avoids repeat kline fetches while fresh DEX volumes are still re-compared.
        let third = await service.quotes(for: [nvda.symbol], at: weekend)
        #expect(third[nvda.symbol]?.darkPool?.code == "btc_btcnvda")
        #expect(DarkPoolProtocol.state.klineCount == 1)
        DarkPoolProtocol.state.updateQuotes(staleUsdtQuotes.replacingOccurrences(of: "NVDAx（英伟达暗盘）,50,", with: "NVDAx（英伟达暗盘）,200000,"))
        let fourth = await service.quotes(for: [nvda.symbol], at: weekend)
        #expect(fourth[nvda.symbol]?.darkPool?.code == "btc_btcnvdax")
        #expect(DarkPoolProtocol.state.klineCount == 2)
        #expect(DarkPoolProtocol.state.searchCount == 1)

        let open = ISO8601DateFormatter().date(from: "2026-11-16T15:00:00Z")!
        let regular = await service.quotes(for: [nvda.symbol], at: open)
        #expect(regular[nvda.symbol]?.darkPool == nil)
        #expect(regular[nvda.symbol]?.last == 162.85)
        #expect(DarkPoolProtocol.state.searchCount == 1)
    }

    @Test func dexFallbackKeepsSinaBaselineWhenKlineFailsAndProbesUsdtForUSTicker() async throws {
        let service = makeService()
        defer { service.session.invalidateAndCancel() }
        // Search omits btcnvdausdt (like short tickers such as MU); service still probes btc_btcnvdausdt.
        let searchWithoutUsdt = """
        var suggestdata="BTCNVDA,71,btcnvda,btcnvda,NVDA（英伟达暗盘）;BTCNVDAX,71,btcnvdax,btcnvdax,NVDAx（英伟达暗盘）";
        """
        DarkPoolProtocol.state.configure(search: searchWithoutUsdt, quotes: darkQuotes, kline: "HTTP_FAILURE")
        let probed = await service.overlayDarkPool(on: [nvda.symbol: nvda], at: weekend)
        #expect(probed[nvda.symbol]?.darkPool?.code == "btc_btcnvdausdt")
        #expect(DarkPoolProtocol.state.lastQuoteURL?.contains("btc_btcnvdausdt") == true)

        // When *usdt is absent and kline fails, DEX falls back cleanly to Sina's own f[3] baseline.
        let dexOnlyQuotes = darkQuotes.replacingOccurrences(of: "英伟达（暗盘）,0,2026-11-15", with: "英伟达（暗盘）,0,2026-11-14")
        DarkPoolProtocol.state.updateQuotes(dexOnlyQuotes)
        let fallback = await service.overlayDarkPool(on: [nvda.symbol: nvda], at: weekend)
        let quote = try #require(fallback[nvda.symbol])
        #expect(quote.darkPool?.code == "btc_btcnvda")
        #expect(quote.darkPool?.isUTC0Baseline == false)
        #expect(abs(quote.change - (159.4951 - 160.4013)) < 0.0001)
    }

    @Test func failuresEmptyAndStaleDataPreserveOriginalQuote() async {
        for body in ["", darkQuotes.replacingOccurrences(of: "2026-11-15", with: "2026-11-14"), "HTTP_FAILURE"] {
            let service = makeService()
            DarkPoolProtocol.state.configure(search: darkSearch, quotes: body)
            let result = await service.overlayDarkPool(on: [nvda.symbol: nvda], at: weekend)
            #expect(result[nvda.symbol] == nvda)
            service.session.invalidateAndCancel()
        }
        let service = makeService()
        defer { service.session.invalidateAndCancel() }
        DarkPoolProtocol.state.configure(search: "HTTP_FAILURE", quotes: darkQuotes)
        #expect(await service.overlayDarkPool(on: [nvda.symbol: nvda], at: weekend)[nvda.symbol] == nvda)
        #expect(await service.overlayDarkPool(on: [nvda.symbol: nvda], at: weekend)[nvda.symbol] == nvda)
        #expect(DarkPoolProtocol.state.searchCount == 1)
    }

    private func makeService() -> QuoteService {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [DarkPoolProtocol.self]
        return QuoteService(session: URLSession(configuration: config))
    }
}

private final class DarkPoolProtocol: URLProtocol, @unchecked Sendable {
    static let state = State()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let url = request.url!
        let body = Self.state.response(for: url)
        if body == "HTTP_FAILURE" {
            client?.urlProtocol(self, didFailWithError: URLError(.timedOut))
            return
        }
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let encoding: String.Encoding = url.host == "quotes.sina.cn"
            ? .utf8
            : String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body.data(using: encoding)!)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}

    final class State: @unchecked Sendable {
        private let lock = NSLock()
        private var search = ""
        private var quotes = ""
        private var kline = ""
        private var count = 0
        private var klines = 0
        private var quoteURL: String?
        var searchCount: Int { lock.withLock { count } }
        var klineCount: Int { lock.withLock { klines } }
        var lastQuoteURL: String? { lock.withLock { quoteURL } }
        func configure(search: String, quotes: String, kline: String = "") {
            lock.withLock {
                self.search = search
                self.quotes = quotes
                self.kline = kline
                count = 0
                klines = 0
                quoteURL = nil
            }
        }
        func updateQuotes(_ body: String) { lock.withLock { quotes = body } }
        func response(for url: URL) -> String {
            lock.withLock {
                if url.host == "suggest3.sinajs.cn" { count += 1; return search }
                if url.host == "hq.sinajs.cn" { quoteURL = url.absoluteString; return quotes }
                if url.host == "quotes.sina.cn" { klines += 1; return kline.isEmpty ? "HTTP_FAILURE" : kline }
                if url.host == "qt.gtimg.cn" {
                    var fields = Array(repeating: "0", count: 33)
                    fields[1] = "英伟达"; fields[3] = "162.85"; fields[31] = "-3.34"; fields[32] = "-2.01"
                    return "v_usNVDA=\"\(fields.joined(separator: "~"))\";"
                }
                return "HTTP_FAILURE"
            }
        }
    }
}
