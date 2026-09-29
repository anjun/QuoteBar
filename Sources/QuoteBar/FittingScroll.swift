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
        let point = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        let height = screen?.visibleFrame.height ?? 0
        return height > 0 ? height : 800
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
