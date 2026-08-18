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
                "当前 \(current.display)。下载安装包时会显示进度，完成后自动重启。"
            )
            guard shouldInstall else {
                await restoreAccessory()
                return
            }
            guard let dmg = release.dmg else {
                throw GitHubReleaseError.missingDMG
            }
            try await apply(dmg: dmg, version: release.version.display, token: token)
        } catch {
            await restoreAccessory()
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
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("QuoteBar", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw UpdateError.http(http.statusCode)
        }
        return try GitHubReleaseParser.parse(data)
    }

    static func apply(dmg asset: GitHubReleaseDMG, version: String, token: String) async throws {
        let progress = await MainActor.run { startProgress(version: version) }
        do {
            let dmg = FileManager.default.temporaryDirectory.appendingPathComponent(asset.name)
            try await UpdateDownload.file(from: asset.apiURL, token: token, to: dmg) { fraction in
                Task { @MainActor in
                    progress.update(fraction: fraction, status: "正在下载安装包")
                }
            }
            await MainActor.run {
                progress.update(fraction: 1, status: "正在下载安装包")
                progress.markInstalling()
            }
            try launchInstaller(dmg: dmg)
            await MainActor.run {
                NSApplication.shared.terminate(nil)
            }
        } catch {
            await MainActor.run { progress.close() }
            throw error
        }
    }

    static func launchInstaller(dmg: URL) throws {
        let script = UpdateInstaller.script(
            dmg: dmg,
            destination: installDestination(),
            waitPID: ProcessInfo.processInfo.processIdentifier
        )
        let directory = FileManager.default.temporaryDirectory
        let scriptURL = directory.appendingPathComponent("quotebar-update.sh")
        let logURL = directory.appendingPathComponent("quotebar-update.log")
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }
        let launch = UpdateInstaller.detachedLaunch(script: scriptURL, log: logURL)
        let process = Process()
        process.executableURL = launch.executable
        process.arguments = launch.arguments
        process.currentDirectoryURL = directory
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = try FileHandle(forWritingTo: logURL)
        process.standardError = try FileHandle(forWritingTo: logURL)
        try process.run()
    }

    static func installDestination() -> URL {
        let bundle = Bundle.main.bundleURL
        if bundle.pathExtension == "app" {
            return bundle
        }
        return URL(fileURLWithPath: "/Applications/QuoteBar.app")
    }

    @MainActor
    static func startProgress(version: String) -> UpdateProgressPanel {
        NSApp.setActivationPolicy(.regular)
        dismissBlockingWindows()
        NSApp.activate(ignoringOtherApps: true)
        let panel = UpdateProgressPanel(version: version)
        panel.show()
        return panel
    }

    @MainActor
    static func dismissBlockingWindows() {
        if NSApp.modalWindow != nil {
            NSApp.stopModal()
        }
        for window in NSApp.windows {
            let name = NSStringFromClass(type(of: window))
            if name.contains("Alert") || name.contains("MenuBarExtra") || name.contains("StatusBar") {
                window.orderOut(nil)
            }
        }
    }

    @MainActor
    static func restoreAccessory() {
        NSApp.setActivationPolicy(.accessory)
    }

    @MainActor
    static func alert(_ title: String, _ message: String) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好")
        alert.runModal()
        alert.window.close()
        restoreAccessory()
    }

    @MainActor
    static func confirm(_ title: String, _ message: String) -> Bool {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "更新")
        alert.addButton(withTitle: "稍后")
        let result = alert.runModal() == .alertFirstButtonReturn
        alert.window.close()
        if NSApp.modalWindow != nil {
            NSApp.stopModal()
        }
        return result
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
