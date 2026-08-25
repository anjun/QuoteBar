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
    let etf = SearchHit(symbol: .usStock("BTC"), name: "Grayscale Bitcoin Mini Trust ET", pinyin: "btc")
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

@Test func searchChineseBitcoinNameHitsCrypto() {
    let ranked = SearchResolver.resolve(query: "比特币", tencent: [], eastMoney: [])
    #expect(ranked.first?.symbol == SymbolID.crypto("BTC"))
    #expect(ranked.first?.name == "比特币")
}

@Test func searchEthereumJianpinAndTicker() {
    #expect(SearchResolver.resolve(query: "eth", tencent: [], eastMoney: []).first?.symbol == SymbolID.crypto("ETH"))
    #expect(SearchResolver.resolve(query: "以太坊", tencent: [], eastMoney: []).first?.symbol == SymbolID.crypto("ETH"))
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
