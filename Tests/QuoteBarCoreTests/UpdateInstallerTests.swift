import Foundation
import Testing
@testable import QuoteBarCore

@Test func installerScriptWaitsForExactPIDNotProcessName() {
    let script = UpdateInstaller.script(
        dmg: URL(fileURLWithPath: "/tmp/QuoteBar-0.1.5.dmg"),
        destination: URL(fileURLWithPath: "/Applications/QuoteBar.app"),
        waitPID: 4242
    )
    #expect(script.contains("kill -0 4242"))
    #expect(!script.contains("pgrep -x QuoteBar"))
}

@Test func installerScriptReplacesThenOpensDestination() {
    let script = UpdateInstaller.script(
        dmg: URL(fileURLWithPath: "/tmp/QuoteBar-0.1.5.dmg"),
        destination: URL(fileURLWithPath: "/Applications/QuoteBar.app"),
        waitPID: 7
    )
    #expect(script.contains("open '/Applications/QuoteBar.app'"))
    #expect(script.contains("QuoteBar.app.old"))
    #expect(script.contains("hdiutil attach"))
}

@Test func detachedLaunchUsesNohupSoParentExitCannotKillInstaller() {
    let launch = UpdateInstaller.detachedLaunch(
        script: URL(fileURLWithPath: "/tmp/quotebar-update.sh"),
        log: URL(fileURLWithPath: "/tmp/quotebar-update.log")
    )
    #expect(launch.executable.path == "/usr/bin/nohup")
    #expect(launch.arguments == ["/bin/bash", "/tmp/quotebar-update.sh"])
}

@Test func mountPointParserKeepsVolumeNamesContainingSpaces() throws {
    let hdiutilOutput = "/dev/disk4          \tGUID_partition_scheme          \t\n"
        + "/dev/disk4s1        \tApple_HFS                      \t/Volumes/QuoteBar 0.1.4\n"
    let parsed = try runShell(
        "printf %s \"$1\" | \(UpdateInstaller.mountPointFilter)",
        argument: hdiutilOutput
    )
    #expect(parsed == "/Volumes/QuoteBar 0.1.4")
}

@Test func installerReopensExistingAppWhenInstallFails() throws {
    let root = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("qb-installer-\(UUID().uuidString)")
    let destination = root.appendingPathComponent("QuoteBar.app")
    let openLog = root.appendingPathComponent("open.log")
    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    // Broken DMG makes hdiutil fail; the script must still relaunch what is installed.
    let brokenDMG = root.appendingPathComponent("broken.dmg")
    try Data("not a disk image".utf8).write(to: brokenDMG)

    var script = UpdateInstaller.script(dmg: brokenDMG, destination: destination, waitPID: 1)
    script = script.replacingOccurrences(
        of: "while kill -0 1 2>/dev/null; do sleep 0.2; done",
        with: ""
    )
    script = "open() { echo \"$@\" >> \(UpdateInstaller.shellQuote(openLog.path)); }\n" + script

    let scriptURL = root.appendingPathComponent("install.sh")
    try script.write(to: scriptURL, atomically: true, encoding: .utf8)

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = [scriptURL.path]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run()
    process.waitUntilExit()

    let logged = (try? String(contentsOf: openLog, encoding: .utf8)) ?? ""
    #expect(logged.contains(destination.path))
    #expect(FileManager.default.fileExists(atPath: destination.path))
}

@Test func installerScriptQuotesMountPathForSpaces() {
    let script = UpdateInstaller.script(
        dmg: URL(fileURLWithPath: "/tmp/QuoteBar-0.1.5.dmg"),
        destination: URL(fileURLWithPath: "/Applications/QuoteBar.app"),
        waitPID: 7
    )
    #expect(!script.contains("print $NF"))
    #expect(script.contains(UpdateInstaller.mountPointFilter))
}

private func runShell(_ script: String, argument: String) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = ["-c", script, "bash", argument]
    let out = Pipe()
    process.standardOutput = out
    try process.run()
    process.waitUntilExit()
    let data = out.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}

@Test func downloadFractionClampsBetweenZeroAndOne() {
    #expect(UpdateDownloadProgress.fraction(received: 0, expected: 100) == 0)
    #expect(UpdateDownloadProgress.fraction(received: 50, expected: 100) == 0.5)
    #expect(UpdateDownloadProgress.fraction(received: 150, expected: 100) == 1)
    #expect(UpdateDownloadProgress.fraction(received: 10, expected: -1) == 0)
}
