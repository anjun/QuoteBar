import CoreTransferable
import QuoteBarCore
import UniformTypeIdentifiers

struct WatchlistMoveToken: Codable, Hashable, Transferable {
    var market: SymbolID.Market
    var code: String
    var kind: SymbolID.Kind

    init(_ symbol: SymbolID) {
        market = symbol.market
        code = symbol.code
        kind = symbol.kind
    }

    var symbol: SymbolID {
        SymbolID(market: market, code: code, kind: kind)
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}
