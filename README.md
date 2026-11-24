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

- **菜单栏标题**：开盘标的轮播：指数（美股含盘前 04:00–09:30、盘后 16:00–20:00 纽约时间）、贵金属现货（纽约时间周日 18:00 至周五 17:00，每日 17:00–18:00 休息）、虚拟货币（24 小时）；右击自选再选固定某一标的；全部休市时显示「休市」
- **紧凑模式**：缩短标题，避免被刘海挡住（右键菜单栏图标可开关）
- **登录时打开**：登录 Mac 后自动启动（右键菜单栏图标可开关；需把应用放在「应用程序」中）
- **自选面板**：按 A 股 / 港股 / 美股 / 期货 / 贵金属 / 虚拟货币分组，显示现价、涨跌、涨跌幅；美股盘前/盘后会标「盘前」「盘后」。列表高出屏幕时出现滚动条，搜索框和底部状态栏保持不动
- **搜索添加**：支持名称和代码（不区分大小写），例如 `腾讯控股`、`Anthropic`、`AAPL`、`AUUSDO`（伦敦金现）、`BTC` / `比特币`
- **整理自选**：右击任意自选进入排序，同一市场分组内可拖动整行（名称、价格、涨跌幅均可），松手自动保存；再次右击或点「完成」退出。排序时单击可选中另一行，底部「…」提供固定/取消固定、删除和检查更新
- **行情源回退**：腾讯 → 东方财富 → 新浪（贵金属现货如 AUUSDO 走同花顺；虚拟货币走币安，失败则 Gate.io），约每 8 秒刷新
- **休市暗盘**：已添加的股票休市时自动查找新浪同名暗盘，优先使用实时更新且原生按 UTC+0 计价的 `*usdt` 暗盘，不可用时回退至成交量最大的有效暗盘并按小时 K 线对齐 UTC+0 自然日（北京时间 08:00）基准；面板及菜单栏标「暗盘」，悬停面板标记可查看来源、成交量和报价时间。无匹配、请求失败或报价超过 15 分钟时保留普通行情；美股盘前/盘后仍使用原有行情。暂不支持暗盘 IPO，也不将 ETF、指数切为暗盘。休市判断沿用各市场时区、工作日和交易时段，目前未包含交易所节假日日历。
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
| 右键自选一行 | 进入整行拖动排序；再次右击完成；底部「…」操作选中行 |
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

行情来自公开的第三方接口（腾讯、东方财富、新浪、同花顺、币安、Gate.io），仅供个人浏览，不构成投资建议，也不保证实时或准确。接口变更时应用可能暂时拿不到数据。伦敦金现对应同花顺代码 `AUUSDO`。虚拟货币按 USDT 计价，24 小时交易，涨跌幅按 UTC+0 自然日（北京时间 08:00 开盘）计算。

检查更新会读取本机 `gh auth token` 或环境变量 `GH_TOKEN` / `GITHUB_TOKEN`，用来访问 GitHub Releases。

## 许可

[MIT](LICENSE)
