#!/usr/bin/env bash
# ============================================================================
#  surface-cachyos 体检
#
#  用法：
#      ./doctor.sh            全部检查
#      ./doctor.sh --quiet    只列失败项
#
#  退出码：0 = 全绿，1 = 有失败项
#
#  ★ 一条重要教训（从旧仓继承）：光查"文件在不在"会漏报。
#    旧仓的 bin/tablet-mode 装了两份、两份都是旧版（仓库已改成按 VID/PID
#    搜索 Type Cover，装机那份还硬编码 USB 路径 1-7），而 doctor 只 test -x，
#    于是报"全绿"。所以本脚本对包管文件一律用 cmp -s 比对【内容】。
# ============================================================================
set -uo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAILED=0
QUIET=0
[ "${1:-}" = "--quiet" ] && QUIET=1

# ★ 从 ssh / 定时任务里跑时，HYPRLAND_INSTANCE_SIGNATURE 和 WAYLAND_DISPLAY
#   都不在环境里，于是所有 hyprctl 调用都会失败、报出"插件没加载""触摸没绑定"
#   之类的假故障。这里自己补上。
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && [ -d "$XDG_RUNTIME_DIR/hypr" ]; then
    HYPRLAND_INSTANCE_SIGNATURE="$(ls -t "$XDG_RUNTIME_DIR/hypr/" 2>/dev/null | head -1)"
    export HYPRLAND_INSTANCE_SIGNATURE
fi
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"

RED=$'\033[31m'; GRN=$'\033[32m'; YEL=$'\033[33m'; DIM=$'\033[2m'; RST=$'\033[0m'
ok()   { [ $QUIET -eq 1 ] || printf '%s✓%s %s\n' "$GRN" "$RST" "$*"; }
bad()  { printf '%s✗%s %s\n' "$RED" "$RST" "$*"; FAILED=1; }
warn() { [ $QUIET -eq 1 ] || printf '%s!%s %s\n' "$YEL" "$RST" "$*"; }
inf()  { [ $QUIET -eq 1 ] || printf '  %s%s%s\n' "$DIM" "$*" "$RST"; }
head_(){ [ $QUIET -eq 1 ] || printf '\n%s── %s %s\n' "$DIM" "$*" "$RST"; }
check(){ local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi; }

HYPR_DIR="$HOME/.config/hypr"
FLAG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/surface-config"
FLAG="$FLAG_DIR/tablet.flag"

# ── 0. 包管文件内容比对 ─────────────────────────────────────────────────────
# 只列出【不一致】的：一致就静默（86 个文件全列出来没人看）。
head_ "包管文件（与仓库比对内容）"
DRIFT=0
while read -r rel sys; do
    [ -z "${rel:-}" ] && continue
    case "$rel" in \#*) continue ;; esac
    d="$(eval echo "$sys")"
    if [ ! -e "$d" ]; then
        bad "缺文件：$d（装：./install.sh）"; continue
    fi
    # ★ 例外：noctalia 的 settings.toml 是【运行时状态】，noctalia 自己一直在写它
    #   （窗口位置、锁屏组件坐标之类）。刚同步完它就可能又变了，所以只查存在、
    #   不比对内容。想把它固化进仓库时，手工 cp 一次即可。
    case "$d" in
        */noctalia/settings.toml) continue ;;
    esac
    if [ -e "$SRC/$rel" ] && ! cmp -s "$SRC/$rel" "$d"; then
        bad "内容不一致：$d"
        inf "$(diff "$SRC/$rel" "$d" 2>/dev/null | head -4 | sed 's/^/      /')"
        DRIFT=1
    fi
done < "$SRC/manifest.map"
[ $DRIFT -eq 0 ] && ok "全部与仓库一致"

# ── 1. 硬件与内核 ───────────────────────────────────────────────────────────
head_ "硬件与内核"
if [[ "$(uname -r)" == *surface* ]]; then ok "运行的是 linux-surface 内核（$(uname -r)）"
else warn "当前内核不是 linux-surface：$(uname -r)（触屏可能整个不工作）"; fi

check "linux-surface 已装"  pacman -Qq linux-surface
check "iptsd 已装"          pacman -Qq iptsd
check "iio-sensor-proxy 已装" pacman -Qq iio-sensor-proxy
check "iio-hyprland 已装"   pacman -Qq iio-hyprland-git

