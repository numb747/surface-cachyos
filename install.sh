#!/usr/bin/env bash
# ============================================================================
#  Surface Pro 6 · CachyOS/Hyprland 平板配置安装器
#
#  用法：
#      ./install.sh                  装全部模块
#      ./install.sh hypr tablet      只装指定模块
#      ./install.sh --list           列出模块
#      ./install.sh --dry-run        只打印会做什么，不动任何文件
#
#  性质：
#      幂等      —— 重复执行结果一致，不会重复追加、不会叠加备份
#      先备份    —— 每个被覆盖的已有文件都存成 <名字>.bak-YYYYmmdd-HHMMSS
#      不碰系统  —— 只写 $HOME 下的文件；需要 sudo 的项在 system 模块里
#                   打印命令让你自己跑
#
#  ★ 与旧的 cachyOS-config + surface-config 两仓模式的区别：
#    那边是"主仓拥有文件、适配层往里面注入挂钩"，并且每次 sync.sh --pull
#    之后要重跑一次 ./install.sh hook 把挂钩插回去。
#    本仓是【独立完整】的一份配置，直接拥有 hyprland.lua / autostart.lua，
#    没有"被覆盖"这回事，所以没有 hook 模块、也没有注入机制。
# ============================================================================
set -uo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
DRY=0
FAILED=0

RED=$'\033[31m'; GRN=$'\033[32m'; YEL=$'\033[33m'; DIM=$'\033[2m'; RST=$'\033[0m'
ok()   { printf '%s✓%s %s\n' "$GRN" "$RST" "$*"; }
inf()  { printf '  %s%s%s\n' "$DIM" "$*" "$RST"; }
warn() { printf '%s!%s %s\n' "$YEL" "$RST" "$*"; }
err()  { printf '%s✗%s %s\n' "$RED" "$RST" "$*" >&2; FAILED=1; }
head_(){ printf '\n%s── %s %s\n' "$DIM" "$*" "$RST"; }

# ── 打包机 HOME 的改写 ──────────────────────────────────────────────────────
# 包里有些路径**没法用 $HOME 表达**，因为它们所在格式不做变量展开：
#   ~/.config/noctalia/config.toml        [storage] key_file
#   ~/.local/state/noctalia/settings.toml [wallpaper.*] path
#   ~/.config/fcitx5/conf/virtualkeyboardadapter.conf  ActivateCmd/DeactivateCmd
#   ~/.config/qt6ct/qt6ct.conf            只有 $USER 字面量，没有 $HOME
# 不改写就全是【静默失效】，而且症状都不指向路径：
#   密钥读不到 → 剪贴板历史不持久化
#   壁纸路径不存在 → 退回默认壁纸
#   适配器 Exec 找不到 → 虚拟键盘不弹
# ★ 两个占位符，不是一个。
#   本仓的文件来自两处：从 cachyOS-config 搬来的那些里面是打【包机】david 的
#   家目录；本仓新写/改过的里面是 charlen。所以两个都得换。
#
# ★ 不要再用 [ "$HOME" = "$PKG_HOME" ] && return 0 短路 —— 这正是本次踩的坑：
#   打包占位符恰好就是本机用户（charlen），短路之后包里那些写着 /home/david
#   的路径【一个都没被改写】。而 /home/david 不存在，症状是：
#     noctalia key_file 读不到  → 剪贴板历史重启即丢（日志里只有
#                                 [secret-store] provider-unavailable，不指向路径）
#     settings.toml 壁纸路径不存在 → 退回默认壁纸
#     .zshrc 里 hacktools 别名指向空目录
#   没有报错，全都静默。
PKG_HOMES=( "/home/david" "/home/charlen" )
rewrite_home() {
    local ph hit=0
    if [ $DRY -eq 1 ]; then
        for ph in "${PKG_HOMES[@]}"; do
            [ "$ph" = "$HOME" ] && continue
            grep -q "$ph" "$1" 2>/dev/null && \
                printf '  [dry] 改写 %s 里的 %s → %s\n' "$1" "$ph" "$HOME"
        done
        return 0
    fi
    [ -f "$1" ] || return 0
    for ph in "${PKG_HOMES[@]}"; do
        [ "$ph" = "$HOME" ] && continue        # 已经是对的，别做无谓的 sed
        grep -q "$ph" "$1" 2>/dev/null || continue
        sed -i "s#$ph#$HOME#g" "$1" && hit=1
    done
    [ $hit -eq 1 ] && inf "路径已改写到 \$HOME：$(basename "$1")"
    return 0
}

