import AppKit
import QuoteBarCore
import SwiftUI
import Testing
@testable import QuoteBar

/// MenuBarExtra's window can keep a stale larger height after the content
/// shrinks, centering the SwiftUI root and exposing blank bands above and
/// below. The panel must force its host window back to the content height.
@Test @MainActor func panelWindowTracksFittingSizeWhenHostKeepsStaleHeight() async {
    let suite = "QuoteBar.PanelWindowFitTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = AppModel(defaults: defaults)
    model.watchlist = Watchlist(items: (0..<6).map { .shStock(String(format: "%06d", $0)) })
    let panel = NSPanel(
        contentRect: NSRect(x: 842, y: 0, width: 400, height: 900),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    defer { panel.close() }
    let fitted = NSHostingView(rootView: WatchlistPanel(model: model)).fittingSize.height
    // Like the real MenuBarExtra host: the window size is decoupled from the
    // content, and the hosting view reports a zero fitting size.
    let container = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 900))
    let host = NSHostingView(rootView: WatchlistPanel(model: model))
    host.sizingOptions = []
    host.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(host)
    panel.contentView = container
    NSLayoutConstraint.activate([
        host.topAnchor.constraint(equalTo: container.topAnchor),
        host.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        host.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        host.trailingAnchor.constraint(equalTo: container.trailingAnchor),
    ])
    container.layoutSubtreeIfNeeded()
    await Task.yield()

    #expect(host.fittingSize.height == 0, "Fixture must not expose the content size via the host")
    #expect(fitted > 100, "Fixture should produce a measurable panel")
    #expect(abs(panel.contentRect(forFrameRect: panel.frame).height - fitted) < 2,
            "Attaching must already shrink an oversized host window to the content")

    let top = panel.frame.maxY
    panel.setFrame(NSRect(x: 842, y: top - 973, width: 400, height: 973), display: false)
    await Task.yield()
    #expect(abs(panel.contentRect(forFrameRect: panel.frame).height - fitted) < 2,
            "A stale oversized window must be shrunk back to the content height")
    #expect(abs(panel.frame.maxY - top) < 1,
            "Resizing must keep the panel's top edge anchored under the menu bar")

    // And it must keep tracking if the host grows the window again.
    panel.setFrame(NSRect(x: 842, y: top - 850, width: 400, height: 850), display: false)
    await Task.yield()
    #expect(abs(panel.contentRect(forFrameRect: panel.frame).height - fitted) < 2)
}
