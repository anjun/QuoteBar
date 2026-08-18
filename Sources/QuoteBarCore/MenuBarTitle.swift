import Foundation

public enum MenuBarTitleStyle: String, Codable, Sendable {
    case full
    case compact
}

public enum MenuBarTitle {
    /// A CJK glyph is about twice as wide as a latin one, so the budget counts half-widths.
    public static let compactNameBudget = 4

    public static func text(name: String, changePercent: Double, style: MenuBarTitleStyle) -> String {
        switch style {
        case .full:
            return "\(name) \(percent(changePercent, decimals: 2))"
        case .compact:
            return "\(shorten(name, budget: compactNameBudget)) \(percent(changePercent, decimals: 1))"
        }
    }

    public static func shorten(_ name: String, budget: Int) -> String {
        var used = 0
        var kept = ""
        for character in name {
            let cost = halfWidths(of: character)
            guard used + cost <= budget else { break }
            used += cost
            kept.append(character)
        }
        return kept.isEmpty ? String(name.prefix(1)) : kept
    }

    public static func percent(_ value: Double, decimals: Int) -> String {
        let prefix = value > 0 ? "+" : ""
        return prefix + String(format: "%.\(decimals)f%%", value)
    }

    static func halfWidths(of character: Character) -> Int {
        character.unicodeScalars.contains { $0.value > 0x2E7F } ? 2 : 1
    }
}

public enum MenuBarTitleStylePersistence {
    public static let key = "quotebar.menu-bar-title-style"

    public static func load(from defaults: UserDefaults, key: String = key) -> MenuBarTitleStyle {
        guard let raw = defaults.string(forKey: key),
              let style = MenuBarTitleStyle(rawValue: raw) else { return .full }
        return style
    }

    public static func save(_ style: MenuBarTitleStyle, to defaults: UserDefaults, key: String = key) {
        defaults.set(style.rawValue, forKey: key)
    }
}
