import Foundation
import Testing
@testable import QuoteBarCore

@Test func tencentHFSpotGoldMapsToMetalXAU() {
    let body = #"v_hf_XAU="4633.49,-0.39,4633.49,4633.84,4696.59,4618.18,11:48:00,4651.59,4654.19,0,0,0,2026-08-25,伦敦金（现货黄金）";"#
    let quotes = TencentQuoteParser.parse(body)
    let gold = quotes.first { $0.symbol == SymbolID.metal("XAU") }
    #expect(gold?.name == "伦敦金（现货黄金）")
    #expect(gold?.last == 4633.49)
    #expect(gold?.changePercent == -0.39)
    #expect(abs((gold?.change ?? 0) - (4633.49 - 4651.59)) < 0.0001)
    #expect(gold?.source == .tencent)
    #expect(gold?.symbol.market == .metal)
    #expect(gold?.symbol.kind == .spot)
    #expect(gold?.shortDisplayName == "伦敦金")
}

@Test func tencentHFCOMEXGoldMapsToCanonicalGC00Y() {
    let body = #"v_hf_GC="4688.07,-0.21,4689.40,4689.80,4755.00,4670.50,11:46:02,4697.80,4710.10,0,2,3,2026-08-25,纽约黄金";"#
    let quotes = TencentQuoteParser.parse(body)
    let gold = quotes.first { $0.symbol == SymbolID.future("GC00Y", quoteMarket: 101) }
    #expect(gold?.name == "纽约黄金")
    #expect(gold?.last == 4688.07)
    #expect(gold?.shortDisplayName == "美黄金")
}

@Test func sinaHFSpotGoldIsMetalNotUSIndex() {
    let body = """
    var hq_str_hf_XAU="4633.05,4651.590,4633.05,4633.40,4696.59,4618.18,11:49:00,4651.59,4654.19,0,0,0,2026-08-25,伦敦金（现货黄金）";
    """
    let quotes = SinaQuoteParser.parse(body)
    #expect(quotes.first?.symbol == SymbolID.metal("XAU"))
    #expect(quotes.first?.last == 4633.05)
    #expect(abs((quotes.first?.change ?? 0) - (4633.05 - 4651.59)) < 0.0001)
    #expect(quotes.first?.symbol.isUSIndex == false)
}

@Test func sinaHFESstillMapsToSPXForPremarketOverlay() {
    let body = """
    var hq_str_hf_ES="7713.675,,7712.750,7713.000,7722.000,7698.250,18:15:45,7714.000,7714.000,0,7,18,2026-08-19,标普500指数期货,0";
    """
    let quotes = SinaQuoteParser.parse(body)
    #expect(quotes.first?.symbol == SymbolID.usIndex("SPX"))
    #expect(abs((quotes.first?.last ?? 0) - 7713.675) < 0.0001)
}

@Test func sinaNFShanghaiGoldContinuousMapsToAum() {
    let body = """
    var hq_str_nf_AU0="黄金连续,113000,1010.000,1015.380,1000.200,0.000,1004.320,1004.420,1004.360,0.000,999.860,1,3,201589.000,388531,沪,黄金,2026-08-25,1,,,,,,,,,1009.291,0.000,0,0.000,0,0.000,0,0.000,0,0.000,0,0.000,0,0.000,0,0.000,0";
    """
    let quotes = SinaQuoteParser.parse(body)
    #expect(quotes.first?.symbol == SymbolID.future("aum", quoteMarket: 113))
    #expect(quotes.first?.name == "黄金连续")
    #expect(quotes.first?.last == 1004.36)
    #expect(abs((quotes.first?.change ?? 0) - 4.5) < 0.0001)
    #expect(quotes.first?.shortDisplayName == "沪金")
}

@Test func sinaNFIndexFutureUsesNumericLayout() {
    let body = """
    var hq_str_nf_IF0="4510.000,4523.000,4488.000,4507.400,34108,153649402.200,148367.000,0.000,0.000,4963.800,4061.400,0.000,0.000,4526.400,4512.600,158088.000,4506.800,4,0.000,0,0.000,0,0.000,0,0.000,0,4507.800,6,0.000,0,0.000,0,0.000,0,0.000,0,2026-08-25,11:30:00,0,1,,,,,,,,,4504.791,沪深300指数期货连续";
    """
    let quotes = SinaQuoteParser.parse(body)
    #expect(quotes.first?.symbol == SymbolID.future("IFM", quoteMarket: 220))
    #expect(quotes.first?.last == 4507.4)
    #expect(abs((quotes.first?.change ?? 0) - (4507.4 - 4512.6)) < 0.0001)
    #expect(quotes.first?.name == "沪深300指数期货连续")
}

