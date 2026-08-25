import Foundation

public enum CryptoCatalog {
    public struct Coin: Sendable {
        public var code: String
        public var name: String
        public var pinyin: String
        public var aliases: [String]
    }

    public static let coins: [Coin] = [
        Coin(code: "BTC", name: "比特币", pinyin: "btb", aliases: ["btc", "bitcoin", "比特币", "btcusdt", "btc-usd"]),
        Coin(code: "ETH", name: "以太坊", pinyin: "ytf", aliases: ["eth", "ethereum", "以太坊", "以太", "ethusdt"]),
        Coin(code: "SOL", name: "索拉纳", pinyin: "sln", aliases: ["sol", "solana", "索拉纳", "solusdt"]),
        Coin(code: "DOGE", name: "狗狗币", pinyin: "ggb", aliases: ["doge", "dogecoin", "狗狗", "狗狗币"]),
        Coin(code: "XRP", name: "瑞波币", pinyin: "xpb", aliases: ["xrp", "ripple", "瑞波", "瑞波币"]),
        Coin(code: "BNB", name: "币安币", pinyin: "bab", aliases: ["bnb", "binance", "币安", "币安币"]),
        Coin(code: "ADA", name: "艾达币", pinyin: "adb", aliases: ["ada", "cardano", "艾达", "艾达币"]),
        Coin(code: "AVAX", name: "雪崩", pinyin: "xbn", aliases: ["avax", "avalanche", "雪崩"]),
        Coin(code: "DOT", name: "波卡", pinyin: "bk", aliases: ["dot", "polkadot", "波卡"]),
        Coin(code: "LINK", name: "链接", pinyin: "lj", aliases: ["link", "chainlink", "链接"]),
        Coin(code: "LTC", name: "莱特币", pinyin: "ltb", aliases: ["ltc", "litecoin", "莱特", "莱特币"]),
        Coin(code: "BCH", name: "比特现金", pinyin: "btxj", aliases: ["bch", "bitcoincash", "比特现金"]),
        Coin(code: "UNI", name: "Uniswap", pinyin: "uni", aliases: ["uni", "uniswap"]),
        Coin(code: "TRX", name: "波场", pinyin: "bc", aliases: ["trx", "tron", "波场"]),
        Coin(code: "SHIB", name: "柴犬", pinyin: "cy", aliases: ["shib", "shiba", "柴犬"]),
        Coin(code: "PEPE", name: "PEPE", pinyin: "pepe", aliases: ["pepe"]),
        Coin(code: "SUI", name: "Sui", pinyin: "sui", aliases: ["sui"]),
        Coin(code: "TON", name: "TON", pinyin: "ton", aliases: ["ton", "toncoin"]),
        Coin(code: "NEAR", name: "NEAR", pinyin: "near", aliases: ["near"]),
        Coin(code: "APT", name: "Aptos", pinyin: "apt", aliases: ["apt", "aptos"]),
        Coin(code: "FIL", name: "文件币", pinyin: "wjb", aliases: ["fil", "filecoin", "文件币"]),
        Coin(code: "ATOM", name: "宇宙", pinyin: "yz", aliases: ["atom", "cosmos", "宇宙"]),
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
        if let ticker = normalizeTicker(trimmed) {
            if let exact = coins.first(where: { $0.code == ticker }) {
                return exact
            }
        }
        return coins.first { coin in
            if coin.name == trimmed { return true }
            if coin.pinyin.lowercased() == lowered { return true }
            return coin.aliases.contains { $0.lowercased() == lowered }
        }
    }

    public static func hits(matching query: String) -> [SearchHit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let lowered = trimmed.lowercased()
        let ticker = normalizeTicker(trimmed)
        return coins.compactMap { coin in
            let matched = coin.code == ticker
                || coin.code.lowercased() == lowered
                || coin.name == trimmed
                || coin.name.contains(trimmed)
                || coin.pinyin.lowercased() == lowered
                || coin.pinyin.lowercased().hasPrefix(lowered)
                || coin.aliases.contains { $0.lowercased() == lowered || $0.lowercased().hasPrefix(lowered) }
            guard matched else { return nil }
            return SearchHit(symbol: .crypto(coin.code), name: coin.name, pinyin: coin.pinyin)
        }
    }

    public static func searchHit(for code: String) -> SearchHit {
        if let coin = coin(forCode: code) {
            return SearchHit(symbol: .crypto(coin.code), name: coin.name, pinyin: coin.pinyin)
        }
        let normalized = normalizeTicker(code) ?? code.uppercased()
        return SearchHit(symbol: .crypto(normalized), name: name(for: normalized) ?? normalized, pinyin: normalized.lowercased())
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
