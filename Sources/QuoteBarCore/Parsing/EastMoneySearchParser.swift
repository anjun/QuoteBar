import Foundation

public enum EastMoneySearchParser {
    public static func parse(_ data: Data) throws -> [SearchHit] {
        let decoded = try JSONDecoder().decode(EastMoneySuggest.self, from: data)
        return (decoded.quotationCodeTable?.data ?? []).compactMap { row in
            guard let code = row.code, let name = row.name else { return nil }
            let typeName = row.securityTypeName ?? ""
            if typeName.contains("板块") { return nil }
            let marketNo: Int
            if let quoteID = row.quoteID, let dot = quoteID.firstIndex(of: ".") {
                marketNo = Int(quoteID[..<dot]) ?? row.marketNumber ?? 1
            } else {
                marketNo = row.marketNumber ?? 1
            }
            if marketNo == 90 { return nil }
            let classify = row.classify ?? ""
            let isSpot = typeName.contains("现货") || classify == "FORPM" || marketNo == 122
            let isFuture = typeName.contains("期货")
                || ["Futures", "UniversalFutures", "CFFEX", "GFEX"].contains(classify)
                || ProviderCodes.futuresMarketNumbers.contains(marketNo)
            let market: SymbolID.Market
            if isSpot {
                market = .metal
            } else if isFuture {
                market = .qh
            } else {
                market = ProviderCodes.market(fromEastMoney: marketNo, code: code)
            }
            var symbol = SymbolID.classify(market: market, code: code, quoteMarket: marketNo)
            if typeName.contains("基金") || typeName.uppercased().contains("ETF") {
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
    var classify: String?

    var marketNumber: Int? { mktNum?.value }

    enum CodingKeys: String, CodingKey {
        case code = "Code"
        case name = "Name"
        case pinYin = "PinYin"
        case quoteID = "QuoteID"
        case mktNum = "MktNum"
        case securityTypeName = "SecurityTypeName"
        case classify = "Classify"
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
