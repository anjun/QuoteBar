import AppKit
import QuoteBarCore
import SwiftUI

struct WatchlistPanel: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var editingSymbol: SymbolID?
    @State private var dropTarget: SymbolID?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            searchField
            FittingScroll(maxHeight: PanelLayout.bodyHeightLimit(visibleHeight: MenuBarScreen.visibleHeight())) {
                VStack(alignment: .leading, spacing: 10) {
                    if !model.searchText.isEmpty {
                        searchResults
                    }
                    watchlist
                }
            }
            footer
        }
        .padding(12)
        .frame(width: QuoteTheme.panelWidth)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            Rectangle()
                .fill(.background)
                .ignoresSafeArea()
            PanelWindowBackground()
        }
        .ignoresSafeArea()
        .overlay {
            if editingSymbol != nil {
                RightClickCatcher(consume: true) {
                    finishSorting()
                }
            }
        }
        .onDisappear { finishSorting() }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("搜索名称 / 代码 / 拼音，如 tx、pg、btc", text: Binding(
                get: { model.searchText },
                set: { model.updateSearch($0) }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            if !model.searchText.isEmpty {
                Button {
                    model.updateSearch("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: QuoteTheme.radius, style: .continuous))
    }

    private var searchResults: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.isSearching && model.searchResults.isEmpty {
                Text("搜索中")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(10)
            } else if model.searchResults.isEmpty {
                Text("没有匹配的标的")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(10)
            } else {
                ForEach(model.searchResults.prefix(8), id: \.symbol) { hit in
                    Button {
                        model.add(hit)
                    } label: {
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(hit.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text("\(hit.symbol.code)  \(hit.symbol.market.familyTitle)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            Image(systemName: model.watchlist.items.contains(hit.symbol) ? "checkmark" : "plus")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
            }
        }
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: QuoteTheme.radius, style: .continuous))
    }

    private var watchlist: some View {
        VStack(alignment: .leading, spacing: 2) {
            if model.watchlist.items.isEmpty {
                Text("自选为空，搜索后添加")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                columnHeader
                ForEach(model.watchlist.groups(), id: \.family) { group in
                    marketHeader(group.family)
                    ForEach(group.items, id: \.self) { symbol in
                        quoteRow(symbol)
                    }
                }
            }
        }
    }

    private var columnHeader: some View {
        HStack(spacing: 0) {
            Text("名称")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("现价")
                .frame(width: QuoteTheme.priceWidth, alignment: .trailing)
            Text("涨跌")
                .frame(width: QuoteTheme.changeWidth, alignment: .trailing)
            Text("涨跌幅")
                .frame(width: QuoteTheme.percentWidth, alignment: .trailing)
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.secondary)
        .padding(.leading, 10)
        .padding(.trailing, 2)
        .padding(.bottom, 4)
    }

    private func marketHeader(_ family: MarketFamily) -> some View {
        HStack(spacing: 6) {
            Text(family.title)
            if family == .us, let label = MarketSession.phase(.us).label {
                sessionBadge(label)
            }
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.top, 8)
        .padding(.bottom, 2)
        .padding(.leading, 10)
    }

    private func sessionBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Color.primary.opacity(0.08), in: Capsule())
            .accessibilityLabel(text)
    }

    @ViewBuilder
    private func quoteRow(_ symbol: SymbolID) -> some View {
        let quote = model.quotes[symbol]
        let sign = QuoteColorSign.of(change: quote?.change ?? 0)
        let ink = QuoteTheme.signed(sign, scheme: colorScheme)
        let selected = editingSymbol == symbol
        let row = quoteRowBody(symbol: symbol, quote: quote, sign: sign, ink: ink)
            .padding(.vertical, 5)
            .padding(.trailing, 2)
            .background {
                if model.pinnedSymbol == symbol || selected {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                }
            }
            .contentShape(Rectangle())

        if editingSymbol != nil {
            row
                .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 6))
                .draggable(WatchlistMoveToken(symbol)) {
                    quoteRowBody(symbol: symbol, quote: quote, sign: sign, ink: ink)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 6)
                        .frame(width: QuoteTheme.panelWidth - 24)
                        .background(.background, in: RoundedRectangle(cornerRadius: 6))
                }
                .dropDestination(for: WatchlistMoveToken.self) { tokens, _ in
                    dropTarget = nil
                    guard editingSymbol != nil, tokens.count == 1,
                          let dragged = tokens.first?.symbol else { return false }
                    let moved = withAnimation(.easeInOut(duration: 0.15)) {
                        model.move(dragged, to: symbol)
                    }
                    if moved { editingSymbol = dragged }
                    return moved
                } isTargeted: { targeted in
                    if targeted { dropTarget = symbol }
                    else if dropTarget == symbol { dropTarget = nil }
                }
                .overlay {
                    if dropTarget == symbol {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.accentColor, lineWidth: 1.5)
                            .allowsHitTesting(false)
                    }
                }
                .onTapGesture { editingSymbol = symbol }
                .help("拖动整行可在同一分组内排序")
        } else {
            row.overlay {
                RightClickCatcher(consume: true) {
                    editingSymbol = symbol
                }
            }
        }
    }

    private func finishSorting() {
        editingSymbol = nil
        dropTarget = nil
    }

    @ViewBuilder
    private var sortingActions: some View {
        if let symbol = editingSymbol {
            Menu {
                if model.pinnedSymbol == symbol {
                    Button("取消固定") { model.unpin() }
                } else {
                    Button("固定到状态栏") { model.pin(symbol) }
                }
                Button("检查更新") {
                    Task { await AppUpdater.check(interactive: true) }
                }
                Divider()
                Button("删除", role: .destructive) {
                    model.remove(symbol)
                    finishSorting()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("\(model.quotes[symbol]?.name ?? symbol.code)：固定、删除等操作")
            .accessibilityLabel("选中行情的操作")
            Button("完成") { finishSorting() }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
        }
    }

    private func quoteRowBody(symbol: SymbolID, quote: Quote?, sign: QuoteColorSign, ink: Color) -> some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(QuoteTheme.tick(sign, scheme: colorScheme))
                .frame(width: 3, height: 28)
                .padding(.trailing, 7)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(quote?.name ?? symbol.code)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if let darkPool = quote?.darkPool {
                        sessionBadge("暗盘")
                            .help(darkPool.detail)
                    } else if symbol.market.family == .us, let label = MarketSession.phase(.us).label {
                        sessionBadge(label)
                    }
                    if model.pinnedSymbol == symbol {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("已固定到状态栏")
                    }
                }
                Text(symbol.code)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(quote.map { QuoteFormat.price($0.last) } ?? "--")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(ink)
                .frame(width: QuoteTheme.priceWidth, alignment: .trailing)

            Text(quote.map { QuoteFormat.signed($0.change) } ?? "--")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(ink)
                .frame(width: QuoteTheme.changeWidth, alignment: .trailing)

            Text(quote.map { QuoteFormat.percent($0.changePercent) } ?? "--")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(ink)
                .frame(width: QuoteTheme.percentWidth, alignment: .trailing)
        }
        .contentShape(Rectangle())
    }

    private var footer: some View {
        HStack {
            Text(editingSymbol == nil
                 ? (model.lastError ?? "每 \(Int(model.refreshSeconds)) 秒刷新  腾讯 / 东财 / 新浪 / 同花顺 / 币安")
                 : "同一分组内拖动整行，右击完成")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Spacer()
            sortingActions
            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)
        }
        .padding(.top, 6)
    }
}
