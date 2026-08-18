import Foundation

enum TextDecode {
    static func string(from data: Data, preferringGBK: Bool) -> String? {
        if preferringGBK, let gbk = decodeGBK(data) {
            return gbk
        }
        if let utf8 = String(data: data, encoding: .utf8) {
            return utf8
        }
        return decodeGBK(data)
    }

    static func decodeGBK(_ data: Data) -> String? {
        let encoding = CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
        )
        return String(data: data, encoding: String.Encoding(rawValue: encoding))
    }

    static func unescapeUnicode(_ raw: String) -> String {
        var result = ""
        var index = raw.startIndex
        while index < raw.endIndex {
            if raw[index] == "\\",
               raw.index(after: index) < raw.endIndex,
               raw[raw.index(after: index)] == "u" {
                let hexStart = raw.index(index, offsetBy: 2)
                if let hexEnd = raw.index(hexStart, offsetBy: 4, limitedBy: raw.endIndex),
                   let value = UInt32(raw[hexStart..<hexEnd], radix: 16),
                   let scalar = UnicodeScalar(value) {
                    result.append(Character(scalar))
                    index = hexEnd
                    continue
                }
            }
            result.append(raw[index])
            index = raw.index(after: index)
        }
        return result
    }

    static func double(_ raw: String) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "--" else { return nil }
        return Double(trimmed)
    }
}
