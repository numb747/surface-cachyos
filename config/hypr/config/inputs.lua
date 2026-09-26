-- 输入配置
--
-- ★ 这是从 CachyOS 上游 skel 改出来的，改动集中在最后四行。
--
--   上游那四条 hl.gesture 是给【触控板】写的（Hyprland 原生手势只监听
--   ITrackpadGesture），但它们的动作在平板上全是破坏性的：
--
--     hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })
--     hl.gesture({ fingers = 3, direction = "down",       action = "close" })
--     hl.gesture({ fingers = 3, direction = "up",         action = "fullscreen" })
--     hl.gesture({ fingers = 3, direction = "left",       action = "float" })
--
--   三指下滑 = 关窗口。这台机器的触摸在快速移动时会【断触】（见 docs/08）：
--   一次滑动被拆成很多 8-60ms 的小片段，合成器可能把一段触摸读成多指，
--   于是凑够三指 → 关窗口。误触代价是丢工作，而收益（少按一次）接近于零。
--
--   所以四条【全部移除】。平板上要用的手势走 hyprgrass（config/touch.lua），
--   那边全部用 tap / longpress 这类静止触发，不做破坏性动作。

hl.config({
    input = {
        -- 触屏的加速度曲线。上游给触控板设的 flat（无加速），
        -- 对触屏也适用 —— 触屏的绝对坐标本来就不需要指针加速。
        accel_profile = "flat",
    },
    -- 光标相关的设置在平板形态下无意义（没有常驻指针）。
    -- 接上 Type Cover 用触控板时同样不需要特殊处理。
})

-- ★ 上游那四条破坏性手势已删除，见文件头说明。
--   如果哪天接了鼠标、想恢复触控板手势，从 /etc/skel 抄回来即可 ——
--   但注意它同时会影响触屏（Hyprland 把两者都当 gesture 源处理）。
