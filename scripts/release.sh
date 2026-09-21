#!/bin/bash
#
# release.sh — 构建签名版 macOS app、打包 DMG、公证并装订票据
#
# 用法:
#   ./scripts/release.sh [x.y.z] [--skip-notarize]
#
#   不带参数   : 版本号取自当前 HEAD 精确匹配的 git tag（vX.Y.Z）
#   带版本号   : 显式指定，用于本地测试（无需打 tag）
#   --skip-notarize : 跳过 Apple 公证（仅用于本地验证打包流程，不可对外分发）
#
# 依赖:
#   - 钥匙串中已安装 "Developer ID Application" 证书
#   - 已配置 notarytool 凭证（一次性）:
#       xcrun notarytool store-credentials notarytool \
#         --apple-id "you@example.com" --team-id "TEAMID" --password "app-specific-password"
#

set -euo pipefail

# ---- 路径 ----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT="$ROOT_DIR/MarkdownDemo/MarkdownDemo.xcodeproj"
SCHEME="MarkdownDemo"
APP_NAME="Mano"

BUILD_DIR="$ROOT_DIR/build"
STAGING_DIR="$BUILD_DIR/dmg-staging"
DERIVED_DATA="$BUILD_DIR/DerivedData"
DIST_DIR="$ROOT_DIR/dist"

# ---- 参数解析 ----
SKIP_NOTARIZE=false
VERSION=""
for arg in "$@"; do
    case "$arg" in
        --skip-notarize) SKIP_NOTARIZE=true ;;
        *)
            if [[ "$arg" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                VERSION="$arg"
            else
                echo "error: 无法识别的参数 '$arg'（版本号格式应为 x.y.z）" >&2
                exit 1
            fi
            ;;
    esac
done

if [[ -z "$VERSION" ]]; then
    TAG="$(git -C "$ROOT_DIR" describe --tags --exact-match 2>/dev/null || true)"
    if [[ "$TAG" =~ ^v([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
        VERSION="${BASH_REMATCH[1]}"
    else
        echo "error: 当前 HEAD 没有匹配 vX.Y.Z 的 tag。" >&2
        echo "       请先打 tag：git tag -a v1.0.0 -m 'release v1.0.0'" >&2
        echo "       或显式指定版本：./scripts/release.sh 1.0.0" >&2
        exit 1
    fi
fi

BUILD_NUMBER="$(git -C "$ROOT_DIR" rev-list --count HEAD)"
DATE="$(date +%Y%m%d)"
ARTIFACT_NAME="${APP_NAME}-V${VERSION}-${DATE}"

echo "==> 版本: $VERSION (build $BUILD_NUMBER)"
echo "==> 产物: ${ARTIFACT_NAME}.dmg"

if [[ -n "$(git -C "$ROOT_DIR" status --porcelain)" ]]; then
    echo "warning: 工作区存在未提交改动，构建内容可能与仓库状态不一致。" >&2
fi

# ---- 签名身份探测 ----
# xcodebuild 分发构建用通用身份名 "Developer ID Application"（Manual 签名），
# Team ID 从钥匙串里实际证书的 "(TEAMID)" 后缀自动提取。
DEVELOPER_ID_LINE="$(security find-identity -v -p codesigning | grep 'Developer ID Application:' | head -1 || true)"
if [[ -z "$DEVELOPER_ID_LINE" ]]; then
    echo "error: 未找到 'Developer ID Application' 证书。" >&2
    echo "       请在钥匙串中安装 Developer ID Application 证书后重试。" >&2
    exit 1
fi
SIGN_IDENTITY="$(echo "$DEVELOPER_ID_LINE" | grep -o '"[^"]*"' | tr -d '"')"
TEAM_ID="${TEAM_ID:-}"
if [[ -z "$TEAM_ID" ]]; then
    TEAM_ID="$(echo "$SIGN_IDENTITY" | sed -n 's/.*(\(.*\)).*/\1/p')"
fi
NOTARY_PROFILE="${NOTARY_KEYCHAIN_PROFILE:-notarytool}"

echo "==> 签名身份: $SIGN_IDENTITY"
echo "==> Team ID : $TEAM_ID"

# ---- 1. 构建 Release（Developer ID 签名 + Hardened Runtime）----
echo "==> [1/6] 构建 Release ..."
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED_DATA" \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    'CODE_SIGN_IDENTITY=Developer ID Application' \
    ENABLE_HARDENED_RUNTIME=YES \
    clean build >/dev/null

APP_PATH="$DERIVED_DATA/Build/Products/Release/${APP_NAME}.app"
if [[ ! -d "$APP_PATH" ]]; then
    echo "error: 构建产物不存在: $APP_PATH" >&2
    exit 1
fi

# ---- 2. 校验签名 ----
echo "==> [2/6] 校验代码签名 ..."
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
codesign -dvv "$APP_PATH" 2>&1 | grep -E "Identifier|Authority|TeamIdentifier|Runtime" || true

# ---- 3. 组装 DMG staging（app + /Applications 快捷方式）----
echo "==> [3/6] 组装 DMG 内容 ..."
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# ---- 4. 生成压缩 DMG ----
echo "==> [4/6] 生成 DMG ..."
mkdir -p "$DIST_DIR"
DMG_PATH="$DIST_DIR/${ARTIFACT_NAME}.dmg"
rm -f "$DMG_PATH"
hdiutil create \
    -volname "$ARTIFACT_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null

# ---- 5. 公证 + 装订 ----
if [[ "$SKIP_NOTARIZE" == "true" ]]; then
    echo "warning: 已跳过公证，此 DMG 不可对外分发（对方机器 Gatekeeper 会拦截）。" >&2
else
    echo "==> [5/6] 提交 Apple 公证（notarytool --wait，可能需要几分钟）..."
    if security find-generic-password -s "com.apple.gke.notary.tool" -a "$NOTARY_PROFILE" >/dev/null 2>&1; then
        xcrun notarytool submit "$DMG_PATH" \
            --keychain-profile "$NOTARY_PROFILE" \
            --wait
    else
        echo "error: 未找到 notarytool 凭证 profile '$NOTARY_PROFILE'。" >&2
        echo "       请先执行（一次性）:" >&2
        echo "       xcrun notarytool store-credentials $NOTARY_PROFILE \\" >&2
        echo "         --apple-id 'you@example.com' --team-id '$TEAM_ID' \\" >&2
        echo "         --password 'app-specific-password'" >&2
        echo "       或临时跳过公证: ./scripts/release.sh $VERSION --skip-notarize" >&2
        exit 1
    fi

    echo "==> 装订公证票据 ..."
    xcrun stapler staple "$DMG_PATH"
    xcrun stapler validate "$DMG_PATH"
fi

# ---- 6. 最终校验 ----
echo "==> [6/6] 最终校验 ..."
hdiutil verify "$DMG_PATH" >/dev/null && echo "DMG 校验通过"

# ---- 清理中间产物 ----
rm -rf "$STAGING_DIR"

DMG_SIZE="$(du -h "$DMG_PATH" | cut -f1)"
echo ""
echo "============================================================"
echo " 发布产物已生成:"
echo "   $DMG_PATH"
echo "   大小: $DMG_SIZE"
echo ""
if [[ "$SKIP_NOTARIZE" == "true" ]]; then
    echo " 注意: 未公证 — 仅限本地测试。"
else
    echo " 已完成 Developer ID 签名 + 公证 + 装订，可对外分发。"
    echo " 可选: 上传到 GitHub Releases"
    echo "   gh release create v$VERSION '$DMG_PATH' --title 'v$VERSION' --generate-notes"
fi
echo "============================================================"
