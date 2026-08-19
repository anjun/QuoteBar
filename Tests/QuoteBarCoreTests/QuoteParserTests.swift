import Foundation
import Testing
@testable import QuoteBarCore

@Test func tencentFrozenPayloadMapsAShareHKUSIndexAndETFFields() throws {
    let quotes = TencentQuoteParser.parse(try FixtureLoader.string("tencent-frozen.txt"))

    let sh = try #require(quotes.first { $0.symbol == SymbolID.shIndex("000001") })
    #expect(sh.name == "上证指数")
    #expect(sh.last == 3956.44)
    #expect(sh.change == -26.21)
    #expect(sh.changePercent == -0.66)
    #expect(sh.source == .tencent)

    let hk = try #require(quotes.first { $0.symbol == SymbolID.hkStock("00700") })
    #expect(hk.name == "腾讯控股")
    #expect(hk.last == 439.0)
    #expect(hk.change == -7.4)
    #expect(hk.changePercent == -1.66)

    let us = try #require(quotes.first { $0.symbol == SymbolID.usStock("AAPL") })
    #expect(us.name == "苹果")
    #expect(us.last == 305.59)
    #expect(us.change == -0.34)
    #expect(us.changePercent == -0.11)

    let etf = try #require(quotes.first { $0.symbol == SymbolID.shETF("510300") })
    #expect(etf.last == 4.754)
    #expect(etf.change == -0.047)
    #expect(etf.changePercent == -0.98)

    let spy = try #require(quotes.first { $0.symbol == SymbolID.usETF("SPY") })
    #expect(spy.last == 772.67)
    #expect(spy.change == -3.67)

    let ndx = try #require(quotes.first { $0.symbol == SymbolID.usIndex("NDX") })
    #expect(ndx.last == 29995.38)
    #expect(ndx.change == -50.76)
    #expect(ndx.symbol.isUSIndex)
}

@Test func tencentLiveCapturePopulatesAllSeedMarkets() throws {
    let quotes = TencentQuoteParser.parse(try FixtureLoader.string("tencent-quotes.txt"))
    let byCode = Dictionary(uniqueKeysWithValues: quotes.map { ($0.symbol.code, $0) })

    for code in ["000001", "399001", "000300", "510300", "00700", "HSI", "AAPL", "SPY", "NDX", "DJI"] {
        let quote = try #require(byCode[code], "missing \(code)")
        #expect(quote.last != 0, "\(code) last")
        #expect(!quote.name.isEmpty, "\(code) name")
        #expect(quote.changePercent != 0 || quote.change != 0 || quote.last > 0)
    }
}

@Test func eastMoneyJSONPopulatesAHKUSIndexAndETF() throws {
    let quotes = try EastMoneyQuoteParser.parse(FixtureLoader.data("eastmoney-quotes.json"))
    let byCode = Dictionary(uniqueKeysWithValues: quotes.map { ($0.symbol.code, $0) })

    let sh = try #require(byCode["000001"])
    #expect(sh.name == "上证指数")
    #expect(sh.last == 3963.85)
    #expect(sh.change == -18.8)
    #expect(sh.changePercent == -0.47)
    #expect(sh.source == .eastMoney)
    #expect(sh.symbol.market == .sh)

    let tencent = try #require(byCode["00700"])
    #expect(tencent.symbol.market == .hk)
    #expect(tencent.last == 438.6)

    let aapl = try #require(byCode["AAPL"])
    #expect(aapl.symbol.market == .us)
    #expect(aapl.last == 305.59)

    let spy = try #require(byCode["SPY"])
    #expect(spy.symbol.kind == .etf)

    let hs300 = try #require(byCode["510300"])
    #expect(hs300.symbol.kind == .etf)

    let ndx = try #require(byCode["NDX"])
    #expect(ndx.symbol.isUSIndex)
    #expect(ndx.last == 26644.91)

    let dji = try #require(byCode["DJI"])
    #expect(dji.symbol.isUSIndex)

    let hsi = try #require(byCode["HSI"])
    #expect(hsi.symbol.market == .hk)
    #expect(hsi.symbol.kind == .index)
}

