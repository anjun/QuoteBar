import Foundation

public enum MarketFamily: String, CaseIterable, Hashable, Sendable {
    case cn = "A 股"
    case hk = "港股"
    case us = "美股"

    public var title: String { rawValue }
}

public extension SymbolID.Market {
    var family: MarketFamily {
        switch self {
        case .sh, .sz: return .cn
        case .hk: return .hk
        case .us: return .us
        }
    }
}

public struct MarketGroup: Equatable, Sendable {
    public var family: MarketFamily
    public var items: [SymbolID]

    public init(family: MarketFamily, items: [SymbolID]) {
        self.family = family
        self.items = items
    }
}
