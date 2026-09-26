#!/usr/bin/env bash
# ============================================================================
#  装 hyprgrass 触屏手势插件
#
#  ★★ 这个脚本【不要用管道喂 stdin】，也【不要后台跑】。★★
#     原因见下，是真踩过的坑（在 charlen 的机器上花了半个多小时才定位）。
#
#  坑：hyprpm 的每个子命令结尾都会执行 sudo -k
#      （源码 hyprpm/src/helpers/Sys.cpp，CScopeGuard x([] { dropSudo(); })）
#      它会【作废整个 sudo 时间戳】。所以每条 hyprpm 命令都会重新问密码
#      —— 这本身是正常现象，不是出错。
#
#      但如果你写成 `yes | hyprpm add ...`，管道会顶替掉 stdin，
#      sudo 的认证会话就拿不到输入，pam_unix 报 "conversation failed"，
#      而 hyprpm 只会打印一个【完全误导】的：
#          [ERR] ✖ Failed to write plugin state
#      真正挂在 DataState.cpp:122 的 sudo install 那一步。
#
#      同理 `sudo -n true` 后台保活也没用：-n 绝不提示密码，
#      时间戳被 -k 清掉之后无法重建。
#
#  结论：在【真实终端】里逐条手敲，提示 Are you sure? [Y/n] 时手输 y，
#        要密码时手输。所以这个脚本只打印清单，不 --run。
# ============================================================================
set -uo pipefail

GRN=$'\033[32m'; YEL=$'\033[33m'; DIM=$'\033[2m'; RST=$'\033[0m'
ok()   { printf '%s✓%s %s\n' "$GRN" "$RST" "$*"; }
inf()  { printf '  %s%s%s\n' "$DIM" "$*" "$RST"; }
warn() { printf '%s!%s %s\n' "$YEL" "$RST" "$*"; }
head_(){ printf '\n%s── %s %s\n' "$DIM" "$*" "$RST"; }

head_ "为什么必须手敲"

cat <<'EOF'
  hyprpm 每条命令末尾跑 sudo -k，会清掉 sudo 时间戳。
  这是正常的，但它意味着：任何「非交互」的喂密码方式都会失败，
  并且失败信息长得像别的问题（Failed to write plugin state）。

  → 在真终端里逐条跑。看到 Are you sure? [Y/n] 敲 y。
EOF

head_ "命令清单（按顺序，逐条跑）"

cat <<'EOF'
    # 1) 装头文件。全新状态下【必须在前】——
    #    否则 add 会因为 main.cpp:115 的
    #    "Headers outdated, please run hyprpm update." 直接返回 1。
    hyprpm update

    # 2) 加仓库并从源码编译。
    #    不要用 AUR 的 hyprgrass-git：那个包停在 2025-08，而
    #    hyprpm.toml 里 pin 的是 8e605468，正是本机 Hyprland 0.56.2 的 commit。
    #    只有从这里编译才拿得到对得上的 ABI。
    hyprpm add https://github.com/horriblename/hyprgrass

    # 3) 启用
    hyprpm enable hyprgrass
    hyprpm reload -n
EOF

head_ "预期输出与验收"

cat <<'EOF'
  预期：hyprgrass 编译成功；
        hyprgrass-backlight / hyprgrass-pulse 编译【失败】——
        这是正常的，上游把它们的 build 步骤换成了 echo 1（标了 deprecated，
        改用 extras/ 里的 Lua 模块），失败不代表插件装坏了。
EOF

printf '\n'
inf "验收（三条都要过）："
inf "  hyprctl plugin list        # 应出现 hyprgrass by horriblename"
inf "  hyprctl configerrors       # 应为空"
inf "  hyprctl getoption plugin:hyprgrass:sensitivity   # 应为 4.0"
printf '\n'
warn "第三条返回 4.0 才是真过了 —— 插件加载 ≠ 配置生效。"
warn "若为 1.0，说明 touch.lua 没被 require，去跑 ./install.sh hook"
printf '\n'
inf "插件本体在 /var/cache/hyprpm/charlen/hyprgrass/，状态在同目录 state.toml。"
inf "插件日志走 LOG(Log::DEBUG)，要看得到得让 Hyprland 带 -v 启动。"
