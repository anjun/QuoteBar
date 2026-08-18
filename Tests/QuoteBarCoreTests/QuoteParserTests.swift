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
    let quotes = SinaQuoteParser.parse(try FixtureLoader.string("sina-frozen.txt"))

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
    let quotes = SinaQuoteParser.parse(try FixtureLoader.string("sina-quotes.txt"))
    #expect(quotes.contains { $0.symbol.code == "000001" && $0.last != 0 })
    #expect(quotes.contains { $0.symbol.code == "00700" && $0.last != 0 })
    #expect(quotes.contains { $0.symbol.code == "AAPL" && $0.last != 0 })
    #expect(quotes.contains { $0.symbol.code == "510300" && $0.last != 0 })
    #expect(quotes.contains { $0.symbol.code == "SPY" && $0.last != 0 })
}
