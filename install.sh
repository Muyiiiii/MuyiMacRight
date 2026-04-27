#!/usr/bin/env bash
# 一键构建并安装 MuyiMacRight 到 /Applications/
# 用法：./install.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="MuyiMacRight"
SRC_PROJECT="MuyiMacRight.xcodeproj"
SCHEME="MuyiMacRight"
DEST="/Applications/${APP_NAME}.app"

cd "$REPO_ROOT"

if [ -d "$DEST" ]; then
    echo "=> Removing existing $DEST"
    rm -rf "$DEST"
fi

echo "=> Building Release directly into /Applications/"
echo "   (Xcode 自动 lsregister -trusted，pkd 会立即识别扩展)"
xcodebuild -project "$SRC_PROJECT" \
           -scheme "$SCHEME" \
           -configuration Release \
           -derivedDataPath /tmp/MuyiMacRight-build \
           CONFIGURATION_BUILD_DIR=/Applications \
           -quiet \
           build

if [ ! -d "$DEST" ]; then
    echo "ERROR: Build did not produce $DEST" >&2
    exit 1
fi

echo "=> Cleaning intermediate build files"
rm -rf /tmp/MuyiMacRight-build
# 清掉 CONFIGURATION_BUILD_DIR 顺带丢到 /Applications/ 的副产物
rm -rf "/Applications/${APP_NAME}.app.dSYM" \
       "/Applications/${APP_NAME}.swiftmodule" \
       "/Applications/${APP_NAME}FinderSync.swiftmodule" \
       "/Applications/MuyiMacRightFinderSync.appex" \
       "/Applications/MuyiMacRightFinderSync.appex.dSYM"

echo "=> Launching $APP_NAME"
open "$DEST"

sleep 2

echo "=> Opening Extensions settings (please tick FinderSync once)"
open "x-apple.systempreferences:com.apple.ExtensionsPreferences" 2>/dev/null \
  || open "x-apple.systempreferences:com.apple.preferences.extensions" 2>/dev/null \
  || open "x-apple.systempreferences:" 2>/dev/null \
  || true

cat <<'EOF'

============================================================
安装完成。

接下来 (只需一次):
  1. 在打开的「扩展」面板里勾选 FinderSync
     (路径: 隐私与安全性 → 扩展 → 已添加的扩展)
  2. 关掉 MuyiMacRight 窗口

之后:
  - 在 Finder 里任意文件夹空白处右键，会看到菜单
  - 这是一个普通 app，可以从 Launchpad / Spotlight 打开
  - 不需要再开 Xcode

更新代码后再次运行 ./install.sh 即可重装
============================================================
EOF
