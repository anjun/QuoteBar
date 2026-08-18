import Foundation

public enum TencentQuoteParser {
    public static func parse(_ body: String) -> [Quote] {
        var quotes: [Quote] = []
        for match in QuotedRecordScanner.scan(body, prefix: "v_") {
            let key = match.key
            let payload = match.payload
            guard let symbol = symbol(fromKey: key) else { continue }
            let fields = payload.split(separator: "~", omittingEmptySubsequences: false).map(String.init)
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

    static func symbol(fromKey key: String) -> SymbolID? {
        guard key.count >= 3 else { return nil }
        let prefix = String(key.prefix(2)).lowercased()
        guard let market = ProviderCodes.market(fromTencentPrefix: prefix) else { return nil }
        let rawCode = String(key.dropFirst(2))
        return SymbolID.classify(market: market, code: rawCode)
    }
}
