import Foundation

public enum StatusBarSelection {
    public static func symbol(
        pinned: SymbolID?,
        watchlist: [SymbolID],
        openIndices: [SymbolID],
        carouselIndex: Int
    ) -> SymbolID? {
        if let pinned, watchlist.contains(pinned) {
            return pinned
        }
        guard !openIndices.isEmpty else { return nil }
        return openIndices[carouselIndex % openIndices.count]
    }

    public static func shouldAdvance(
        pinned: SymbolID?,
        watchlist: [SymbolID],
        openIndexCount: Int
    ) -> Bool {
        if let pinned, watchlist.contains(pinned) {
            return false
        }
        return openIndexCount > 1
    }

    public static func isPinnedDisplay(pinned: SymbolID?, watchlist: [SymbolID]) -> Bool {
        pinned.map { watchlist.contains($0) } ?? false
    }
}

public enum PinnedSymbolPersistence {
    public static let key = "quotebar.pinned-symbol"

    public static func load(from defaults: UserDefaults, key: String = key) -> SymbolID? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SymbolID.self, from: data)
    }

    public static func save(_ symbol: SymbolID?, to defaults: UserDefaults, key: String = key) {
        if let symbol, let data = try? JSONEncoder().encode(symbol) {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
