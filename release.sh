#!/usr/bin/env bash
# 打包 MuyiMacRight 为可分发的 .zip
# 用法: ./release.sh [version]   默认 version=1.0

set -euo pipefail

VERSION="${1:-1.0}"
APP_NAME="MuyiMacRight"
SCHEME="MuyiMacRight"
SRC_PROJECT="MuyiMacRight.xcodeproj"
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
RELEASE_DIR="${REPO_ROOT}/release"
BUILD_DIR="/tmp/MuyiMacRight-release"
APP_BUNDLE="${BUILD_DIR}/Build/Products/Release/${APP_NAME}.app"

cd "$REPO_ROOT"

echo "=> 清掉旧的 release 产物"
rm -rf "$BUILD_DIR" "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

echo "=> 构建 universal Release (arm64 + x86_64)"
xcodebuild -project "$SRC_PROJECT" \
           -scheme "$SCHEME" \
           -configuration Release \
           -derivedDataPath "$BUILD_DIR" \
           ARCHS="arm64 x86_64" \
           ONLY_ACTIVE_ARCH=NO \
           -quiet \
           clean build

if [ ! -d "$APP_BUNDLE" ]; then
    echo "ERROR: build 没产出 $APP_BUNDLE" >&2
    exit 1
fi

echo "=> 验证架构"
lipo -info "$APP_BUNDLE/Contents/MacOS/${APP_NAME}"
lipo -info "$APP_BUNDLE/Contents/PlugIns/MuyiMacRightFinderSync.appex/Contents/MacOS/MuyiMacRightFinderSync"

echo "=> 验证签名"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE" 2>&1 | tail -5

echo "=> 准备分发目录（含 .app + 一键安装脚本）"
STAGE_DIR="${BUILD_DIR}/${APP_NAME}-${VERSION}"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"
ditto "$APP_BUNDLE" "${STAGE_DIR}/${APP_NAME}.app"
cp "${REPO_ROOT}/install-for-user.command" "${STAGE_DIR}/"
chmod +x "${STAGE_DIR}/install-for-user.command"

echo "=> 用 ditto 打 zip（保留签名 + 符号链接 + 资源 fork）"
ZIP_NAME="${APP_NAME}-${VERSION}.zip"
ZIP_PATH="${RELEASE_DIR}/${ZIP_NAME}"
ditto -c -k --keepParent --sequesterRsrc "$STAGE_DIR" "$ZIP_PATH"

echo "=> 生成 README.txt（给下载用户看）"
cat > "${RELEASE_DIR}/README.txt" <<'EOF'
MuyiMacRight - Finder 右键扩展
============================

功能：在 Finder 任意文件夹空白处右键，弹出
  • 用 VSCode 打开此文件夹
  • 新建文件 ▶  Markdown / Python / JavaScript / TypeScript /
                HTML / JSON / CSV / Plain Text / Shell Script

新建文件后会自动选中（首次安装+授权完后还会自动进入重命名模式）。


----------------------------------------
首次安装（推荐流程，1 分钟）
----------------------------------------

1. 解压 zip，进入解压出来的文件夹

2. **双击 install-for-user.command**
   Terminal 会自动跳出，几秒钟跑完所有命令行步骤
   （拷到 /Applications/、剥隔离属性、注册扩展、启动 app、打开扩展面板）

   如果被「无法打开开发者未识别的脚本」拦住：
   右键 install-for-user.command → 打开 → 弹窗里再点【打开】

3. 脚本跑完后做两件 macOS 强制人工的事：

   ① 在弹出的【系统设置】里勾选 FinderSync 扩展
      - macOS 15: 通用 → 登录项与扩展 → 滚到最下「扩展」区
                  → 点「已添加的扩展」→ 勾选 FinderSync
      - macOS 13/14: 隐私与安全性 → 扩展 → 已添加的扩展
                    → 勾选 FinderSync

   ② 点屏幕右上角菜单栏【鼠标光标点击图标】，按引导走三段权限：
      a. 「Finder 控制权」          → 弹窗点【好】
      b. 「System Events 控制权」    → 弹窗点【好】
      c. 「辅助功能（模拟回车）」    → 系统设置自动打开
                                    → 列表里点【+】→ 选 /Applications/MuyiMacRight.app
                                    → 打开右边开关

4. 重新点菜单图标，三行权限都是 ✓ 即安装成功

----------------------------------------
手动安装（脚本跑不了的话）
----------------------------------------

1. 把 MuyiMacRight.app 拖到 /Applications/
2. 打开终端，执行：xattr -cr /Applications/MuyiMacRight.app
3. 右键 MuyiMacRight.app → 打开（双击会被 Gatekeeper 挡）→ 弹窗再点【打开】
4. 跟上面【首次安装】3-4 步一样配权限 + 启用扩展

----------------------------------------
使用
----------------------------------------

到 Finder 任意文件夹的**空白处右键**（不是文件上）：

  • 用 VSCode 打开此文件夹  → 在 VSCode 新窗口打开当前文件夹
  • 新建文件 ▶ Markdown      → 创建空 untitled.md，自动选中并进重命名模式
                              输入名字 → 回车 → 完成

----------------------------------------
卸载
----------------------------------------

1. 菜单栏图标 → 退出 MuyiMacRight
2. 删除 /Applications/MuyiMacRight.app
3. 系统设置 → 隐私与安全性 → 自动化、辅助功能、扩展 里把 MuyiMacRight 相关条目删掉

----------------------------------------
依赖
----------------------------------------

* macOS 13 (Ventura) 或更新
* Visual Studio Code 装在 /Applications/Visual Studio Code.app
  （如果装在别的位置，「用 VSCode 打开此文件夹」会失败 —— 大多数人用默认路径不会有事）

----------------------------------------
排查
----------------------------------------

右键看不到菜单 →
  系统设置 → 隐私与安全性 → 扩展 → 已添加的扩展
  里 FinderSync 那个开关有没有打开

新建文件没自动重命名 →
  「辅助功能」里 MuyiMacRight 的开关没开

权限给了仍然报「未授权」→
  在「辅助功能」列表里**先把 MuyiMacRight 删掉再加回来**
  （因为 ad-hoc 签名升级 app 时签名指纹会变，旧授权失效）
EOF

echo ""
echo "=> 完成"
echo ""
echo "  $ZIP_PATH"
ls -lh "$ZIP_PATH"
echo ""
echo "  README: ${RELEASE_DIR}/README.txt"
echo ""
echo "把整个 release/ 目录或者 zip 单文件分发都行。"
