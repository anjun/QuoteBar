import Foundation

public struct GitHubRelease: Equatable, Sendable {
    public var tag: String
    public var version: SemanticVersion
    public var dmgAssetID: Int
    public var dmgName: String
    public var assetAPIURL: URL

    public init(tag: String, version: SemanticVersion, dmgAssetID: Int, dmgName: String, assetAPIURL: URL) {
        self.tag = tag
        self.version = version
        self.dmgAssetID = dmgAssetID
        self.dmgName = dmgName
        self.assetAPIURL = assetAPIURL
    }
}

public enum GitHubReleaseParser {
    public static func parse(_ data: Data) throws -> GitHubRelease {
        let decoded = try JSONDecoder().decode(ReleasePayload.self, from: data)
        guard let version = SemanticVersion(decoded.tagName) else {
            throw GitHubReleaseError.invalidTag(decoded.tagName)
        }
        guard let asset = decoded.assets.first(where: { $0.name.lowercased().hasSuffix(".dmg") }) else {
            throw GitHubReleaseError.missingDMG
        }
        guard let url = URL(string: asset.url) else {
            throw GitHubReleaseError.invalidAssetURL
        }
        return GitHubRelease(
            tag: decoded.tagName,
            version: version,
            dmgAssetID: asset.id,
            dmgName: asset.name,
            assetAPIURL: url
        )
    }
}

public enum GitHubReleaseError: Error, Equatable {
    case invalidTag(String)
    case missingDMG
    case invalidAssetURL
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
