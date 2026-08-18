import AppKit
import Combine
import Foundation
import QuoteBarCore
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var watchlist: Watchlist
    @Published var quotes: [SymbolID: Quote] = [:]
    @Published var searchText = ""
    @Published var searchResults: [SearchHit] = []
    @Published var isSearching = false
    @Published var carouselIndex = 0
    @Published var pinnedSymbol: SymbolID?
    @Published var titleStyle: MenuBarTitleStyle
    @Published var lastError: String?

    let service: QuoteService
    let defaults: UserDefaults
    let refreshSeconds: TimeInterval
    let carouselSeconds: TimeInterval

    private var searchTask: Task<Void, Never>?
    private var loopsStarted = false

    init(
        service: QuoteService = QuoteService(),
        defaults: UserDefaults = .standard,
        refreshSeconds: TimeInterval = RefreshPolicy.defaultSeconds,
        carouselSeconds: TimeInterval = 8
    ) {
        self.service = service
        self.defaults = defaults
        self.refreshSeconds = RefreshPolicy.clamp(refreshSeconds)
        self.carouselSeconds = carouselSeconds
        self.watchlist = WatchlistPersistence.load(from: defaults)
        self.pinnedSymbol = PinnedSymbolPersistence.load(from: defaults)
        self.titleStyle = MenuBarTitleStylePersistence.load(from: defaults)
    }

    var openCarouselItems: [SymbolID] {
        CarouselSelection.indices(from: watchlist.items)
    }

    var statusBarSymbol: SymbolID? {
        StatusBarSelection.symbol(
            pinned: pinnedSymbol,
            watchlist: watchlist.items,
            openIndices: openCarouselItems,
            carouselIndex: carouselIndex
        )
    }

    var carouselQuote: Quote? {
        statusBarSymbol.flatMap { quotes[$0] }
    }

    var showsPinnedMark: Bool {
        StatusBarSelection.isPinnedDisplay(pinned: pinnedSymbol, watchlist: watchlist.items)
    }

    var menuBarTitle: String? {
        carouselQuote.map { QuoteFormat.menuBarTitle($0, style: titleStyle) }
    }

    var isCompactTitle: Bool { titleStyle == .compact }

    func toggleCompactTitle() {
        titleStyle = titleStyle == .compact ? .full : .compact
        MenuBarTitleStylePersistence.save(titleStyle, to: defaults)
    }

    func start() {
        guard !loopsStarted else { return }
        loopsStarted = true
        NSApplication.shared.setActivationPolicy(.accessory)
        Task { await refresh() }
        Task { await refreshLoop() }
        Task { await carouselLoop() }
        Task { await AppUpdater.check(interactive: false) }
    }

    func refresh() async {
        let items = watchlist.items
        let fetched = await service.quotes(for: items)
        quotes = fetched
        if fetched.isEmpty, !items.isEmpty {
            lastError = "行情暂时不可用"
        } else {
            lastError = nil
        }
    }

    func add(_ hit: SearchHit) {
        watchlist.add(hit.symbol)
        persist()
        searchText = ""
        searchResults = []
        Task { await refresh() }
    }

    func remove(_ symbol: SymbolID) {
        watchlist.remove(symbol)
        quotes[symbol] = nil
        if pinnedSymbol == symbol {
            unpin()
        }
        persist()
    }

    func move(in family: MarketFamily, from offsets: IndexSet, to destination: Int) {
        watchlist.move(in: family, from: offsets, to: destination)
        persist()
    }

    func move(_ symbol: SymbolID, by offset: Int) {
        watchlist.move(symbol, by: offset)
        persist()
    }

    func canMove(_ symbol: SymbolID, by offset: Int) -> Bool {
        let group = watchlist.items.filter { $0.market.family == symbol.market.family }
        guard let index = group.firstIndex(of: symbol) else { return false }
        return group.indices.contains(index + offset)
    }

    @discardableResult
    func move(_ symbol: SymbolID, before target: SymbolID) -> Bool {
        guard symbol != target, symbol.market.family == target.market.family else { return false }
        let family = symbol.market.family
        let group = watchlist.items.filter { $0.market.family == family }
        guard let from = group.firstIndex(of: symbol),
              let to = group.firstIndex(of: target) else { return false }
        let destination = to > from ? to + 1 : to
        watchlist.move(in: family, from: IndexSet(integer: from), to: destination)
        persist()
        return true
    }

    func pin(_ symbol: SymbolID) {
        pinnedSymbol = symbol
        persistPin()
    }

    func unpin() {
        pinnedSymbol = nil
        persistPin()
    }

    func togglePin(_ symbol: SymbolID) {
        if pinnedSymbol == symbol {
            unpin()
        } else {
            pin(symbol)
        }
    }

    func updateSearch(_ text: String) {
        searchText = text
        searchTask?.cancel()
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        isSearching = true
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard !Task.isCancelled else { return }
            let hits = await self?.service.search(query) ?? []
            guard !Task.isCancelled else { return }
            self?.searchResults = hits
            self?.isSearching = false
        }
    }

    private func persist() {
        WatchlistPersistence.save(watchlist, to: defaults)
    }

    private func persistPin() {
        PinnedSymbolPersistence.save(pinnedSymbol, to: defaults)
    }

    private func refreshLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64(refreshSeconds * 1_000_000_000))
            await refresh()
        }
    }

    private func carouselLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64(carouselSeconds * 1_000_000_000))
            let items = openCarouselItems
            guard StatusBarSelection.shouldAdvance(
                pinned: pinnedSymbol,
                watchlist: watchlist.items,
                openIndexCount: items.count
            ) else { continue }
            carouselIndex = (carouselIndex + 1) % items.count
        }
    }
}

enum QuoteFormat {
    static func price(_ value: Double) -> String {
        if abs(value) >= 1000 {
            return String(format: "%.2f", value)
        }
        if abs(value) < 10 {
            return String(format: "%.3f", value)
        }
        return String(format: "%.2f", value)
    }

    static func signed(_ value: Double) -> String {
        let prefix = value > 0 ? "+" : ""
        return prefix + price(value)
    }

    static func percent(_ value: Double) -> String {
        let prefix = value > 0 ? "+" : ""
        return prefix + String(format: "%.2f%%", value)
    }

    static func menuBarTitle(_ quote: Quote, style: MenuBarTitleStyle = .full) -> String {
        MenuBarTitle.text(name: quote.shortDisplayName, changePercent: quote.changePercent, style: style)
    }
}