@Test func eastMoneyJSONMapsSpotGoldAndFutures() throws {
    let quotes = try EastMoneyQuoteParser.parse(FixtureLoader.data("eastmoney-quotes-metals.json"))
    let xau = try #require(quotes.first { $0.symbol == SymbolID.metal("XAU") })
    #expect(xau.name == "黄金/美元")
    #expect(xau.last == 4634.37)
    #expect(xau.change == -17.01)
    #expect(xau.changePercent == -0.37)
    #expect(xau.shortDisplayName == "伦敦金")

    let aum = try #require(quotes.first { $0.symbol.code == "aum" })
    #expect(aum.symbol.market == .qh)
    #expect(aum.symbol.kind == .future)
    #expect(aum.symbol.quoteMarket == 113)
    #expect(aum.last == 1004.36)

    let gc = try #require(quotes.first { $0.symbol.code == "GC00Y" })
    #expect(gc.symbol.quoteMarket == 101)
    #expect(gc.name == "COMEX黄金")
}

@Test func eastMoneySearchLondonGoldIsMetalNotAShare() throws {
    let parsed = try EastMoneySearchParser.parse(FixtureLoader.data("eastmoney-search-xau.json"))
    let hit = try #require(parsed.first)
    #expect(hit.symbol == SymbolID.metal("XAU"))
    #expect(hit.name == "黄金/美元")
    #expect(hit.symbol.market.family == .metal)
}

@Test func eastMoneySearchShanghaiGoldIsFutures() throws {
    let parsed = try EastMoneySearchParser.parse(FixtureLoader.data("eastmoney-search-aum.json"))
    let hit = try #require(parsed.first)
    #expect(hit.symbol == SymbolID.future("aum", quoteMarket: 113))
    #expect(hit.name == "沪金主连")
    #expect(hit.symbol.market.family == .futures)
}

