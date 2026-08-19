import Foundation

public enum SinaQuoteParser {
    public static func parse(_ body: String, at date: Date = Date()) -> [Quote] {
        var quotes: [Quote] = []
        for match in QuotedRecordScanner.scan(body, prefix: "hq_str_") {
            let key = match.key
            let payload = match.payload
            if key.hasPrefix("int_") { continue }
            guard let quote = parseRecord(key: key, payload: payload, at: date) else { continue }
            quotes.append(quote)
        }
        return quotes
    }

    static func parseRecord(key: String, payload: String, at date: Date) -> Quote? {
        let fields = payload.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        if key.hasPrefix("sh") || key.hasPrefix("sz") {
            return parseCN(key: key, fields: fields)
        }
        if key.hasPrefix("rt_hk") {
            return parseHK(key: key, fields: fields)
        }
        if key.hasPrefix("hf_") {
            return parseUSFuture(key: key, fields: fields)
        }
        if key.hasPrefix("gb_") {
            return parseUS(key: key, fields: fields, at: date)
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

    static func parseUS(key: String, fields: [String], at date: Date) -> Quote? {
        guard fields.count > 4,
              let last = TextDecode.double(fields[1]),
              let percent = TextDecode.double(fields[2]),
              let change = TextDecode.double(fields[4]) else { return nil }
        let symbol = usSymbol(fromSinaKey: key)
        let phase = MarketSession.phase(.us, at: date)
        if (phase == .preMarket || phase == .afterHours),
           fields.count > 24,
           let extLast = TextDecode.double(fields[21]), extLast > 0,
           let extPercent = TextDecode.double(fields[22]),
           let extChange = TextDecode.double(fields[23]),
           !fields[24].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return Quote(
                symbol: symbol,
                name: fields[0],
                last: extLast,
                change: extChange,
                changePercent: extPercent,
                source: .sina
            )
        }
        return Quote(
            symbol: symbol,
            name: fields[0],
            last: last,
            change: change,
            changePercent: percent,
            source: .sina
        )
    }

    static func parseUSFuture(key: String, fields: [String]) -> Quote? {
        guard fields.count > 7,
              let last = TextDecode.double(fields[0]),
              let prev = TextDecode.double(fields[7]), prev != 0 else { return nil }
        let code = String(key.dropFirst(3)).uppercased()
        let symbol: SymbolID
        switch code {
        case "ES": symbol = .usIndex("SPX")
        case "YM": symbol = .usIndex("DJI")
        case "NQ": symbol = .usIndex("NDX")
        default: return nil
        }
        let change = last - prev
        return Quote(
            symbol: symbol,
            name: fields.count > 13 ? fields[13] : symbol.code,
            last: last,
            change: change,
            changePercent: change / prev * 100,
            source: .sina
        )
    }

    static func usSymbol(fromSinaKey key: String) -> SymbolID {
        let code = String(key.dropFirst(3))
        switch code.lowercased() {
        case "qmi", "qiv": return .usIndex("NDX")
        default: return SymbolID.classify(market: .us, code: code)
        }
    }
}
