#!/bin/sh
# 从 GitHub Actions 取回 CoomiDev APK 并做本地校验。
#
# 用法：
#   tools/ci/fetch-apk.sh                 # 取最近一次成功的 run
#   tools/ci/fetch-apk.sh <run_id>        # 取指定 run
#
# 前置：GH_TOKEN（或 /tmp/.ghtok）里有一个 repo 权限的 token。
# 说明：本 guest 没有 JRE，apksigner 无法本地运行，签名校验以 CI 里的
#       apksigner verify --verbose 输出为准；本地校验包名 / ABI / 关键资产 / sha256。
set -eu

REPO="${COOMI_FORK:-kimi-hqx/Coomi}"
OUT_DIR="${COOMI_APK_OUT:-/home/coomi/CoomiDev-output}"
ARTIFACT="${COOMI_ARTIFACT:-coomidev-apk}"
APK_TOOLS="${COOMI_APK_TOOLS:-/home/coomi/bin/apk-tools}"

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
gh run download "$RUN_ID" --repo "$REPO" --name "$ARTIFACT" --dir "$OUT_DIR/download"
APK=$(find "$OUT_DIR/download" -name '*.apk' | head -n 1)
[ -n "$APK" ] || { echo "APK not found in artifact" >&2; exit 1; }
cp "$APK" "$OUT_DIR/"
APK="$OUT_DIR/$(basename "$APK")"
echo "[i] apk: $APK"

echo "--- sha256 ---"
sha256sum "$APK"
find "$OUT_DIR/download" -name '*.sha256' -exec cat {} \; || true

echo "--- badging（包名 / 版本 / label / ABI）---"
"$APK_TOOLS" aapt dump badging "$APK" 2>/dev/null \
    | grep -E "^package:|^application-label:|native-code|sdkVersion|targetSdkVersion" || true

echo "--- zipalign 校验 ---"
"$APK_TOOLS" zipalign -c -v 4 "$APK" > /dev/null 2>&1 && echo "aligned: yes" || echo "aligned: NO"

echo "--- 关键内容 ---"
unzip -l "$APK" | grep -E "lib/arm64-v8a/|assets/web.zip|assets/runtime-v2/|coomi_agent_dev" || true

echo "--- 签名块存在性（本地无 JRE，仅作存在性检查）---"
unzip -l "$APK" | grep -E "META-INF/.*\.(RSA|DSA|EC|SF)" || true

echo "[ok] $APK"
