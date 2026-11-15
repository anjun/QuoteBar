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

@Test func darkSelectsLargestVolumeNotTurnoverAndRejectsStalePrices() throws {
    let parsed = SinaDarkPool.parse(darkQuotes)
    let snapshots = ["btc_btcnvda", "btc_btcnvdausdt", "btc_btcnvdax"].compactMap { parsed[$0] }
    #expect(SinaDarkPool.best(snapshots, at: weekend)?.info.code == "btc_btcnvda")
    #expect(SinaDarkPool.best(snapshots, at: weekend.addingTimeInterval(901)) == nil)
    #expect(SinaDarkPool.best(snapshots, at: weekend.addingTimeInterval(-120)) == nil)
    var stale = try #require(parsed["btc_btcnvda"])
    stale.info.quotedAt = weekend.addingTimeInterval(-1800)
    #expect(SinaDarkPool.best([stale, snapshots[2]], at: weekend)?.info.code == "btc_btcnvdax")
    var a = snapshots[0]
    var b = snapshots[1]
    a.info.volume = 0
    b.info.volume = 0
    #expect(SinaDarkPool.best([a, b], at: weekend)?.info.code == SinaDarkPool.best([b, a], at: weekend)?.info.code)
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

@Suite(.serialized)
struct SinaDarkPoolServiceTests {
    @Test func refreshComparesVolumesAgainCachesOnlyCandidatesAndReturnsToRegularAtOpen() async throws {
        let service = makeService()
        defer { service.session.invalidateAndCancel() }
        DarkPoolProtocol.state.configure(search: darkSearch, quotes: darkQuotes)
        let first = await service.quotes(for: [nvda.symbol], at: weekend)
        #expect(first[nvda.symbol]?.darkPool?.code == "btc_btcnvda")
        DarkPoolProtocol.state.updateQuotes(darkQuotes.replacingOccurrences(of: "暗盘）,0,2026", with: "暗盘）,200000,2026"))
        let second = await service.quotes(for: [nvda.symbol], at: weekend)
        #expect(second[nvda.symbol]?.darkPool?.code == "btc_btcnvdausdt")
        #expect(DarkPoolProtocol.state.searchCount == 1)
        let open = ISO8601DateFormatter().date(from: "2026-11-16T15:00:00Z")!
        let regular = await service.quotes(for: [nvda.symbol], at: open)
        #expect(regular[nvda.symbol]?.darkPool == nil)
        #expect(regular[nvda.symbol]?.last == 162.85)
        #expect(DarkPoolProtocol.state.searchCount == 1)
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
        let body = Self.state.response(for: request.url!)
        if body == "HTTP_FAILURE" {
            client?.urlProtocol(self, didFailWithError: URLError(.timedOut))
            return
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body.data(using: encoding)!)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}

    final class State: @unchecked Sendable {
        private let lock = NSLock()
        private var search = ""
        private var quotes = ""
        private var count = 0
        var searchCount: Int { lock.withLock { count } }
        func configure(search: String, quotes: String) {
            lock.withLock { self.search = search; self.quotes = quotes; count = 0 }
        }
        func updateQuotes(_ body: String) { lock.withLock { quotes = body } }
        func response(for url: URL) -> String {
            lock.withLock {
                if url.host == "suggest3.sinajs.cn" { count += 1; return search }
                if url.host == "hq.sinajs.cn" { return quotes }
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
