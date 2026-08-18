import Foundation

public enum TencentSearchParser {
    public static func parse(_ body: String) -> [SearchHit] {
        guard let payloadRange = body.range(of: "v_hint=\"") else { return [] }
        let start = payloadRange.upperBound
        let rest = body[start...]
        let raw: Substring
        if let end = rest.firstIndex(of: "\"") {
            raw = rest[..<end]
        } else {
            raw = rest
        }
        let decoded = TextDecode.unescapeUnicode(String(raw))
        return decoded.split(separator: "^").compactMap { chunk in
            let parts = chunk.split(separator: "~", omittingEmptySubsequences: false).map(String.init)
            guard parts.count >= 4,
                  let market = ProviderCodes.market(fromTencentPrefix: parts[0]) else { return nil }
            var symbol = SymbolID.classify(market: market, code: parts[1])
            if parts.count >= 5 {
                let type = parts[4].uppercased()
                if type.contains("ETF") {
                    symbol.kind = .etf
                } else if type == "ZS" {
                    symbol.kind = .index
                }
            }
            return SearchHit(symbol: symbol, name: parts[2], pinyin: parts[3])
        }
    }
}
