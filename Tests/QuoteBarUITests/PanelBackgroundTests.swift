import AppKit
import SwiftUI
import Testing
@testable import QuoteBar

@Test(arguments: [NSAppearance.Name.aqua, .darkAqua])
@MainActor func panelFillsTransparentHostAboveSwiftUIContent(appearance: NSAppearance.Name) async {
    let defaults = UserDefaults(suiteName: "QuoteBar.PanelBackgroundTests")!
    let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
        styleMask: [.titled, .fullSizeContentView],
        backing: .buffered,
        defer: false
    )
    // MenuBarExtra's host can expose a region outside the SwiftUI root.
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.titlebarAppearsTransparent = true
    panel.appearance = NSAppearance(named: appearance)
    let host = NSHostingView(rootView: WatchlistPanel(model: AppModel(defaults: defaults)))
    panel.contentView = host
    host.layoutSubtreeIfNeeded()
    await Task.yield()
    #expect(panel.backgroundColor.alphaComponent == 1,
            "The region above the search field must not show the window behind it")
    // Reopening the panel must also configure a newly attached host window.
    panel.contentView = nil
    panel.backgroundColor = .clear
    panel.contentView = host
    host.layoutSubtreeIfNeeded()
    await Task.yield()
    #expect(panel.backgroundColor.alphaComponent == 1)
    #expect(!panel.isOpaque, "Preserve the host's rounded transparent corners")
    panel.contentView = nil
    panel.close()
}
