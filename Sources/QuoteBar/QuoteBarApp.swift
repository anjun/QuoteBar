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
                    StatusItemRightClick.install(model: model)
                }
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarLabel: View {
    @ObservedObject var model: AppModel

    var body: some View {
        if let title = model.menuBarTitle {
            HStack(spacing: 3) {
                if model.showsPinnedMark {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8, weight: .semibold))
                        .accessibilityHidden(true)
                }
                Text(title)
                    .monospacedDigit()
            }
            .accessibilityLabel(model.showsPinnedMark ? "已固定 \(title)" : title)
        } else if model.watchlist.items.isEmpty {
            Text("行情")
        } else if model.openCarouselItems.isEmpty {
            Text("休市")
        } else {
            Text("行情 …")
        }
    }
}
