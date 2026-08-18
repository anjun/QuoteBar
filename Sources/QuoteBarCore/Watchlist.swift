import Foundation

public struct Watchlist: Equatable, Codable, Sendable {
    public private(set) var items: [SymbolID]

    public init(items: [SymbolID]) {
        var seen = Set<SymbolID>()
        self.items = items.filter { seen.insert($0).inserted }
    }

    public static var seededDefaults: Watchlist {
        Watchlist(items: DefaultWatchlist.symbols)
    }

    public mutating func add(_ symbol: SymbolID) {
        guard !items.contains(symbol) else { return }
        items.append(symbol)
    }

    public mutating func remove(_ symbol: SymbolID) {
        items.removeAll { $0 == symbol }
    }
}

public enum DefaultWatchlist {
    public static let symbols: [SymbolID] = [
        .shIndex("000001"),
        .szIndex("399001"),
        .shIndex("000300"),
        .hkIndex("HSI"),
        .hkIndex("HSTECH"),
        .usIndex("NDX"),
        .usIndex("SPX"),
        .usIndex("DJI"),
        .shETF("510300"),
        .usETF("SPY"),
    ]
}

public enum WatchlistPersistence {
    public static let key = "quotebar.watchlist"

    public static func load(from defaults: UserDefaults, key: String = key) -> Watchlist {
        guard let data = defaults.data(forKey: key) else {
            return .seededDefaults
        }
        guard let list = try? JSONDecoder().decode(Watchlist.self, from: data) else {
            return .seededDefaults
        }
        return list
    }

    public static func save(_ list: Watchlist, to defaults: UserDefaults, key: String = key) {
        guard let data = try? JSONEncoder().encode(list) else { return }
        defaults.set(data, forKey: key)
    }
}
