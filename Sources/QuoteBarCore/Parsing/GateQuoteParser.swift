import Foundation

public enum GateQuoteParser {
    public static func parse(_ data: Data) throws -> [Quote] {
        let rows = try JSONDecoder().decode([GateTicker].self, from: data)
        return rows.compactMap(quote(from:))
    }

    static func quote(from row: GateTicker) -> Quote? {
        guard let pair = row.currencyPair,
              let code = ProviderCodes.cryptoCode(fromGatePair: pair),
              let last = row.last?.value,
              let percent = row.changePercentage?.value else {
            return nil
        }
        let change: Double
        if percent == -100 {
            change = -last
        } else {
            change = last * percent / (100 + percent)
        }
        return Quote(
            symbol: .crypto(code),
            name: CryptoCatalog.name(for: code) ?? code,
            last: last,
            change: change,
            changePercent: percent,
            source: .gate
        )
    }
}

struct GateTicker: Decodable {
    var currencyPair: String?
    var last: JSONDouble?
    var changePercentage: JSONDouble?

    enum CodingKeys: String, CodingKey {
        case currencyPair = "currency_pair"
        case last
        case changePercentage = "change_percentage"
    }
}
