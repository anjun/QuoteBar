import Foundation

public enum PanelLayout {
    /// Search field, footer, padding, and a gap above the Dock.
    public static let reservedChrome: CGFloat = 120
    /// Preferred list height once the screen can spare it.
    public static let minimumBodyHeight: CGFloat = 160
    /// Smallest list height that still scrolls on a short screen.
    public static let shortScreenBodyFloor: CGFloat = 80

    public static func bodyHeightLimit(
        visibleHeight: CGFloat,
        reservedChrome: CGFloat = PanelLayout.reservedChrome,
        minimumBodyHeight: CGFloat = PanelLayout.minimumBodyHeight,
        shortScreenBodyFloor: CGFloat = PanelLayout.shortScreenBodyFloor
    ) -> CGFloat {
        guard visibleHeight.isFinite, visibleHeight > 0 else { return minimumBodyHeight }
        let available = visibleHeight - reservedChrome
        if available >= minimumBodyHeight { return available }
        if available >= shortScreenBodyFloor { return available }
        return minimumBodyHeight
    }
}
