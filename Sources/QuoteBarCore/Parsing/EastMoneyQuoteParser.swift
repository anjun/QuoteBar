import Foundation

public enum EastMoneyQuoteParser {
    public static func parse(_ data: Data) throws -> [Quote] {
        let decoded = try JSONDecoder().decode(EastMoneyList.self, from: data)
        return (decoded.data?.diff ?? []).compactMap(quote(from:))
    }

    static func quote(from row: EastMoneyRow) -> Quote? {
        guard let last = row.f2, let percent = row.f3, let change = row.f4, let code = row.f12, let marketNo = row.f13 else {
            return nil
        }
        let market = ProviderCodes.market(fromEastMoney: marketNo, code: code)
        var symbol = SymbolID.classify(market: market, code: code)
        if marketNo == 107 || marketNo == 106, symbol.kind == .stock, SymbolID.usETFCodes.contains(symbol.code) {
            symbol = .usETF(symbol.code)
        }
        return Quote(
            symbol: symbol,
            name: row.f14 ?? symbol.code,
            last: last,
            change: change,
            changePercent: percent,
            source: .eastMoney
        )
    }
}

struct EastMoneyList: Decodable {
    var data: EastMoneyData?
}

struct EastMoneyData: Decodable {
    var diff: [EastMoneyRow]?
}

struct EastMoneyRow: Decodable {
    var f2: Double?
    var f3: Double?
    var f4: Double?
    var f12: String?
    var f13: Int?
    var f14: String?
}
