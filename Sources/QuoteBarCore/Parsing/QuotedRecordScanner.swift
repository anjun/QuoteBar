import Foundation

enum QuotedRecordScanner {
    struct Record {
        var key: String
        var payload: String
    }

    static func scan(_ body: String, prefix: String) -> [Record] {
        var records: [Record] = []
        var searchStart = body.startIndex
        while searchStart < body.endIndex, let prefixRange = body.range(of: prefix, range: searchStart..<body.endIndex) {
            let keyStart = prefixRange.upperBound
            guard let eq = body[keyStart...].firstIndex(of: "=") else { break }
            let key = String(body[keyStart..<eq])
            let afterEq = body.index(after: eq)
            guard afterEq < body.endIndex, body[afterEq] == "\"" else {
                searchStart = body.index(after: prefixRange.lowerBound)
                continue
            }
            let valueStart = body.index(after: afterEq)
            guard let valueEnd = body[valueStart...].firstIndex(of: "\"") else { break }
            records.append(Record(key: key, payload: String(body[valueStart..<valueEnd])))
            searchStart = body.index(after: valueEnd)
        }
        return records
    }
}
