import Foundation
import Testing
@testable import QuoteBarCore

@Test func panelScrollLimitLeavesRoomForSearchAndFooter() {
    let limit = PanelLayout.bodyHeightLimit(visibleHeight: 900)
    #expect(limit == 900 - PanelLayout.reservedChrome)
    #expect(limit >= PanelLayout.minimumBodyHeight)
}

@Test func panelScrollLimitShrinksOnAShortScreen() {
    let visible: CGFloat = PanelLayout.reservedChrome + 100
    let limit = PanelLayout.bodyHeightLimit(visibleHeight: visible)
    #expect(limit == 100)
    #expect(limit < PanelLayout.minimumBodyHeight)
    #expect(limit + PanelLayout.reservedChrome == visible)
}

@Test func panelScrollLimitFallsBackWhenTheScreenHeightIsUnknown() {
    #expect(PanelLayout.bodyHeightLimit(visibleHeight: 0) == PanelLayout.minimumBodyHeight)
    #expect(PanelLayout.bodyHeightLimit(visibleHeight: -20) == PanelLayout.minimumBodyHeight)
    #expect(PanelLayout.bodyHeightLimit(visibleHeight: .nan) == PanelLayout.minimumBodyHeight)
    #expect(PanelLayout.bodyHeightLimit(visibleHeight: .infinity) == PanelLayout.minimumBodyHeight)
    let tiny = PanelLayout.bodyHeightLimit(visibleHeight: PanelLayout.reservedChrome + 40)
    #expect(tiny == PanelLayout.minimumBodyHeight)
}
