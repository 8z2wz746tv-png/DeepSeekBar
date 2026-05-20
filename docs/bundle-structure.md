# DeepSeekBar 打包规范

## 构建命令

```bash
bash scripts/build-app.sh
```

## 产物

```
.build/
├── release/DeepSeekMenuBar       # SPM 编译产物
├── DeepSeekMenuBar.app/          # macOS App Bundle
│   └── Contents/
│       ├── MacOS/
│       │   └── DeepSeekMenuBar   # 可执行文件
│       ├── Resources/
│       │   ├── AppIcon.icns      # 应用图标
│       │   └── favicon.svg       # 面板 logo
│       ├── Frameworks/           # 动态库 (当前为空)
│       └── Info.plist            # Bundle 元数据
└── DeepSeekBar.dmg               # DMG 安装镜像
```

## Info.plist 关键字段

| 字段 | 值 | 说明 |
|------|-----|------|
| `CFBundleExecutable` | `DeepSeekMenuBar` | 可执行文件名 |
| `CFBundleIdentifier` | `com.deepseek.menubar` | Bundle ID |
| `LSUIElement` | `true` | 隐藏 Dock 图标 |
| `LSMinimumSystemVersion` | `15.0` | 最低系统版本 |
| `NSHighResolutionCapable` | `true` | Retina 支持 |

## 资源路径规则

### 开发阶段 (Xcode / `swift run`)

- 资源通过 SPM 的 `Bundle.module` 访问
- `Package.swift` 声明 `.process("Resources")` 确保 SPM 打包

### 发布阶段 (`.app` Bundle)

- 资源存放在 `Contents/Resources/`
- 代码通过 `Bundle.main` 访问
- `build-app.sh` 从 `Sources/DeepSeekMenuBar/Resources/` 拷贝资源

### 代码中的资源访问模式

```swift
// 正确: 双重回退确保开发/发布都能工作
Bundle.main.url(forResource: "favicon", withExtension: "svg")
    ?? Bundle.module.url(forResource: "favicon", withExtension: "svg")

// 禁止: 相对路径
// "./Resources/favicon.svg"  ← 不允许
// "../favicon.svg"           ← 不允许
```

## 签名

- 当前使用 ad-hoc 签名: `codesign --force --deep --sign -`
- 无需 Developer ID，仅本地使用
- 如需分发，可替换为正式签名证书

## 持久化路径规则

所有运行时数据统一使用 `Application Support` 目录：

```
~/Library/Application Support/DeepSeekMenuBar/
└── usage-history.json          # 用量历史
```

**禁止**: 在 Bundle 内或工作目录写入文件。
**CC-Switch**: `~/.cc-switch/cc-switch.db` 是第三方工具的固定路径，只读访问，不修改。
