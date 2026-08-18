import AppKit
import QuoteBarCore
import SwiftUI

struct WatchlistPanel: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            searchField
            if !model.searchText.isEmpty {
                searchResults
            }
            watchlist
            footer
        }
        .padding(10)
        .frame(width: 360)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("搜索名称 / 代码 / 拼音，如 tx", text: Binding(
                get: { model.searchText },
                set: { model.updateSearch($0) }
            ))
            .textFieldStyle(.plain)
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
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
    }

    private var searchResults: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.isSearching && model.searchResults.isEmpty {
                Text("搜索中…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(8)
            } else if model.searchResults.isEmpty {
                Text("没有匹配的标的")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(8)
            } else {
                ForEach(model.searchResults.prefix(8), id: \.symbol) { hit in
                    Button {
                        model.add(hit)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(hit.name)
                                    .font(.system(size: 12, weight: .medium))
                                Text("\(hit.symbol.code)  \(hit.symbol.market.rawValue.uppercased())")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: model.watchlist.items.contains(hit.symbol) ? "checkmark" : "plus")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                }
            }
        }
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
    }

    private var watchlist: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
            Divider()
            if model.watchlist.items.isEmpty {
                Text("自选为空，搜索后添加")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                ForEach(model.watchlist.items, id: \.self) { symbol in
                    quoteRow(symbol)
                }
            }
        }
    }

    private var headerRow: some View {
        HStack {
            Text("名称/代码")
            Spacer()
            Text("现价")
                .frame(width: 64, alignment: .trailing)
            Text("涨跌")
                .frame(width: 58, alignment: .trailing)
            Text("涨跌幅")
                .frame(width: 58, alignment: .trailing)
            Color.clear.frame(width: 16)
        }
        .font(.system(size: 10))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }

    private func quoteRow(_ symbol: SymbolID) -> some View {
        let quote = model.quotes[symbol]
        let sign = QuoteColorSign.of(change: quote?.change ?? 0)
        return HStack(spacing: 4) {
            Button {
                model.pin(symbol)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(quote?.name ?? symbol.code)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                        Text(symbol.code)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(quote.map { QuoteFormat.price($0.last) } ?? "--")
                        .frame(width: 64, alignment: .trailing)
                        .monospacedDigit()
                    Text(quote.map { QuoteFormat.signed($0.change) } ?? "--")
                        .frame(width: 58, alignment: .trailing)
                        .monospacedDigit()
                    Text(quote.map { QuoteFormat.percent($0.changePercent) } ?? "--")
                        .frame(width: 58, alignment: .trailing)
                        .monospacedDigit()
                }
                .foregroundStyle(sign.color)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(model.pinnedSymbol == symbol ? Color.accentColor.opacity(0.12) : .clear)

            Button {
                model.remove(symbol)
            } label: {
                Image(systemName: "minus.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("从自选删除")
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 5)
    }

    private var footer: some View {
        HStack {
            Text(model.lastError ?? "每 \(Int(model.refreshSeconds)) 秒刷新 · 腾讯 / 东财 / 新浪")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Spacer()
            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
        }
        .padding(.top, 2)
    }
}
