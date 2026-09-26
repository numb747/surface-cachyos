#!/usr/bin/env bash
# ============================================================================
#  编译打过补丁的 iptsd，修"单指划动断触"
#
#      ./setup/03-iptsd-patched.sh           # 编译（不需要 sudo）+ 打印安装命令
#      ./setup/03-iptsd-patched.sh --verify  # 额外用录像离线对比补丁前后
#
#  ■ 修的是什么
#      iptsd 判定"这里有没有手指"分两步：先找热图里的局部极大值（要求 >
#      ActivationThreshold），再从极大值向外生长区域（只要求 > Deactivation-
#      Threshold）。滞回只做在了第二步。手指划动时指下峰值会周期性跌到阈值
#      下面一点点（实测 SP6：正常中位 ~61，断触那几帧 2/3 落在 32~40，阈值 40），
#      第一步直接失败 → 这一帧没有触点 → 发 UP → 下一帧峰值回来又 DOWN。
#      补丁让"上一帧有触点的位置附近"只需过 DeactivationThreshold 即可，
#      全新触点仍要过 ActivationThreshold。详见 docs/08。
#
#  ■ 为什么不用系统包
#      pacman 的 iptsd 是上游 v3.1.0 原样。补丁没进上游之前只能自己编。
#      装到 /usr/local/bin/iptsd，用 systemd drop-in 改 ExecStart 指过去 ——
#      【不覆盖】 /usr/bin/iptsd，pacman 升级互不干扰，删 drop-in 即回滚。
#
#  ■ 依赖
#      meson、gcc（base-devel 里有）。Eigen / CLI11 / GSL 系统没装也行，
#      meson 会用上游 subprojects/*.wrap 自动下载（需要联网，只第一次）。
# ============================================================================
set -uo pipefail

GRN=$'\033[32m'; YEL=$'\033[33m'; RED=$'\033[31m'; DIM=$'\033[2m'; RST=$'\033[0m'
ok()   { printf '%s✓%s %s\n' "$GRN" "$RST" "$*"; }
inf()  { printf '  %s%s%s\n' "$DIM" "$*" "$RST"; }
warn() { printf '%s!%s %s\n' "$YEL" "$RST" "$*"; }
die()  { printf '%s✗%s %s\n' "$RED" "$RST" "$*"; exit 1; }
head_(){ printf '\n%s── %s %s\n' "$DIM" "$*" "$RST"; }

HERE="$(cd "$(dirname "$0")" && pwd)"
PATCH="$HERE/iptsd/0001-sticky-maxima.patch"
# 与 pacman 装的版本保持一致；补丁是对着这个 tag 做的
TAG="v3.1.0"
BUILD="${XDG_CACHE_HOME:-$HOME/.cache}/surface-cachyos/iptsd"

VERIFY=0
[ "${1:-}" = "--verify" ] && VERIFY=1

command -v meson >/dev/null || die "缺 meson：sudo pacman -S --needed meson"
command -v g++   >/dev/null || die "缺编译器：sudo pacman -S --needed base-devel"
[ -f "$PATCH" ] || die "找不到补丁 $PATCH"

head_ "取源码（$TAG）"
if [ ! -d "$BUILD/src/.git" ]; then
    mkdir -p "$BUILD"
    git -c advice.detachedHead=false clone -q --branch "$TAG" --depth 1 https://github.com/linux-surface/iptsd "$BUILD/src" \
        || die "clone 失败"
fi
cd "$BUILD/src"
git checkout -q -- . && git clean -qfd -e subprojects/ -e build*/
ok "源码就绪：$BUILD/src"

head_ "打补丁"
git apply --check "$PATCH" || die "补丁打不上（上游 tag 变了？）"
git apply "$PATCH"
ok "$(basename "$PATCH")"

head_ "编译"
if [ ! -d build ]; then
    # ★ --prefix=/usr --sysconfdir=/etc 不能省。
    #   iptsd 把配置搜索路径【编译进二进制】（设备配置 $prefix/share/iptsd/*.conf，
    #   用户配置 $sysconfdir/iptsd.conf 和 iptsd.d/）。meson 默认 prefix 是
    #   /usr/local，那样编出来的 iptsd 会去 /usr/local/share/iptsd 找设备配置 ——
    #   找不到 surface-pro-6.conf，屏幕尺寸为 0，直接报错退出，触屏整个没了。
    #   二进制本身照样装到 /usr/local/bin（见下面的 install 命令），只是路径
    #   要和系统包一致，读的是同一份配置。
    meson setup build --buildtype=release --prefix=/usr --sysconfdir=/etc \
        "-Dservice_manager=[]" -Ddebug_tools=perf -Dsample_config=false -Daccess_checks=false \
        >/dev/null 2>&1 || die "meson setup 失败（第一次需要联网下 subprojects）"
