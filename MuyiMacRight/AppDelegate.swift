import Cocoa
import ApplicationServices

@main
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu === statusItem.menu { rebuildStatusMenu() }
    }


    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = CommandLine.arguments
        NSLog("MuyiMacRight: launched argv=\(args)")

        // Backup CLI 路径（命令行调试用，不走菜单栏）
        if let idx = args.firstIndex(of: "--open-vscode"), idx + 1 < args.count {
            NSApp.setActivationPolicy(.prohibited)
            let folder = args[idx + 1]
            let file: String? = (idx + 2 < args.count) ? args[idx + 2] : nil
            self.runVSCodeCLI(folder: folder, file: file)
            exit(0)
        }

        // 菜单栏常驻 app
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()

        // 首次启动跑一遍引导式权限请求
        let firstRunKey = "MuyiMacRight.didCompleteFirstLaunchSetup"
        if !UserDefaults.standard.bool(forKey: firstRunKey) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.runFirstLaunchSetup()
                UserDefaults.standard.set(true, forKey: firstRunKey)
            }
        } else {
            // 不是首次：仅静默触发 AppleEvents 提示（无害），不打扰用户
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.silentlyPokeAppleEvents()
            }
        }
    }

    /// 首次启动：弹欢迎框 → 自动触发三个权限请求 → 自动打开两个系统设置面板 → 完成对话框
    private func runFirstLaunchSetup() {
        let intro = NSAlert()
        intro.messageText = "MuyiMacRight 首次配置（约 1 分钟）"
        intro.informativeText = """
        点【开始】后我会自动：
        1. 弹两个 Apple Events 权限对话框（Finder + System Events）
        2. 弹辅助功能权限对话框，并打开「隐私与安全性 → 辅助功能」面板
        3. 打开「扩展」面板

        你只需要：
        • 在每个对话框里点「好」/「允许」
        • 在辅助功能列表里点 + 加上 MuyiMacRight，打开开关
        • 在扩展列表里勾上 FinderSync
        """
        intro.addButton(withTitle: "开始")
        intro.addButton(withTitle: "稍后再说")
        guard intro.runModal() == .alertFirstButtonReturn else { return }

        // ① + ② AppleEvents (Finder + System Events) —— 各跑一个无害脚本，TCC 自动弹框
        let scripts = [
            "tell application \"Finder\" to count windows",
            "tell application \"System Events\" to count processes",
        ]
        for src in scripts {
            var err: NSDictionary?
            _ = NSAppleScript(source: src)?.executeAndReturnError(&err)
        }

        // ③ Accessibility 权限请求（弹「需要辅助功能」对话框）
        let opts: NSDictionary = ["AXTrustedCheckOptionPrompt" as NSString: true]
        _ = AXIsProcessTrustedWithOptions(opts)

        // ④ 直接把「辅助功能」面板顶到屏幕上 —— 比让用户点对话框里那个「打开设置」按钮快
        if let axURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(axURL)
        }

        // ⑤ 同时打开「扩展」面板
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let extURLs = [
                "x-apple.systempreferences:com.apple.ExtensionsPreferences",
                "x-apple.systempreferences:com.apple.preferences.extensions",
            ]
            for s in extURLs {
                if let u = URL(string: s), NSWorkspace.shared.open(u) { break }
            }

            // ⑥ 最后弹一个完成提示，告诉用户接下来怎么做
            let done = NSAlert()
            done.messageText = "权限请求都发出去了 ✓"
            done.informativeText = """
            屏幕上现在打开了两个系统设置面板：

            【辅助功能】
              点列表底部的 + → 选 /Applications/MuyiMacRight.app → 打开右边开关

            【扩展】
              在「已添加的扩展」里找到 FinderSync，勾上

            做完之后到 Finder 任意文件夹空白处右键 → 新建文件 → Markdown，
            就能看到自动选中并进入重命名模式了。
            """
            done.addButton(withTitle: "知道了")
            done.runModal()
        }
    }

    private func silentlyPokeAppleEvents() {
        let scripts = [
            "tell application \"Finder\" to count windows",
            "tell application \"System Events\" to count processes",
        ]
        for src in scripts {
            var err: NSDictionary?
            _ = NSAppleScript(source: src)?.executeAndReturnError(&err)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 菜单栏 app，关闭面板不退出
        false
    }

    // MARK: - 状态栏

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            // 鼠标光标 + 点击星号，直观表达「右键」
            button.image = NSImage(systemSymbolName: "cursorarrow.click", accessibilityDescription: "MuyiMacRight")
            button.image?.isTemplate = true
        }

        // 用 NSMenu（标准下拉菜单，不会闪退）
        let menu = NSMenu()
        menu.delegate = self  // 每次打开重建以反映最新权限
        statusItem.menu = menu
    }

    func rebuildStatusMenu() {
        guard let menu = statusItem.menu else { return }
        menu.removeAllItems()

        let s = permissionStatus()

        let header = NSMenuItem(title: "MuyiMacRight  •  Finder 右键扩展", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        let permsTitle = NSMenuItem(title: "权限状态", action: nil, keyEquivalent: "")
        permsTitle.isEnabled = false
        menu.addItem(permsTitle)

        addPermissionItem(to: menu, name: "Finder 控制权",        granted: s.finder,        action: #selector(grantAppleEvents))
        addPermissionItem(to: menu, name: "System Events 控制权", granted: s.systemEvents,  action: #selector(grantAppleEvents))
        addPermissionItem(to: menu, name: "辅助功能（模拟回车）",  granted: s.accessibility, action: #selector(openAccessibilityPane))

        menu.addItem(.separator())

        let openExt = NSMenuItem(title: "打开扩展设置（启用/停用 FinderSync）",
                                 action: #selector(openExtensionSettings),
                                 keyEquivalent: "")
        openExt.target = self
        menu.addItem(openExt)

        let regrant = NSMenuItem(title: "重新触发所有权限请求",
                                 action: #selector(regrantAll),
                                 keyEquivalent: "")
        regrant.target = self
        menu.addItem(regrant)

        menu.addItem(.separator())

        let about = NSMenuItem(title: "关于 / 调试日志",
                               action: #selector(openConsole),
                               keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        let quit = NSMenuItem(title: "退出 MuyiMacRight",
                              action: #selector(NSApplication.terminate(_:)),
                              keyEquivalent: "q")
        menu.addItem(quit)
    }

    private func addPermissionItem(to menu: NSMenu, name: String, granted: Bool, action: Selector) {
        let prefix = granted ? "✓" : "✗"
        let suffix = granted ? "已授权" : "未授权 — 点击授权"
        let item = NSMenuItem(title: "  \(prefix)  \(name)  ·  \(suffix)",
                              action: granted ? nil : action,
                              keyEquivalent: "")
        item.target = self
        item.isEnabled = !granted
        menu.addItem(item)
    }

    @objc private func grantAppleEvents() {
        let scripts = [
            "tell application \"Finder\" to count windows",
            "tell application \"System Events\" to count processes",
        ]
        for src in scripts {
            var err: NSDictionary?
            _ = NSAppleScript(source: src)?.executeAndReturnError(&err)
        }
    }

    @objc private func openAccessibilityPane() {
        let opts: NSDictionary = ["AXTrustedCheckOptionPrompt" as NSString: true]
        _ = AXIsProcessTrustedWithOptions(opts)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openExtensionSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.ExtensionsPreferences",
            "x-apple.systempreferences:com.apple.preferences.extensions",
        ]
        for s in urls {
            if let u = URL(string: s), NSWorkspace.shared.open(u) { return }
        }
    }

    @objc private func regrantAll() {
        grantAppleEvents()
        openAccessibilityPane()
    }

    @objc private func openConsole() {
        if let u = URL(string: "https://github.com/your/MuyiMacRight") {
            // 占位 - 用控制台代替
            let _ = u
        }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", "Console"]
        try? task.run()
    }

    // MARK: - URL scheme

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            NSLog("MuyiMacRight: handling URL=\(url.absoluteString)")
            guard url.scheme == "muyimacright" else { continue }
            switch url.host {
            case "open-vscode":   handleOpenVSCodeURL(url)
            case "select-rename": handleSelectRenameURL(url)
            default:              break
            }
        }
        // 不退出 —— 菜单栏 app 保持运行
    }

    private func handleOpenVSCodeURL(_ url: URL) {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = comps.queryItems else { return }
        var folder: String?
        var file: String?
        for it in items {
            switch it.name {
            case "folder": folder = it.value
            case "file":   file = it.value
            default:       break
            }
        }
        guard let f = folder else { return }
        runVSCodeCLI(folder: f, file: file)
    }

    private func handleSelectRenameURL(_ url: URL) {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = comps.queryItems,
              let path = items.first(where: { $0.name == "file" })?.value else {
            return
        }
        runSelectAndRename(filePath: path)
    }

    /// 让 Finder 选中新文件并模拟回车键触发重命名模式
    private func runSelectAndRename(filePath: String) {
        let escaped = filePath
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = """
        tell application "Finder"
            activate
            select POSIX file "\(escaped)" as alias
        end tell
        delay 0.18
        tell application "Finder" to activate
        delay 0.05
        tell application "System Events" to keystroke return
        """
        var err: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&err)
        if let err = err {
            NSLog("MuyiMacRight: select+rename AppleScript failed: \(err)")
        }
    }

    private func runVSCodeCLI(folder: String, file: String?) {
        let cliCandidates = [
            "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code",
            "/usr/local/bin/code",
            "/opt/homebrew/bin/code",
        ]
        let cli = cliCandidates.first { FileManager.default.fileExists(atPath: $0) }
        guard let cliPath = cli else {
            NSLog("MuyiMacRight: code CLI not found")
            return
        }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: cliPath)
        var taskArgs = ["-n", folder]
        if let f = file { taskArgs.append(f) }
        task.arguments = taskArgs
        task.standardInput = FileHandle.nullDevice
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        do { try task.run() } catch {
            NSLog("MuyiMacRight: code CLI launch failed: \(error)")
        }
    }

    // MARK: - 权限

    func permissionStatus() -> (finder: Bool, systemEvents: Bool, accessibility: Bool) {
        var finderErr: NSDictionary?
        _ = NSAppleScript(source: "tell application \"Finder\" to count windows")?
            .executeAndReturnError(&finderErr)
        var seErr: NSDictionary?
        _ = NSAppleScript(source: "tell application \"System Events\" to count processes")?
            .executeAndReturnError(&seErr)
        let ax = AXIsProcessTrusted()
        return (finderErr == nil, seErr == nil, ax)
    }
}