# put <相对源路径> <目标绝对路径>
put() {
    local s="$SRC/$1" d="$2"
    [ -e "$s" ] || { err "包内缺文件：$1"; return 1; }
    if [ $DRY -eq 1 ]; then
        printf '  [dry] %s → %s%s\n' "$1" "$d" "$([ -e "$d" ] && echo '  (会先备份)')"
        return 0
    fi
    mkdir -p "$(dirname "$d")" || { err "建不了目录：$(dirname "$d")"; return 1; }
    if [ -e "$d" ]; then
        if cmp -s "$s" "$d"; then inf "$d 已是最新，跳过"; return 0; fi
        cp -a "$d" "$d.bak-$STAMP" || { err "备份失败，跳过不覆盖：$d"; return 1; }
        inf "备份 → $(basename "$d").bak-$STAMP"
    fi
    cp -a "$s" "$d" || { err "写入失败：$d"; return 1; }
    rewrite_home "$d"
    ok "$d"
}

# ── 解析 manifest.map ───────────────────────────────────────────────────────
# 读法：以 #@module 分组，`<包内路径> <系统路径>` 两列。
#   read -r rel sys 会把 `#@module hypr` 切成 rel='#@module' sys='hypr'，
#   所以判 "$rel" = "#@module" 就是在切模块。
#
# ★ 这是从 cachyOS-config 的 install.sh 移植的机制。旧的 surface-config
#   里也有一份 manifest.map，但【没有任何脚本读它】—— 路径全硬编码在脚本里，
#   于是 manifest 只是文档，会静默漂移（tablet-mode 就这么漂了）。
put_module() {
    local want="$1" cur="" rel sys
    while read -r rel sys; do
        [ -z "${rel:-}" ] && continue
        case "$rel" in \#*)
            [ "$rel" = "#@module" ] && cur="$sys"
            continue ;;
        esac
        [ "$cur" = "$want" ] || continue
        put "$rel" "$(eval echo "$sys")"
    done < "$SRC/manifest.map"
}

# ── 模块 ────────────────────────────────────────────────────────────────────

mod_hypr() {
    head_ "hypr — Hyprland 入口、触屏手势、键位"
    put_module hypr
}

mod_tablet() {
    head_ "tablet — 平板模式开关与救援键"
    put_module tablet

    # udev 的 RUN 以 root 跑、环境最小，用不了 ~，所以 /usr/local/bin 里
    # 必须有一份【真文件】（不是软链）。install.sh 只写 $HOME，这一步要 sudo，
    # 所以只打印命令。
    cat <<'EOS'

  ★ 下面这条要 sudo，请自己跑（install.sh 不代跑）：
      sudo install -m755 ~/.local/bin/tablet-mode   /usr/local/bin/tablet-mode
      sudo install -m755 ~/.local/bin/tablet-rescue /usr/local/bin/tablet-rescue
      sudo ln -sf ~/.local/bin/surface-ctl /usr/local/bin/surface-ctl
EOS
}

mod_osk() {
    head_ "osk — 虚拟键盘"
    put_module osk

    # wvkbd-toggle 也要一份在 /usr/local/bin：旧模式下 Hyprland 的 PATH
    # 里没有 ~/.local/bin，裸命令名会静默失败（见 docs/07 坑 B）。
    # 本仓的 touch.lua 已经统一改用绝对路径，这份软链是给手敲和兜底用的。
    cat <<'EOS'

  ★ 要 sudo，请自己跑：
      sudo ln -sf ~/.local/bin/wvkbd-toggle /usr/local/bin/wvkbd-toggle

  fcitx 适配器本体（不在本仓，需自行编译安装）：
      cd ~/build/fcitx-virtualkeyboard-adapter && sudo cmake --install build
EOS
}

mod_sensor() {
    head_ "sensor — 自动旋转"
    put_module sensor

    cat <<'EOS'

  ★ 装完启用（用户级单元，不需 sudo）：
      systemctl --user daemon-reload
      systemctl --user enable --now iio-hyprland.service
      systemctl --user status iio-hyprland.service --no-pager
EOS
}

mod_ui()   { head_ "ui — noctalia、主题、输入法、字体"; put_module ui; }
mod_apps() { head_ "apps — 默认打开方式"; put_module apps; }
mod_wall() { head_ "wall — 壁纸库脚本"; put_module wall; }
mod_ocr()  {
    head_ "ocr — 屏幕取字"
    put_module ocr
    cat <<'EOS'

  ★ 启用常驻服务（用户级，不需 sudo）：
      systemctl --user daemon-reload
      systemctl --user enable --now ocrd.socket
EOS
}
mod_term() { head_ "term — kitty / alacritty / zsh"; put_module term; }