# ── 2. 触屏链路 ─────────────────────────────────────────────────────────────
head_ "触屏链路"

# iptsd 进程活着 ≠ 它在干活。旧仓踩过：进程在、设备在，但一个事件都不产出
# （iptsd 3.1.0 的阻塞 read() 被信号打断后挂住）。所以查两件事：
# 进程在不在、以及触摸设备有没有真的被识别出来。
#
# ★ 服务实例名不能写死 iptsd@dev-hidraw1：hidraw 编号按枚举顺序分配，
#   冷启动后触屏可能变成 hidraw0（2026-09-27 强制关机后就是这样，
#   另一个 hidraw 给了 hid-ishtp 传感器集线器）。按 HID_NAME 找真正的触屏节点。
IPTS_HID=""
for h in /sys/class/hidraw/hidraw*; do
    grep -q '^HID_NAME=IPTS ' "$h/device/uevent" 2>/dev/null && { IPTS_HID="$(basename "$h")"; break; }
done
IPTSD_UNIT="iptsd@dev-${IPTS_HID:-hidraw1}.service"
[ -n "$IPTS_HID" ] && inf "触屏 hidraw 节点：/dev/$IPTS_HID（服务 $IPTSD_UNIT）"

if pgrep -x iptsd >/dev/null 2>&1; then ok "iptsd 在跑"
else bad "iptsd 没跑 → sudo systemctl restart '$IPTSD_UNIT'"; fi

EV="$(grep -l 'IPTSD Virtual Touchscreen' /sys/class/input/event*/device/name 2>/dev/null \
      | sed -E 's|.*/(event[0-9]+)/.*|\1|' | head -1)"
if [ -n "$EV" ]; then
    ok "触摸设备节点：/dev/input/$EV"
    # 内核给的原始 IPTS 节点应该被 udev 规则禁掉，否则触摸会被上报两次
    if udevadm info "/dev/input/$EV" 2>/dev/null | grep -q 'ID_INPUT_TOUCHSCREEN=1'; then
        ok "虚拟触摸屏的 udev 属性正常"
    fi
    RAW="$(udevadm info --query=property --name="/dev/input/$EV" 2>/dev/null | grep -c LIBINPUT_IGNORE_DEVICE=1 || true)"
    :
else
    bad "没找到 IPTSD 虚拟触摸屏 → 触屏不能用了，先看 iptsd 服务日志"
fi

# 内核给的原始节点应当被禁（否则同一次触摸上报两遍，见 docs/07 坑 A）。
# ★ 找的是 /dev/input/eventNN，不是 /sys/class/input/inputN —— 后者不是设备节点。
RAW_FOUND=0
for n in /sys/class/input/event*/device/name; do
    [ -f "$n" ] || continue
    [ "$(cat "$n" 2>/dev/null)" = "IPTS 045E:001F Touchscreen" ] || continue
    RAW_FOUND=1
    d="/dev/input/$(basename "$(dirname "$(dirname "$n")")")"
    if udevadm info "$d" 2>/dev/null | grep -q 'LIBINPUT_IGNORE_DEVICE=1'; then
        ok "原始 IPTS 节点 $d 已被 udev 禁用（不会重复上报）"
    else
        bad "原始 IPTS 节点 $d 没被禁用 → 触摸会上报两遍；装 udev/71-*.rules 并 reload"
    fi
done
[ $RAW_FOUND -eq 0 ] && ok "没有多余的原始 IPTS 输入节点"

check "iptsd 自愈补丁已装" test -f /etc/systemd/system/iptsd@.service.d/override.conf
if [ -f /etc/systemd/system/iptsd@.service.d/override.conf ]; then
    if grep -q 'Restart=always' /etc/systemd/system/iptsd@.service.d/override.conf; then
        ok "  └ 里面有 Restart=always"
    else
        bad "  └ 补丁里没有 Restart=always"
    fi
fi

check "忽略原始触屏的 udev 规则与仓库一致" \
    cmp -s "$SRC/udev/71-surface-ipts-ignore-raw.rules" /etc/udev/rules.d/71-surface-ipts-ignore-raw.rules

