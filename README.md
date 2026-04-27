# MuyiMacRight

> [English](README.en.md)

在 Finder 文件夹空白处右键，弹出「用 VSCode 打开此文件夹」与「新建文件 ▶ Markdown / Python / JavaScript / …」菜单。基于 macOS Finder Sync Extension。

## 目录结构

```
MuyiMacRight.xcodeproj/        Xcode 工程
MuyiMacRight/                  宿主 App
├── AppDelegate.swift            程序入口
├── ViewController.swift         说明窗口（含「打开扩展设置」按钮）
├── Info.plist
├── MuyiMacRight.entitlements  App Sandbox
└── Assets.xcassets/             AppIcon 占位
MuyiMacRightFinderSync/          Finder Sync Extension
├── FinderSync.swift             核心：菜单生成 + 新建文件 + 调起 VSCode
├── Info.plist                   NSExtension 配置
└── FinderSync.entitlements      Extension Sandbox
```

## 安装

```sh
./install.sh
```

一条命令搞定：构建 Release → 装到 `/Applications/` → 启动 → 弹出系统扩展设置面板。

之后只需在系统设置里勾选 **FinderSync** 一次（macOS 安全机制要求用户手动确认扩展）。从此 `MuyiMacRight` 就是个普通 app，可以从 Launchpad / Spotlight 启动；右键菜单由系统加载扩展提供，不需要 app 常驻。

> ⚠️ 不要手动 `cp` 构建产物到 /Applications/。Xcode 的 build phase 会调 `lsregister -f -R -trusted`，缺 `-trusted` flag 的话 pkd 不识别扩展。`install.sh` 用 `CONFIGURATION_BUILD_DIR=/Applications` 让 Xcode 直接产出到目标位置，规避这一坑。

### 调试模式

如果改了代码想用 Xcode 调试器：打开 `MuyiMacRight.xcodeproj`，选 `MuyiMacRight` scheme，`Cmd+R` 即可。

## 测试

到 `~/Desktop` 下任意文件夹，**在窗口空白处右键**：

- 看到「用 VSCode 打开此文件夹」与「新建文件 ▶」
- 点「Markdown (.md)」→ 当前文件夹下生成 `untitled.md`，VSCode 启动并打开
- 再点一次 → 生成 `untitled-2.md`（自动避免重名）

## 验证扩展是否加载

```sh
pluginkit -m -A -v -p com.apple.FinderSync
```

看到 `+    com.muyi.MuyiMacRight.FinderSync(1.0)` 就 OK。`+` 表示已启用，`-` 表示禁用。

## 自定义文件类型

修改 `MuyiMacRightFinderSync/FinderSync.swift` 顶部的 `fileTypes` 数组：

```swift
private let fileTypes: [FileType] = [
    .init(title: "Markdown", ext: "md", template: "# Untitled\n\n"),
    // ... 想加什么直接加
]
```

加完重新 `Cmd+R`，扩展自动重载。

## 排查

| 现象 | 原因 / 处理 |
|------|------------|
| 右键看不到菜单 | 系统设置里扩展没勾上；或 `pluginkit -m -p com.apple.FinderSync` 看不到 `com.muyi.MuyiMacRight.FinderSync` |
| 菜单只在 Home 目录里出现 | 这是设计行为。`FinderSync.swift` 里 `directoryURLs` 只设了 `NSHomeDirectory()`，要扩到全盘改成 `[URL(fileURLWithPath: "/")]` |
| 点菜单没反应 | 看 Console.app 过滤 `MuyiMacRight`，常见是 VSCode 没装或 bundle id 变了 |
| 改了代码没生效 | macOS 可能缓存旧扩展。`pluginkit -e ignore -i com.muyi.MuyiMacRight.FinderSync && pluginkit -e use -i com.muyi.MuyiMacRight.FinderSync`，或重新启动 Finder：`killall Finder` |

## 系统约束

- 最低 macOS：13.0（`MACOSX_DEPLOYMENT_TARGET`），实际开发在 macOS 14.8.5 (Sonoma) + Xcode 16.0
- 签名：ad-hoc（`CODE_SIGN_IDENTITY = "-"`），仅本机使用。要分发给别人需要付费 Apple Developer 账号 + notarization
