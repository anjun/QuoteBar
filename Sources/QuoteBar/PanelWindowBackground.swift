import AppKit
import SwiftUI

/// Fill host-owned regions as well as the SwiftUI content. MenuBarExtra can
/// leave space above its hosting view that a SwiftUI background cannot paint.
/// It can also retain a stale larger size after the content shrinks, centering
/// the SwiftUI root inside the window; pin the window's height to the content's
/// fitting size so no blank bands appear above or below the panel.
struct PanelWindowBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> BackgroundAnchor { BackgroundAnchor() }

    func updateNSView(_ nsView: BackgroundAnchor, context: Context) {
        nsView.apply()
    }

    final class BackgroundAnchor: NSView {
        private var resizeObserver: NSObjectProtocol?
        private var fitPending = false

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        deinit {
            if let resizeObserver { NotificationCenter.default.removeObserver(resizeObserver) }
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let resizeObserver {
                NotificationCenter.default.removeObserver(resizeObserver)
                self.resizeObserver = nil
            }
            if let window {
                resizeObserver = NotificationCenter.default.addObserver(
                    forName: NSWindow.didResizeNotification,
                    object: window,
                    queue: .main
                ) { [weak self] _ in self?.apply() }
            }
            apply()
            // The host finishes configuring the window after attaching content.
            DispatchQueue.main.async { [weak self] in self?.apply() }
        }

        override func layout() {
            super.layout()
            apply()
        }

        func apply() {
            guard let window else { return }
            if window.backgroundColor != .windowBackgroundColor {
                window.backgroundColor = .windowBackgroundColor
            }
            // Resizing the window during layout loops AppKit's constraint pass.
            guard !fitPending else { return }
            fitPending = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.fitPending = false
                self.fit()
            }
        }

        /// The anchor backs the panel root, so its height is the content height.
        /// MenuBarExtra's hosting view reports a zero `fittingSize`, so it
        /// cannot be asked for the content size.
        private func fit() {
            guard let window, let root = window.contentView else { return }
            let fitting = bounds.height
            guard fitting.isFinite, fitting > 0 else { return }
            // Never extend past the screen's visible area.
            let screenCap = window.screen.map { $0.visibleFrame.height - 12 } ?? .infinity
            let excess = root.bounds.height - min(fitting, screenCap)
            guard abs(excess) > 0.5 else { return }
            var frame = window.frame
            frame.origin.y += excess
            frame.size.height -= excess
            window.setFrame(frame, display: true, animate: false)
        }
    }
}
