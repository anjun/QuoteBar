import Foundation

public enum CryptoCatalog {
    public struct Coin: Sendable {
        public var code: String
        public var name: String
        public var englishName: String
    }

    public static let coins: [Coin] = [
        Coin(code: "BTC", name: "比特币", englishName: "Bitcoin"),
        Coin(code: "ETH", name: "以太坊", englishName: "Ethereum"),
        Coin(code: "SOL", name: "索拉纳", englishName: "Solana"),
        Coin(code: "DOGE", name: "狗狗币", englishName: "Dogecoin"),
        Coin(code: "XRP", name: "瑞波币", englishName: "Ripple"),
        Coin(code: "BNB", name: "币安币", englishName: "Binance"),
        Coin(code: "ADA", name: "艾达币", englishName: "Cardano"),
        Coin(code: "AVAX", name: "雪崩", englishName: "Avalanche"),
        Coin(code: "DOT", name: "波卡", englishName: "Polkadot"),
        Coin(code: "LINK", name: "链接", englishName: "Chainlink"),
        Coin(code: "LTC", name: "莱特币", englishName: "Litecoin"),
        Coin(code: "BCH", name: "比特现金", englishName: "Bitcoin Cash"),
        Coin(code: "UNI", name: "Uniswap", englishName: "Uniswap"),
        Coin(code: "TRX", name: "波场", englishName: "Tron"),
        Coin(code: "SHIB", name: "柴犬", englishName: "Shiba"),
        Coin(code: "PEPE", name: "PEPE", englishName: "PEPE"),
        Coin(code: "SUI", name: "Sui", englishName: "Sui"),
        Coin(code: "TON", name: "TON", englishName: "Toncoin"),
        Coin(code: "NEAR", name: "NEAR", englishName: "NEAR"),
        Coin(code: "APT", name: "Aptos", englishName: "Aptos"),
        Coin(code: "FIL", name: "文件币", englishName: "Filecoin"),
        Coin(code: "ATOM", name: "宇宙", englishName: "Cosmos"),
    ]

    public static func name(for code: String) -> String? {
        let key = code.uppercased()
        return coins.first { $0.code == key }?.name
    }

    public static func coin(forCode code: String) -> Coin? {
        let key = code.uppercased()
        return coins.first { $0.code == key }
    }

    public static func match(_ query: String) -> Coin? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lowered = trimmed.lowercased()
        let compact = lowered.replacingOccurrences(of: " ", with: "")
        if let ticker = normalizeTicker(trimmed) {
            if let exact = coins.first(where: { $0.code == ticker }) {
                return exact
            }
        }
        return coins.first { coin in
            if coin.name.lowercased() == lowered { return true }
            let english = coin.englishName.lowercased()
            return english == lowered || english.replacingOccurrences(of: " ", with: "") == compact
        }
    }

    public static func matches(_ symbol: SymbolID, query: String) -> Bool {
        guard symbol.market == .crypto, let coin = coin(forCode: symbol.code) else { return false }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return coinMatches(coin, trimmed: trimmed, lowered: trimmed.lowercased(), ticker: normalizeTicker(trimmed))
    }

    public static func hits(matching query: String) -> [SearchHit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let lowered = trimmed.lowercased()
        let ticker = normalizeTicker(trimmed)
        return coins.compactMap { coin in
            guard coinMatches(coin, trimmed: trimmed, lowered: lowered, ticker: ticker) else { return nil }
            return SearchHit(symbol: .crypto(coin.code), name: coin.name)
        }
    }

    private static func coinMatches(_ coin: Coin, trimmed: String, lowered: String, ticker: String?) -> Bool {
        if let ticker, coin.code == ticker { return true }
        if coin.code.lowercased().hasPrefix(lowered) { return true }
        if coin.name.lowercased().contains(lowered) { return true }
        let english = coin.englishName.lowercased()
        if english.hasPrefix(lowered) { return true }
        let compactQuery = lowered.replacingOccurrences(of: " ", with: "")
        if !compactQuery.isEmpty, english.replacingOccurrences(of: " ", with: "").hasPrefix(compactQuery) {
            return true
        }
        return false
    }

    public static func searchHit(for code: String) -> SearchHit {
        if let coin = coin(forCode: code) {
            return SearchHit(symbol: .crypto(coin.code), name: coin.name)
        }
        let normalized = normalizeTicker(code) ?? code.uppercased()
        return SearchHit(symbol: .crypto(normalized), name: name(for: normalized) ?? normalized)
    }

    /// `btc`, `BTCUSDT`, `btc-usd` → `BTC`. Returns nil when the query is not a ticker.
    public static func normalizeTicker(_ raw: String) -> String? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        value = value.replacingOccurrences(of: "-", with: "")
        value = value.replacingOccurrences(of: "_", with: "")
        value = value.replacingOccurrences(of: "/", with: "")
        if value.hasPrefix(".") {
            value = String(value.dropFirst())
        }
        value = value.uppercased()
        guard !value.isEmpty else { return nil }
        if value != "USDT", value.hasSuffix("USDT"), value.count > 4 {
            value = String(value.dropLast(4))
        } else if value != "USDC", value.hasSuffix("USDC"), value.count > 4 {
            value = String(value.dropLast(4))
        } else if value != "USD", value.hasSuffix("USD"), value.count > 3 {
            value = String(value.dropLast(3))
        }
        guard value.count >= 2, value.count <= 16,
              value.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else {
            return nil
        }
        return value
    }
}
