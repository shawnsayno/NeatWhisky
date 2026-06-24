#!/bin/zsh
# 修复 Whisky 下 Steam (CEF 126 / Wine 11) 黑屏：重新安装 steamwebhelper wrapper。
# 当 Steam 更新后界面又变黑时，运行本脚本即可恢复。
set -e

DIR="$HOME/.steam-wine-fix"
WRAPPER="$DIR/steamwebhelper_wrapper.exe"
BOTTLE="$HOME/Library/Containers/com.isaacmarovitz.Whisky/Bottles/7B6DFCAB-43C6-4FA1-9510-1EFBABE65789"
CEF="$BOTTLE/drive_c/Program Files (x86)/Steam/bin/cef"

if [ ! -f "$WRAPPER" ]; then
  echo "找不到 wrapper：$WRAPPER" >&2
  exit 1
fi

for d in cef.win64 cef.win7x64; do
  D="$CEF/$d"
  [ -d "$D" ] || continue
  # 备份真身（仅在尚未备份时）
  if [ ! -f "$D/steamwebhelper_orig.exe" ]; then
    cp "$D/steamwebhelper.exe" "$D/steamwebhelper_orig.exe"
  fi
  # 如果当前 steamwebhelper.exe 是原版（被 Steam 还原过），用它刷新 _orig 备份
  if [ "$(stat -f%z "$D/steamwebhelper.exe")" != "$(stat -f%z "$WRAPPER")" ]; then
    cp "$D/steamwebhelper.exe" "$D/steamwebhelper_orig.exe"
  fi
  cp "$WRAPPER" "$D/steamwebhelper.exe"
  echo "[$d] wrapper 已安装"
done

echo "完成。请通过 Whisky 启动 Steam（启动参数已含 -noverifyfiles 等防还原标志）。"
