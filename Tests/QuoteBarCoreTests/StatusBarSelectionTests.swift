import Foundation
import Testing
@testable import QuoteBarCore

@Test func pinnedStockWinsOverIndexCarousel() {
    let stock = SymbolID.shStock("002714")
    let shown = StatusBarSelection.symbol(
        pinned: stock,
        watchlist: [.shIndex("000001"), stock],
        openIndices: [.shIndex("000001")],
        carouselIndex: 0
    )
    #expect(shown == stock)
}

@Test func missingPinFallsBackToOpenIndexCarousel() {
    let shown = StatusBarSelection.symbol(
        pinned: nil,
        watchlist: [.shIndex("000001"), .szIndex("399001")],
        openIndices: [.shIndex("000001"), .szIndex("399001")],
        carouselIndex: 1
    )
    #expect(shown == .szIndex("399001"))
}

@Test func pinRemovedFromWatchlistFallsBackToCarousel() {
    let shown = StatusBarSelection.symbol(
        pinned: .shStock("002714"),
        watchlist: [.shIndex("000001")],
        openIndices: [.shIndex("000001")],
        carouselIndex: 0
    )
    #expect(shown == .shIndex("000001"))
}

@Test func pinStopsCarouselAdvanceEvenForStocks() {
    #expect(!StatusBarSelection.shouldAdvance(
        pinned: .shStock("002714"),
        watchlist: [.shIndex("000001"), .shStock("002714")],
        openIndexCount: 3
    ))
}

@Test func unpinnedCarouselAdvancesWhenMultipleOpen() {
    #expect(StatusBarSelection.shouldAdvance(
        pinned: nil,
        watchlist: [.shIndex("000001")],
        openIndexCount: 2
    ))
}

@Test func pinnedSymbolRoundTripsInDefaults() {
    let suite = "QuoteBarPinnedTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }

    #expect(PinnedSymbolPersistence.load(from: defaults) == nil)
    PinnedSymbolPersistence.save(.hkStock("00700"), to: defaults)
    #expect(PinnedSymbolPersistence.load(from: defaults) == .hkStock("00700"))
    PinnedSymbolPersistence.save(nil, to: defaults)
    #expect(PinnedSymbolPersistence.load(from: defaults) == nil)
}
