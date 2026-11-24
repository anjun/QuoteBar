import Foundation
import Testing
@testable import QuoteBarCore

@Test func usIndexChainIsTencentThenEastMoneyNeverSina() {
    let ndx = SymbolID.usIndex("NDX")
    let dji = SymbolID.usIndex("DJI")
    let spx = SymbolID.usIndex("SPX")
    #expect(QuoteSourceChain.sources(for: ndx) == [.tencent, .eastMoney])
    #expect(QuoteSourceChain.sources(for: dji) == [.tencent, .eastMoney])
    #expect(QuoteSourceChain.sources(for: spx) == [.tencent, .eastMoney])
    #expect(!QuoteSourceChain.sources(for: ndx).contains(.sina))
}

@Test func hkChainUsesSinaOnlyNeverTencentOrEastMoney() {
    let stock = SymbolID.hkStock("00700")
    let index = SymbolID.hkIndex("HSI")
    let tech = SymbolID.hkIndex("HSTECH")
    let etf = SymbolID(market: .hk, code: "02800", kind: .etf)
    for symbol in [stock, index, tech, etf] {
        #expect(QuoteSourceChain.sources(for: symbol) == [.sina])
    }

    let tencent = Quote(symbol: stock, name: "腾讯控股", last: 341.80, change: -2.20, changePercent: -0.64, source: .tencent)
    let eastMoney = Quote(symbol: stock, name: "腾讯控股", last: 341.70, change: -2.30, changePercent: -0.67, source: .eastMoney)
    let sina = Quote(symbol: stock, name: "腾讯控股", last: 341.00, change: -3.00, changePercent: -0.872, source: .sina)

    let withSina = QuoteBatchResolver.resolve(
        symbols: [stock],
        tencent: [stock: tencent],
        eastMoney: [stock: eastMoney],
        sina: [stock: sina]
    )
    #expect(withSina[stock]?.source == .sina)
    #expect(withSina[stock]?.last == 341.00)

    let withoutSina = QuoteBatchResolver.resolve(
        symbols: [stock],
        tencent: [stock: tencent],
        eastMoney: [stock: eastMoney],
        sina: nil
    )
    #expect(withoutSina[stock] == nil)
}

@Test func stockAndETFChainIncludesSinaAsLastResort() {
    #expect(QuoteSourceChain.sources(for: SymbolID.usStock("AAPL")) == [.tencent, .eastMoney, .sina])
    #expect(QuoteSourceChain.sources(for: SymbolID.shETF("510300")) == [.tencent, .eastMoney, .sina])
    #expect(QuoteSourceChain.sources(for: SymbolID.shIndex("000001")) == [.tencent, .eastMoney, .sina])
}

@Test func failedTencentYieldsEastMoneyQuote() {
    let aapl = SymbolID.usStock("AAPL")
    let em = Quote(symbol: aapl, name: "苹果", last: 305.59, change: -0.34, changePercent: -0.11, source: .eastMoney)
    let sina = Quote(symbol: aapl, name: "苹果", last: 1, change: 1, changePercent: 1, source: .sina)

    let resolved = QuoteBatchResolver.resolve(
        symbols: [aapl],
        tencent: nil,
        eastMoney: [aapl: em],
        sina: [aapl: sina]
    )
    #expect(resolved[aapl]?.source == .eastMoney)
    #expect(resolved[aapl]?.last == 305.59)
}

@Test func sinaFillsStockButNotUSIndexAfterEarlierSourcesFail() {
    let aapl = SymbolID.usStock("AAPL")
    let ndx = SymbolID.usIndex("NDX")
    let emNDX = Quote(symbol: ndx, name: "纳斯达克100", last: 26644.91, change: -84.25, changePercent: -0.32, source: .eastMoney)
    let sinaAAPL = Quote(symbol: aapl, name: "苹果", last: 305.59, change: -0.34, changePercent: -0.11, source: .sina)
    let sinaNDX = Quote(symbol: ndx, name: "假指数", last: 1, change: 1, changePercent: 1, source: .sina)

    let resolved = QuoteBatchResolver.resolve(
        symbols: [aapl, ndx],
        tencent: nil,
        eastMoney: [ndx: emNDX],
        sina: [aapl: sinaAAPL, ndx: sinaNDX]
    )

    #expect(resolved[aapl]?.source == .sina)
    #expect(resolved[ndx]?.source == .eastMoney)
    #expect(resolved[ndx]?.last == 26644.91)
    #expect(resolved[ndx]?.name != "假指数")
}

@Test func firstSuccessfulSourceWinsPerSymbol() {
    let spy = SymbolID.usETF("SPY")
    let tencent = Quote(symbol: spy, name: "SPY", last: 772.67, change: -3.67, changePercent: -0.47, source: .tencent)
    let em = Quote(symbol: spy, name: "SPY", last: 1, change: 0, changePercent: 0, source: .eastMoney)

    let resolved = QuoteBatchResolver.resolve(
        symbols: [spy],
        tencent: [spy: tencent],
        eastMoney: [spy: em],
        sina: [:]
    )
    #expect(resolved[spy]?.source == .tencent)
    #expect(resolved[spy]?.last == 772.67)
}

