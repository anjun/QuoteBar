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
