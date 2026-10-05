#!/bin/sh
# 从 GitHub Actions 的运行里取回 CoomiDev APK，并做本地校验。
#
# 用法：
#   tools/ci/fetch-apk.sh                 # 取最近一次成功的 run
#   tools/ci/fetch-apk.sh <run_id>        # 取指定 run
#
# 前置：GH_TOKEN 环境变量（或 /tmp/.ghtok）里有 repo 权限的 token。
set -eu

REPO="${COOMI_FORK:-kimi-hqx/Coomi}"
OUT_DIR="${COOMI_APK_OUT:-/home/coomi/CoomiDev-output}"
ARTIFACT="${COOMI_ARTIFACT:-coomidev-apk}"

if [ -z "${GH_TOKEN:-}" ] && [ -f /tmp/.ghtok ]; then
    GH_TOKEN=$(tr -d '\n' < /tmp/.ghtok)
    export GH_TOKEN
fi
[ -n "${GH_TOKEN:-}" ] || { echo "GH_TOKEN is not set" >&2; exit 1; }

RUN_ID="${1:-}"
if [ -z "$RUN_ID" ]; then
    RUN_ID=$(gh api "/repos/$REPO/actions/workflows/coomidev-build.yml/runs?status=success&per_page=1" \
        -q '.workflow_runs[0].id')
fi
[ -n "$RUN_ID" ] || { echo "no successful run found" >&2; exit 1; }
echo "[i] run id: $RUN_ID"

mkdir -p "$OUT_DIR"
rm -rf "$OUT_DIR/artifact" "$OUT_DIR"/*.apk 2>/dev/null || true
gh run download "$RUN_ID" --repo "$REPO" --name "$ARTIFACT" --dir "$OUT_DIR/artifact"
APK=$(find "$OUT_DIR/artifact" -name 'CoomiDev-*.apk' | head -n 1)
[ -n "$APK" ] || { echo "APK not found in artifact" >&2; exit 1; }
cp "$APK" "$OUT_DIR/"
APK="$OUT_DIR/$(basename "$APK")"
echo "[i] apk: $APK"
sha256sum "$APK"

echo "--- badging（包名/版本/ABI/label）---"
aapt dump badging "$APK" 2>/dev/null | grep -E "^package:|^application-label:|native-code|sdkVersion|targetSdkVersion" || true

echo "--- 签名 ---"
apksigner verify --verbose "$APK" || true

echo "--- 关键内容 ---"
unzip -l "$APK" | grep -E "lib/arm64-v8a/|assets/web.zip|assets/runtime-v2/|assets/coomi" || true

echo "[ok] $APK"
