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
