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

@Test func stockAndETFChainIncludesSinaAsLastResort() {
    #expect(QuoteSourceChain.sources(for: SymbolID.usStock("AAPL")) == [.tencent, .eastMoney, .sina])
    #expect(QuoteSourceChain.sources(for: SymbolID.hkStock("00700")) == [.tencent, .eastMoney, .sina])
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
