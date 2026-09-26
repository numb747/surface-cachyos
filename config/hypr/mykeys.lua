-- ============================================================================
--  mykeys.lua —— Surface 平板形态的个人 Hyprland 配置
-- ----------------------------------------------------------------------------
--  这是 PC 版 mykeys.lua（972 行）精简而来。原版是给台机/笔记本写的，
--  核心设计是「双平面抽屉架 + 全键盘导航」，在触屏平板上大部分用不到 ——
--  而且有一整个模块（第 6 节"鼠标指针管理"）建立在「指针下 = 焦点窗口」
--  这个不变式上，触屏根本没有常驻指针，那套逻辑在平板上是无意义的。
--
--  删掉的部分（想恢复就从 ~/cachyOS-config/config/hypr/mykeys.lua 抄）：
--    §1b  双平面骨架（rack）          —— 抽屉架导航，纯键盘操作
--    §2/4/4b/4c  CTRL+ALT+HJKL、ALT+[/]、CTRL+2/3 等导航和弦
--    §5   分屏终端（ALT+\）            —— 平板不这么用
--    §6   鼠标指针管理                 —— 触屏无常驻指针，不变式不成立
--    §10  抽屉架（rack）实现体         —— 同 §1b
--    §11  Caps Lock 当 Esc             —— 纯物理键盘需求
--    §16  窗口分组                     —— 键盘操作，触屏上有更好方式
--
--  保留的部分与理由：
--    · noctalia 面板调用 —— 平板上的主要 UI 入口，触屏和键盘都走它们
--    · OCR 取字 —— 平板上没有键盘，手写笔圈选取字比敲快捷键实际
--    · 截图 / 录屏 —— 同一类操作，触屏上通过 noctalia 面板也能触发
--    · 毛玻璃 —— 纯外观，与输入方式无关
--    · 硬件键（音量/亮度/媒体）—— Surface 侧边有实体键、Type Cover 上有
--
--  原理备忘：hl.bind 对同一键位是「叠加」不是「覆盖」，所以要替换官方键位
--  必须先 hl.unbind("键位字符串")。unbind 不存在的键位不会报错，幂等安全。
--  适用：Hyprland >= 0.56（Lua 配置）+ cachyos-hypr-noctalia
-- ============================================================================

local noctCall = "noctalia msg "


-- ────────────────────────────────────────────────────────────────────────────
--  1. 毛玻璃（终端背景模糊）
--
--     kitty 的 background_blur 要求合成器实现 KDE blur 扩展协议，
--     Hyprland 走的是自己的 decoration:blur。这里打开它。
--     hl.config 逐项合并，只写 blur 不会冲掉它的 rounding / *_opacity。
--
--     验证用的是 `hyprctl getoption decoration:blur:<键>` 的 set: true ——
--     set: false 说明读到的是默认值，配置没生效。
-- ────────────────────────────────────────────────────────────────────────────
hl.config({
    decoration = {
        blur = {
            enabled = true,
            size = 6,
            passes = 3,
            new_optimizations = true,
            xray = false,
            noise = 0.02,
            contrast = 0.9,
            brightness = 0.85,
            popups = true,
        },
    },
})


-- ────────────────────────────────────────────────────────────────────────────
--  2. 屏幕取字（OCR）：SUPER + SHIFT + O 框选 ／ SUPER + ALT + O 整屏
--
--     把屏幕上的文字识别出来直接进剪贴板。RapidOCR（PP-OCRv6 + onnxruntime），
--     模型加载抽进常驻服务（ocrd.socket，socket 激活、空闲 10 分钟退出）。
--
--     ★ 触屏平板上的用法：用笔或手指框选一块区域，识别结果进剪贴板。
--       这在没有键盘的场景下比截图再抄写实际得多。
--
--     ★ 为什么用 SUPER 而不是 ALT —— 本文件其余动作类键位都在 ALT 上，
--       这里是【有意的例外】：取字属于「截图家族」，而这一家的修饰键分工是
--       SHIFT = 框选，ALT = 整屏（截图 SUPER+SHIFT/ALT+P、录屏 +R）。
--       取字是第三个成员，跟着它们走 O 才不用记两套规则。
--
--     ⚠️ 每天第一次按会等 2~3 秒（现拉进程 + 加载模型），之后几十毫秒。
--       想改常驻：调 ocr-server 里的 IDLE_TIMEOUT。见 docs/10-ocr.md。
-- ────────────────────────────────────────────────────────────────────────────
local ocrCall = "~/.local/bin/ocr-grab "

