import AppKit
import SwiftUI

struct RightClickCatcher: NSViewRepresentable {
    var consume: Bool = false
    var onRightClick: () -> Void

    func makeNSView(context: Context) -> CatcherView {
        let view = CatcherView()
        view.consume = consume
        view.onRightClick = onRightClick
        return view
    }

    func updateNSView(_ nsView: CatcherView, context: Context) {
        nsView.consume = consume
        nsView.onRightClick = onRightClick
    }

    final class CatcherView: NSView {
        var consume = false
        var onRightClick: (() -> Void)?
        private var monitor: Any?

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
                guard let self, self.handle(event) else { return event }
                return self.consume ? nil : event
            }
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        @discardableResult
        private func handle(_ event: NSEvent) -> Bool {
            guard let window, event.window == window else { return false }
            let location = convert(event.locationInWindow, from: nil)
            guard bounds.contains(location) else { return false }
            onRightClick?()
            return true
        }
    }
}
