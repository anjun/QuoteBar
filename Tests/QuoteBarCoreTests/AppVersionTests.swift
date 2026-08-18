import Foundation
import Testing
@testable import QuoteBarCore

@Test func semanticVersionParsesAndCompares() throws {
    let a = try #require(SemanticVersion("1.2.3"))
    let b = try #require(SemanticVersion("v1.2.4"))
    let c = try #require(SemanticVersion("1.3.0"))
    #expect(a < b)
    #expect(b < c)
    #expect(SemanticVersion("1.2.3") == SemanticVersion("v1.2.3"))
    #expect(SemanticVersion("oops") == nil)
}

@Test func updatePolicyOnlyMovesForward() throws {
    let current = try #require(SemanticVersion("0.1.0"))
    let same = try #require(SemanticVersion("0.1.0"))
    let newer = try #require(SemanticVersion("0.1.1"))
    let older = try #require(SemanticVersion("0.0.9"))
    #expect(UpdatePolicy.shouldUpdate(current: current, latest: newer))
    #expect(!UpdatePolicy.shouldUpdate(current: current, latest: same))
    #expect(!UpdatePolicy.shouldUpdate(current: current, latest: older))
}

@Test func githubReleaseParserPicksUniversalDMG() throws {
    let data = try FixtureLoader.data("github-release.json")
    let release = try GitHubReleaseParser.parse(data)
    #expect(release.tag == "v0.2.0")
    #expect(release.version == SemanticVersion("0.2.0"))
    #expect(release.dmgAssetID == 987654321)
    #expect(release.dmgName == "QuoteBar-0.2.0.dmg")
    #expect(release.assetAPIURL.host == "api.github.com")
}
