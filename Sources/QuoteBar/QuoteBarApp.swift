import AppKit
import QuoteBarCore
import SwiftUI

@main
struct QuoteBarApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            WatchlistPanel(model: model)
        } label: {
            MenuBarLabel(model: model)
                .onAppear {
                    model.start()
                    StatusItemRightClick.install()
                }
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarLabel: View {
    @ObservedObject var model: AppModel

    var body: some View {
        if let quote = model.carouselQuote {
            Text(QuoteFormat.menuBarTitle(quote))
                .monospacedDigit()
        } else if model.watchlist.items.isEmpty {
            Text("行情")
        } else if model.openCarouselItems.isEmpty {
            Text("休市")
        } else {
            Text("行情 …")
        }
    }
}
