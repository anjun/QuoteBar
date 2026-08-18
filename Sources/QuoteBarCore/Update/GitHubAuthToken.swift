import Foundation

public enum GitHubAuthTokenError: Error, Equatable, LocalizedError {
    case cliNotFound
    case missingCredentials

    public var errorDescription: String? {
        switch self {
        case .cliNotFound:
            return "找不到 GitHub CLI（gh）。请先安装：brew install gh"
        case .missingCredentials:
            return "读不到 GitHub 凭证。请先在终端执行 gh auth login。"
        }
    }
}

public enum GitHubAuthToken {
    public static func resolve(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileExists: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }
    ) throws -> String {
        try resolve(environment: environment, fileExists: fileExists, run: runCLI)
    }

    static func resolve(
        environment: [String: String],
        fileExists: (String) -> Bool,
        run: (URL, [String]) throws -> (Int32, String)
    ) throws -> String {
        if let token = environmentToken(environment) {
            return token
        }
        guard let gh = GitHubCLILocator.executablePath(
            pathEnvironment: environment["PATH"] ?? "",
            fileExists: fileExists
        ) else {
            throw GitHubAuthTokenError.cliNotFound
        }
        let status: Int32
        let stdout: String
        do {
            (status, stdout) = try run(URL(fileURLWithPath: gh), ["auth", "token"])
        } catch let error as GitHubAuthTokenError {
            throw error
        } catch {
            throw GitHubAuthTokenError.cliNotFound
        }
        let token = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard status == 0, !token.isEmpty else {
            throw GitHubAuthTokenError.missingCredentials
        }
        return token
    }

    static func environmentToken(_ environment: [String: String]) -> String? {
        for key in ["GITHUB_TOKEN", "GH_TOKEN"] {
            if let value = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                return value
            }
        }
        return nil
    }

    static func runCLI(_ url: URL, _ arguments: [String]) throws -> (Int32, String) {
        let process = Process()
        process.executableURL = url
        process.arguments = arguments
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()
        process.waitUntilExit()
        let stdout = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (process.terminationStatus, stdout)
    }
}
