# DeepSeekBar 数据流

## 状态管理

所有状态由 `DashboardViewModel` 作为唯一数据源管理。

### Published 状态

| 属性 | 类型 | 来源 |
|------|------|------|
| `balanceInfos` | `[BalanceInfo]` | DeepSeek API |
| `records` | `[UsageRecord]` | cc-switch SQLite |
| `snapshots` | `[BalanceSnapshot]` | 余额刷新时生成 |
| `selectedModel` | `String?` | 用户选择 |
| `selectedMonth` | `Date` | 用户选择 |
| `isRefreshing` | `Bool` | 刷新状态 |
| `errorMessage` | `String?` | 错误状态 |
| `successMessage` | `String?` | 成功提示 |

### 派生数据 (Computed)

| 属性 | 计算方式 |
|------|----------|
| `modelSummaries` | `UsageAggregator.modelSummaries()` |
| `trendPoints` | `UsageAggregator.trendPoints()` |
| `currentMonthSpend` | `UsageAggregator.monthlySpend()` |
| `currentMonthRequestCount` | `UsageAggregator.monthlyRequestCount()` |
| `currentMonthTokens` | `UsageAggregator.monthlyTokens()` |

## 数据流序列

### 启动流程

```
AppDelegate.applicationDidFinishLaunching
  → DashboardViewModel.onAppear()
    → loadPersistedState()        # 加载历史数据
    → startPolling()              # 启动定时任务
      → polling.runBalanceRefresh()  # 定时刷新余额
      → polling.runCCSwitchSync()     # 定时同步用量
```

### 余额刷新

```
User taps refresh / Timer fires
  → DashboardViewModel.refreshBalance()
    → KeychainService.load()       获取 API Key
    → DeepSeekAPI.fetchBalance()   调用 /user/balance
    → 更新 balanceInfos
    → addSnapshot()                记录余额快照
    → checkLowBalanceNotification() 检查是否需要推送
    → savePersistedState()         持久化
```

### 用量同步

```
Timer fires (每 120 秒)
  → DashboardViewModel.syncFromCCSwitch()
    → CCSwitchService.readRequestLogs(since: latest)
    → 去重: filter { !existingIDs.contains($0.id) }
    → 合并到 records
    → 截断: 最多保留 10000 条
    → savePersistedState()
    → (可选) 发送用量通知
```

### 通知触发

```
checkLowBalanceNotification():
  if 余额 < 阈值 AND 不在同一小时 AND 余额有变化:
    → NotificationService.sendLowBalanceNotification()
    → 更新 lastNotifiedBalance / lastNotificationHour
```

## 数据聚合

`UsageAggregator` 是纯函数式工具，将原始 `[UsageRecord]` 转换为 UI 需要的数据结构：

```
UsageRecord[] → UsageAggregator.modelSummaries()    → [ModelSummary]
UsageRecord[] → UsageAggregator.trendPoints()       → [TrendPoint]
UsageRecord[] → UsageAggregator.monthlySpend()      → Double
UsageRecord[] → UsageAggregator.estimateSpendFromSnapshots() → Double
```

## 定价计算

`PricingService` 根据模型和 Token 类型计算费用：

| 模型 | 缓存命中 | 缓存未命中 | 输出 |
|------|----------|------------|------|
| deepseek-v4-flash | ¥0.0028/M | ¥0.14/M | ¥0.28/M |
| deepseek-v4-pro | ¥0.0145/M | ¥1.74/M | ¥3.48/M |

费用 = (cacheHitTokens × cacheHitPrice + cacheMissTokens × cacheMissPrice + outputTokens × outputPrice) / 1_000_000
