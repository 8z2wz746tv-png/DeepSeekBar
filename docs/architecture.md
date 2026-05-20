# DeepSeekBar 架构文档

## 概述

DeepSeekBar 是一个 macOS 菜单栏应用，用于监控 DeepSeek API 的账户余额和使用统计。

- **语言**: Swift 6
- **框架**: SwiftUI + AppKit
- **架构**: MVVM
- **构建**: Swift Package Manager (`Package.swift`)
- **最低系统**: macOS 15.0

## 架构分层

```
┌─────────────────────────────────────────────────┐
│ Views (SwiftUI)                                  │
│ Dashboard / Settings / Charts / TopBar           │
├─────────────────────────────────────────────────┤
│ ViewModels                                       │
│ DashboardViewModel / SettingsViewModel           │
├────────────────────┬────────────────────────────┤
│ Services           │ Utilities                   │
│ DeepSeekAPI        │ UsageAggregator             │
│ CCSwitchService    │ FormatUtils                 │
│ KeychainService    │ AppSettings                 │
│ PersistenceService │ PollingManager              │
│ NotificationSvc    │                             │
│ PricingService     │                             │
└────────────────────┴────────────────────────────┘
```

## 核心数据流

```
1. 余额刷新:
   User Action → DashboardVM.refreshBalance()
     → KeychainService.load() (获取 API Key)
     → DeepSeekAPI.fetchBalance() (调用 DeepSeek API)
     → BalanceInfo[] (更新 UI)
     → BalanceSnapshot → PersistenceService.save()

2. 用量同步 (来自 cc-switch):
   PollingManager → DashboardVM.syncFromCCSwitch()
     → CCSwitchService.readRequestLogs() (读取 SQLite)
     → UsageRecord[] (去重后合并)
     → PersistenceService.save()

3. 通知:
   PollingManager → DashboardVM.checkLowBalanceNotification()
     → NotificationService.sendLowBalanceNotification()
```

## 持久化

| 数据 | 位置 | 服务 |
|------|------|------|
| API Key | macOS Keychain | KeychainService |
| 用量历史 | `~/Library/Application Support/DeepSeekMenuBar/usage-history.json` | PersistenceService |
| 用户设置 | UserDefaults | AppSettings |
| cc-switch 数据 | `~/.cc-switch/cc-switch.db` (只读，第三方) | CCSwitchService |

## 打包

打包由 `scripts/build-app.sh` 完成，生成标准 macOS `.app` Bundle：

```
DeepSeekMenuBar.app/
└── Contents/
    ├── MacOS/DeepSeekMenuBar     # 可执行文件
    ├── Resources/                 # 资源文件 (favicon.svg, AppIcon.icns)
    ├── Frameworks/               # 动态库 (当前为空)
    └── Info.plist                # Bundle 元数据
```

详见 [bundle-structure.md](bundle-structure.md)

## 技术决策

1. **SPM 而非 Xcode Project**: 当前仅使用 `Package.swift` 管理，便于 CI 和纯命令行构建。
2. **Accessory 模式**: App 设置 `LSUIElement = true`，不在 Dock 显示，仅在状态栏运行。
3. **Bundle.module 回退**: 所有资源读取使用 `Bundle.main ?? Bundle.module` 确保 Xcode Run 和 Release App 都能正常工作。
4. **cc-switch 依赖**: cc-switch 是第三方 API 代理工具，DeepSeekBar 只读取其 SQLite 数据库，不修改。
