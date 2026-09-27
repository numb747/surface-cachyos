-- 显示器配置
-- Wiki: https://wiki.hypr.land/Configuring/Basics/Monitors/
--
-- ★ 这是从 CachyOS 上游 skel 改出来的。上游是 mode/position/scale 全 auto，
--   本机改成写死竖屏基线，原因：
--
--   Surface Pro 6 的屏幕是 2736x1824 @ 3:2，物理尺寸 260x170mm。
--   这台机器【主要当平板竖着用】，所以平板模式的默认是竖屏（transform = 3，
--   即顺时针 90 度）；PC 模式是横屏 0，见下面 BASE_TRANSFORM。
--
--   上游的 scale = "auto" 会算出 2（2736/1368），这个是对的，写死是为了
--   可预测 —— auto 在换内核/换合成器版本时可能变。逻辑分辨率 1368x912。
--
--   ★ 但【自动旋转】会覆盖这里的 transform：iio-hyprland 监听加速度计，
--     转到别的方向时用 hyprctl eval 直接改 monitor 的 transform。
--     所以这里写死的是"没转动时的基线"，不是恒定值。
--     见 docs/05-自动旋转.md。
--
--   ★ 基线按模式分（TABLET_MODE 见 variables.lua）：
--       PC 模式   → 横屏 0。接着 Type Cover 物理上只能横着用，自动旋转也停了
--                    （iio-hyprland.service 带 ConditionPathExists=标记文件）。
--       平板模式 → 竖屏 3。reload 后由 tablet-mode 按传感器转到实际朝向。
--     早先无论什么模式都写死 3，而切模式就是 reload —— 于是插上 Cover 回到
--     PC 模式，屏幕反而变竖屏；iio-hyprland 只在方向【变化】时才转，平板
--     不动就一直竖着（2026-09-27 实测）。
local BASE_TRANSFORM = TABLET_MODE and 3 or 0

hl.monitor({
    output    = MONITOR1,
    mode      = "preferred",   -- 2736x1824@59.96
    position  = "0x0",
    scale     = 2,
    transform = BASE_TRANSFORM,
})

-- ★ 触摸设备也要跟着转。
--
--   Hyprland 里触摸坐标的旋转是【独立设置】的（input:touchdevice:transform），
--   不跟着 monitor 的 transform 走。如果两者不一致，触摸点会落到错误的
--   位置 —— 症状是"点哪儿都没反应"或者"点左半边右边动"。
--
--   这里和上面保持一致。iio-hyprland 和 tablet-mode 旋转时都会同时改这三个
--   （hyprctl eval 串里带着 input.touchdevice / tablet 的 transform）。
--
--   历史坑：2026-09-26 排查时见过 monitor 是横屏（transform 0）而
--   触摸设备还是竖屏（transform 3）的状态，表现为触屏完全点不动，
--   而且 libinput 那一层看事件是正常的 —— 因为错位发生在合成器内部。
hl.config({
    input = {
        touchdevice = {
            transform = BASE_TRANSFORM,
        },
        -- 手写笔同样要转，否则笔的坐标和手指对不上。
        tablet = {
            transform = BASE_TRANSFORM,
        },
    },
})
