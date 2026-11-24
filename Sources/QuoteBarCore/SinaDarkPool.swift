import Foundation

public struct DarkPoolInfo: Equatable, Sendable {
    public var code: String
    public var name: String
    public var volume: Double
    public var quotedAt: Date
    public var currency: String
    public var provider: String
    public var isUTC0Baseline: Bool

    public init(code: String, name: String, volume: Double, quotedAt: Date,
                currency: String, provider: String, isUTC0Baseline: Bool = false) {
        self.code = code
        self.name = name
        self.volume = volume
        self.quotedAt = quotedAt
        self.currency = currency
        self.provider = provider
        self.isUTC0Baseline = isUTC0Baseline
    }

    var isUSDTFeed: Bool {
        SinaDarkPool.isUSDTFeed(code: code, provider: provider)
    }

    public var detail: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "MM-dd HH:mm:ss"
        let origin = provider.isEmpty ? "新浪财经" : provider
        let volumeText = volume > 0 ? "；成交量 \(volume)" : ""
        let unit = currency.isEmpty ? "" : "；新浪标注币种 \(currency)"
        let basis = isUTC0Baseline ? "涨跌按 UTC+0 自然日（北京时间 08:00）计算" : "涨跌按新浪暗盘自身基准计算"
        return "\(name)（\(code)）\n\(origin)\(volumeText)\(unit)\n报价时间 \(formatter.string(from: quotedAt))（北京时间）\n\(basis)"
    }
}

struct SinaDarkPoolCandidate: Equatable, Sendable {
    var code: String
    var name: String
}

struct SinaDarkPoolSnapshot: Sendable {
    var info: DarkPoolInfo
    var last: Double
    var previous: Double

    func overlay(_ quote: Quote) -> Quote {
        Quote(symbol: quote.symbol, name: quote.name, last: last,
              change: last - previous, changePercent: (last / previous - 1) * 100,
              source: .sina, darkPool: info)
    }
}

enum SinaDarkPool {
    // Prefer a regular close to a dark-pool price that has stopped updating.
    static let maximumAge: TimeInterval = 15 * 60

    static func eligible(_ symbol: SymbolID, at date: Date) -> Bool {
        symbol.kind == .stock && [.sh, .sz, .hk, .us].contains(symbol.market)
            && MarketSession.phase(symbol.market, at: date) == .closed
    }

    static func candidates(_ body: String, matching quote: Quote) -> [SinaDarkPoolCandidate] {
        guard let start = body.firstIndex(of: "\""), let end = body.lastIndex(of: "\""), start < end else { return [] }
        let payload = TextDecode.unescapeUnicode(String(body[body.index(after: start)..<end]))
        var seen = Set<String>()
        return payload.split(separator: ";").compactMap { record in
            let fields = record.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            let category = fields.count > 12 ? fields[12] : nil
            guard fields.count > 4, fields[1] == "71", fields[3].hasPrefix("btc"),
                  fields[3].allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") }),
                  matches(name: fields[4], code: "btc_" + fields[3], quote: quote, category: category),
                  seen.insert(fields[3]).inserted else { return nil }
            return SinaDarkPoolCandidate(code: "btc_" + fields[3], name: fields[4])
        }
    }