hl.bind("SUPER + SHIFT + O", hl.dsp.exec_cmd(ocrCall .. "region"))
hl.bind("SUPER + ALT + O",   hl.dsp.exec_cmd(ocrCall .. "screen"))


-- ────────────────────────────────────────────────────────────────────────────
--  3. 快捷键面板（noctalia 各面板的键盘入口）
--
--     平板上的主要 UI 入口是【手势】（见 config/touch.lua），这里保留一份
--     键盘等价物：接上 Type Cover 时用键盘更快，两个入口并存不冲突。
--
--     与 config/binds.lua 里那批是同一套命令 —— 那边是"官方风格的 SUPER+X"，
--     这边把常用的几个复制到更好按的位置。重复绑定同一个键位会叠加触发，
--     所以下面用的都是 binds.lua 里没占用的组合。
-- ────────────────────────────────────────────────────────────────────────────
hl.bind("ALT + Space",   hl.dsp.exec_cmd(noctCall .. "panel-toggle launcher"))
hl.bind("ALT + C",       hl.dsp.exec_cmd(noctCall .. "panel-toggle control-center"))
hl.bind("ALT + N",       hl.dsp.exec_cmd(noctCall .. "panel-toggle control-center notifications"))
hl.bind("ALT + V",       hl.dsp.exec_cmd(noctCall .. "panel-toggle clipboard"))
hl.bind("ALT + W",       hl.dsp.exec_cmd(noctCall .. "panel-toggle wallpaper"))
hl.bind("ALT + S",       hl.dsp.exec_cmd(noctCall .. "settings-toggle"))
hl.bind("ALT + L",       hl.dsp.exec_cmd(noctCall .. "session lock"))
hl.bind("ALT + Q",       hl.dsp.exec_cmd(noctCall .. "panel-toggle session"))

-- 窗口切换器：触屏上等同于"我该点哪个窗口"
hl.bind("ALT + Tab",     hl.dsp.exec_cmd(noctCall .. "window-switcher"))


-- ────────────────────────────────────────────────────────────────────────────
--  4. 虚拟键盘
--
--     ★ 平板模式下没有物理键盘，Super+K 够不着，所以除了底部边缘下滑的手势
--       （config/touch.lua）之外，这里再给一个键盘入口。
--
--     ★ 必须用绝对路径。Hyprland 进程的 PATH 里【没有】~/.local/bin：
--         PATH=/usr/local/sbin:/usr/local/bin:/usr/bin:...
--       写裸命令名会静默失败（不报错、没反应），排查时很难往 PATH 上想。
--       这是踩过的坑，见 docs/07。
-- ────────────────────────────────────────────────────────────────────────────
hl.bind("SUPER + K", hl.dsp.exec_cmd("/usr/local/bin/wvkbd-toggle"))


-- ────────────────────────────────────────────────────────────────────────────
--  5. 救援
--
--     触屏手势会误触发（触摸断触时一次滑动可能被读成多指，见 docs/08）。
--     误触之后纯触摸用户没法自己恢复（平板模式没有键盘，够不着 SUPER+1）。
--     这里给键盘用户一个等价入口；触屏用户走双指长按（config/touch-tablet.lua）。
-- ────────────────────────────────────────────────────────────────────────────
hl.bind("SUPER + SHIFT + Escape", hl.dsp.exec_cmd("/usr/local/bin/tablet-rescue"))
