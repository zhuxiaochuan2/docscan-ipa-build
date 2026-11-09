#!/bin/bash
# ---------------------------------------------------------------------------
# 在 macOS 上一键生成 TrollStore 可直接安装的「未签名 ipa」
# 用法：  ./build.sh
# 输出：  build/DocScan-unsigned.ipa
# ---------------------------------------------------------------------------
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "❌ 需要 macOS + Xcode（命令行工具）。没有 Mac 请改用 GitHub Actions 编译。" >&2
  exit 1
fi

echo "==> 1/4 生成 Xcode 工程"
python3 tools/gen_xcodeproj.py

echo "==> 2/4 编译 Release (iphoneos, 关闭签名)"
rm -rf build
xcodebuild \
  -project DocScan.xcodeproj \
  -scheme DocScan \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  clean build

APP="build/DerivedData/Build/Products/Release-iphoneos/DocScan.app"
if [ ! -d "$APP" ]; then
  echo "❌ 未找到 $APP" >&2
  exit 1
fi

echo "==> 3/4 打包 Payload"
rm -rf build/ipa
mkdir -p build/ipa/Payload
cp -R "$APP" build/ipa/Payload/

echo "==> 4/4 生成 ipa"
(cd build/ipa && zip -qry ../DocScan-unsigned.ipa Payload)
echo "✅ 完成：$(pwd)/build/DocScan-unsigned.ipa"
echo "   把这个 ipa 传到 iPhone，用 TrollStore 打开即可安装（无需签名）。"
