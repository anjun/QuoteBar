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
        private var isFitting = false

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
            fit(window)
        }

        private func fit(_ window: NSWindow) {
            guard !isFitting, let hosting = hostingView() else { return }
            let fitting = hosting.fittingSize.height
            guard fitting.isFinite, fitting > 0 else { return }
            // Never extend past the screen's visible area.
            let screenCap = window.screen.map { $0.visibleFrame.height - 12 } ?? .infinity
            let desired = min(fitting, screenCap)
            let current = window.contentRect(forFrameRect: window.frame).height
            guard abs(current - desired) > 0.5 else { return }
            let newHeight = window.frameRect(forContentRect: NSRect(
                x: 0, y: 0, width: window.frame.width, height: desired
            )).height
            guard abs(newHeight - window.frame.height) > 0.5 else { return }
            var frame = window.frame
            frame.origin.y += frame.height - newHeight
            frame.size.height = newHeight
            isFitting = true
            window.setFrame(frame, display: false, animate: false)
            isFitting = false
        }

        private func hostingView() -> NSView? {
            var view = superview
            while let candidate = view {
                if NSStringFromClass(type(of: candidate)).contains("HostingView") {
                    return candidate
                }
                view = candidate.superview
            }
            return nil
        }
    }
}
