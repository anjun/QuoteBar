import Foundation

enum FixtureLoader {
    static func string(_ name: String) throws -> String {
        let url = try url(name)
        return try String(contentsOf: url, encoding: .utf8)
    }

    static func data(_ name: String) throws -> Data {
        try Data(contentsOf: try url(name))
    }

    private static func url(_ name: String) throws -> URL {
        let bundle = Bundle.module
        if let url = bundle.url(forResource: name, withExtension: nil, subdirectory: "Fixtures") {
            return url
        }
        if let url = bundle.url(forResource: (name as NSString).deletingPathExtension, withExtension: (name as NSString).pathExtension, subdirectory: "Fixtures") {
            return url
        }
        throw FixtureError.missing(name)
    }

    enum FixtureError: Error {
        case missing(String)
    }
}