    static func matches(name: String, code: String = "", quote: Quote, category: String? = nil, last: Double? = nil) -> Bool {
        let name = name.replacingOccurrences(of: "（", with: "(").replacingOccurrences(of: "）", with: ")")
        let normal = { (s: String) in s.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
        // Sina intermittently reports US *usdt dark pools as "<TICKER>USDT" instead of "<中文>（暗盘）".
        if quote.symbol.market == .us,
           code.uppercased() == "BTC_BTC" + quote.symbol.code.uppercased() + "USDT",
           normal(name) == quote.symbol.code.uppercased() + "USDT" {
            if let category, category != "5" { return false }
            if let last {
                guard quote.last > 0, last >= quote.last * 0.5, last <= quote.last * 2.0 else { return false }
            }
            return category == "5" || last != nil
        }
        guard name.contains("暗盘"), !name.lowercased().contains("ipo") else { return false }
        // This verified A-share dark pool must not replace the identically named H share.
        if code == "btc_btczhongjiusdt" { return quote.symbol == .szStock("300308") }
        // Compare whole names, never substrings (e.g. 苹果 must not match 苹果杠杆ETF).
        let parts = name.replacingOccurrences(of: "暗盘", with: "")
            .split(whereSeparator: { $0 == "(" || $0 == ")" }).map { normal(String($0)) }
        if parts.contains(normal(quote.name)) { return true }
        // US wrappers use suffixes such as NVDAx, NVDAB, NVDAon, NVDAc.
        guard quote.symbol.market == .us, let ticker = parts.first else { return false }
        let suffixes = ["", "X", "B", "ON", "C", "USDT"]
        return suffixes.contains { ticker == quote.symbol.code + $0 }
            || suffixes.contains { code.uppercased() == "BTC_BTC" + quote.symbol.code + $0 }
    }

    static func isUSDTFeed(code: String, provider: String) -> Bool {
        code.lowercased().hasSuffix("usdt") && !provider.localizedCaseInsensitiveContains("DEX")
    }

    static func isUSUsdtTickerName(code: String, name: String, provider: String) -> Bool {
        guard isUSDTFeed(code: code, provider: provider),
              provider.isEmpty,
              code.lowercased().hasPrefix("btc_btc") else { return false }
        let suffix = String(code.dropFirst("btc_btc".count)).uppercased()
        let normalName = name.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return !suffix.isEmpty && normalName == suffix
    }

    static func usdtProbeCode(for symbol: SymbolID) -> String? {
        guard symbol.market == .us,
              !symbol.code.isEmpty,
              symbol.code.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else { return nil }
        return "btc_btc" + symbol.code.lowercased() + "usdt"
    }

    static func utcDayStart(for date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.startOfDay(for: date)
    }

    static func parse(_ body: String) -> [String: SinaDarkPoolSnapshot] {
        let formatter = shanghaiDateFormatter()
        var result: [String: SinaDarkPoolSnapshot] = [:]
        for record in QuotedRecordScanner.scan(body, prefix: "hq_str_") where record.key.hasPrefix("btc_btc") {
            let f = record.payload.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            let provider = f.count > 15 ? f[15] : ""
            guard f.count >= 12,
                  (f[9].contains("暗盘") && !f[9].lowercased().contains("ipo"))
                    || isUSUsdtTickerName(code: record.key, name: f[9], provider: provider),
                  let previous = TextDecode.double(f[3]), previous.isFinite, previous > 0,
                  let last = TextDecode.double(f[8]), last.isFinite, last > 0,
                  let volume = TextDecode.double(f[10]), volume.isFinite, volume >= 0,
                  let date = formatter.date(from: f[11] + " " + f[0]),
                  (last / previous * 100).isFinite else { continue }
            let isUTC0 = isUSDTFeed(code: record.key, provider: provider)
            let info = DarkPoolInfo(code: record.key, name: f[9], volume: volume, quotedAt: date,
                                    currency: f.count > 14 ? f[14] : "", provider: provider,
                                    isUTC0Baseline: isUTC0)
            result[record.key] = SinaDarkPoolSnapshot(info: info, last: last, previous: previous)
        }
        return result
    }

    static func best(_ snapshots: [SinaDarkPoolSnapshot], at date: Date) -> SinaDarkPoolSnapshot? {
        snapshots.filter {
            let age = date.timeIntervalSince($0.info.quotedAt)
            return age >= -60 && age <= maximumAge
        }.sorted {
            // Sina's *usdt dark-pool feeds update live and use UTC+0 (08:00 CST) natively,
            // while reporting volume == 0 in hq.sinajs.cn; prefer them over slower OKX DEX wrappers.
            if $0.info.isUSDTFeed != $1.info.isUSDTFeed { return $0.info.isUSDTFeed }
            if $0.info.volume != $1.info.volume { return $0.info.volume > $1.info.volume }
            return $0.info.code < $1.info.code
        }.first
    }

    private struct KlineResponse: Decodable {
        struct Result: Decodable {
            var data: [Bar]?
        }
        struct Bar: Decodable {
            var d: String
            var c: String
        }
        var result: Result?
    }

    static func parseUTC0Baseline(_ data: Data, at date: Date) -> (price: Double, exact: Bool)? {
        guard let decoded = try? JSONDecoder().decode(KlineResponse.self, from: data),
              let bars = decoded.result?.data, !bars.isEmpty else { return nil }
        let formatter = shanghaiDateFormatter()
        let boundary = utcDayStart(for: date)
        let oldestAllowed = boundary.addingTimeInterval(-72 * 3600)
        var bestBar: (date: Date, close: Double)?
        for bar in bars {
            guard let barDate = formatter.date(from: bar.d),
                  barDate <= boundary, barDate >= oldestAllowed,
                  let close = TextDecode.double(bar.c), close.isFinite, close > 0 else { continue }
            if bestBar == nil || barDate > bestBar!.date {
                bestBar = (barDate, close)
            }
        }
        guard let matched = bestBar else { return nil }
        return (matched.close, matched.date == boundary)
    }

    private static func shanghaiDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.isLenient = false
        return formatter
    }
}

actor SinaDarkPoolCache {
    struct Entry: Sendable {
        var candidates: [SinaDarkPoolCandidate]
        var expiresAt: Date
    }
    struct BaselineEntry: Sendable {
        var price: Double?
        var expiresAt: Date
    }
    private var entries: [String: Entry] = [:]
    private var baselines: [String: BaselineEntry] = [:]

    func get(_ key: String, at date: Date) -> [SinaDarkPoolCandidate]? {
        guard let entry = entries[key], date < entry.expiresAt else { return nil }
        return entry.candidates
    }

    func set(_ candidates: [SinaDarkPoolCandidate], key: String, at date: Date, failed: Bool = false) {
        if entries.count > 500 { entries = entries.filter { $0.value.expiresAt > date } }
        let lifetime: TimeInterval = failed ? 60 : (candidates.isEmpty ? 3600 : 21600)
        entries[key] = Entry(candidates: candidates, expiresAt: date.addingTimeInterval(lifetime))
    }

    func baseline(for key: String, at date: Date) -> BaselineEntry? {
        guard let entry = baselines[key], date < entry.expiresAt else { return nil }
        return entry
    }

    func setBaseline(_ price: Double?, key: String, expiresAt: Date, at date: Date) {
        if baselines.count > 500 { baselines = baselines.filter { $0.value.expiresAt > date } }
        baselines[key] = BaselineEntry(price: price, expiresAt: expiresAt)
    }
}
