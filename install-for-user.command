#!/bin/bash
# MuyiMacRight 一键安装（给最终用户）
# 双击此文件运行，自动把 .app 装到 /Applications/、剥 quarantine、注册扩展。

set -e

cd "$(dirname "$0")"

APP_NAME="MuyiMacRight"
SRC="./${APP_NAME}.app"
DEST="/Applications/${APP_NAME}.app"
EXT_BUNDLE="com.muyi.MuyiMacRight.FinderSync"
LSREG="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"

echo "========================================"
echo "  MuyiMacRight 安装"
echo "========================================"
echo ""

if [ ! -d "$SRC" ]; then
    echo "✗ 没找到 ${APP_NAME}.app"
    echo "  请确认 ${APP_NAME}.app 和这个脚本放在同一个文件夹里"
    echo ""
    read -p "按回车关闭..."
    exit 1
fi

if [ -d "$DEST" ]; then
    echo "→ 检测到已安装版本，替换中..."
    killall "$APP_NAME" 2>/dev/null || true
    sleep 1
    rm -rf "$DEST"
fi

echo "→ 安装到 /Applications/ ..."
ditto "$SRC" "$DEST"

echo "→ 移除隔离属性 (quarantine) ..."
xattr -cr "$DEST"

echo "→ 注册到 LaunchServices ..."
"$LSREG" -f -R "$DEST" 2>/dev/null || true

echo "→ 启用 FinderSync 扩展 ..."
pluginkit -e use -i "$EXT_BUNDLE" 2>/dev/null || true

echo "→ 启动 ${APP_NAME} ..."
open "$DEST"
sleep 2

echo "→ 打开系统扩展设置面板 ..."
open "x-apple.systempreferences:com.apple.LoginItems-Settings.extension" 2>/dev/null \
  || open "x-apple.systempreferences:com.apple.ExtensionsPreferences" 2>/dev/null \
  || open "x-apple.systempreferences:com.apple.preferences.extensions" 2>/dev/null \
  || open "x-apple.systempreferences:" 2>/dev/null

echo ""
echo "========================================"
echo "  自动步骤完成 ✓"
echo "========================================"
echo ""
echo "接下来还需要手动做两件事（macOS 安全机制要求，无法自动）："
echo ""
echo "1. 在弹出的【系统设置】里勾选 FinderSync 扩展"
echo "   - macOS 15: 通用 → 登录项与扩展 → 滚到最下「扩展」区"
echo "               → 点「已添加的扩展」→ 勾选 FinderSync"
echo "   - macOS 13/14: 隐私与安全性 → 扩展 → 已添加的扩展"
echo "                  → 勾选 FinderSync"
echo ""
echo "2. 点屏幕右上角菜单栏【鼠标光标点击图标】"
echo "   按引导授予 Finder / System Events / 辅助功能 三项权限"
echo ""
echo "都完成后到任意文件夹空白处右键，能看到菜单就说明 OK 了。"
echo ""
read -p "按回车键关闭此窗口..."
