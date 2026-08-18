import Foundation

public enum SearchRanker {
    public static let aliases: [String: SymbolID] = [
        "tx": .hkStock("00700"),
        "txkg": .hkStock("00700"),
        "腾讯": .hkStock("00700"),
        "腾讯控股": .hkStock("00700"),
        "mt": .shStock("600519"),
        "gzmt": .shStock("600519"),
        "茅台": .shStock("600519"),
        "贵州茅台": .shStock("600519"),
    ]

    public static func rank(_ hits: [SearchHit], query: String) -> [SearchHit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return hits }
        let alias = aliases[trimmed.lowercased()] ?? aliases[trimmed]
        return hits.enumerated().sorted { lhs, rhs in
            let l = score(lhs.element, query: trimmed, alias: alias)
            let r = score(rhs.element, query: trimmed, alias: alias)
            if l != r { return l > r }
            return lhs.offset < rhs.offset
        }.map(\.element)
    }

    static func score(_ hit: SearchHit, query: String, alias: SymbolID?) -> Int {
        let q = query.lowercased()
        var value = 0
        if let alias, hit.symbol == alias { value += 2000 }
        if hit.symbol.code.lowercased() == q { value += 1000 }
        if hit.name == query { value += 900 }
        if hit.pinyin.lowercased() == q { value += 400 }
        if hit.pinyin.lowercased().hasPrefix(q) { value += 200 }
        if hit.name.contains(query) { value += 150 }
        if hit.symbol.code.lowercased().hasPrefix(q) { value += 80 }
        return value
    }
}
