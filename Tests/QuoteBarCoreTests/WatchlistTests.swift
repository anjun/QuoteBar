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
