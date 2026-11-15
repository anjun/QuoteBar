import Foundation
import QuoteBarCore
import Testing
@testable import QuoteBar

@Test @MainActor func droppedOrderPersistsAndKeepsPinnedSymbol() {
    let suite = "QuoteBar.ReorderTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = AppModel(defaults: defaults)
    let first = SymbolID.szStock("300308")
    let second = SymbolID.shStock("600519")
    let otherGroup = SymbolID.hkStock("00700")
    model.watchlist = Watchlist(items: [first, second, otherGroup])
    model.pin(first)

    #expect(model.move(first, to: second))
    let restored = AppModel(defaults: defaults)
    #expect(restored.watchlist.items == [second, first, otherGroup])
    #expect(restored.pinnedSymbol == first)
    #expect(!model.move(first, to: otherGroup))
    #expect(WatchlistPersistence.load(from: defaults) == restored.watchlist)
}