# 开机自动登录（登录界面没有虚拟键盘，见 docs/03）。没装只是警告：接着 Type Cover 能输密码。
if sed "s/@USER@/$USER/" "$SRC/setup/greetd/config.toml" | cmp -s - /etc/greetd/config.toml; then
    ok "greetd 开机自动登录已装"
elif grep -q '^\[initial_session\]' /etc/greetd/config.toml 2>/dev/null; then
    warn "greetd 有自动登录，但与 setup/greetd/config.toml 不一致"
else
    warn "greetd 没配自动登录 → 摘掉 Type Cover 开机时输不了密码（./install.sh system 第 6 条）"
fi

# 打过"粘滞极大值"补丁的 iptsd（修单指划动断触，见 docs/08、setup/03）。
# 没装只是警告：系统包原版照样能用，只是划动会断。
# ★ 看的是【正在跑的进程】的命令行，不是 drop-in 在不在 —— drop-in 装了
#   但没 daemon-reload / restart，跑的仍是原版，只查文件会误报绿。
# ★ 读 cmdline 不读 /proc/PID/exe：iptsd 以 root 跑，普通用户 readlink 它的 exe
#   会被拒（返回空），而 cmdline 谁都能读。
PATCHED_DROPIN=/etc/systemd/system/iptsd@.service.d/10-patched.conf
ipid="$(systemctl show "$IPTSD_UNIT" -p MainPID --value 2>/dev/null)"
running="$(tr '\0' ' ' < "/proc/${ipid:-0}/cmdline" 2>/dev/null | awk '{print $1}')"
if [ "$running" = /usr/local/bin/iptsd ]; then
    ok "iptsd 跑的是补丁版（/usr/local/bin/iptsd）"
    # 补丁是对着某个版本做的。pacman 把系统包升级了而补丁版没重编，
    # 就是新配置 + 旧程序，行为说不清 —— 提醒重跑 setup/03。
    pkgver="$(pacman -Q iptsd 2>/dev/null | awk '{print $2}' | cut -d- -f1)"
    [ "$pkgver" = "3.1.0" ] || warn "  └ 系统包 iptsd 已是 $pkgver，补丁版还是 3.1.0 → 重跑 ./setup/03-iptsd-patched.sh"
elif [ -f "$PATCHED_DROPIN" ]; then
    bad "补丁版 drop-in 已装但跑的还是 ${running:-?} → sudo systemctl daemon-reload && sudo systemctl restart '$IPTSD_UNIT'"
else
    warn "iptsd 跑的是系统包原版 → 单指划动会断；修：./setup/03-iptsd-patched.sh"
fi

# ── 3. hyprgrass 插件 ───────────────────────────────────────────────────────
head_ "hyprgrass 触屏手势插件"
if pgrep -x Hyprland >/dev/null 2>&1; then
    if hyprctl plugin list 2>/dev/null | grep -qi hyprgrass; then
        ok "hyprgrass 已加载"
        sens="$(hyprctl getoption plugin:hyprgrass:sensitivity 2>/dev/null | awk '/float:/{print $2}')"
        if [ -n "$sens" ]; then
            case "$sens" in 4.0*) ok "sensitivity = $sens（touch.lua 已生效）" ;;
                *) bad "sensitivity = $sens（应为 4.0）→ touch.lua 没被加载" ;; esac
        fi
        lp="$(hyprctl getoption plugin:hyprgrass:long_press_delay 2>/dev/null | awk '/int:/{print $2}')"
        [ -n "$lp" ] && ok "long_press_delay = $lp"
    else
        bad "hyprgrass 没加载 → hyprpm list 看状态，可能需要 hyprpm update && hyprpm reload"
    fi
    if [ -z "$(hyprctl configerrors 2>/dev/null)" ]; then ok "Hyprland 配置无报错"
    else bad "Hyprland 配置有报错："; hyprctl configerrors 2>/dev/null | head -5 | sed 's/^/      /'; fi

    # 触屏设备有没有被合成器认出来
    if hyprctl devices 2>/dev/null | grep -q 'iptsd-virtual-touchscreen'; then
        ok "合成器已绑定触摸设备"
    else
        bad "合成器没绑定触摸设备 → 触屏点不动（hyprctl devices 里应有 iptsd-virtual-touchscreen）"
    fi