@Test func eastMoneySearchDropsSectorBoards() throws {
    let json = Data(#"{"QuotationCodeTable":{"Data":[{"Code":"BK1617","Name":"黄金","PinYin":"HJ","SecurityTypeName":"板块","MktNum":"90","QuoteID":"90.BK1617","Classify":"BK"}]}}"#.utf8)
    let parsed = try EastMoneySearchParser.parse(json)
    #expect(parsed.isEmpty)
}

@Test func searchLondonGoldSpotAliasUsesTonghuashunAUUSDO() {
    let ranked = SearchResolver.resolve(query: "伦敦金现", tencent: [], eastMoney: [])
    let first = ranked.first
    #expect(first?.symbol == SymbolID.metal("AUUSDO"))
    #expect(first?.name == "伦敦金现")
}

@Test func searchAuusdoCodeAliasHitsLondonGoldSpot() {
    let ranked = SearchResolver.resolve(query: "auusdo", tencent: [], eastMoney: [])
    #expect(ranked.first?.symbol == SymbolID.metal("AUUSDO"))
}

@Test func searchLondonGoldMergesEastMoneyXAUButRanksAUUSDOFirst() throws {
    let em = try EastMoneySearchParser.parse(FixtureLoader.data("eastmoney-search-xau.json"))
    let ranked = SearchResolver.resolve(query: "伦敦金", tencent: [], eastMoney: em)
    let first = try #require(ranked.first)
    #expect(first.symbol == SymbolID.metal("AUUSDO"))
    #expect(ranked.contains { $0.symbol == SymbolID.metal("XAU") })
}

@Test func providerCodesForLondonGoldSpotAndShanghaiGold() {
    let spot = SymbolID.metal("AUUSDO")
    #expect(ProviderCodes.tonghuashunTimeCode(spot) == "218_AUUSDO")
    #expect(ProviderCodes.sinaListCode(spot) == nil)

    let xau = SymbolID.metal("XAU")
    #expect(ProviderCodes.tencentQuery(xau) == "hf_XAU")
    #expect(ProviderCodes.eastMoneySecID(xau) == "122.XAU")
    #expect(ProviderCodes.sinaListCode(xau) == "hf_XAU")
    #expect(ProviderCodes.tonghuashunTimeCode(xau) == nil)

    let aum = SymbolID.future("aum", quoteMarket: 113)
    #expect(ProviderCodes.eastMoneySecID(aum) == "113.aum")
    #expect(ProviderCodes.sinaListCode(aum) == "nf_AU0")

    let gc = SymbolID.future("GC00Y", quoteMarket: 101)
    #expect(ProviderCodes.tencentQuery(gc) == "hf_GC")
    #expect(ProviderCodes.eastMoneySecID(gc) == "101.GC00Y")
    #expect(ProviderCodes.sinaListCode(gc) == "hf_GC")
}

@Test func futuresAndMetalStayOnFullSourceChain() {
    #expect(QuoteSourceChain.sources(for: .metal("AUUSDO")) == [.tonghuashun])
    #expect(QuoteSourceChain.sources(for: .metal("XAU")) == [.tencent, .eastMoney, .sina])
    #expect(QuoteSourceChain.sources(for: .future("aum", quoteMarket: 113)) == [.tencent, .eastMoney, .sina])
}

@Test func tonghuashunTimePayloadMapsLondonGoldSpotAUUSDO() {
    let body = """
    quotebridge_v6_time_218_AUUSDO_last({"218_AUUSDO":{"name":"伦敦金现","open":1,"stop":0,"isTrading":1,"pre":"4679.740","date":"20260825","data":"0800,4679.740,0,4679.740,0;1213,4637.150,0,4637.150,0"}});
    """
    let quotes = TonghuashunQuoteParser.parse(body)
    let gold = quotes.first { $0.symbol == SymbolID.metal("AUUSDO") }
    #expect(gold?.name == "伦敦金现")
    #expect(gold?.last == 4637.15)
    #expect(abs((gold?.change ?? 0) - (4637.15 - 4679.74)) < 0.0001)
    #expect(gold?.source == .tonghuashun)
    #expect(gold?.shortDisplayName == "伦敦金现")
}

@Test func watchlistGroupsFuturesAndMetalsSeparately() {
    var list = Watchlist(items: [
        .shIndex("000001"),
        .metal("AUUSDO"),
        .future("aum", quoteMarket: 113),
        .usIndex("NDX"),
    ])
    let groups = list.groups()
    #expect(groups.map(\.family) == [.cn, .us, .futures, .metal])
    #expect(groups.first { $0.family == .metal }?.items == [.metal("AUUSDO")])
    #expect(groups.first { $0.family == .futures }?.items == [.future("aum", quoteMarket: 113)])

    list.move(.future("aum", quoteMarket: 113), by: -1)
    #expect(list.groups().first { $0.family == .futures }?.items == [.future("aum", quoteMarket: 113)])
}

@Test func metalSessionFollowsNewYorkAlmostAroundTheClock() {
    #expect(MarketSession.isOpen(.metal, at: weekday(tz: newYork, hour: 10, minute: 0)))
    #expect(MarketSession.isOpen(.metal, at: weekday(tz: newYork, hour: 21, minute: 0)))
    #expect(!MarketSession.isOpen(.metal, at: weekday(tz: newYork, hour: 17, minute: 30)))
    #expect(!MarketSession.isOpen(.metal, at: saturday(tz: newYork, hour: 10, minute: 0)))
    #expect(MarketSession.phase(.metal, at: sunday(tz: newYork, hour: 18, minute: 0)) == .regular)
    #expect(MarketSession.phase(.metal, at: sunday(tz: newYork, hour: 17, minute: 0)) == .closed)
}

@Test func domesticFuturesIncludeNightSessionAndSundayOpen() {
    #expect(MarketSession.isOpen(.qh, at: weekday(tz: shanghai, hour: 10, minute: 0)))
    #expect(MarketSession.isOpen(.qh, at: weekday(tz: shanghai, hour: 21, minute: 30)))
    #expect(MarketSession.isOpen(.qh, at: weekday(tz: shanghai, hour: 1, minute: 0)))
    #expect(!MarketSession.isOpen(.qh, at: weekday(tz: shanghai, hour: 12, minute: 0)))
    #expect(MarketSession.isOpen(.qh, at: saturday(tz: shanghai, hour: 1, minute: 0)))
    #expect(!MarketSession.isOpen(.qh, at: saturday(tz: shanghai, hour: 10, minute: 0)))
    #expect(MarketSession.phase(.qh, at: sunday(tz: shanghai, hour: 21, minute: 0)) == .regular)
    #expect(MarketSession.phase(.qh, at: sunday(tz: shanghai, hour: 10, minute: 0)) == .closed)
}

@Test func symbolIdentityIgnoresQuoteMarketSoSourcesCanMerge() {
    let fromSearch = SymbolID.future("aum", quoteMarket: 113)
    let fromParser = SymbolID(market: .qh, code: "aum", kind: .future, quoteMarket: nil)
    #expect(fromSearch == fromParser)
    #expect(fromSearch.hashValue == fromParser.hashValue)
}

private let shanghai = TimeZone(identifier: "Asia/Shanghai")!
private let newYork = TimeZone(identifier: "America/New_York")!

private func weekday(tz: TimeZone, hour: Int, minute: Int) -> Date {
    date(tz: tz, year: 2026, month: 8, day: 18, hour: hour, minute: minute)
}

private func saturday(tz: TimeZone, hour: Int, minute: Int) -> Date {
    date(tz: tz, year: 2026, month: 8, day: 22, hour: hour, minute: minute)
}

private func sunday(tz: TimeZone, hour: Int, minute: Int) -> Date {
    date(tz: tz, year: 2026, month: 8, day: 23, hour: hour, minute: minute)
}

private func date(tz: TimeZone, year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = tz
    return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}
