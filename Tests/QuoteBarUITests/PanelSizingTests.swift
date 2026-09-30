import AppKit
import QuoteBarCore
import SwiftUI
import Testing
@testable import QuoteBar

@Test @MainActor func emptyPanelFitsItsContentWithoutVerticalSlack() {
    let suite = "QuoteBar.PanelSizingTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = AppModel(defaults: defaults)
    model.watchlist = Watchlist(items: [])
    let host = NSHostingView(rootView: WatchlistPanel(model: model))
    host.frame = NSRect(x: 0, y: 0, width: 400, height: 900)
    host.layoutSubtreeIfNeeded()
    #expect(host.fittingSize.width == 400)
    #expect(host.fittingSize.height < 180,
            "An empty panel must fit the search field, empty state and footer, not fill the screen")
    let measurement = PanelMeasurement()
    let proposedHost = NSHostingView(rootView: PanelSizingProbe(measurement: measurement, height: 900) {
        WatchlistPanel(model: model)
    })
    proposedHost.frame = host.frame
    proposedHost.layoutSubtreeIfNeeded()
    #expect(measurement.size.height < 180,
            "The menu bar host must not stretch the panel beyond its content height")
}

@Test(arguments: [1, 10, 60], [CGFloat(600), 900, 1400])
@MainActor func panelHeightIsIndependentOfHostSlack(itemCount: Int, proposedHeight: CGFloat) {
    let suite = "QuoteBar.PanelSizingTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = AppModel(defaults: defaults)
    model.watchlist = Watchlist(items: (0..<itemCount).map { .shStock(String(format: "%06d", $0)) })
    let host = NSHostingView(rootView: WatchlistPanel(model: model))
    host.layoutSubtreeIfNeeded()
    let contentHeight = host.fittingSize.height
    let measurement = PanelMeasurement()
    let proposedHost = NSHostingView(rootView: PanelSizingProbe(measurement: measurement, height: proposedHeight) {
        WatchlistPanel(model: model)
    })
    proposedHost.frame = NSRect(x: 0, y: 0, width: 400, height: proposedHeight)
    proposedHost.layoutSubtreeIfNeeded()
    #expect(abs(measurement.size.height - contentHeight) < 1,
            "Additional host space must not introduce blank areas above or below the panel")
}

@Test(arguments: [CGFloat(44), 600], [CGFloat(100), 200])
@MainActor func fittingScrollUsesContentHeightUpToTheScreenLimit(contentHeight: CGFloat, limit: CGFloat) {
    let host = NSHostingView(rootView: FittingScroll(maxHeight: limit) {
        Color.clear.frame(height: contentHeight)
    }.frame(width: 376))
    host.layoutSubtreeIfNeeded()
    #expect(abs(host.fittingSize.height - min(contentHeight, limit)) < 1)
}

private final class PanelMeasurement {
    var size: CGSize = .zero
}

private struct PanelSizingProbe: Layout {
    let measurement: PanelMeasurement
    let height: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        measurement.size = subviews[0].sizeThatFits(ProposedViewSize(width: 400, height: height))
        return measurement.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews[0].place(at: bounds.origin, proposal: ProposedViewSize(measurement.size))
    }
}
