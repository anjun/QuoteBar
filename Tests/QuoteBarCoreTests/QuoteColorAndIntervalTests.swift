import Testing
@testable import QuoteBarCore

@Test func colorSignIsRedUpGreenDownForAllMarkets() {
    #expect(QuoteColorSign.of(change: 0.22) == .up)
    #expect(QuoteColorSign.of(change: -0.34) == .down)
    #expect(QuoteColorSign.of(change: 0) == .flat)
    #expect(QuoteColorSign.of(changePercent: 1.2) == .up)
    #expect(QuoteColorSign.of(changePercent: -0.5) == .down)
}

@Test func refreshIntervalStaysBetweenFiveAndTenSeconds() {
    #expect(RefreshPolicy.minimumSeconds == 5)
    #expect(RefreshPolicy.maximumSeconds == 10)
    #expect(RefreshPolicy.defaultSeconds >= 5)
    #expect(RefreshPolicy.defaultSeconds <= 10)
    #expect(RefreshPolicy.clamp(3) == 5)
    #expect(RefreshPolicy.clamp(12) == 10)
    #expect(RefreshPolicy.clamp(8) == 8)
}
