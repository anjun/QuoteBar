import Foundation

public enum MarketFamily: String, CaseIterable, Hashable, Sendable {
    case cn = "A 股"
    case hk = "港股"
    case us = "美股"
    case futures = "期货"
    case metal = "贵金属"
    case crypto = "虚拟货币"

    public var title: String { rawValue }
}

public extension SymbolID.Market {
    var family: MarketFamily {
        switch self {
        case .sh, .sz: return .cn
        case .hk: return .hk
        case .us: return .us
        case .qh: return .futures
        case .metal: return .metal
        case .crypto: return .crypto
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
