import Foundation
import Testing
@testable import QuoteBarCore

@Test func defaultWatchlistSeedsMajorIndicesAndTwoETFs() {
    let list = Watchlist.seededDefaults
    let codes = Set(list.items.map(\.code))
    #expect(codes.isSuperset(of: ["000001", "399001", "000300", "HSI", "HSTECH", "NDX", "SPX", "DJI"]))
    let etfs = list.items.filter { $0.kind == .etf }
    #expect(etfs.count == 2)
    #expect(Set(etfs.map(\.code)) == Set(["510300", "SPY"]))
    #expect(list.items.contains { $0.kind == .index && $0.market == .us && $0.code == "NDX" })
}

@Test func groupsCollectSameMarketTogetherPreservingRelativeOrder() {
    var list = Watchlist(items: [
        .shIndex("000001"),
        .hkIndex("HSI"),
        .usIndex("NDX"),
        .shETF("510300"),
        .usETF("SPY"),
        .shStock("002714"),
    ])
    let groups = list.groups()
    #expect(groups.map(\.family) == [.cn, .hk, .us])
    #expect(groups[0].items.map(\.code) == ["000001", "510300", "002714"])
    #expect(groups[1].items.map(\.code) == ["HSI"])
    #expect(groups[2].items.map(\.code) == ["NDX", "SPY"])
}

@Test func moveWithinAShareGroupDoesNotSplitTheGroup() {
    var list = Watchlist(items: [
        .shIndex("000001"),
        .hkIndex("HSI"),
        .shStock("002714"),
        .szIndex("399001"),
    ])
    list.move(in: .cn, from: IndexSet(integer: 2), to: 1)
    #expect(list.groups()[0].items.map(\.code) == ["000001", "399001", "002714"])
    #expect(list.items.map(\.code) == ["000001", "399001", "002714", "HSI"])
}

@Test func moveSymbolUpAndDownStaysInsideMarket() {
    var list = Watchlist(items: [
        .shIndex("000001"),
        .shStock("002714"),
        .hkIndex("HSI"),
    ])
    list.move(.shStock("002714"), by: -1)
    #expect(list.groups()[0].items.map(\.code) == ["002714", "000001"])
    list.move(.shStock("002714"), by: -1)
    #expect(list.groups()[0].items.map(\.code) == ["002714", "000001"])
    list.move(.shStock("002714"), by: 1)
    #expect(list.groups()[0].items.map(\.code) == ["000001", "002714"])
}

@Test func watchlistAddAndRemoveKeepUniqueOrder() {
    var list = Watchlist(items: [SymbolID.shIndex("000001")])
    list.add(SymbolID.hkStock("00700"))
    list.add(SymbolID.hkStock("00700"))
    #expect(list.items == [SymbolID.shIndex("000001"), SymbolID.hkStock("00700")])
    list.remove(SymbolID.shIndex("000001"))
    #expect(list.items == [SymbolID.hkStock("00700")])
    list.remove(SymbolID.hkStock("00700"))
    #expect(list.items.isEmpty)
}

@Test func draggingRowsMovesBothDirectionsIncludingFirstAndLast() {
    let first = SymbolID.shStock("600519")
    let middle = SymbolID.szStock("300308")
    let last = SymbolID.shETF("510300")
    let hongKong = SymbolID.hkStock("00700")
    var list = Watchlist(items: [first, middle, last, hongKong])

    let movedToLast = list.move(first, to: last)
    #expect(movedToLast)
    #expect(list.items == [middle, last, first, hongKong])
    let movedToFirst = list.move(first, to: middle)
    #expect(movedToFirst)
    #expect(list.items == [first, middle, last, hongKong])
    let movedDownOne = list.move(first, to: middle)
    #expect(movedDownOne)
    #expect(list.items == [middle, first, last, hongKong])
    let movedUpOne = list.move(first, to: middle)
    #expect(movedUpOne)
    #expect(list.items == [first, middle, last, hongKong])
}

@Test func draggingRejectsOtherGroupsMissingRowsAndSameRowWithoutChanges() {
    let first = SymbolID.szStock("300308")
    let hongKong = SymbolID.hkStock("00700")
    let missing = SymbolID.szStock("000001")
    let original = Watchlist(items: [first, hongKong])
    var list = original
    let sameRow = list.move(first, to: first)
    #expect(!sameRow)
    let otherGroup = list.move(first, to: hongKong)
    #expect(!otherGroup)
    let missingSource = list.move(missing, to: first)
    #expect(!missingSource)
    let missingTarget = list.move(first, to: missing)
    #expect(!missingTarget)
    #expect(list == original)
}

@Test func firstLaunchSeedsWhenKeyMissingEmptyAfterUserClears() {
    let suite = "QuoteBarTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }

    let first = WatchlistPersistence.load(from: defaults)
    #expect(first.items.count == Watchlist.seededDefaults.items.count)
    #expect(first.items.contains(SymbolID.shIndex("000001")))

    var empty = first
    for item in first.items {
        empty.remove(item)
    }
    WatchlistPersistence.save(empty, to: defaults)
    let reloaded = WatchlistPersistence.load(from: defaults)
    #expect(reloaded.items.isEmpty)
}
