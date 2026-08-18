import Foundation

public enum RefreshPolicy {
    public static let minimumSeconds: TimeInterval = 5
    public static let maximumSeconds: TimeInterval = 10
    public static let defaultSeconds: TimeInterval = 8

    public static func clamp(_ value: TimeInterval) -> TimeInterval {
        min(max(value, minimumSeconds), maximumSeconds)
    }
}
