import Foundation

public struct DarkPoolInfo: Equatable, Sendable {
    public var code: String
    public var name: String
    public var volume: Double
    public var quotedAt: Date
    public var currency: String
    public var provider: String

    public var detail: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "MM-dd HH:mm:ss"
        let origin = provider.isEmpty ? "新浪财经" : provider
        let unit = currency.isEmpty ? "" : "；新浪标注币种 \(currency)"
        return "\(name)（\(code)）\n\(origin)；成交量 \(volume)\(unit)\n报价时间 \(formatter.string(from: quotedAt))（北京时间）\n涨跌按新浪暗盘自身基准计算"
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
            guard fields.count > 4, fields[1] == "71", fields[3].hasPrefix("btc"),
                  fields[3].allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") }),
                  matches(name: fields[4], code: "btc_" + fields[3], quote: quote),
                  seen.insert(fields[3]).inserted else { return nil }
            return SinaDarkPoolCandidate(code: "btc_" + fields[3], name: fields[4])
        }
    }

    static func matches(name: String, code: String = "", quote: Quote) -> Bool {
        let name = name.replacingOccurrences(of: "（", with: "(").replacingOccurrences(of: "）", with: ")")
        guard name.contains("暗盘"), !name.lowercased().contains("ipo") else { return false }
        // This verified A-share dark pool must not replace the identically named H share.
        if code == "btc_btczhongjiusdt" { return quote.symbol == .szStock("300308") }
        // Compare whole names, never substrings (e.g. 苹果 must not match 苹果杠杆ETF).
        let normal = { (s: String) in s.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
        let parts = name.replacingOccurrences(of: "暗盘", with: "")
            .split(whereSeparator: { $0 == "(" || $0 == ")" }).map { normal(String($0)) }
        if parts.contains(normal(quote.name)) { return true }
        // US wrappers use suffixes such as NVDAx, NVDAB, NVDAon, NVDAc.
        guard quote.symbol.market == .us, let ticker = parts.first else { return false }
        let suffixes = ["", "X", "B", "ON", "C", "USDT"]
        return suffixes.contains { ticker == quote.symbol.code + $0 }
            || suffixes.contains { code.uppercased() == "BTC_BTC" + quote.symbol.code + $0 }
    }

    static func parse(_ body: String) -> [String: SinaDarkPoolSnapshot] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.isLenient = false
        var result: [String: SinaDarkPoolSnapshot] = [:]
        for record in QuotedRecordScanner.scan(body, prefix: "hq_str_") where record.key.hasPrefix("btc_btc") {
            let f = record.payload.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            guard f.count >= 12, f[9].contains("暗盘"), !f[9].lowercased().contains("ipo"),
                  let previous = TextDecode.double(f[3]), previous.isFinite, previous > 0,
                  let last = TextDecode.double(f[8]), last.isFinite, last > 0,
                  let volume = TextDecode.double(f[10]), volume.isFinite, volume >= 0,
                  let date = formatter.date(from: f[11] + " " + f[0]),
                  (last / previous * 100).isFinite else { continue }
            let info = DarkPoolInfo(code: record.key, name: f[9], volume: volume, quotedAt: date,
                                    currency: f.count > 14 ? f[14] : "", provider: f.count > 15 ? f[15] : "")
            result[record.key] = SinaDarkPoolSnapshot(info: info, last: last, previous: previous)
        }
        return result
    }

    static func best(_ snapshots: [SinaDarkPoolSnapshot], at date: Date) -> SinaDarkPoolSnapshot? {
        snapshots.filter {
            let age = date.timeIntervalSince($0.info.quotedAt)
            return age >= -60 && age <= maximumAge
        }.sorted {
            if $0.info.volume != $1.info.volume { return $0.info.volume > $1.info.volume }
            return $0.info.code < $1.info.code
        }.first
    }
}

actor SinaDarkPoolCache {
    struct Entry: Sendable {
        var candidates: [SinaDarkPoolCandidate]
        var expiresAt: Date
    }
    private var entries: [String: Entry] = [:]

    func get(_ key: String, at date: Date) -> [SinaDarkPoolCandidate]? {
        guard let entry = entries[key], date < entry.expiresAt else { return nil }
        return entry.candidates
    }

    func set(_ candidates: [SinaDarkPoolCandidate], key: String, at date: Date, failed: Bool = false) {
        if entries.count > 500 { entries = entries.filter { $0.value.expiresAt > date } }
        let lifetime: TimeInterval = failed ? 60 : (candidates.isEmpty ? 3600 : 21600)
        entries[key] = Entry(candidates: candidates, expiresAt: date.addingTimeInterval(lifetime))
    }
}
