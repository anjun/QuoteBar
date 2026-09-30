import AppKit
import SwiftUI

/// Fill host-owned regions as well as the SwiftUI content. MenuBarExtra can
/// leave space above its hosting view that a SwiftUI background cannot paint.
struct PanelWindowBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> BackgroundAnchor { BackgroundAnchor() }

    func updateNSView(_ nsView: BackgroundAnchor, context: Context) {
        nsView.apply()
    }

    final class BackgroundAnchor: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            apply()
            // The host finishes configuring the window after attaching content.
            DispatchQueue.main.async { [weak self] in self?.apply() }
        }

        func apply() {
            window?.backgroundColor = .windowBackgroundColor
        }
    }
}
