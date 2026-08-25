import Foundation

public enum TencentQuoteParser {
    public static func parse(_ body: String) -> [Quote] {
        var quotes: [Quote] = []
        for match in QuotedRecordScanner.scan(body, prefix: "v_") {
            if match.key.hasPrefix("hf_"), let quote = parseHF(key: match.key, payload: match.payload) {
                quotes.append(quote)
                continue
            }
            guard let symbol = symbol(fromKey: match.key) else { continue }
            let fields = match.payload.split(separator: "~", omittingEmptySubsequences: false).map(String.init)
            guard fields.count > 32,
                  let last = TextDecode.double(fields[3]),
                  let change = TextDecode.double(fields[31]),
                  let percent = TextDecode.double(fields[32]) else { continue }
            let name = fields.count > 1 ? fields[1] : symbol.code
            quotes.append(
                Quote(
                    symbol: symbol,
                    name: name,
                    last: last,
                    change: change,
                    changePercent: percent,
                    source: .tencent
                )
            )
        }
        return quotes
    }

    static func parseHF(key: String, payload: String) -> Quote? {
        let fields = payload.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        guard fields.count > 7,
              let last = TextDecode.double(fields[0]),
              let prev = TextDecode.double(fields[7]), prev != 0 else { return nil }
        let raw = String(key.dropFirst(3))
        guard let symbol = ProviderCodes.symbol(fromTencentHF: raw) else { return nil }
        let change = last - prev
        let percent = TextDecode.double(fields[1]) ?? (change / prev * 100)
        let name = fields.count > 13 ? fields[13] : symbol.code
        return Quote(
            symbol: symbol,
            name: name,
            last: last,
            change: change,
            changePercent: percent,
            source: .tencent
        )
    }

    static func symbol(fromKey key: String) -> SymbolID? {
        guard key.count >= 3 else { return nil }
        let prefix = String(key.prefix(2)).lowercased()
        guard let market = ProviderCodes.market(fromTencentPrefix: prefix) else { return nil }
        let rawCode = String(key.dropFirst(2))
        return SymbolID.classify(market: market, code: rawCode)
    }
}
