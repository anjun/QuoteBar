import Foundation

public struct SemanticVersion: Comparable, Equatable, Sendable {
    public var major: Int
    public var minor: Int
    public var patch: Int

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public init?(_ raw: String) {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.first == "v" || value.first == "V" {
            value.removeFirst()
        }
        let parts = value.split(separator: ".").map(String.init)
        guard parts.count >= 2,
              let major = Int(parts[0]),
              let minor = Int(parts[1]) else { return nil }
        let patch = parts.count >= 3 ? Int(parts[2]) ?? 0 : 0
        self.init(major: major, minor: minor, patch: patch)
    }

    public var display: String { "\(major).\(minor).\(patch)" }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
}

public enum UpdatePolicy {
    public static func shouldUpdate(current: SemanticVersion, latest: SemanticVersion) -> Bool {
        latest > current
    }
}
