import Cocoa
import FinderSync

final class FinderSync: FIFinderSync {

    private struct FileType {
        let title: String
        let ext: String
        let template: String
    }

    private let fileTypes: [FileType] = [
        .init(title: "Markdown",     ext: "md",   template: ""),
        .init(title: "Python",       ext: "py",   template: ""),
        .init(title: "JavaScript",   ext: "js",   template: ""),
        .init(title: "TypeScript",   ext: "ts",   template: ""),
        .init(title: "HTML",         ext: "html", template: ""),
        .init(title: "JSON",         ext: "json", template: ""),
        .init(title: "CSV",          ext: "csv",  template: ""),
        .init(title: "Plain Text",   ext: "txt",  template: ""),
        .init(title: "Shell Script", ext: "sh",   template: ""),
    ]

    override init() {
        super.init()
        // 监听整个文件系统。在沙盒里 NSHomeDirectory() 返回的是扩展容器路径
        // (~/Library/Containers/.../Data) 不是真实用户 home，所以不能用它。
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "MuyiMacRight")
        switch menuKind {
        case .contextualMenuForContainer:
            buildContainerMenu(menu)
        case .contextualMenuForItems:
            buildItemsMenu(menu)
        default:
            break
        }
        return menu
    }

    private func buildContainerMenu(_ menu: NSMenu) {
        let openItem = NSMenuItem(
            title: "用 VSCode 打开此文件夹",
            action: #selector(openFolderInVSCode(_:)),
            keyEquivalent: ""
        )
        openItem.target = self
        menu.addItem(openItem)

        let parent = NSMenuItem(title: "新建文件", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "新建文件")
        for (idx, type) in fileTypes.enumerated() {
            let item = NSMenuItem(
                title: "\(type.title)  (.\(type.ext))",
                action: #selector(createNewFile(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = idx
            submenu.addItem(item)
        }
        parent.submenu = submenu
        menu.addItem(parent)
    }

    private func buildItemsMenu(_ menu: NSMenu) {
        let item = NSMenuItem(
            title: "用 VSCode 打开",
            action: #selector(openSelectedInVSCode(_:)),
            keyEquivalent: ""
        )
        item.target = self
        menu.addItem(item)
    }

    @objc private func openSelectedInVSCode(_ sender: NSMenuItem) {
        let selected = FIFinderSyncController.default().selectedItemURLs() ?? []
        guard let first = selected.first else {
            NSLog("MuyiMacRight: no selection")
            return
        }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: first.path, isDirectory: &isDir) else {
            NSLog("MuyiMacRight: selected item missing: \(first.path)")
            return
        }
        if isDir.boolValue {
            openInVSCodeNewWindow(folder: first, file: nil, activate: true)
        } else {
            openInVSCodeNewWindow(folder: first.deletingLastPathComponent(), file: first, activate: true)
        }
    }

    @objc private func openFolderInVSCode(_ sender: NSMenuItem) {
        guard let folder = currentTargetFolder() else {
            NSLog("MuyiMacRight: no target folder")
            return
        }
        // 这是「打开文件夹」菜单，可以让 VSCode 拿焦点
        openInVSCodeNewWindow(folder: folder, file: nil, activate: true)
    }

    @objc private func createNewFile(_ sender: NSMenuItem) {
        guard let folder = currentTargetFolder() else {
            NSLog("MuyiMacRight: no target folder")
            return
        }
        guard fileTypes.indices.contains(sender.tag) else { return }
        let type = fileTypes[sender.tag]
        guard let newURL = makeFile(in: folder, ext: type.ext, template: type.template) else { return }
        // 只创建 + 进入重命名模式。不打开 VSCode（独立菜单项「用 VSCode 打开此文件夹」处理打开需求）
        selectAndRenameInFinder(newURL)
    }

    /// 通过 URL scheme 让宿主跑 select+keystroke AppleScript。
    /// 不能在扩展里直接 keystroke —— Accessibility 权限只能给「真实 .app」，
    /// 后台扩展自己唤不起 TCC 对话框，宿主才能弹（在授权流程里同步触发 AX 权限请求）。
    private func selectAndRenameInFinder(_ fileURL: URL) {
        var comps = URLComponents()
        comps.scheme = "muyimacright"
        comps.host = "select-rename"
        comps.queryItems = [URLQueryItem(name: "file", value: fileURL.path)]
        guard let url = comps.url else {
            NSLog("MuyiMacRight: failed to build select-rename URL")
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        NSWorkspace.shared.open(
            [url],
            withApplicationAt: URL(fileURLWithPath: "/Applications/MuyiMacRight.app"),
            configuration: config
        ) { _, error in
            if let error = error {
                NSLog("MuyiMacRight: open select-rename URL failed: \(error)")
            }
        }
    }

    private func currentTargetFolder() -> URL? {
        let controller = FIFinderSyncController.default()
        guard let target = controller.targetedURL() else { return nil }
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: target.path, isDirectory: &isDir) {
            return isDir.boolValue ? target : target.deletingLastPathComponent()
        }
        return nil
    }

    private func makeFile(in folder: URL, ext: String, template: String) -> URL? {
        let fm = FileManager.default
        var url = folder.appendingPathComponent("untitled.\(ext)")
        var n = 2
        while fm.fileExists(atPath: url.path) {
            url = folder.appendingPathComponent("untitled-\(n).\(ext)")
            n += 1
        }
        do {
            try template.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            NSLog("MuyiMacRight: write file failed at \(url.path): \(error)")
            return nil
        }
    }

    /// 通过自定义 URL scheme `muyimacright://open-vscode?folder=X&file=Y` 让宿主
    /// 拉起一个 headless 实例去跑 `code -n` CLI。openApplication 传 argv 在沙盒里
    /// 不可靠（args 会丢），URL scheme 是稳定的 IPC 通道。
    private func openInVSCodeNewWindow(folder: URL, file: URL?, activate: Bool) {
        var comps = URLComponents()
        comps.scheme = "muyimacright"
        comps.host = "open-vscode"
        var items = [URLQueryItem(name: "folder", value: folder.path)]
        if let file = file {
            items.append(URLQueryItem(name: "file", value: file.path))
        }
        comps.queryItems = items
        guard let url = comps.url else {
            NSLog("MuyiMacRight: failed to build muyimacright:// URL")
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = activate
        NSWorkspace.shared.open([url], withApplicationAt: URL(fileURLWithPath: "/Applications/MuyiMacRight.app"), configuration: config) { _, error in
            if let error = error {
                NSLog("MuyiMacRight: open URL via host failed: \(error)")
            }
        }
    }
}
