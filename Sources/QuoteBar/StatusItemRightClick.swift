import AppKit

enum StatusItemRightClick {
    private static var monitor: Any?
    private static let target = StatusItemMenuTarget()

    static func install() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown, .rightMouseUp, .leftMouseDown]) { event in
            guard isStatusItemClick(event) else { return event }
            if event.type == .rightMouseDown || isControlClick(event) {
                showQuitMenu(with: event)
                return nil
            }
            if event.type == .rightMouseUp {
                return nil
            }
            return event
        }
    }

    private static func isControlClick(_ event: NSEvent) -> Bool {
        event.type == .leftMouseDown && event.modifierFlags.contains(.control)
    }

    private static func isStatusItemClick(_ event: NSEvent) -> Bool {
        guard let window = event.window else { return false }
        guard window.frame.height <= 40 else { return false }
        let className = NSStringFromClass(type(of: window))
        if className.contains("StatusBar") || className.contains("MenuBarExtra") {
            return true
        }
        if let screen = window.screen ?? NSScreen.main {
            return window.frame.maxY >= screen.visibleFrame.maxY - 2
        }
        return false
    }

    private static func showQuitMenu(with event: NSEvent) {
        let menu = NSMenu()
        let version = NSMenuItem(
            title: "QuoteBar \(AppVersion.marketing)",
            action: nil,
            keyEquivalent: ""
        )
        version.isEnabled = false
        menu.addItem(version)
        menu.addItem(.separator())
        let update = NSMenuItem(
            title: "检查更新",
            action: #selector(StatusItemMenuTarget.checkForUpdates),
            keyEquivalent: ""
        )
        update.target = target
        menu.addItem(update)
        menu.addItem(.separator())
        let quit = NSMenuItem(
            title: "退出",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quit.target = NSApp
        menu.addItem(quit)

        if let view = event.window?.contentView {
            NSMenu.popUpContextMenu(menu, with: event, for: view)
        } else {
            menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        }
    }
}

final class StatusItemMenuTarget: NSObject {
    @objc func checkForUpdates() {
        Task { await AppUpdater.check(interactive: true) }
    }
}
