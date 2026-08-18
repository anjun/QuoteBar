import Foundation

public enum SinaQuoteParser {
    public static func parse(_ body: String) -> [Quote] {
        var quotes: [Quote] = []
        for match in QuotedRecordScanner.scan(body, prefix: "hq_str_") {
            let key = match.key
            let payload = match.payload
            if key.hasPrefix("int_") { continue }
            guard let quote = parseRecord(key: key, payload: payload) else { continue }
            quotes.append(quote)
        }
        return quotes
    }

    static func parseRecord(key: String, payload: String) -> Quote? {
        let fields = payload.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        if key.hasPrefix("sh") || key.hasPrefix("sz") {
            return parseCN(key: key, fields: fields)
        }
        if key.hasPrefix("rt_hk") {
            return parseHK(key: key, fields: fields)
        }
        if key.hasPrefix("gb_") {
            return parseUS(key: key, fields: fields)
        }
        return nil
    }

    static func parseCN(key: String, fields: [String]) -> Quote? {
        guard fields.count > 3,
              let prev = TextDecode.double(fields[2]),
              let last = TextDecode.double(fields[3]) else { return nil }
        let market: SymbolID.Market = key.hasPrefix("sz") ? .sz : .sh
        let code = String(key.dropFirst(2))
        let change = last - prev
        let percent = prev == 0 ? 0 : change / prev * 100
        return Quote(
            symbol: SymbolID.classify(market: market, code: code),
            name: fields[0],
            last: last,
            change: change,
            changePercent: percent,
            source: .sina
        )
    }

    static func parseHK(key: String, fields: [String]) -> Quote? {
        guard fields.count > 8,
              let last = TextDecode.double(fields[6]),
              let change = TextDecode.double(fields[7]),
              let percent = TextDecode.double(fields[8]) else { return nil }
        let code = String(key.dropFirst("rt_hk".count))
        return Quote(
            symbol: SymbolID.classify(market: .hk, code: code),
            name: fields.count > 1 ? fields[1] : code,
            last: last,
            change: change,
            changePercent: percent,
            source: .sina
        )
    }

    static func parseUS(key: String, fields: [String]) -> Quote? {
        guard fields.count > 4,
              let last = TextDecode.double(fields[1]),
              let percent = TextDecode.double(fields[2]),
              let change = TextDecode.double(fields[4]) else { return nil }
        let code = String(key.dropFirst(3))
        return Quote(
            symbol: SymbolID.classify(market: .us, code: code),
            name: fields[0],
            last: last,
            change: change,
            changePercent: percent,
            source: .sina
        )
    }
}
