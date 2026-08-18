import XCTest
@testable import QuoteBarCore

final class MenuBarTitleTests: XCTestCase {
    func testFullStyleKeepsWholeNameAndTwoDecimals() {
        let title = MenuBarTitle.text(name: "泰嘉股份", changePercent: 1.204, style: .full)
        XCTAssertEqual(title, "泰嘉股份 +1.20%")
    }

    func testCompactStyleTrimsCJKNameToTwoGlyphsAndOneDecimal() {
        let title = MenuBarTitle.text(name: "泰嘉股份", changePercent: 1.24, style: .compact)
        XCTAssertEqual(title, "泰嘉 +1.2%")
    }

    func testCompactStyleKeepsShortLatinTickerIntact() {
        let title = MenuBarTitle.text(name: "AAPL", changePercent: -0.86, style: .compact)
        XCTAssertEqual(title, "AAPL -0.9%")
    }

    func testCompactStyleTrimsLongLatinNameToBudget() {
        XCTAssertEqual(MenuBarTitle.shorten("NVIDIA", budget: 4), "NVID")
    }

    func testShortenNeverDropsASingleWideGlyphBelowBudget() {
        XCTAssertEqual(MenuBarTitle.shorten("腾讯控股", budget: 3), "腾")
    }

    func testShortenKeepsNameThatAlreadyFits() {
        XCTAssertEqual(MenuBarTitle.shorten("上证", budget: 4), "上证")
    }

    func testNegativeChangeKeepsItsOwnSign() {
        XCTAssertEqual(MenuBarTitle.text(name: "恒生", changePercent: -1.25, style: .full), "恒生 -1.25%")
    }

    func testStylePersistenceRoundTrip() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        XCTAssertEqual(MenuBarTitleStylePersistence.load(from: defaults), .full)

        MenuBarTitleStylePersistence.save(.compact, to: defaults)
        XCTAssertEqual(MenuBarTitleStylePersistence.load(from: defaults), .compact)

        MenuBarTitleStylePersistence.save(.full, to: defaults)
        XCTAssertEqual(MenuBarTitleStylePersistence.load(from: defaults), .full)
    }
}
