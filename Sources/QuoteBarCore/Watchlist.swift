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

    public func groups() -> [MarketGroup] {
        MarketFamily.allCases.compactMap { family in
            let grouped = items.filter { $0.market.family == family }
            return grouped.isEmpty ? nil : MarketGroup(family: family, items: grouped)
        }
    }

    public mutating func move(in family: MarketFamily, from offsets: IndexSet, to destination: Int) {
        var buckets = Dictionary(uniqueKeysWithValues: MarketFamily.allCases.map { family in
            (family, items.filter { $0.market.family == family })
        })
        if var group = buckets[family] {
            group.moveItems(from: offsets, to: destination)
            buckets[family] = group
        }
        items = MarketFamily.allCases.flatMap { buckets[$0] ?? [] }
    }

    public mutating func move(_ symbol: SymbolID, by offset: Int) {
        let family = symbol.market.family
        var group = items.filter { $0.market.family == family }
        guard let index = group.firstIndex(of: symbol) else { return }
        let target = index + offset
        guard group.indices.contains(target) else { return }
        group.swapAt(index, target)
        let buckets = Dictionary(uniqueKeysWithValues: MarketFamily.allCases.map { itemFamily in
            (itemFamily, itemFamily == family ? group : items.filter { $0.market.family == itemFamily })
        })
        items = MarketFamily.allCases.flatMap { buckets[$0] ?? [] }
    }
}

private extension Array {
    mutating func moveItems(from offsets: IndexSet, to destination: Int) {
        let moving = offsets.sorted().compactMap { indices.contains($0) ? self[$0] : nil }
        for index in offsets.sorted(by: >) where indices.contains(index) {
            remove(at: index)
        }
        let adjusted = destination - offsets.filter { $0 < destination }.count
        let insertAt = Swift.min(Swift.max(adjusted, 0), count)
        insert(contentsOf: moving, at: insertAt)
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
