import Foundation

public struct GitHubReleaseDMG: Equatable, Sendable {
    public var id: Int
    public var name: String
    public var apiURL: URL

    public init(id: Int, name: String, apiURL: URL) {
        self.id = id
        self.name = name
        self.apiURL = apiURL
    }
}

public struct GitHubRelease: Equatable, Sendable {
    public var tag: String
    public var version: SemanticVersion
    public var dmg: GitHubReleaseDMG?

    public init(tag: String, version: SemanticVersion, dmg: GitHubReleaseDMG?) {
        self.tag = tag
        self.version = version
        self.dmg = dmg
    }
}

public enum GitHubReleaseParser {
    public static func parse(_ data: Data) throws -> GitHubRelease {
        let decoded = try JSONDecoder().decode(ReleasePayload.self, from: data)
        guard let version = SemanticVersion(decoded.tagName) else {
            throw GitHubReleaseError.invalidTag(decoded.tagName)
        }
        let dmg = try decoded.assets.first(where: { $0.name.lowercased().hasSuffix(".dmg") }).map { asset in
            guard let url = URL(string: asset.url) else {
                throw GitHubReleaseError.invalidAssetURL
            }
            return GitHubReleaseDMG(id: asset.id, name: asset.name, apiURL: url)
        }
        return GitHubRelease(tag: decoded.tagName, version: version, dmg: dmg)
    }
}

public enum GitHubReleaseError: Error, Equatable, LocalizedError {
    case invalidTag(String)
    case missingDMG
    case invalidAssetURL

    public var errorDescription: String? {
        switch self {
        case .invalidTag(let value):
            return "版本标签无效：\(value)"
        case .missingDMG:
            return "新版本还没有安装包，稍后再检查更新"
        case .invalidAssetURL:
            return "安装包地址无效"
        }
    }
}

private struct ReleasePayload: Decodable {
    var tagName: String
    var assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case assets
    }

    struct Asset: Decodable {
        var id: Int
        var name: String
        var url: String
    }
}
