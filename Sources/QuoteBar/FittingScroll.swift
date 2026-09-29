import AppKit
import SwiftUI

struct FittingScroll<Content: View>: View {
    var maxHeight: CGFloat
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background { LegacyScrollerAnchor() }
        }
        .scrollIndicators(.automatic, axes: .vertical)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .frame(maxHeight: maxHeight)
        .fixedSize(horizontal: false, vertical: true)
    }
}

enum MenuBarScreen {
    static func visibleHeight() -> CGFloat {
        let height = statusItemScreen()?.visibleFrame.height
            ?? screen(containing: NSEvent.mouseLocation)?.visibleFrame.height
            ?? NSScreen.main?.visibleFrame.height
            ?? 0
        return height > 0 ? height : 800
    }

    static func statusItemScreen() -> NSScreen? {
        let windows = NSApp.windows.filter { $0.frame.height <= 40 }
        let primary = windows.first { !isReplicant($0) && isStatusItem($0) }
            ?? windows.first(where: isStatusItem)
        return primary?.screen
    }

    private static func screen(containing point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) }
    }

    private static func isStatusItem(_ window: NSWindow) -> Bool {
        let className = NSStringFromClass(type(of: window))
        if className.contains("StatusBar") || className.contains("MenuBarExtra") {
            return true
        }
        guard let screen = window.screen else { return false }
        return window.frame.maxY >= screen.frame.maxY - 2
    }

    private static func isReplicant(_ window: NSWindow) -> Bool {
        guard let root = window.contentView else { return false }
        func walk(_ view: NSView) -> Bool {
            if NSStringFromClass(type(of: view)).contains("Replicant") { return true }
            return view.subviews.contains(where: walk)
        }
        return walk(root)
    }
}

private struct LegacyScrollerAnchor: NSViewRepresentable {
    func makeNSView(context: Context) -> AnchorView { AnchorView() }

    func updateNSView(_ nsView: AnchorView, context: Context) {
        nsView.apply()
    }

    final class AnchorView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            apply()
            DispatchQueue.main.async { [weak self] in self?.apply() }
        }

        func apply() {
            guard let scroll = enclosingScrollView else { return }
            if scroll.scrollerStyle != .legacy {
                scroll.scrollerStyle = .legacy
            }
            if !scroll.autohidesScrollers {
                scroll.autohidesScrollers = true
            }
            if !scroll.hasVerticalScroller {
                scroll.hasVerticalScroller = true
            }
            if scroll.hasHorizontalScroller {
                scroll.hasHorizontalScroller = false
            }
        }
    }
}
