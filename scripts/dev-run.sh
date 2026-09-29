#!/bin/sh
# dev-run.sh — 一键「退出旧实例 → 领域测试 → Release 构建 → 启动新版」的开发闭环。
# 供所有 AI（Claude Code / Codex / 经 Drive 改码的外部 agent）与用户本人统一调用:
# 改完代码想目观感,跑这一个脚本,不要用 ⌘R,更不要自己拼 killall + xcodebuild。
#
# 为什么不用最常见的那种三步脚本（本仓库的三个已知坑）:
#   1. 进程名是 "TomatoBar Personal"（PRODUCT_NAME 带空格）。
#      `killall TomatoBar` 什么都杀不掉还报成功,旧实例仍占着菜单栏和沙盒容器。
#   2. 这是沙盒化应用（com.dilyar.TomatoBarPersonal）。`CODE_SIGNING_ALLOWED=NO`
#      的裸构建没有 entitlements,启动即失败或容器漂移。构建统一走 scripts/build.sh:
#      ad-hoc 签名 + codesign --verify --deep --strict,失败即停。
#   3. killall 的 SIGTERM 会绕过 App.swift 的退出闸门 —— 有未落盘的专注记录时
#      （hasUnsavedChanges）应用会拒绝退出。本脚本用 AppleEvent 优雅退出:
#      被拦下就中止并保留现场,绝不强杀、不丢记录。
#
# 启动的是 /tmp 构建目录里的新产物（与正式版同一沙盒容器、同一份真实数据,
# 用于目测迭代）;/Applications 的正式版不动,定版安装走定版流程。
# SKIP_TESTS=1 可跳过测试闸门（默认跑）。
set -eu
cd "$(dirname "$0")/.."

APP="TomatoBar Personal"
BUNDLE="com.dilyar.TomatoBarPersonal"
PROD_APP="/Applications/$APP.app"
NEW_APP="/tmp/TomatoBar-personal-build/Build/Products/Release/$APP.app"

quit_target="$PROD_APP"
if pgrep -x "$APP" >/dev/null 2>&1; then
  # 从 /tmp 启动的开发实例不在 /Applications,按 bundle id 让 LaunchServices 找正在跑的那个
  running_path=$(ps -eo comm= | grep -x ".*/$APP" | head -1 || true)
  case "$running_path" in
    "$PROD_APP"/*) quit_target="$PROD_APP" ;;
    *) quit_target="$BUNDLE" ;;
  esac

  echo "1/4 优雅退出旧实例（若有未保存的专注记录会被拦下,脚本随之中止,不杀）..."
  if [ "$quit_target" = "$BUNDLE" ]; then
    osascript -e "with timeout of 10 seconds
      tell application id \"$BUNDLE\" to quit
    end timeout" >/dev/null || {
      echo "✗ 应用拒绝退出（多半是「专注记录尚未保存」的闸门拦住了）。已中止:旧版仍在跑,什么都没丢。" >&2
      exit 1
    }
  else
    osascript -e "with timeout of 10 seconds
      tell application \"$PROD_APP\" to quit
    end timeout" >/dev/null || {
      echo "✗ 应用拒绝退出（多半是「专注记录尚未保存」的闸门拦住了）。已中止:旧版仍在跑,什么都没丢。" >&2
      exit 1
    }
  fi
  i=0
  while pgrep -x "$APP" >/dev/null 2>&1 && [ "$i" -lt 20 ]; do sleep 0.5; i=$((i+1)); done
  if pgrep -x "$APP" >/dev/null 2>&1; then
    echo "✗ 退出事件发出后旧实例仍在,中止（不强杀,避免绕过数据闸门）。" >&2
    exit 1
  fi
else
  echo "1/4 没有在跑的实例,跳过退出。"
fi

echo "2/4 领域测试闸门..."
if [ "${SKIP_TESTS:-0}" = "1" ]; then
  echo "  （SKIP_TESTS=1,已跳过）"
else
  sh scripts/test.sh | tail -1
fi

echo "3/4 Release 构建 + 严格签名（scripts/build.sh）..."
sh scripts/build.sh > /tmp/tomatobar-dev-run-build.log 2>&1 || {
  echo "✗ 构建失败,日志尾部:" >&2
  tail -25 /tmp/tomatobar-dev-run-build.log >&2
  exit 1
}
grep -q "BUILD SUCCEEDED" /tmp/tomatobar-dev-run-build.log
echo "  BUILD SUCCEEDED（日志:/tmp/tomatobar-dev-run-build.log）"

echo "4/4 启动新版（/tmp 构建产物;容器与正式版共用,数据无损延续）..."
[ -d "$NEW_APP" ] || { echo "✗ 产物缺失:$NEW_APP" >&2; exit 1; }
open "$NEW_APP"
sleep 1
pgrep -x "$APP" >/dev/null 2>&1 || { echo "✗ 启动后没找到进程,检查一下 $NEW_APP" >&2; exit 1; }
echo "✅ 新版已启动。菜单栏图标即最新构建;/Applications 的正式版未被触碰。"
echo "   目测不满意 → 截图 → 改代码 → 再跑本脚本。定版时另走安装流程。"
