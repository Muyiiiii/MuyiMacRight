# MuyiMacRight

> [中文文档](README.md)

A macOS Finder right-click extension. Adds two menus to any folder background:

- **Open this folder in VSCode** — open the current folder as a new VSCode workspace
- **New file ▶ Markdown / Python / JavaScript / …** — create an empty file of the chosen type, auto-select it and drop into rename mode

When you right-click a selected file or folder, it also adds an **Open in VSCode** menu — if it's a file, VSCode opens with the parent directory as workspace and the file selected; if it's a folder, it opens that folder.

Built as a macOS Finder Sync Extension. Universal binary (arm64 + x86_64). Menu-bar app (no Dock icon). Distributed as a ~274 KB zip.

## Install for end users (recommended)

1. Go to [Releases](https://github.com/Muyiiiii/MuyiMacRight/releases) and download the latest `MuyiMacRight-x.y.z.zip`.
2. Unzip, drag `MuyiMacRight.app` into `/Applications/`.
3. **Right-click → Open** (do NOT double-click). macOS Gatekeeper will warn because the app is ad-hoc signed (no paid Apple Developer account); right-click bypass is the standard workaround. Click "Open" in the warning dialog.
4. The app appears in the **menu bar** (cursor-click icon, no Dock entry). Click it and walk through the one-time setup:
   - Grant **Finder** Apple-events permission (system popup → OK)
   - Grant **System Events** Apple-events permission (system popup → OK)
   - Grant **Accessibility** permission — system settings opens, click `+`, pick `/Applications/MuyiMacRight.app`, toggle on
5. Click **Open Extensions Settings** in the menu and enable **FinderSync** in the system panel.
6. Right-click any folder background in Finder — the menu should appear.

> ⚠️ Do **not** double-click the unzipped `.app` while it's still in your Downloads/Desktop. macOS LaunchServices registers that temporary path as the active host, which displaces the `/Applications/` registration and silently breaks the menu. Move it into `/Applications/` first, then open from there.

### Requirements

- macOS 13 (Ventura) or later
- VSCode installed at `/Applications/Visual Studio Code.app` (otherwise the "Open in VSCode" actions cannot find the `code` CLI)

### Upgrading to a new version

Ad-hoc signatures have a different cdhash on every build, so previously granted permissions become invalid after replacing the app. After upgrading:

- **System Settings → Privacy & Security → Accessibility** — remove the old `MuyiMacRight` entry and re-add `/Applications/MuyiMacRight.app`
- Re-confirm the Finder / System Events popups when they appear

## Build from source (developers)

```sh
git clone git@github.com:Muyiiiii/MuyiMacRight.git
cd MuyiMacRight
./install.sh
```

One command does the full flow: build Release → install into `/Applications/` → launch → open Extensions panel.

> ⚠️ Don't manually `cp` build products into `/Applications/`. Xcode's build phase runs `lsregister -f -R -trusted`; without the `-trusted` flag `pkd` won't recognize the extension. `install.sh` uses `CONFIGURATION_BUILD_DIR=/Applications` so Xcode emits straight to the target and the registration sticks.

### Debugging

Open `MuyiMacRight.xcodeproj`, pick the `MuyiMacRight` scheme, `Cmd+R`.

### Packaging a distribution zip

```sh
./release.sh 1.0.1
```

Produces `release/MuyiMacRight-1.0.1.zip` (universal binary) plus `release/README.txt` (end-user install guide). Upload via `gh release create v1.0.1 release/MuyiMacRight-1.0.1.zip --notes-file release/README.txt`.

## Project layout

```
MuyiMacRight.xcodeproj/        Xcode project
MuyiMacRight/                  Host app
├── AppDelegate.swift          Status item + URL scheme handler + permission wizard
├── ViewController.swift       Info window
├── Info.plist
├── MuyiMacRight.entitlements  App sandbox + Apple-events temporary exceptions
└── Assets.xcassets/           AppIcon (cursorarrow.click on blue gradient)
MuyiMacRightFinderSync/        Finder Sync extension
├── FinderSync.swift           Menu generation + new-file logic + VSCode dispatch
├── Info.plist                 NSExtension config
└── FinderSync.entitlements    Extension sandbox
```

## Verify the extension is loaded

```sh
pluginkit -m -A -v -p com.apple.FinderSync
```

Look for `+    com.muyi.MuyiMacRight.FinderSync(1.0)` — `+` means enabled, `-` means registered but disabled.

## Customize file types

Edit the `fileTypes` array at the top of `MuyiMacRightFinderSync/FinderSync.swift`:

```swift
private let fileTypes: [FileType] = [
    .init(title: "Markdown", ext: "md", template: "# Untitled\n\n"),
    // add whatever you want
]
```

Re-run `./install.sh` (or `Cmd+R` in Xcode) and the extension reloads.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| No right-click menu after install | Extension not enabled in System Settings → Privacy & Security → Extensions; or `pluginkit -m -p com.apple.FinderSync` doesn't show `com.muyi.MuyiMacRight.FinderSync` |
| Menu only in home directory | `directoryURLs` in `FinderSync.swift` is set narrowly. The current default is `[URL(fileURLWithPath: "/")]` (system-wide); if you change it, remember `NSHomeDirectory()` in a sandboxed extension returns the container path, not the real home |
| Menu item does nothing | Check `Console.app` filtered by `MuyiMacRight`. Usually VSCode is missing or installed in a non-standard path |
| Code change not taking effect | macOS may cache the old extension. Run `pluginkit -e ignore -i com.muyi.MuyiMacRight.FinderSync && pluginkit -e use -i com.muyi.MuyiMacRight.FinderSync`, or `killall Finder` |
| "MuyiRight.app not found" popup | Stale registration of an old build (often from `/tmp/` or an extracted `.app`). `pluginkit -e ignore -i <old-bundle-id>`, `rm -rf` the leftover build dir, `killall Finder` |

## System constraints

- Minimum macOS: 13.0 (`MACOSX_DEPLOYMENT_TARGET`); developed on macOS 14.8.5 (Sonoma) + Xcode 16.0
- Signature: ad-hoc (`CODE_SIGN_IDENTITY = "-"`). Works locally with Gatekeeper bypass. Public distribution to many users would benefit from a paid Apple Developer account + notarization
- Architecture: universal binary (arm64 + x86_64) in Release config
