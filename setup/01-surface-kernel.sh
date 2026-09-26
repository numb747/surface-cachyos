#!/usr/bin/env bash
# ============================================================================
#  装 linux-surface 内核，并在 Limine 启动菜单里给出可选项
#
#  ★ 这个脚本【需要 sudo】，而且会问你密码。
#     charlen 的习惯是自己跑 sudo，所以这里只打印命令、由你确认后执行：
#
#         ./setup/01-surface-kernel.sh            # 打印命令清单
#         ./setup/01-surface-kernel.sh --run      # 真的执行
#
#  设计要点：装完之后【普通内核仍然保留】，BOOT_ORDER 里 surface 排第一，
#  但 '*' 兜在第二位 —— 所以 surface 内核哪天坏了，开机菜单选第二项就回退。
#  这是当初选 Limine 而不是直接换内核的原因。
# ============================================================================
set -uo pipefail

GRN=$'\033[32m'; YEL=$'\033[33m'; DIM=$'\033[2m'; RST=$'\033[0m'
ok()   { printf '%s✓%s %s\n' "$GRN" "$RST" "$*"; }
inf()  { printf '  %s%s%s\n' "$DIM" "$*" "$RST"; }
warn() { printf '%s!%s %s\n' "$YEL" "$RST" "$*"; }

RUN=0
[ "${1:-}" = "--run" ] && RUN=1

CMDS=(
    # CachyOS 仓库里有预编译的 linux-surface（就是 linux-surface 内核的
    # Arch 打包），比走 https://github.com/linux-surface/linux-surface 的
    # 自编译省事得多，也不用引第三方 keyring。
    # headers 是必须的 —— hyprpm 要拿它编译 hyprgrass 插件。
    "sudo pacman -S --needed linux-surface linux-surface-headers iptsd iio-sensor-proxy"
    # iio-hyprland 走 AUR
    "paru -S --needed iio-hyprland-git"
    # wvkbd 的桌面布局版也在 AUR
    "paru -S --needed wvkbd-deskintl"
    # 把 surface 内核提到启动菜单第一位，其余保持兜底
    "sudo sed -i 's/^BOOT_ORDER=.*/BOOT_ORDER=\"*surface, *, *lts, *fallback, Snapshots\"/' /etc/default/limine"
)

printf '%s装 Surface 内核与传感器栈%s\n\n' "$DIM" "$RST"

for c in "${CMDS[@]}"; do
    if [ $RUN -eq 1 ]; then
        printf '%s$ %s%s\n' "$DIM" "$c" "$RST"
        eval "$c" || warn "上面这条失败了，自己判断要不要继续"
    else
        printf '    %s\n' "$c"
    fi
done

printf '\n'
if [ $RUN -eq 0 ]; then
    warn "上面是命令清单，没执行。确认后加 --run 重跑，或者自己逐条敲。"
else
    ok "执行完毕，重启进 surface 内核"
fi
printf '\n'
inf "重启后验证："
inf "  uname -r                      # 应含 surface"
inf "  systemctl status 'iptsd@*'    # 触屏服务"
inf "  ./doctor.sh                   # 全套体检"
printf '\n'
inf "★ 内核更新后 hyprgrass 的 ABI 会失效（插件静默不加载），"
inf "  需要重新 hyprpm update && hyprpm reload —— 在真终端里跑，会问密码。"
