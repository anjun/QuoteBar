import Foundation
import Testing
@testable import QuoteBarCore

@Test func aShareRegularHoursExcludeLunchWeekendAndClose() {
    #expect(MarketSession.isOpen(.sh, at: weekday(tz: shanghai, hour: 10, minute: 0)))
    #expect(MarketSession.isOpen(.sz, at: weekday(tz: shanghai, hour: 14, minute: 0)))
    #expect(!MarketSession.isOpen(.sh, at: weekday(tz: shanghai, hour: 9, minute: 29)))
    #expect(!MarketSession.isOpen(.sh, at: weekday(tz: shanghai, hour: 12, minute: 0)))
    #expect(!MarketSession.isOpen(.sh, at: weekday(tz: shanghai, hour: 15, minute: 0)))
    #expect(!MarketSession.isOpen(.sh, at: saturday(tz: shanghai, hour: 10, minute: 0)))
}

@Test func hongKongRegularHoursIncludeAfternoonAfterAShareClose() {
    #expect(MarketSession.isOpen(.hk, at: weekday(tz: hongKong, hour: 10, minute: 0)))
    #expect(MarketSession.isOpen(.hk, at: weekday(tz: hongKong, hour: 15, minute: 30)))
    #expect(!MarketSession.isOpen(.hk, at: weekday(tz: hongKong, hour: 12, minute: 10)))
    #expect(!MarketSession.isOpen(.hk, at: weekday(tz: hongKong, hour: 16, minute: 0)))
}

@Test func usRegularHoursUseNewYorkTimeAndIgnorePrePost() {
    #expect(MarketSession.isOpen(.us, at: weekday(tz: newYork, hour: 10, minute: 0)))
    #expect(MarketSession.isOpen(.us, at: weekday(tz: newYork, hour: 15, minute: 59)))
    #expect(!MarketSession.isOpen(.us, at: weekday(tz: newYork, hour: 9, minute: 29)))
    #expect(!MarketSession.isOpen(.us, at: weekday(tz: newYork, hour: 16, minute: 0)))
    #expect(!MarketSession.isOpen(.us, at: weekday(tz: shanghai, hour: 10, minute: 0)))
}

@Test func carouselKeepsOnlyOpenIndicesFromWatchlist() {
    let list = [
        SymbolID.shIndex("000001"),
        SymbolID.szIndex("399001"),
        SymbolID.hkIndex("HSI"),
        SymbolID.usIndex("NDX"),
        SymbolID.shETF("510300"),
        SymbolID.usStock("AAPL"),
    ]

    let asiaMorning = CarouselSelection.indices(
        from: list,
        at: weekday(tz: shanghai, hour: 10, minute: 0)
    )
    #expect(asiaMorning == [
        SymbolID.shIndex("000001"),
        SymbolID.szIndex("399001"),
        SymbolID.hkIndex("HSI"),
    ])

    let hkOnlyAfternoon = CarouselSelection.indices(
        from: list,
        at: weekday(tz: hongKong, hour: 15, minute: 30)
    )
    #expect(hkOnlyAfternoon == [SymbolID.hkIndex("HSI")])

    let usHours = CarouselSelection.indices(
        from: list,
        at: weekday(tz: newYork, hour: 10, minute: 0)
    )
    #expect(usHours == [SymbolID.usIndex("NDX")])

    let weekend = CarouselSelection.indices(
        from: list,
        at: saturday(tz: shanghai, hour: 10, minute: 0)
    )
    #expect(weekend.isEmpty)
}

private let shanghai = TimeZone(identifier: "Asia/Shanghai")!
private let hongKong = TimeZone(identifier: "Asia/Hong_Kong")!
private let newYork = TimeZone(identifier: "America/New_York")!

private func weekday(tz: TimeZone, hour: Int, minute: Int) -> Date {
    date(tz: tz, year: 2026, month: 8, day: 18, hour: hour, minute: minute)
}

private func saturday(tz: TimeZone, hour: Int, minute: Int) -> Date {
    date(tz: tz, year: 2026, month: 8, day: 22, hour: hour, minute: minute)
}

private func date(tz: TimeZone, year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = tz
    return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}
