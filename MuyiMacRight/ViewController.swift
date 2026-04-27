import Cocoa
import ApplicationServices

/// 状态栏 popover 里的面板内容：权限状态 + 操作按钮
final class PreferencesViewController: NSViewController {

    private var finderRow: PermissionRow!
    private var systemEventsRow: PermissionRow!
    private var accessibilityRow: PermissionRow!

    override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 380, height: 360))

        let title = NSTextField(labelWithString: "MuyiMacRight")
        title.font = .systemFont(ofSize: 16, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false

        let subtitle = NSTextField(labelWithString: "Finder 右键扩展")
        subtitle.font = .systemFont(ofSize: 11)
        subtitle.textColor = .secondaryLabelColor
        subtitle.translatesAutoresizingMaskIntoConstraints = false

        let permsHeader = NSTextField(labelWithString: "权限")
        permsHeader.font = .systemFont(ofSize: 11, weight: .medium)
        permsHeader.textColor = .secondaryLabelColor
        permsHeader.translatesAutoresizingMaskIntoConstraints = false

        finderRow = PermissionRow(name: "Finder 控制权", target: self, action: #selector(grantAppleEvents))
        systemEventsRow = PermissionRow(name: "System Events 控制权", target: self, action: #selector(grantAppleEvents))
        accessibilityRow = PermissionRow(name: "辅助功能（模拟回车）", target: self, action: #selector(openAccessibilityPane))

        let permsStack = NSStackView(views: [finderRow, systemEventsRow, accessibilityRow])
        permsStack.orientation = .vertical
        permsStack.spacing = 8
        permsStack.alignment = .leading
        permsStack.translatesAutoresizingMaskIntoConstraints = false

        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false

        let extButton = NSButton(title: "打开扩展设置（启用/停用 FinderSync）", target: self, action: #selector(openExtensionSettings))
        extButton.bezelStyle = .rounded
        extButton.translatesAutoresizingMaskIntoConstraints = false

        let regrantButton = NSButton(title: "重新触发权限请求", target: self, action: #selector(regrantAll))
        regrantButton.bezelStyle = .rounded
        regrantButton.translatesAutoresizingMaskIntoConstraints = false

        let quitButton = NSButton(title: "退出 MuyiMacRight", target: NSApp, action: #selector(NSApplication.terminate(_:)))
        quitButton.bezelStyle = .rounded
        quitButton.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(title)
        root.addSubview(subtitle)
        root.addSubview(permsHeader)
        root.addSubview(permsStack)
        root.addSubview(divider)
        root.addSubview(extButton)
        root.addSubview(regrantButton)
        root.addSubview(quitButton)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: root.topAnchor, constant: 16),
            title.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),

            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 2),
            subtitle.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),

            permsHeader.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 16),
            permsHeader.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),

            permsStack.topAnchor.constraint(equalTo: permsHeader.bottomAnchor, constant: 8),
            permsStack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            permsStack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),

            divider.topAnchor.constraint(equalTo: permsStack.bottomAnchor, constant: 16),
            divider.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            divider.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
            divider.heightAnchor.constraint(equalToConstant: 1),

            extButton.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 12),
            extButton.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            extButton.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),

            regrantButton.topAnchor.constraint(equalTo: extButton.bottomAnchor, constant: 8),
            regrantButton.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            regrantButton.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),

            quitButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -16),
            quitButton.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            quitButton.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
        ])

        self.view = root
    }

    func refresh() {
        guard let app = NSApp.delegate as? AppDelegate else { return }
        let s = app.permissionStatus()
        finderRow.setGranted(s.finder)
        systemEventsRow.setGranted(s.systemEvents)
        accessibilityRow.setGranted(s.accessibility)
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.refresh() }
    }

    @objc private func openAccessibilityPane() {
        let opts: NSDictionary = ["AXTrustedCheckOptionPrompt" as NSString: true]
        _ = AXIsProcessTrustedWithOptions(opts)
        // 同时直接打开「辅助功能」面板
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
}

/// 一行权限：[名称]  [状态徽章]  [按钮]
final class PermissionRow: NSView {
    private let badge = NSTextField(labelWithString: "")
    private let button: NSButton

    init(name: String, target: AnyObject, action: Selector) {
        button = NSButton(title: "授权", target: target, action: action)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: name)
        label.font = .systemFont(ofSize: 13)
        label.translatesAutoresizingMaskIntoConstraints = false

        badge.font = .systemFont(ofSize: 12, weight: .medium)
        badge.translatesAutoresizingMaskIntoConstraints = false

        button.bezelStyle = .rounded
        button.controlSize = .small
        button.translatesAutoresizingMaskIntoConstraints = false

        addSubview(label)
        addSubview(badge)
        addSubview(button)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 28),
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),

            badge.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 8),
            badge.centerYAnchor.constraint(equalTo: centerYAnchor),

            button.trailingAnchor.constraint(equalTo: trailingAnchor),
            button.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func setGranted(_ granted: Bool) {
        if granted {
            badge.stringValue = "✓ 已授权"
            badge.textColor = .systemGreen
            button.title = "已授权"
            button.isEnabled = false
        } else {
            badge.stringValue = "✗ 未授权"
            badge.textColor = .systemRed
            button.title = "授权"
            button.isEnabled = true
        }
    }
}
