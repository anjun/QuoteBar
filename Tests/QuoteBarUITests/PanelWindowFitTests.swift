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
    panel.isReleasedWhenClosed = false
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

@Test @MainActor func staleOversizedPanelFitsBeforeFirstDraw() async {
    let suite = "QuoteBar.PanelWindowFitTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = AppModel(defaults: defaults)
    model.watchlist = makeTallWatchlist()

    guard let screen = NSScreen.screens.min(by: { $0.visibleFrame.height < $1.visibleFrame.height }) else {
        return
    }
    let staleHeight = screen.visibleFrame.height + 150
    let top = screen.visibleFrame.maxY

    let panel = FrameRecordingPanel(
        contentRect: NSRect(x: screen.visibleFrame.minX + 100, y: top - staleHeight, width: 400, height: staleHeight),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    panel.isReleasedWhenClosed = false
    defer { panel.close() }

    let container = DrawHeightRecorder(frame: NSRect(x: 0, y: 0, width: 400, height: staleHeight))
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
    panel.displayIfNeeded()
    for _ in 0..<5 { try? await Task.sleep(for: .milliseconds(15)) }
    let settledHeight = panel.contentRect(forFrameRect: panel.frame).height

    #expect(settledHeight < staleHeight - 10)
    for drawnHeight in container.heightsAtWillDraw {
        #expect(abs(drawnHeight - settledHeight) < 1,
                "Panel drew at \(drawnHeight)pt before shrinking to \(settledHeight)pt")
    }
    for resizedHeight in panel.recordedHeights {
        #expect(resizedHeight <= settledHeight + 1,
                "Panel overshot to \(resizedHeight)pt above settled height \(settledHeight)pt")
    }
}

@Test @MainActor func panelScrollLimitFollowsExplicitPanelScreenHeight() {
    let suite = "QuoteBar.PanelWindowFitTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = AppModel(defaults: defaults)
    model.watchlist = makeTallWatchlist()

    model.updatePanelScreenVisibleHeight(1050)
    let tallHost = NSHostingView(rootView: WatchlistPanel(model: model))
    tallHost.layoutSubtreeIfNeeded()
    let tallHeight = tallHost.fittingSize.height

    model.updatePanelScreenVisibleHeight(640)
    let shortHost = NSHostingView(rootView: WatchlistPanel(model: model))
    shortHost.layoutSubtreeIfNeeded()
    let shortHeight = shortHost.fittingSize.height

    #expect(tallHeight - shortHeight > 250,
            "Explicit panel screen height must control WatchlistPanel's scroll limit")
    #expect(shortHeight < 640)
}

