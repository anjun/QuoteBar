import Testing
@testable import QuoteBarCore

@Test func tencentSearchTxRanksTencentHoldingsFirstEvenIfShuffled() throws {
    let parsed = TencentSearchParser.parse(try FixtureLoader.string("tencent-search-tx.txt"))
    #expect(parsed.contains { $0.symbol.code == "00700" && $0.name == "腾讯控股" })

    let ranked = SearchRanker.rank(parsed.shuffled(), query: "tx")
    let first = try #require(ranked.first)
    #expect(first.name == "腾讯控股")
    #expect(first.symbol == SymbolID.hkStock("00700"))
}

@Test func tencentSearchUnescapesUnicodeName() throws {
    let parsed = TencentSearchParser.parse(try FixtureLoader.string("tencent-search-tx.txt"))
    let hit = try #require(parsed.first { $0.symbol.code == "00700" })
    #expect(hit.name == "腾讯控股")
    #expect(hit.pinyin.lowercased().hasPrefix("tx"))
}

@Test func eastMoneySearchTxSurfacesTencentHoldings() throws {
    let parsed = try EastMoneySearchParser.parse(FixtureLoader.data("eastmoney-search-tx.json"))
    let ranked = SearchRanker.rank(parsed, query: "tx")
    let first = try #require(ranked.first)
    #expect(first.name == "腾讯控股")
    #expect(first.symbol.market == .hk)
    #expect(first.symbol.code == "00700")
}

@Test func searchRankPrefersExactCodeOverPinyinPrefix() {
    let hits = [
        SearchHit(symbol: SymbolID.shStock("600556"), name: "天下秀", pinyin: "txx"),
        SearchHit(symbol: SymbolID.hkStock("00700"), name: "腾讯控股", pinyin: "txkg"),
        SearchHit(symbol: SymbolID.usStock("TX"), name: "特尔尼翁钢铁", pinyin: "tx"),
    ]
    let byCode = SearchRanker.rank(hits, query: "00700")
    #expect(byCode.first?.symbol.code == "00700")

    let byTx = SearchRanker.rank(hits, query: "tx")
    #expect(byTx.first?.name == "腾讯控股")
}

@Test func tencentSearchPgParsesAppleAndRanksItAboveProcter() {
    let body = #"v_hint="us~aapl.oq~\u82f9\u679c~pg~GP^us~pg.n~\u5b9d\u6d01~bj~GP""#
    let parsed = TencentSearchParser.parse(body)
    let apple = parsed.first { $0.symbol.code == "AAPL" }
    #expect(apple?.name == "苹果")
    #expect(apple?.pinyin.lowercased() == "pg")
    #expect(apple?.symbol == SymbolID.usStock("AAPL"))

    let ranked = SearchRanker.rank(parsed, query: "pg")
    #expect(ranked.first?.symbol == SymbolID.usStock("AAPL"))
}

@Test func searchRankUSPinyinBeatsSameLetterTicker() {
    let hits = [
        SearchHit(symbol: SymbolID.usStock("PG"), name: "宝洁", pinyin: "bj"),
        SearchHit(symbol: SymbolID.usStock("AAPL"), name: "苹果", pinyin: "pg"),
        SearchHit(symbol: SymbolID.shStock("600312"), name: "平高电气", pinyin: "pgdq"),
    ]
    let ranked = SearchRanker.rank(hits, query: "pg")
    #expect(ranked.first?.symbol == SymbolID.usStock("AAPL"))
}

@Test func searchRankUSTeslaJianpinBeatsAShareHomophone() {
    let hits = [
        SearchHit(symbol: SymbolID.shStock("600535"), name: "天士力", pinyin: "tsl"),
        SearchHit(symbol: SymbolID.usStock("TSLA"), name: "特斯拉", pinyin: "tsl"),
    ]
    let ranked = SearchRanker.rank(hits, query: "tsl")
    #expect(ranked.first?.symbol == SymbolID.usStock("TSLA"))
}
