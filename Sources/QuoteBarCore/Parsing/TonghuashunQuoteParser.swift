import Foundation

public enum TonghuashunQuoteParser {
    public static func parse(_ body: String) -> [Quote] {
        guard let json = jsonObject(fromJSONP: body) else { return [] }
        return json.keys.compactMap { key in
            guard let row = json[key] as? [String: Any] else { return nil }
            return quote(from: row, key: key)
        }
    }

    static func quote(from row: [String: Any], key: String) -> Quote? {
        guard let symbol = symbol(fromKey: key) else { return nil }
        let ticks = (row["data"] as? String ?? "")
            .split(separator: ";", omittingEmptySubsequences: true)
        guard let lastTick = ticks.last else { return nil }
        let fields = lastTick.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        guard fields.count > 1, let last = TextDecode.double(fields[1]), last > 0 else { return nil }
        let prev = TextDecode.double(row["pre"] as? String ?? "") ?? last
        let change = last - prev
        let percent = prev == 0 ? 0 : change / prev * 100
        let name = (row["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? symbol.code
        return Quote(
            symbol: symbol,
            name: name,
            last: last,
            change: change,
            changePercent: percent,
            source: .tonghuashun
        )
    }

    static func symbol(fromKey key: String) -> SymbolID? {
        let code: String
        if let idx = key.firstIndex(of: "_") {
            code = String(key[key.index(after: idx)...])
        } else {
            code = key
        }
        guard !code.isEmpty else { return nil }
        return .metal(code)
    }

    static func jsonObject(fromJSONP body: String) -> [String: Any]? {
        guard let start = body.firstIndex(of: "{"),
              let end = body.lastIndex(of: "}"),
              start < end else { return nil }
        let json = String(body[start...end])
        return (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any]
    }
}