fi
nice ninja -C build src/iptsd src/iptsd-replay >/dev/null 2>&1 || die "编译失败"
ok "build/src/iptsd"
inf "$(build/src/iptsd --help 2>&1 | head -1)"

# 配置路径必须与系统包一致（见上面 meson setup 的注释），不一致就别往下装。
# 查 meson 生成的 configure.h 而不是 strings 二进制 —— release 编译下短字符串
# 会被内联成立即数，strings 看不全。
cfg=build/src/configure.h
grep -q '"/usr/share/iptsd"' "$cfg" && grep -q '"/etc/iptsd.conf"' "$cfg" && grep -q '"/etc/iptsd.d"' "$cfg" \
    || die "编出来的 iptsd 配置路径不对（$cfg）—— 删掉 $BUILD/src/build 重跑"
ok "配置搜索路径与系统包一致（/usr/share/iptsd、/etc/iptsd.conf、/etc/iptsd.d）"

if [ $VERIFY -eq 1 ]; then
    head_ "用录像离线对比（不碰系统）"
    DUMP="${DUMP:-$HOME/touch-test/baseline.bin}"
    if [ ! -f "$DUMP" ]; then
        warn "没有录像 $DUMP，跳过。录一份：sudo timeout -s INT 30 iptsd-dump /dev/\$(grep -l \"^HID_NAME=IPTS \" /sys/class/hidraw/*/device/uevent | cut -d/ -f5)"
    else
        # 与守护进程一样的配置级联：设备配置（去掉 [Device] 匹配段）+ /etc/iptsd.conf
        # + 本仓的 iptsd.d 补充 —— 这样回放结果才等于装好之后的实际效果
        conf="$BUILD/replay.conf"
        { grep -v '^\[Device\]\|^Vendor\|^Product' /usr/share/iptsd/surface-pro-6.conf
          cat /etc/iptsd.conf 2>/dev/null
          cat "$HERE/iptsd/10-surface-cachyos.conf"; } > "$conf"
        # 只把检测器那一个文件临时退回原版（回放工具本身也是补丁带进来的，不能一起退）
        det=src/contacts/detection/detector.hpp
        cp "$det" "$BUILD/detector.patched"
        git show "HEAD:$det" > "$det"
        ninja -C build src/iptsd-replay >/dev/null 2>&1 && cp build/src/iptsd-replay "$BUILD/replay-stock"
        cp "$BUILD/detector.patched" "$det"
        ninja -C build src/iptsd-replay >/dev/null 2>&1
        count() { grep -cE '^[0-9]+ DOWN ' "$1"; }
        IPTSD_CONFIG_FILE="$conf" "$BUILD/replay-stock"   "$DUMP" 2>/dev/null > "$BUILD/stock.txt"
        IPTSD_CONFIG_FILE="$conf" build/src/iptsd-replay "$DUMP" 2>/dev/null > "$BUILD/patched.txt"
        inf "落指次数（越少 = 断得越少；按住/点击的次数两边应一样）"
        inf "  原版：$(count "$BUILD/stock.txt")"
        inf "  补丁：$(count "$BUILD/patched.txt")"
    fi
fi

head_ "安装（要 sudo，自己跑）"
cat <<EOS

      sudo install -m755 $BUILD/src/build/src/iptsd /usr/local/bin/iptsd
      sudo install -Dm644 ~/surface-cachyos/setup/iptsd/10-surface-cachyos.conf \\
           /etc/iptsd.d/10-surface-cachyos.conf
      sudo install -Dm644 ~/surface-cachyos/systemd/iptsd@.service.d/10-patched.conf \\
           /etc/systemd/system/iptsd@.service.d/10-patched.conf
      sudo systemctl daemon-reload
      sudo systemctl restart 'iptsd@*.service'

  验证：
      systemctl show 'iptsd@*' -p ExecStart | grep -o /usr/local/bin/iptsd

  回滚（回到系统包的原版）：
      sudo rm /etc/systemd/system/iptsd@.service.d/10-patched.conf
      # /etc/iptsd.d/10-surface-cachyos.conf 对原版没有影响，留着也行
      sudo systemctl daemon-reload && sudo systemctl restart 'iptsd@*.service'
EOS
