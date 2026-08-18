import Foundation

public enum UpdateDownloadProgress {
    public static func fraction(received: Int64, expected: Int64) -> Double {
        guard expected > 0 else { return 0 }
        return min(1, Double(received) / Double(expected))
    }
}

public struct DetachedLaunch: Equatable, Sendable {
    public var executable: URL
    public var arguments: [String]

    public init(executable: URL, arguments: [String]) {
        self.executable = executable
        self.arguments = arguments
    }
}

public enum UpdateInstaller {
    /// Volume names contain spaces (`/Volumes/QuoteBar 0.1.4`), so keep everything after `/Volumes/`.
    public static let mountPointFilter = #"sed -n 's|.*\(/Volumes/.*\)$|\1|p' | head -n 1"#

    public static func script(dmg: URL, destination: URL, waitPID: Int32) -> String {
        let dest = shellQuote(destination.path)
        let destOld = shellQuote(destination.path + ".old")
        let dmgQ = shellQuote(dmg.path)
        return """
        set -e
        MOUNT=""
        # Never leave the user without an app: relaunch whatever is installed on any failure.
        recover() {
          if [ -n "$MOUNT" ]; then
            hdiutil detach "$MOUNT" >/dev/null 2>&1 || true
          fi
          if [ ! -e \(dest) ] && [ -e \(destOld) ]; then
            mv \(destOld) \(dest) || true
          fi
          if [ -e \(dest) ]; then
            open \(dest) || true
          fi
          exit 1
        }
        trap recover EXIT
        while kill -0 \(waitPID) 2>/dev/null; do sleep 0.2; done
        sleep 0.3
        MOUNT="$(hdiutil attach -nobrowse -readonly \(dmgQ) | \(mountPointFilter))"
        if [ -z "$MOUNT" ]; then
          exit 1
        fi
        APP="$(find "$MOUNT" -maxdepth 2 -name 'QuoteBar.app' -type d | head -n 1)"
        if [ -z "$APP" ]; then
          exit 1
        fi
        STAGE="$(mktemp -d)/QuoteBar.app"
        rm -rf "$STAGE"
        cp -R "$APP" "$STAGE"
        hdiutil detach "$MOUNT" >/dev/null 2>&1 || true
        MOUNT=""
        rm -rf \(destOld)
        if [ -e \(dest) ]; then
          mv \(dest) \(destOld)
        fi
        mkdir -p "$(dirname \(dest))"
        cp -R "$STAGE" \(dest)
        rm -rf \(destOld)
        xattr -dr com.apple.quarantine \(dest) || true
        trap - EXIT
        open \(dest)
        rm -f \(dmgQ)
        """
    }

    public static func detachedLaunch(script: URL, log: URL) -> DetachedLaunch {
        DetachedLaunch(
            executable: URL(fileURLWithPath: "/usr/bin/nohup"),
            arguments: ["/bin/bash", script.path]
        )
    }

    public static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