else
    warn "Hyprland 没在跑，跳过插件与合成器检查"
fi

# ── 4. 自动旋转 ─────────────────────────────────────────────────────────────
head_ "自动旋转"
check "iio-hyprland.service 已装" test -f "$HOME/.config/systemd/user/iio-hyprland.service"
if systemctl --user is-enabled iio-hyprland.service >/dev/null 2>&1; then
    ok "iio-hyprland.service 已启用"
    systemctl --user is-active iio-hyprland.service >/dev/null 2>&1 \
        && ok "  └ 正在运行" || bad "  └ 已启用但没在跑（开机偶发不旋转就是这个）"
else
    warn "iio-hyprland.service 未启用 → systemctl --user enable --now iio-hyprland.service"
fi
if busctl --system list 2>/dev/null | grep -q net.hadess.SensorProxy; then
    ok "iio-sensor-proxy 在 D-Bus 上"
else
    bad "iio-sensor-proxy 不在 D-Bus 上 → 不会旋转"
fi

# ── 5. 平板模式 ─────────────────────────────────────────────────────────────
head_ "平板模式"
if [ -f "$FLAG" ]; then ok "当前是【平板模式】（$FLAG 存在）"
else ok "当前是【PC 模式】（无标记文件）"; fi

check "tablet-mode 已装（~/.local/bin）"   test -x "$HOME/.local/bin/tablet-mode"
check "tablet-rescue 已装（~/.local/bin）" test -x "$HOME/.local/bin/tablet-rescue"
# ★ 比对内容。只查存在性时，旧版 RUN+="systemd-run --user" 那条规则 3 天里
#   失败 15 次、一次都没切成功，doctor 照样报绿。
if cmp -s "$SRC/udev/70-surface-tablet-mode.rules" /etc/udev/rules.d/70-surface-tablet-mode.rules; then
    ok "udev 平板模式规则与仓库一致"
else
    bad "udev 平板模式规则没装或是旧版 → Type Cover 插拔不会自动切模式"
    inf "  修：sudo install -m644 $SRC/udev/70-surface-tablet-mode.rules /etc/udev/rules.d/"
    inf "      sudo udevadm control --reload-rules"
    inf "      sudo udevadm trigger --action=add --attr-match=idVendor=045e --attr-match=idProduct=09c0"
fi

# ★ Hyprland 的 Lua 调的是 /usr/local/bin 那个路径（它的 PATH 里没有 ~/.local/bin）。
#   可以是软链，但必须【能执行】—— 旧仓这里只查存在性，结果装了份旧文件也报绿。
for b in tablet-mode tablet-rescue; do
    if [ -x "/usr/local/bin/$b" ]; then
        src="$(readlink -f "/usr/local/bin/$b")"
        if cmp -s "$HOME/.local/bin/$b" "$src"; then ok "/usr/local/bin/$b（udev 用的那份）与仓库一致"
        else bad "/usr/local/bin/$b 指向的 $src 与 ~/.local/bin/$b 不一致 → 重跑 install.sh tablet，再按提示 sudo install"; fi
    else
        bad "/usr/local/bin/$b 不可执行 → 手势和 ALT+M 调不到它"
        inf "  修：sudo install -m755 ~/.local/bin/$b /usr/local/bin/$b"
    fi
done

# surface-ctl：顶栏按钮、锁屏 hook、空闲熄屏都调 /usr/local/bin 这份（noctalia 的
# PATH 里没有 ~/.local/bin）。软链即可，指向 ~/.local/bin 就永远一致。
if [ -x /usr/local/bin/surface-ctl ]; then
    if cmp -s "$HOME/.local/bin/surface-ctl" "$(readlink -f /usr/local/bin/surface-ctl)"; then
        ok "/usr/local/bin/surface-ctl（顶栏按钮用）与仓库一致"
    else
        bad "/usr/local/bin/surface-ctl 与 ~/.local/bin/surface-ctl 不一致"
    fi
else
    bad "/usr/local/bin/surface-ctl 不存在 → 顶栏的旋转/锁屏按钮、锁屏键盘、空闲熄屏都不工作"
    inf "  修：sudo ln -sf ~/.local/bin/surface-ctl /usr/local/bin/surface-ctl"