@Test func sinaFrozenPayloadMapsAShareHKUSAndETF() throws {
    let quotes = SinaQuoteParser.parse(
        try FixtureLoader.string("sina-frozen.txt"),
        at: usRegularHours
    )

    let sh = try #require(quotes.first { $0.symbol.code == "000001" })
    #expect(sh.name == "上证指数")
    #expect(abs(sh.last - 3959.0386) < 0.0001)
    #expect(abs(sh.change - (3959.0386 - 3982.6535)) < 0.0001)
    #expect(sh.source == .sina)

    let hk = try #require(quotes.first { $0.symbol.code == "00700" })
    #expect(hk.name == "腾讯控股")
    #expect(hk.last == 439.2)
    #expect(hk.change == -7.2)
    #expect(abs(hk.changePercent - (-1.613)) < 0.0001)

    let aapl = try #require(quotes.first { $0.symbol.code == "AAPL" })
    #expect(aapl.last == 305.59)
    #expect(aapl.change == -0.34)
    #expect(aapl.changePercent == -0.11)

    let etf = try #require(quotes.first { $0.symbol.code == "510300" })
    #expect(etf.last == 4.756)
    #expect(abs(etf.change - (4.756 - 4.801)) < 0.0001)

    let spy = try #require(quotes.first { $0.symbol.code == "SPY" })
    #expect(spy.last == 772.67)
    #expect(spy.change == -3.67)
}

@Test func sinaLiveCapturePopulatesStocksAndETFs() throws {
    let quotes = SinaQuoteParser.parse(
        try FixtureLoader.string("sina-quotes.txt"),
        at: usRegularHours
    )
    #expect(quotes.contains { $0.symbol.code == "000001" && $0.last != 0 })
    #expect(quotes.contains { $0.symbol.code == "00700" && $0.last != 0 })
    #expect(quotes.contains { $0.symbol.code == "AAPL" && $0.last != 0 })
    #expect(quotes.contains { $0.symbol.code == "510300" && $0.last != 0 })
    #expect(quotes.contains { $0.symbol.code == "SPY" && $0.last != 0 })
}

@Test func sinaUSPreMarketUsesExtendedHoursPrintNotPreviousClose() {
    let body = """
    var hq_str_gb_skhy="SK海力士,155.6200,-9.20,2026-08-19 18:14:25,-15.7600,161.7800,163.8800,154.5302,194.8000,124.8000,22821889,23719132,0,0.00,--,0.00,0.08,0.00,0.00,7288654771,0,161.8000,3.97,6.18,Aug 19 06:14AM EDT,Aug 18 04:00PM EDT,171.3800,5804891,1,2026,0,166.9900,150.0200,0,165.0000,155.6200";
    """
    let pre = SinaQuoteParser.parse(body, at: usPreMarket)
    #expect(pre.first?.symbol == SymbolID.usStock("SKHY"))
    #expect(pre.first?.last == 161.8)
    #expect(pre.first?.change == 6.18)
    #expect(pre.first?.changePercent == 3.97)

    let regular = SinaQuoteParser.parse(body, at: usRegularHours)
    #expect(regular.first?.last == 155.62)
    #expect(regular.first?.change == -15.76)
    #expect(regular.first?.changePercent == -9.20)
}

@Test func sinaNDXPreMarketMapsQMIIndicator() {
    let body = """
    var hq_str_gb_qmi="纳斯达克100盘前交易指数,29591.7547,-1.35,2026-08-19 15:55:43,-403.6266,29628.7762,29646.6766,29569.7659,30758.2441,23033.9824,0,0,0,0.00,--,0.00,0.00,0.00,0.00,0,0,0.0000,0.00,0.00,,Aug 18 09:29AM EDT,29995.3813,0,1,2026,0,0,0,0,0,0";
    """
    let quotes = SinaQuoteParser.parse(body, at: usPreMarket)
    #expect(quotes.first?.symbol == SymbolID.usIndex("NDX"))
    #expect(abs((quotes.first?.last ?? 0) - 29591.7547) < 0.0001)
    #expect(quotes.first?.changePercent == -1.35)
}

@Test func sinaSPXPreMarketMapsESFutures() {
    let body = """
    var hq_str_hf_ES="7713.675,,7712.750,7713.000,7722.000,7698.250,18:15:45,7714.000,7714.000,0,7,18,2026-08-19,标普500指数期货,0";
    """
    let quotes = SinaQuoteParser.parse(body, at: usPreMarket)
    #expect(quotes.first?.symbol == SymbolID.usIndex("SPX"))
    #expect(abs((quotes.first?.last ?? 0) - 7713.675) < 0.0001)
    #expect(abs((quotes.first?.change ?? 0) - (7713.675 - 7714.0)) < 0.0001)
}

private let usNewYork = TimeZone(identifier: "America/New_York")!

private var usRegularHours: Date {
    usDate(year: 2026, month: 8, day: 18, hour: 10, minute: 0)
}

private var usPreMarket: Date {
    usDate(year: 2026, month: 8, day: 19, hour: 6, minute: 14)
}

private func usDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = usNewYork
    return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}
