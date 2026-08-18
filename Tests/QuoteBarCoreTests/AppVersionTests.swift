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
    #expect(release.dmg?.id == 987654321)
    #expect(release.dmg?.name == "QuoteBar-0.2.0.dmg")
    #expect(release.dmg?.apiURL.host == "api.github.com")
}

@Test func githubReleaseParserReadsVersionWhenDMGIsStillMissing() throws {
    let data = try FixtureLoader.data("github-release-no-dmg.json")
    let release = try GitHubReleaseParser.parse(data)
    #expect(release.tag == "v0.1.4")
    #expect(release.version == SemanticVersion("0.1.4"))
    #expect(release.dmg == nil)
}

@Test func githubReleaseErrorsHaveChineseDescriptions() {
    #expect(GitHubReleaseError.missingDMG.errorDescription == "新版本还没有安装包，稍后再检查更新")
    #expect(GitHubReleaseError.invalidTag("oops").errorDescription == "版本标签无效：oops")
    #expect(GitHubReleaseError.invalidAssetURL.errorDescription == "安装包地址无效")
}