@Test func sinaExtendedHoursOverlayReplacesUSLastKeepsTencentName() {
    let skhy = SymbolID.usStock("SKHY")
    let ndx = SymbolID.usIndex("NDX")
    let tencentSKHY = Quote(symbol: skhy, name: "SK海力士", last: 155.62, change: -15.76, changePercent: -9.20, source: .tencent)
    let tencentNDX = Quote(symbol: ndx, name: "纳斯达克100", last: 29490.96, change: -504.42, changePercent: -1.68, source: .tencent)
    let sinaSKHY = Quote(symbol: skhy, name: "SK海力士", last: 161.80, change: 6.18, changePercent: 3.97, source: .sina)
    let sinaNDX = Quote(symbol: ndx, name: "纳斯达克100盘前交易指数", last: 29591.75, change: -403.63, changePercent: -1.35, source: .sina)

    let resolved = QuoteBatchResolver.resolve(
        symbols: [skhy, ndx],
        tencent: [skhy: tencentSKHY, ndx: tencentNDX],
        eastMoney: nil,
        sina: [skhy: sinaSKHY, ndx: sinaNDX],
        sinaOverlaysExisting: true
    )

    #expect(resolved[skhy]?.name == "SK海力士")
    #expect(resolved[skhy]?.last == 161.80)
    #expect(resolved[skhy]?.changePercent == 3.97)
    #expect(resolved[skhy]?.source == .sina)
    #expect(resolved[ndx]?.name == "纳斯达克100")
    #expect(resolved[ndx]?.last == 29591.75)
    #expect(resolved[ndx]?.source == .sina)
}

@Test func sinaListCodeUsesPreMarketIndicatorsForUSIndices() {
    #expect(ProviderCodes.sinaListCode(SymbolID.usStock("SKHY")) == "gb_skhy")
    #expect(ProviderCodes.sinaListCode(SymbolID.usIndex("NDX")) == nil)
    #expect(ProviderCodes.sinaListCode(SymbolID.usIndex("NDX"), phase: .preMarket) == "gb_qmi")
    #expect(ProviderCodes.sinaListCode(SymbolID.usIndex("NDX"), phase: .afterHours) == "gb_qiv")
    #expect(ProviderCodes.sinaListCode(SymbolID.usIndex("SPX"), phase: .preMarket) == "hf_ES")
    #expect(ProviderCodes.sinaListCode(SymbolID.usIndex("DJI"), phase: .afterHours) == "hf_YM")
}

@Suite(.serialized)
struct HKQuoteServiceTests {
    @Test func hkQuotesRequestOnlySinaAndNeverFallBackToTencentOrEastMoney() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [HKCaptureProtocol.self]
        let service = QuoteService(session: URLSession(configuration: config))
        defer { service.session.invalidateAndCancel() }

        let trading = ISO8601DateFormatter().date(from: "2026-11-24T07:20:00Z")! // 15:20 HKT
        let symbols: [SymbolID] = [.hkStock("00700"), .hkIndex("HSI"), .hkIndex("HSTECH")]
        HKCaptureProtocol.state.reset(failSina: false)
        let quotes = await service.quotes(for: symbols, at: trading)
        #expect(HKCaptureProtocol.state.hosts == ["hq.sinajs.cn"])
        #expect(quotes[.hkStock("00700")]?.source == .sina)
        #expect(quotes[.hkStock("00700")]?.last == 341.0)
        #expect(quotes[.hkIndex("HSI")]?.source == .sina)
        #expect(quotes[.hkIndex("HSTECH")]?.source == .sina)

        HKCaptureProtocol.state.reset(failSina: true)
        let failed = await service.quotes(for: symbols, at: trading)
        #expect(HKCaptureProtocol.state.hosts == ["hq.sinajs.cn"])
        #expect(failed.isEmpty)
    }
}

private final class HKCaptureProtocol: URLProtocol, @unchecked Sendable {
    static let state = State()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let url = request.url!
        let fail = Self.state.record(url)
        if fail || url.host != "hq.sinajs.cn" {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
            return
        }
        let body = """
        var hq_str_rt_hk00700="TENCENT,腾讯控股,352.000,344.000,353.000,340.600,341.000,-3.000,-0.872,341.000,341.200,8431981557.840,24435268,12.404,0.000,631.641,333.000,2026/11/24,15:24:57";
        var hq_str_rt_hkHSI="HSI,恒生指数,22627.290,22383.740,22647.500,22183.160,22243.939,-139.800,-0.620,0.000,0.000,182827321.465,11000113821,0.000,0.000,28056.100,21998.050,2026/11/24,15:24:57";
        var hq_str_rt_hkHSTECH="HSTECH,恒生科技指数,3579.830,3508.000,3603.700,3439.340,3468.580,-39.420,-1.120,0.000,0.000,55166958.317,1503963213,0.000,0.000,6001.020,3395.380,2026/11/24,15:24:56";
        """
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body.data(using: encoding)!)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}

    final class State: @unchecked Sendable {
        private let lock = NSLock()
        private var recordedHosts: [String] = []
        private var shouldFailSina = false
        var hosts: [String] { lock.withLock { recordedHosts } }
        func reset(failSina: Bool) {
            lock.withLock { recordedHosts = []; shouldFailSina = failSina }
        }
        func record(_ url: URL) -> Bool {
            lock.withLock {
                if let host = url.host { recordedHosts.append(host) }
                return shouldFailSina
            }
        }
    }
}
