import Foundation
import Testing
@testable import QuoteBarCore

@Test func locatesGhInHomebrewWhenPATHIsMacOSGUIDefault() {
    let found = GitHubCLILocator.executablePath(
        pathEnvironment: "/usr/bin:/bin:/usr/sbin:/sbin",
        fileExists: { $0 == "/opt/homebrew/bin/gh" }
    )
    #expect(found == "/opt/homebrew/bin/gh")
}

@Test func locatesGhInUsrLocalWhenPATHIsMacOSGUIDefault() {
    let found = GitHubCLILocator.executablePath(
        pathEnvironment: "/usr/bin:/bin:/usr/sbin:/sbin",
        fileExists: { $0 == "/usr/local/bin/gh" }
    )
    #expect(found == "/usr/local/bin/gh")
}

@Test func prefersGhOnPATHOverExtraSearchDirectories() {
    let found = GitHubCLILocator.executablePath(
        pathEnvironment: "/custom/bin:/usr/bin",
        fileExists: { $0 == "/custom/bin/gh" || $0 == "/opt/homebrew/bin/gh" }
    )
    #expect(found == "/custom/bin/gh")
}

@Test func returnsNilWhenGhIsMissing() {
    let found = GitHubCLILocator.executablePath(
        pathEnvironment: "/usr/bin:/bin",
        fileExists: { _ in false }
    )
    #expect(found == nil)
}

@Test func usesGITHUB_TOKENWithoutCallingGh() throws {
    var ran = false
    let token = try GitHubAuthToken.resolve(
        environment: ["GITHUB_TOKEN": "env-token", "GH_TOKEN": "other-token", "PATH": "/usr/bin"],
        fileExists: { _ in false },
        run: { _, _ in
            ran = true
            return (0, "should-not-run")
        }
    )
    #expect(token == "env-token")
    #expect(!ran)
}

@Test func usesGH_TOKENWhenGITHUB_TOKENIsEmpty() throws {
    let token = try GitHubAuthToken.resolve(
        environment: ["GITHUB_TOKEN": "  ", "GH_TOKEN": "gh-token", "PATH": "/usr/bin"],
        fileExists: { _ in false },
        run: { _, _ in (1, "") }
    )
    #expect(token == "gh-token")
}

@Test func readsGhTokenWhenPATHIsMacOSGUIDefault() throws {
    let token = try GitHubAuthToken.resolve(
        environment: ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin"],
        fileExists: { $0 == "/opt/homebrew/bin/gh" },
        run: { url, arguments in
            #expect(url.path == "/opt/homebrew/bin/gh")
            #expect(arguments == ["auth", "token"])
            return (0, "gho_from_cli\n")
        }
    )
    #expect(token == "gho_from_cli")
}

@Test func throwsCLINotFoundWhenGhIsMissing() {
    #expect(throws: GitHubAuthTokenError.cliNotFound) {
        try GitHubAuthToken.resolve(
            environment: ["PATH": "/usr/bin:/bin"],
            fileExists: { _ in false },
            run: { _, _ in (0, "unused") }
        )
    }
}

@Test func throwsMissingCredentialsWhenGhAuthFails() {
    #expect(throws: GitHubAuthTokenError.missingCredentials) {
        try GitHubAuthToken.resolve(
            environment: ["PATH": "/opt/homebrew/bin"],
            fileExists: { $0 == "/opt/homebrew/bin/gh" },
            run: { _, _ in (1, "") }
        )
    }
}

@Test func throwsCLINotFoundWhenGhCannotStart() {
    struct LaunchError: Error {}
    #expect(throws: GitHubAuthTokenError.cliNotFound) {
        try GitHubAuthToken.resolve(
            environment: ["PATH": "/opt/homebrew/bin"],
            fileExists: { $0 == "/opt/homebrew/bin/gh" },
            run: { _, _ in throw LaunchError() }
        )
    }
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["CI"] != "true"))
func resolveTokenWithRealGhWhenPATHLooksLikeMacOSGUI() throws {
    var env = ProcessInfo.processInfo.environment
    env["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin"
    env.removeValue(forKey: "GITHUB_TOKEN")
    env.removeValue(forKey: "GH_TOKEN")
    let token = try GitHubAuthToken.resolve(environment: env)
    #expect(!token.isEmpty)
}
