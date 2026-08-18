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
        carouselSeconds: TimeInterval = 3
    ) {
        self.service = service
        self.defaults = defaults
        self.refreshSeconds = RefreshPolicy.clamp(refreshSeconds)
        self.carouselSeconds = carouselSeconds
        self.watchlist = WatchlistPersistence.load(from: defaults)
    }

    var carouselQuote: Quote? {
        let items = watchlist.items
        guard !items.isEmpty else { return nil }
        if let pinnedSymbol, let quote = quotes[pinnedSymbol] {
            return quote
        }
        let index = carouselIndex % items.count
        let symbol = items[index]
        return quotes[symbol]
    }

    func start() {
        guard !loopsStarted else { return }
        loopsStarted = true
        NSApplication.shared.setActivationPolicy(.accessory)
        Task { await refresh() }
        Task { await refreshLoop() }
        Task { await carouselLoop() }
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
            pinnedSymbol = nil
        }
        persist()
    }

    func pin(_ symbol: SymbolID) {
        if pinnedSymbol == symbol {
            pinnedSymbol = nil
        } else {
            pinnedSymbol = symbol
            if let index = watchlist.items.firstIndex(of: symbol) {
                carouselIndex = index
            }
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

    private func refreshLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64(refreshSeconds * 1_000_000_000))
            await refresh()
        }
    }

    private func carouselLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64(carouselSeconds * 1_000_000_000))
            guard pinnedSymbol == nil, watchlist.items.count > 1 else { continue }
            carouselIndex = (carouselIndex + 1) % watchlist.items.count
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

    static func menuBarTitle(_ quote: Quote) -> String {
        "\(quote.shortDisplayName) \(price(quote.last)) \(percent(quote.changePercent))"
    }
}

extension QuoteColorSign {
    var color: Color {
        switch self {
        case .up: return Color(red: 0.86, green: 0.18, blue: 0.18)
        case .down: return Color(red: 0.10, green: 0.62, blue: 0.36)
        case .flat: return .secondary
        }
    }
}
