import AppKit
import QuartzCore
import SwiftUI

/// Fill host-owned regions as well as the SwiftUI content. MenuBarExtra can
/// leave space above its hosting view that a SwiftUI background cannot paint.
/// It can also retain a stale larger size after the content shrinks or after
/// moving from a taller display to a shorter one; track the host window's
/// screen and pin the window's height to the content before it draws so it
/// does not flash oversized and then shrink.
struct PanelWindowBackground: NSViewRepresentable {
    var renderedVisibleHeight: CGFloat? = nil
    var hasExplicitScreenHeight: Bool = false
    var onScreenHeightChange: ((CGFloat) -> Void)? = nil

    func makeNSView(context: Context) -> BackgroundAnchor {
        let view = BackgroundAnchor()
        view.renderedVisibleHeight = renderedVisibleHeight
        view.hasExplicitScreenHeight = hasExplicitScreenHeight
        view.onScreenHeightChange = onScreenHeightChange
        return view
    }

    func updateNSView(_ nsView: BackgroundAnchor, context: Context) {
        nsView.renderedVisibleHeight = renderedVisibleHeight
        nsView.hasExplicitScreenHeight = hasExplicitScreenHeight
        nsView.onScreenHeightChange = onScreenHeightChange
        nsView.isInSwiftUIUpdate = true
        nsView.applyBackground()
        nsView.scheduleFit()
        nsView.isInSwiftUIUpdate = false
    }

    final class BackgroundAnchor: NSView {
        var renderedVisibleHeight: CGFloat?
        var hasExplicitScreenHeight = false
        var onScreenHeightChange: ((CGFloat) -> Void)?
        var isInSwiftUIUpdate = false

        private var observers: [NSObjectProtocol] = []
        private var runLoopObserver: CFRunLoopObserver?
        private var isInLayout = false
        private var isFitting = false
        private var fitScheduled = false
        private var needsScreenSync = false
        private weak var lastObservedScreen: NSScreen?
        private var lastObservedScreenHeight: CGFloat?

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        deinit {
            removeWindowObservers()
            invalidateRunLoopObserver()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            removeWindowObservers()
            lastObservedScreen = nil
            lastObservedScreenHeight = nil
            guard let window else {
                invalidateRunLoopObserver()
                return
            }
            applyBackground()
            installWindowObservers(for: window)

            if isInLayout || isInSwiftUIUpdate {
                // Defer model updates until outside SwiftUI's view-update pass,
                // before the frame commits or draws.
                needsScreenSync = window.isVisible || !hasExplicitScreenHeight
                if !needsScreenSync {
                    recordCurrentScreen(of: window)
                }
                scheduleFit()
            } else {
                if window.isVisible || !hasExplicitScreenHeight {
                    if syncScreenHeight(for: window, force: true) {
                        window.layoutIfNeeded()
                    }
                } else {
                    recordCurrentScreen(of: window)
                }
                if !hasStaleScreenLayout(for: window) {
                    fit(display: false)
                }
                scheduleFit()
            }
        }

        override func layout() {
            isInLayout = true
            super.layout()
            isInLayout = false
            applyBackground()
            if !isFitting {
                scheduleFit()
            }
        }

        override func viewWillDraw() {
            applyBackground()
            if !isInLayout && !isFitting, let window {
                let screenChanged = syncScreenHeight(for: window, force: needsScreenSync)
                needsScreenSync = false
                if screenChanged || hasStaleScreenLayout(for: window) {
                    window.layoutIfNeeded()
                }
                fit(display: false)
                fitScheduled = false
                invalidateRunLoopObserver()
            }
            super.viewWillDraw()
        }

        func applyBackground() {
            guard let window else { return }
            if window.backgroundColor != .windowBackgroundColor {
                window.backgroundColor = .windowBackgroundColor
            }
        }

        func scheduleFit() {
            guard let window else { return }
            if needsFit(for: window) {
                needsDisplay = true
            }
            guard !fitScheduled else { return }
            fitScheduled = true
            installRunLoopObserverIfNeeded()
            DispatchQueue.main.async { [weak self] in
                self?.runScheduledFit()
            }
        }

