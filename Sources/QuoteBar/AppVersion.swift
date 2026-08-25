import Foundation
import QuoteBarCore

enum AppVersion {
    static let githubRepo = "anjun/QuoteBar"

    static var marketing: String {
        if let value = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           value != "1.0", !value.isEmpty {
            return value
        }
        return "0.1.11"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    static var semantic: SemanticVersion? {
        SemanticVersion(marketing)
    }
}