@Test @MainActor func reusedPanelTracksOwnScreenAcrossDisplaysWithoutDrawingOversized() async {
    let screens = NSScreen.screens
    guard screens.count >= 2 else { return }
    let tall = screens.max(by: { $0.visibleFrame.height < $1.visibleFrame.height })!
    let short = screens.min(by: { $0.visibleFrame.height < $1.visibleFrame.height })!
    guard tall.visibleFrame.height - short.visibleFrame.height > 40 else { return }

    // Simulate a primary status bar window living on the taller external display.
    let fakeStatusBar = NSWindow(
        contentRect: NSRect(x: tall.frame.midX, y: tall.frame.maxY - 24, width: 100, height: 24),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    fakeStatusBar.isReleasedWhenClosed = false
    defer { fakeStatusBar.close() }

    let suite = "QuoteBar.PanelWindowFitTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = AppModel(defaults: defaults)
    model.watchlist = makeTallWatchlist()

    let initialHeight = tall.visibleFrame.height - 28
    let panel = FrameRecordingPanel(
        contentRect: NSRect(x: tall.frame.midX - 200, y: tall.visibleFrame.maxY - initialHeight, width: 400, height: initialHeight),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    panel.isReleasedWhenClosed = false
    defer { panel.close() }

    let container = DrawHeightRecorder(frame: NSRect(x: 0, y: 0, width: 400, height: initialHeight))
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
    for _ in 0..<3 { try? await Task.sleep(for: .milliseconds(15)) }
    let tallSettledHeight = panel.frame.height
    #expect(tallSettledHeight > short.visibleFrame.height)

    // Move reused window to the shorter display keeping its stale tall height.
    panel.recordedHeights.removeAll()
    container.heightsAtWillDraw.removeAll()
    let shortTop = short.visibleFrame.maxY
    panel.setFrame(NSRect(x: short.frame.midX - 200, y: shortTop - tallSettledHeight, width: 400, height: tallSettledHeight), display: false)
    container.layoutSubtreeIfNeeded()
    panel.displayIfNeeded()
    let immediateShortHeight = panel.frame.height

    for _ in 0..<5 { try? await Task.sleep(for: .milliseconds(15)) }
    let shortSettledHeight = panel.frame.height
    let shortAnchorHeight = findBackgroundAnchor(in: container)?.bounds.height ?? -1

    // Subsequent background quote refresh must not cause a second shrink.
    model.carouselIndex += 1
    for _ in 0..<3 { try? await Task.sleep(for: .milliseconds(15)) }

    #expect(abs(immediateShortHeight - shortSettledHeight) < 1)
    #expect(shortAnchorHeight <= shortSettledHeight + 1,
            "Content (\(shortAnchorHeight)pt) must not overflow the shorter screen's window (\(shortSettledHeight)pt)")
    #expect(abs(panel.frame.height - shortSettledHeight) < 1)
    #expect(abs(panel.frame.maxY - shortTop) < 1)
    for drawnHeight in container.heightsAtWillDraw {
        #expect(abs(drawnHeight - shortSettledHeight) < 1)
    }

    // Moving back to the taller display restores the taller height.
    let tallTop = tall.visibleFrame.maxY
    panel.setFrame(NSRect(x: tall.frame.midX - 200, y: tallTop - shortSettledHeight, width: 400, height: shortSettledHeight), display: false)
    container.layoutSubtreeIfNeeded()
    for _ in 0..<3 { try? await Task.sleep(for: .milliseconds(15)) }
    #expect(abs(panel.frame.height - tallSettledHeight) < 1)
    #expect(abs(panel.frame.maxY - tallTop) < 1)
}

@Test @MainActor func preseededClickScreenHeightSurvivesHiddenWindowAttachment() async {
    let screens = NSScreen.screens
    guard screens.count >= 2 else { return }
    let tall = screens.max(by: { $0.visibleFrame.height < $1.visibleFrame.height })!
    let short = screens.min(by: { $0.visibleFrame.height < $1.visibleFrame.height })!
    guard tall.visibleFrame.height - short.visibleFrame.height > 40 else { return }

    let suite = "QuoteBar.PanelWindowFitTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = AppModel(defaults: defaults)
    model.watchlist = makeTallWatchlist()
    model.updatePanelScreenVisibleHeight(short.visibleFrame.height)

    let staleHeight = tall.visibleFrame.height - 28
    let panel = NSPanel(
        contentRect: NSRect(x: tall.frame.midX - 200, y: tall.visibleFrame.maxY - staleHeight, width: 400, height: staleHeight),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    panel.isReleasedWhenClosed = false
    defer { panel.close() }

    let container = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: staleHeight))
    panel.contentView = container
    let host = NSHostingView(rootView: WatchlistPanel(model: model))
    host.sizingOptions = []
    host.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(host)
    NSLayoutConstraint.activate([
        host.topAnchor.constraint(equalTo: container.topAnchor),
        host.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        host.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        host.trailingAnchor.constraint(equalTo: container.trailingAnchor),
    ])
    container.layoutSubtreeIfNeeded()

    #expect(abs((model.panelScreenVisibleHeight ?? 0) - short.visibleFrame.height) < 1,
            "Attaching to a hidden window parked on another screen must not clobber the clicked screen height")
    let anchorHeight = findBackgroundAnchor(in: container)?.bounds.height ?? -1
    #expect(anchorHeight < short.visibleFrame.height)
}

private final class FrameRecordingPanel: NSPanel {
    var recordedHeights: [CGFloat] = []

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        recordedHeights.append(frameRect.height)
        super.setFrame(frameRect, display: flag)
    }

    override func setFrame(_ frameRect: NSRect, display displayFlag: Bool, animate animateFlag: Bool) {
        recordedHeights.append(frameRect.height)
        super.setFrame(frameRect, display: displayFlag, animate: animateFlag)
    }
}

private final class DrawHeightRecorder: NSView {
    var heightsAtWillDraw: [CGFloat] = []

    override func viewWillDraw() {
        super.viewWillDraw()
        if let height = window?.frame.height {
            heightsAtWillDraw.append(height)
        }
    }
}

private func makeTallWatchlist() -> Watchlist {
    var items: [SymbolID] = []
    for i in 0..<7 { items.append(.shStock(String(format: "600%03d", i))) }
    for i in 0..<5 { items.append(.szStock(String(format: "000%03d", i))) }
    items.append(.hkStock("00700"))
    for i in 0..<4 { items.append(.usStock("US\(i)")) }
    items.append(.future("AU0", quoteMarket: 113))
    items.append(.metal("AUUSDO"))
    items.append(.crypto("BTC"))
    return Watchlist(items: items)
}

private func findBackgroundAnchor(in view: NSView) -> PanelWindowBackground.BackgroundAnchor? {
    if let anchor = view as? PanelWindowBackground.BackgroundAnchor { return anchor }
    for subview in view.subviews {
        if let found = findBackgroundAnchor(in: subview) { return found }
    }
    return nil
}
