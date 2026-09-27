-- 触屏手势配置（全局，PC / 平板都加载 —— 平板专属的在 config/touch-tablet.lua）
--
-- ★ 设计前提：这台 Surface Pro 6 的触摸在【快速移动时会断触】——
--   一次连贯滑动会被拆成很多 8-60ms 的小片段（实测见 docs/08-触摸断触.md）。
--   而【按住不动】很稳（三指按住实测 3.4 秒不断）。所以：
--     1. 只用 tap（点击）和 longpress（按住）—— 静止触发，最可靠；
--     2. 不用 swipe（滑动）—— 移动中断触会导致手势收不到结束事件；
--     3. 【不做破坏性动作】。触屏误触代价太大，下列动作一律不绑：
--        · 关窗口            误触 = 丢工作
--        · 移动窗口到别的工作区  误触 = 窗口"不见了"，纯触摸难找回
--        · 切换抽屉工作区（special）误触 = 空工作区盖住屏幕、不自动恢复，
--                                    看起来就像"窗口凭空消失"
--
-- ★ 指头数分配（两个文件之间【不能重复】）：
--     3 指点击 / 3 指长按 / 4 指点击 / 4 指长按 / 5 指点击  ← 本文件
--     2 指长按 / 5 指长按                                 ← touch-tablet.lua
--   重复绑定谁生效取决于插件内部顺序，很脆弱，所以按指头数切开。
--
-- hl.plugin 命名空间只有在插件加载后才存在，所以插件相关调用必须包在
-- nil 守卫里，否则插件未加载时配置会报错。

hl.config({
    gestures = {
        -- 原生单指边缘切工作区：关。
        -- 单指滑动在这台设备上最容易被误判（滑动即断触 → 手势收不到结束事件
        -- → 切工作区动画卡在半截，画面停在两个工作区之间且不复位）。
        workspace_swipe_touch        = false,
        workspace_swipe_cancel_ratio = 0.15,
    },
})

if hl.plugin.hyprgrass == nil then
    return
end

hl.config({
    plugin = {
        hyprgrass = {
            -- 默认 1.0 在平板屏幕上太低，作者建议调到 4.0
            sensitivity                 = 4.0,
            -- 长按判定时间。按住类手势在本设备上最可靠，400ms 略短，
            -- 容易把"按一下"读成"长按"，放宽到 500ms。
            long_press_delay            = 500,
            -- 长按窗口边框调整大小：触屏上极难精确命中，关掉。
            resize_on_border_long_press = false,
            edge_margin                 = 10,
        },
    },
})

-- ── 保留的手势（非破坏性，且适配本设备的触摸特性）─────────────────────────

-- 三指点击 → 启动器（应用 + 窗口搜索）
--    平板与 PC 通用：一个入口既能开应用也能找窗口。
hl.plugin.hyprgrass.bind {
    pattern = { kind = "tap", fingers = 3 },
    action  = hl.dsp.exec_cmd("noctalia msg panel-toggle launcher"),
}

-- 三指长按 → 拖动窗口
--    用按住触发而不是滑动，正因为它稳：手指停住时触点不会碎。
--    mouse = true 是关键，把触屏手势转成鼠标拖拽。
hl.plugin.hyprgrass.bind {
    pattern = { kind = "longpress", fingers = 3 },
    action  = hl.dsp.window.drag(),
    mouse   = true,
}

-- 四指点击 → 切换全屏
hl.plugin.hyprgrass.bind {
    pattern = { kind = "tap", fingers = 4 },
    action  = hl.dsp.window.fullscreen(),
}

-- 四指长按 → 控制中心（音量/亮度/网络/蓝牙/电源）
hl.plugin.hyprgrass.bind {
    pattern = { kind = "longpress", fingers = 4 },
    action  = hl.dsp.exec_cmd("noctalia msg panel-toggle control-center"),
}

-- 五指点击 → 剪贴板历史
hl.plugin.hyprgrass.bind {
    pattern = { kind = "tap", fingers = 5 },
    action  = hl.dsp.exec_cmd("noctalia msg panel-toggle clipboard"),
}

-- 底部边缘下滑 → 显示/隐藏虚拟键盘
--    （原版这里是"上滑关窗口"——触屏上最危险的一条，已删除。）
--
-- ★ 必须用绝对路径。Hyprland 进程的 PATH 里【没有】~/.local/bin：
--     PATH=/usr/local/sbin:/usr/local/bin:/usr/bin:...
--   写裸命令名会静默失败（不报错、没反应），排查时很难往 PATH 上想。
--
--   这里指 /usr/local/bin 而不是 ~/.local/bin —— 那个目录【在 PATH 里】，
--   而且与用户名无关。代价是 install.sh 装不进去（要 sudo），所以文件本体
--   走 ~/.local/bin，/usr/local/bin 里由 ./install.sh system 打命令让你自己
--   sudo 一份真文件过去。
--
--   noctalia 走的是 D-Bus，PATH 里能找到，所以上面几条可以直接写名字。
hl.plugin.hyprgrass.bind {
    pattern = { kind = "edge", origin = "d", direction = "d" },
    action  = hl.dsp.exec_cmd("/usr/local/bin/wvkbd-toggle"),
}

-- ── 平板模式手势集（条件加载）──────────────────────────────────────────────
-- 平板模式才 require 平板专属手势。TABLET_MODE 由 variables.lua 从标记文件
-- 读出（为什么用文件判断见那边）。
--
-- 切换用 ~/.local/bin/tablet-mode {on|off|toggle}，它改标记后调 hyprctl reload。
if TABLET_MODE then
    require("config.touch-tablet")
end
