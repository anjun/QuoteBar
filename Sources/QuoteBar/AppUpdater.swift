import AppKit
import Foundation
import QuoteBarCore

enum AppUpdater {
    static let repo = (Bundle.main.object(forInfoDictionaryKey: "QuoteBarGitHubRepo") as? String) ?? AppVersion.githubRepo

    static func check(interactive: Bool) async {
        do {
            let current = try currentVersion()
            let token = try resolveToken()
            let release = try await fetchLatest(token: token)
            guard UpdatePolicy.shouldUpdate(current: current, latest: release.version) else {
                if interactive {
                    await alert("已是最新版", "当前版本 \(current.display)")
                }
                return
            }
            let shouldInstall = await confirm(
                "发现新版本 \(release.version.display)",
                "当前 \(current.display)。下载 DMG 并覆盖安装后会自动重启。"
            )
            guard shouldInstall else { return }
            try await apply(release: release, token: token)
        } catch {
            if interactive {
                await alert("检查更新失败", error.localizedDescription)
            }
        }
    }

    static func currentVersion() throws -> SemanticVersion {
        guard let version = SemanticVersion(AppVersion.marketing) else {
            throw UpdateError.invalidCurrentVersion(AppVersion.marketing)
        }
        return version
    }

    static func resolveToken() throws -> String {
        try GitHubAuthToken.resolve()
    }

    static func fetchLatest(token: String) async throws -> GitHubRelease {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("QuoteBar", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw UpdateError.http(http.statusCode)
        }
        return try GitHubReleaseParser.parse(data)
    }

    static func apply(release: GitHubRelease, token: String) async throws {
        let dmg = FileManager.default.temporaryDirectory.appendingPathComponent(release.dmgName)
        try await downloadAsset(release.assetAPIURL, token: token, to: dmg)
        let script = relaunchScript(dmg: dmg)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", script]
        try process.run()
        await MainActor.run {
            NSApplication.shared.terminate(nil)
        }
    }

    static func downloadAsset(_ url: URL, token: String, to destination: URL) async throws {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
        request.setValue("QuoteBar", forHTTPHeaderField: "User-Agent")
        let (temp, response) = try await URLSession.shared.download(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw UpdateError.http(http.statusCode)
        }
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: temp, to: destination)
    }

    static func installDestination() -> URL {
        let bundle = Bundle.main.bundleURL
        if bundle.pathExtension == "app" {
            return bundle
        }
        return URL(fileURLWithPath: "/Applications/QuoteBar.app")
    }

    static func relaunchScript(dmg: URL) -> String {
        let dest = installDestination().path
        let destQ = shellQuote(dest)
        let dmgQ = shellQuote(dmg.path)
        return """
        set -e
        sleep 1
        while pgrep -x QuoteBar >/dev/null 2>&1; do sleep 0.2; done
        MOUNT="$(hdiutil attach -nobrowse -readonly \(dmgQ) | awk '/\\/Volumes\\//{print $NF; exit}')"
        APP="$(find "$MOUNT" -maxdepth 2 -name 'QuoteBar.app' -type d | head -n 1)"
        if [ -z "$APP" ]; then
          hdiutil detach "$MOUNT" >/dev/null 2>&1 || true
          exit 1
        fi
        TMP="$(mktemp -d)/QuoteBar.app"
        rm -rf "$TMP"
        cp -R "$APP" "$TMP"
        hdiutil detach "$MOUNT" >/dev/null 2>&1 || true
        rm -rf \(destQ)
        mkdir -p "$(dirname \(destQ))"
        cp -R "$TMP" \(destQ)
        xattr -dr com.apple.quarantine \(destQ) || true
        open \(destQ)
        rm -f \(dmgQ)
        """
    }

    static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    @MainActor
    static func alert(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    @MainActor
    static func confirm(_ title: String, _ message: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "更新")
        alert.addButton(withTitle: "稍后")
        return alert.runModal() == .alertFirstButtonReturn
    }
}

enum UpdateError: LocalizedError {
    case invalidCurrentVersion(String)
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .invalidCurrentVersion(let value):
            return "当前版本号无效：\(value)"
        case .http(let code):
            return "GitHub 返回 HTTP \(code)"
        }
    }
}