mod_system() {
    head_ "system — 需要 sudo 的部分（只打印，不代跑）"
    cat <<'EOS'

  以下全部要 sudo，install.sh 只负责把命令列出来。

  1) udev 规则（触屏 + 平板模式自动切换）
       sudo install -m644 ~/surface-cachyos/udev/70-surface-tablet-mode.rules /etc/udev/rules.d/
       sudo install -m644 ~/surface-cachyos/udev/71-surface-ipts-ignore-raw.rules /etc/udev/rules.d/
       sudo udevadm control --reload-rules
       sudo udevadm trigger --subsystem-match=input
     ★ trigger 默认是 --action=change，匹配不到 71 里的 ACTION=="add|change"
       之外的部分；触屏相关用上面这条即可。

  2) iptsd 自愈（上游 Restart=no + 3.1.0 的 EINTR 缺陷会让触屏整个消失）
       sudo install -Dm644 ~/surface-cachyos/systemd/iptsd@.service.d/override.conf \
            /etc/systemd/system/iptsd@.service.d/override.conf
       sudo systemctl daemon-reload
       sudo systemctl restart 'iptsd@*.service'    # hidraw 编号会变，用通配

  2b) iptsd 补丁版（修单指划动断触；先编译，编完它会打印安装命令）
       ~/surface-cachyos/setup/03-iptsd-patched.sh           # 不需要 sudo

  3) /usr/local/bin 的两份真文件（udev 的 RUN 要用，见 tablet 模块）
       sudo install -m755 ~/.local/bin/tablet-mode   /usr/local/bin/tablet-mode
       sudo install -m755 ~/.local/bin/tablet-rescue /usr/local/bin/tablet-rescue
       sudo ln -sf ~/.local/bin/surface-ctl /usr/local/bin/surface-ctl   # 顶栏按钮用，软链即可

  4) 内核与传感器栈
       ~/surface-cachyos/setup/01-surface-kernel.sh          # 打印命令；加 --run 才执行

  5) hyprgrass 插件
       ~/surface-cachyos/setup/02-hyprgrass.sh               # ★ 必须手敲，见该脚本头部

  6) 开机自动登录（摘掉 Type Cover 时登录界面没有虚拟键盘，见 docs/03）
       sudo cp -a /etc/greetd/config.toml /etc/greetd/config.toml.bak-$(date +%Y%m%d-%H%M%S)
       sed "s/@USER@/$USER/" ~/surface-cachyos/setup/greetd/config.toml \
           | sudo tee /etc/greetd/config.toml >/dev/null
     下次开机生效，不用重启 greetd（重启它会立刻结束当前桌面会话）。
EOS
}

mod_list() {
    printf '\n模块：\n'
    printf '  %-8s %s\n' hypr   "Hyprland 入口、触屏手势、键位"
    printf '  %-8s %s\n' tablet "平板模式开关与救援键（+ udev 命令）"
    printf '  %-8s %s\n' osk    "虚拟键盘"
    printf '  %-8s %s\n' sensor "自动旋转"
    printf '  %-8s %s\n' ui     "noctalia、GTK/Qt/btop 主题、输入法、字体"
    printf '  %-8s %s\n' apps   "默认打开方式（imv / mpv）"
    printf '  %-8s %s\n' wall   "壁纸库脚本"
    printf '  %-8s %s\n' ocr    "屏幕取字（RapidOCR 常驻服务）"
    printf '  %-8s %s\n' term   "kitty / alacritty / zsh / powerlevel10k"
    printf '  %-8s %s\n' system "需要 sudo 的全部内容（只打印命令）"
    printf '\n不装：nvim、wine、cc（本仓有意不搬）\n'
    printf '不加参数 = 装【除 system 外】的全部模块\n\n'
}

# ── 入口 ────────────────────────────────────────────────────────────────────
ALL=(hypr tablet osk sensor ui apps wall ocr term)
SELECTED=()

for a in "$@"; do
    case "$a" in
        --list|-l) mod_list; exit 0 ;;
        --dry-run) DRY=1 ;;
        -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) SELECTED+=("$a") ;;
    esac
done

for m in "${SELECTED[@]:-}"; do
    [ -z "$m" ] && continue
    case "$m" in
        hypr|tablet|osk|sensor|ui|apps|wall|ocr|term|system) ;;
        *) err "未知模块：$m（--list 看全部）"; exit 2 ;;
    esac
done

[ ${#SELECTED[@]} -eq 0 ] && SELECTED=("${ALL[@]}")

printf '%s\n' "Surface · CachyOS 平板配置$([ $DRY -eq 1 ] && echo '（dry-run）')"
inf "源：$SRC"

for m in "${SELECTED[@]}"; do "mod_$m"; done

printf '\n'
if [ $FAILED -eq 0 ]; then
    printf '%s全部完成%s\n' "$GRN" "$RST"
    inf "体检：./doctor.sh"
    inf "需要 sudo 的部分：./install.sh system"
else
    printf '%s有失败项，见上面的 ✗%s\n' "$RED" "$RST"
fi
exit $FAILED
