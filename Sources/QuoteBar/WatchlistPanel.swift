import AppKit
import QuoteBarCore
import SwiftUI

struct WatchlistPanel: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var editingSymbol: SymbolID?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            searchField
            if !model.searchText.isEmpty {
                searchResults
            }
            watchlist
            footer
        }
        .padding(12)
        .frame(width: QuoteTheme.panelWidth)
        .background {
            Rectangle()
                .fill(.background)
        }
        .overlay {
            if editingSymbol != nil {
                RightClickCatcher(consume: true) {
                    editingSymbol = nil
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("搜索名称 / 代码 / 拼音，如 tx", text: Binding(
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
                    marketHeader(group.family.title)
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

    private func marketHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 8)
            .padding(.bottom, 2)
            .padding(.leading, 10)
    }

    private func quoteRow(_ symbol: SymbolID) -> some View {
        let quote = model.quotes[symbol]
        let sign = QuoteColorSign.of(change: quote?.change ?? 0)
        let ink = QuoteTheme.signed(sign, scheme: colorScheme)
        let pinned = model.pinnedSymbol == symbol
        let editingThis = editingSymbol == symbol
        let body = quoteRowBody(symbol: symbol, quote: quote, sign: sign, ink: ink)

        return HStack(spacing: 0) {
            if editingThis {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 28)
                    .contentShape(Rectangle())
                    .help("拖动排序")
                    .draggable(WatchlistMoveToken(symbol)) {
                        Text(quote?.name ?? symbol.code)
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.background, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
            }

            Button {
                if editingSymbol != nil, editingSymbol != symbol {
                    editingSymbol = nil
                }
                model.pin(symbol)
            } label: {
                body
            }
            .buttonStyle(.plain)

            if editingThis {
                HStack(spacing: 2) {
                    Button {
                        model.move(symbol, by: -1)
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 10, weight: .semibold))
                            .frame(width: 20, height: 22)
                    }
                    .buttonStyle(.plain)
                    .disabled(!model.canMove(symbol, by: -1))
                    .foregroundStyle(model.canMove(symbol, by: -1) ? .primary : .tertiary)
                    .help("上移")

                    Button {
                        model.move(symbol, by: 1)
                    } label: {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 10, weight: .semibold))
                            .frame(width: 20, height: 22)
                    }
                    .buttonStyle(.plain)
                    .disabled(!model.canMove(symbol, by: 1))
                    .foregroundStyle(model.canMove(symbol, by: 1) ? .primary : .tertiary)
                    .help("下移")

                    Button {
                        model.remove(symbol)
                        if editingSymbol == symbol { editingSymbol = nil }
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 12))
                            .frame(width: 20, height: 22)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("从自选删除")
                }
            }
        }
        .padding(.vertical, 5)
        .padding(.trailing, 2)
        .background {
            if pinned || editingThis {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            }
        }
        .dropDestination(for: WatchlistMoveToken.self) { tokens, _ in
            guard let dragged = tokens.first?.symbol else { return false }
            return model.move(dragged, before: symbol)
        }
        .overlay {
            if editingSymbol == nil {
                RightClickCatcher {
                    editingSymbol = symbol
                }
            }
        }
        .contextMenu {
            Button("上移") { model.move(symbol, by: -1) }
                .disabled(!model.canMove(symbol, by: -1))
            Button("下移") { model.move(symbol, by: 1) }
                .disabled(!model.canMove(symbol, by: 1))
            Divider()
            Button("完成") { editingSymbol = nil }
            Button("检查更新") {
                Task { await AppUpdater.check(interactive: true) }
            }
            Divider()
            Button("删除", role: .destructive) {
                model.remove(symbol)
                if editingSymbol == symbol { editingSymbol = nil }
            }
        }
    }

    private func quoteRowBody(symbol: SymbolID, quote: Quote?, sign: QuoteColorSign, ink: Color) -> some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(QuoteTheme.tick(sign, scheme: colorScheme))
                .frame(width: 3, height: 28)
                .padding(.trailing, 7)

            VStack(alignment: .leading, spacing: 1) {
                Text(quote?.name ?? symbol.code)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
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
                 ? (model.lastError ?? "每 \(Int(model.refreshSeconds)) 秒刷新  腾讯 / 东财 / 新浪")
                 : "拖动排序，任意处右击确认")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Spacer()
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


