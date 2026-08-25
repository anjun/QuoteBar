import Foundation

public enum BinanceQuoteParser {
    public static func parse(_ data: Data) throws -> [Quote] {
        if let rows = try? JSONDecoder().decode([BinanceTicker].self, from: data) {
            return rows.compactMap(quote(from:))
        }
        let row = try JSONDecoder().decode(BinanceTicker.self, from: data)
        return [quote(from: row)].compactMap { $0 }
    }

    static func quote(from row: BinanceTicker) -> Quote? {
        guard let code = ProviderCodes.cryptoCode(fromBinanceSymbol: row.symbol),
              let last = row.lastPrice?.value,
              let percent = row.priceChangePercent?.value else {
            return nil
        }
        let change = row.priceChange?.value ?? 0
        let symbol = SymbolID.crypto(code)
        return Quote(
            symbol: symbol,
            name: CryptoCatalog.name(for: code) ?? code,
            last: last,
            change: change,
            changePercent: percent,
            source: .binance
        )
    }
}

struct BinanceTicker: Decodable {
    var symbol: String
    var lastPrice: JSONDouble?
    var priceChange: JSONDouble?
    var priceChangePercent: JSONDouble?
}
