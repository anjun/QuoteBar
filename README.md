<p align="center">
  <img src="Resources/AppIcon-1024.png" width="128" height="128" alt="QuoteBar">
</p>

<h1 align="center">QuoteBar</h1>

<p align="center">
  macOS 菜单栏行情：A 股 / 港股 / 美股 / 期货 / 贵金属 / 虚拟货币
</p>

<p align="center">
  <a href="https://github.com/anjun/QuoteBar/releases/latest"><img alt="Release" src="https://img.shields.io/github/v/release/anjun/QuoteBar"></a>
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-black">
  <img alt="Swift 5.10" src="https://img.shields.io/badge/Swift-5.10-F05138">
  <img alt="License MIT" src="https://img.shields.io/badge/License-MIT-blue.svg">
</p>

QuoteBar 是一个常驻菜单栏的原生 Mac 应用。打开后菜单栏会轮播当前开盘的指数、贵金属和虚拟货币涨跌幅，点一下就能看完整自选。

首次启动会带上一组默认指数和 ETF（上证、深成、沪深 300、恒指、恒科、纳指、标普、道指、沪深 300ETF、SPY）。

## 功能

- **菜单栏标题**：开盘标的轮播：指数（美股含盘前 04:00–09:30、盘后 16:00–20:00 纽约时间）、贵金属现货（纽约时间周日 18:00 至周五 17:00，每日 17:00–18:00 休息）、虚拟货币（24 小时）；点自选可固定某一标的；全部休市时显示「休市」
- **紧凑模式**：缩短标题，避免被刘海挡住（右键菜单栏图标可开关）
- **登录时打开**：登录 Mac 后自动启动（右键菜单栏图标可开关；需把应用放在「应用程序」中）
- **自选面板**：按 A 股 / 港股 / 美股 / 期货 / 贵金属 / 虚拟货币分组，显示现价、涨跌、涨跌幅；美股盘前/盘后会标「盘前」「盘后」
- **搜索添加**：支持名称、代码、拼音/简拼，例如 `tx`、`pg`、`auusdo`（伦敦金现）、`btc` / `比特币`
- **整理自选**：左键固定/取消固定；右键进入排序，可拖动、上移、下移、删除
- **行情源回退**：腾讯 → 东方财富 → 新浪（贵金属现货如 AUUSDO 走同花顺；虚拟货币走币安，失败则 Gate.io），约每 8 秒刷新
- **检查更新**：从 GitHub Releases 下载 DMG 并安装（需要本机已登录 [GitHub CLI](https://cli.github.com/)）

## 安装

需要 **macOS 14** 或更高版本。

1. 从 [Releases](https://github.com/anjun/QuoteBar/releases/latest) 下载 `QuoteBar-*.dmg`
2. 把 `QuoteBar.app` 拖进「应用程序」
3. 应用目前未公证。若系统拦截，在终端执行：

```bash
xattr -dr com.apple.quarantine /Applications/QuoteBar.app
open /Applications/QuoteBar.app
```

或在项目目录执行 `make start`，会打包、安装到 `/Applications` 并去掉隔离属性。

## 用法

| 操作 | 效果 |
| --- | --- |
| 左键菜单栏图标 | 打开自选面板 |
| 右键菜单栏图标 | 紧凑模式 / 登录时打开 / 检查更新 / 退出 |
| 左键自选一行 | 固定或取消固定到菜单栏 |
| 右键自选一行 | 排序、删除、检查更新 |
| 面板底部「退出」 | 退出 QuoteBar |

自选、固定标的和标题样式会保存在 `UserDefaults`。

## 从源码构建

```bash
git clone https://github.com/anjun/QuoteBar.git
cd QuoteBar
make test          # 运行测试
make start         # 打包、安装并启动
make dmg           # 打通用架构 DMG
```

其它命令见 `make help`。

环境要求：Xcode 16 / Swift 5.10。

## 仓库结构

```
Sources/QuoteBar          # SwiftUI 菜单栏应用
Sources/QuoteBarCore      # 行情、解析、自选、更新
Tests/QuoteBarCoreTests   # 解析、回退、会话、更新等单测
scripts/                  # 打包、图标、发版
```

## 说明

行情来自公开的第三方接口（腾讯、东方财富、新浪、同花顺、币安、Gate.io），仅供个人浏览，不构成投资建议，也不保证实时或准确。接口变更时应用可能暂时拿不到数据。伦敦金现对应同花顺代码 `AUUSDO`。虚拟货币按 USDT 计价，24 小时交易。

检查更新会读取本机 `gh auth token` 或环境变量 `GH_TOKEN` / `GITHUB_TOKEN`，用来访问 GitHub Releases。

## 许可

[MIT](LICENSE)