fi

# Type Cover 检测：和 tablet-mode 同一套 VID/PID 逻辑
COVER_VID="${SURFACE_COVER_VID:-045e}"
COVER_PID="${SURFACE_COVER_PID:-09c0}"
cover=""
for d in /sys/bus/usb/devices/*/; do
    [ -f "$d/idVendor" ] || continue
    if [ "$(cat "$d/idVendor")" = "$COVER_VID" ] && [ "$(cat "$d/idProduct")" = "$COVER_PID" ]; then
        cover="$d"; break
    fi
done
if [ -n "$cover" ]; then inf "Type Cover 已接上（$cover）"
else inf "Type Cover 没接（纯平板形态）"; fi

# 自动切换链路是否真的通：Cover 接着时 udev 应该已经把它交给 systemd，
# 并拉起了 surface-typecover.service。规则装对了但这里不通，说明链路断在
# udev → systemd 之间（比如装完规则没 trigger，要拔插一次）。
if [ -n "$cover" ]; then
    if [ "$(systemctl --user is-active surface-typecover.service 2>/dev/null)" = "active" ]; then
        ok "surface-typecover.service 在跑（插拔会自动切模式）"
    else
        bad "Type Cover 接着，但 surface-typecover.service 没被拉起 → 插拔不会自动切模式"
        inf "  看：systemctl --user status dev-typecover.device surface-typecover.service"
    fi
fi

# 模式与 Cover 对不上：可能是手动 ALT+M 切的（正常），也可能是自动切换没工作。
# 只警告，不算失败。
if [ -n "$cover" ] && [ -f "$FLAG" ]; then
    warn "Type Cover 接着，但处于平板模式（手动切的就没事）"
elif [ -z "$cover" ] && [ ! -f "$FLAG" ]; then
    warn "Type Cover 没接，但处于 PC 模式（手动切的就没事）"
fi

# ── 6. 虚拟键盘 ─────────────────────────────────────────────────────────────
head_ "虚拟键盘"
check "wvkbd 已装"              pacman -Qq wvkbd-deskintl
check "wvkbd-toggle 已装"       test -x "$HOME/.local/bin/wvkbd-toggle"
check "fcitx 适配器配置存在"    test -f "$HOME/.config/fcitx5/conf/virtualkeyboardadapter.conf"
check "fcitx 适配器 .so 已装"   test -f /usr/lib/fcitx5/libvirtualkeyboardadapter.so
if pgrep -x fcitx5 >/dev/null 2>&1; then ok "fcitx5 在跑"; else warn "fcitx5 没跑"; fi

# 适配器配置里的路径必须存在，否则虚拟键盘静默不弹（绝对路径的坑，见 docs/07）
ADP="$HOME/.config/fcitx5/conf/virtualkeyboardadapter.conf"
if [ -f "$ADP" ]; then
    miss=0
    while read -r p; do
        [ -n "$p" ] && [ ! -x "$p" ] && { bad "适配器配置里的命令不存在：$p"; miss=1; }
    done < <(grep -oE '/[^ "]+/(wvkbd-toggle|tablet-mode)' "$ADP" 2>/dev/null | sort -u)
    [ $miss -eq 0 ] && ok "适配器配置里的命令都存在"
fi

# ── 7. 屏幕 ─────────────────────────────────────────────────────────────────
head_ "屏幕与旋转"
if pgrep -x Hyprland >/dev/null 2>&1; then
    mons="$(hyprctl monitors -j 2>/dev/null | jq 'length' 2>/dev/null || echo 0)"
    [ "$mons" = "1" ] && ok "单显示器（eDP-1）" || warn "检测到 $mons 个显示器"
    hyprctl monitors 2>/dev/null | grep -E 'transform|scale:' | sed 's/^/  /'
fi

# ── 汇总 ────────────────────────────────────────────────────────────────────
printf '\n'
if [ $FAILED -eq 0 ]; then
    printf '%s全绿%s\n' "$GRN" "$RST"
else
    printf '%s有失败项（上面带 ✗ 的）%s\n' "$RED" "$RST"
fi
exit $FAILED
