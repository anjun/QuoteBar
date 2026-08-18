import Foundation

public enum EastMoneySearchParser {
    public static func parse(_ data: Data) throws -> [SearchHit] {
        let decoded = try JSONDecoder().decode(EastMoneySuggest.self, from: data)
        return (decoded.quotationCodeTable?.data ?? []).compactMap { row in
            guard let code = row.code, let name = row.name else { return nil }
            let market: SymbolID.Market
            if let quoteID = row.quoteID, let dot = quoteID.firstIndex(of: ".") {
                let marketNo = Int(quoteID[..<dot]) ?? row.marketNumber ?? 1
                market = ProviderCodes.market(fromEastMoney: marketNo, code: code)
            } else if let mkt = row.marketNumber {
                market = ProviderCodes.market(fromEastMoney: mkt, code: code)
            } else {
                market = .sh
            }
            var symbol = SymbolID.classify(market: market, code: code)
            if (row.securityTypeName ?? "").contains("基金") || (row.securityTypeName ?? "").uppercased().contains("ETF") {
                symbol.kind = .etf
            }
            return SearchHit(symbol: symbol, name: name, pinyin: row.pinYin ?? "")
        }
    }
}

struct EastMoneySuggest: Decodable {
    var quotationCodeTable: EastMoneySuggestTable?

    enum CodingKeys: String, CodingKey {
        case quotationCodeTable = "QuotationCodeTable"
    }
}

struct EastMoneySuggestTable: Decodable {
    var data: [EastMoneySuggestRow]?

    enum CodingKeys: String, CodingKey {
        case data = "Data"
    }
}

struct EastMoneySuggestRow: Decodable {
    var code: String?
    var name: String?
    var pinYin: String?
    var quoteID: String?
    var mktNum: FlexibleInt?
    var securityTypeName: String?

    var marketNumber: Int? { mktNum?.value }

    enum CodingKeys: String, CodingKey {
        case code = "Code"
        case name = "Name"
        case pinYin = "PinYin"
        case quoteID = "QuoteID"
        case mktNum = "MktNum"
        case securityTypeName = "SecurityTypeName"
    }
}

struct FlexibleInt: Decodable {
    var value: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) {
            value = int
        } else if let string = try? container.decode(String.self), let int = Int(string) {
            value = int
        } else {
            throw DecodingError.typeMismatch(Int.self, .init(codingPath: decoder.codingPath, debugDescription: "Not an int"))
        }
    }
}