        private func installWindowObservers(for window: NSWindow) {
            let center = NotificationCenter.default
            observers.append(center.addObserver(
                forName: NSWindow.didResizeNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.handleWindowDidResize()
            })
            observers.append(center.addObserver(
                forName: NSWindow.didMoveNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.handleWindowScreenChangeIfNeeded(force: false)
            })
            observers.append(center.addObserver(
                forName: NSWindow.didChangeScreenNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.handleWindowScreenChangeIfNeeded(force: true)
            })
            observers.append(center.addObserver(
                forName: NSWindow.didChangeScreenProfileNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.handleWindowScreenChangeIfNeeded(force: true)
            })
            observers.append(center.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.handleWindowGeometryChange(syncEvenIfSameScreen: true)
            })
            observers.append(center.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleWindowScreenChangeIfNeeded(force: true)
            })
        }

        private func removeWindowObservers() {
            let center = NotificationCenter.default
            for observer in observers {
                center.removeObserver(observer)
            }
            observers.removeAll()
        }

        private func installRunLoopObserverIfNeeded() {
            guard runLoopObserver == nil else { return }
            // Order 0 runs before AppKit's display cycle (~600_000) and
            // CoreAnimation's transaction commit (~2_000_000), so the window
            // resizes in the same frame before anything paints on screen.
            let observer = CFRunLoopObserverCreateWithHandler(
                kCFAllocatorDefault,
                CFRunLoopActivity.beforeWaiting.rawValue,
                false,
                0
            ) { [weak self] _, _ in
                guard let self else { return }
                self.runLoopObserver = nil
                self.runScheduledFit()
            }
            if let observer {
                runLoopObserver = observer
                CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
            }
        }

        private func invalidateRunLoopObserver() {
            if let observer = runLoopObserver {
                CFRunLoopRemoveObserver(CFRunLoopGetMain(), observer, .commonModes)
                runLoopObserver = nil
            }
        }

        private func handleWindowScreenChangeIfNeeded(force: Bool) {
            guard let window, !isFitting else { return }
            if isInLayout || isInSwiftUIUpdate {
                needsScreenSync = needsScreenSync || force
                scheduleFit()
                return
            }
            if syncScreenHeight(for: window, force: force) {
                window.layoutIfNeeded()
                if !hasStaleScreenLayout(for: window) {
                    fit(display: window.isVisible)
                }
                scheduleFit()
            }
        }

        private func handleWindowDidResize() {
            guard let window, !isFitting else { return }
            applyBackground()
            // `didResizeNotification` can fire synchronously inside AppKit's
            // `updateConstraintsIfNeeded()` pass (via NSHostingView), where
            // calling `window.setFrame` would loop constraints. Defer to the
            // pre-commit RunLoop observer so it still runs before drawing.
            if lastObservedScreen !== window.screen {
                needsScreenSync = true
            }
            scheduleFit()
        }

        private func handleWindowGeometryChange(syncEvenIfSameScreen: Bool) {
            guard let window, !isFitting else { return }
            applyBackground()
            if isInLayout || isInSwiftUIUpdate {
                if syncEvenIfSameScreen { needsScreenSync = true }
                scheduleFit()
                return
            }
            if syncScreenHeight(for: window, force: syncEvenIfSameScreen) {
                window.layoutIfNeeded()
            }
            if !hasStaleScreenLayout(for: window) {
                fit(display: window.isVisible)
            }
            scheduleFit()
        }

        private func runScheduledFit() {
            guard fitScheduled, let window else {
                fitScheduled = false
                invalidateRunLoopObserver()
                return
            }
            guard !isInLayout, !isInSwiftUIUpdate, !isFitting else {
                installRunLoopObserverIfNeeded()
                return
            }
            fitScheduled = false
            invalidateRunLoopObserver()
            applyBackground()
            if needsScreenSync {
                needsScreenSync = false
                if syncScreenHeight(for: window, force: true) {
                    window.layoutIfNeeded()
                }
            }
            fit(display: window.isVisible)
        }

        private func recordCurrentScreen(of window: NSWindow) {
            guard let screen = window.screen else { return }
            lastObservedScreen = screen
            lastObservedScreenHeight = screen.visibleFrame.height
        }

        @discardableResult
        private func syncScreenHeight(for window: NSWindow, force: Bool) -> Bool {
            guard let screen = window.screen else { return false }
            let height = screen.visibleFrame.height
            guard height.isFinite, height > 0 else { return false }
            let screenChanged = lastObservedScreen !== screen
                || lastObservedScreenHeight.map { abs($0 - height) > 0.5 } ?? true
            guard force || screenChanged else { return false }
            lastObservedScreen = screen
            lastObservedScreenHeight = height
            onScreenHeightChange?(height)
            return true
        }

        private func hasStaleScreenLayout(for window: NSWindow) -> Bool {
            guard let renderedVisibleHeight,
                  let screenHeight = window.screen?.visibleFrame.height,
                  screenHeight.isFinite, screenHeight > 0 else {
                return false
            }
            return abs(renderedVisibleHeight - screenHeight) > 0.5
        }

        private func currentContentHeight(of window: NSWindow) -> CGFloat? {
            guard let root = window.contentView else { return nil }
            let layoutHeight = window.contentLayoutRect.height
            return layoutHeight > 0 ? layoutHeight : root.bounds.height
        }

        private func needsFit(for window: NSWindow) -> Bool {
            guard let currentHeight = currentContentHeight(of: window) else { return false }
            let fitting = bounds.height
            guard fitting.isFinite, fitting > 0 else { return false }
            let screenCap = window.screen.map { $0.visibleFrame.height - 12 } ?? .infinity
            return abs(currentHeight - min(fitting, screenCap)) > 0.5
        }

        /// The anchor backs the panel root, so its height is the content height.
        /// MenuBarExtra's hosting view reports a zero `fittingSize`, so it
        /// cannot be asked for the content size.
        private func fit(display: Bool) {
            guard !isFitting, !isInLayout, let window,
                  let currentHeight = currentContentHeight(of: window) else { return }
            let fitting = bounds.height
            guard fitting.isFinite, fitting > 0 else { return }
            // Never extend past the screen's visible area.
            let screenCap = window.screen.map { $0.visibleFrame.height - 12 } ?? .infinity
            let excess = currentHeight - min(fitting, screenCap)
            guard abs(excess) > 0.5 else { return }
            var frame = window.frame
            frame.origin.y += excess
            frame.size.height -= excess
            isFitting = true
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            window.setFrame(frame, display: display, animate: false)
            CATransaction.commit()
            isFitting = false
        }
    }
}
