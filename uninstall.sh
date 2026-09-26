#!/usr/bin/env bash
# ============================================================================
#  surface-cachyos 卸载 / 回滚
#
#  用法：
#      ./uninstall.sh --list-baks [文件]   列出历史备份（不给文件就列全部）
#      ./uninstall.sh --dry-run            只打印会做什么
#      ./uninstall.sh                      还原包管文件
#
#  性质：
#      只动 manifest.map 里列的包管文件，不碰别的东西
#      不直接从 .bak-* 还原（备份里可能是任意历史状态，直接还原会把状态搞混）
#      还原方式：备份系统上的文件，然后从【包内版本】重新装一份
#
#  ★ 本仓没有"注入块"要移除 —— 旧的两仓模式下才有那个概念（往主仓的
#    hyprland.lua / autostart.lua 里插标记块）。本仓直接拥有这些文件，
#    所以卸载就是普通的"还原成包内版本"。
# ============================================================================
set -uo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
DRY=0

RED=$'\033[31m'; GRN=$'\033[32m'; YEL=$'\033[33m'; DIM=$'\033[2m'; RST=$'\033[0m'
ok()   { printf '%s✓%s %s\n' "$GRN" "$RST" "$*"; }
inf()  { printf '  %s%s%s\n' "$DIM" "$*" "$RST"; }
warn() { printf '%s!%s %s\n' "$YEL" "$RST" "$*"; }
head_(){ printf '\n%s── %s %s\n' "$DIM" "$*" "$RST"; }

# 备份就放在原文件旁边（跟 cachyOS-config 同一套约定），
# 所以别把那些 .bak-* 归档走，挪走等于废掉回滚点。
# 两种命名都要认：本仓用连字符 .bak-YYYYmmdd-HHMMSS，手工备的可能是点号。
latest_bak() { ls -1t "$1".bak-* "$1".bak.* 2>/dev/null | head -1; }

list_baks() {
    local target="${1:-}"
    while read -r rel sys; do
        [ -z "${rel:-}" ] && continue
        case "$rel" in \#*) continue ;; esac
        local d; d="$(eval echo "$sys")"
        [ -n "$target" ] && [ "$d" != "$target" ] && continue
        local b; b="$(latest_bak "$d")"
        if [ -n "$b" ]; then printf '%s\n   最新备份：%s\n' "$d" "$b"
        else printf '%s\n   (无备份)\n' "$d"; fi
    done < "$SRC/manifest.map"
}

# 还原成包内版本：先把系统上的文件备份，再用包内版本覆盖回去。
restore() {
    local s="$SRC/$1" d="$2"
    [ -e "$d" ] || { inf "$d 不存在，跳过"; return 0; }
    if [ $DRY -eq 1 ]; then inf "[dry] 备份并还原 $d"; return 0; fi
    cp -a "$d" "$d.bak-$STAMP" || { warn "备份失败，跳过：$d"; return 1; }
    if [ -e "$s" ]; then
        cp -a "$s" "$d" && ok "还原 $d（旧版在 $(basename "$d").bak-$STAMP）"
    else
        rm -f "$d" && ok "移除 $d（备份在 $(basename "$d").bak-$STAMP）"
    fi
}

# ── 入口 ────────────────────────────────────────────────────────────────────
MODE="restore"
for a in "$@"; do
    case "$a" in
        --dry-run)     DRY=1 ;;
        --list-baks)   MODE="list" ;;
        -h|--help)     sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)             TARGET="$a" ;;
    esac
done

if [ "$MODE" = list ]; then
    head_ "历史备份"
    list_baks "${TARGET:-}"
    exit 0
fi

printf '%s\n' "surface-cachyos 卸载$([ $DRY -eq 1 ] && echo '（dry-run）')"

head_ "还原包管文件"
while read -r rel sys; do
    [ -z "${rel:-}" ] && continue
    case "$rel" in \#*) continue ;; esac
    restore "$rel" "$(eval echo "$sys")"
done < "$SRC/manifest.map"

cat <<'EOS'

── 这些不在本仓管理范围内，需要手工处理 ─────────────────────────────────

  1) sudo 装的副本（本仓不代跑，也不代卸）：
       sudo rm -f /usr/local/bin/{tablet-mode,tablet-rescue,wvkbd-toggle}
       sudo rm -f /etc/udev/rules.d/70-surface-tablet-mode.rules
       sudo rm -f /etc/udev/rules.d/71-surface-ipts-ignore-raw.rules
       sudo rm -rf /etc/systemd/system/iptsd@.service.d
       sudo udevadm control --reload-rules && sudo systemctl daemon-reload

  2) 用户级服务的启用状态：
       systemctl --user disable --now iio-hyprland.service ocrd.socket

  3) 运行时状态：
       rm -f ~/.local/state/surface-config/tablet.flag

  ★ 想回到旧的两仓配置：两个旧仓都没动过，直接
       cd ~/cachyOS-config && ./install.sh hypr ui term
       cd ~/surface-config && ./install.sh
EOS
