-- 键位绑定
--
-- ★ 这是从 CachyOS 上游 skel 改出来的（经 cachyOS-config 中转），
--   改动是【删掉平板上用不到、或者会打架的部分】。理由分三类：
--
--   1. 鼠标和弦：mainMod + mouse:272/273（拖拽/缩放窗口）、
--      mouse_up/down（滚轮切工作区）。平板没有鼠标；接上 Type Cover 后
--      用的是触控板，滚轮切工作区在那里是反直觉的（和触摸手势重复）。
--      窗口拖拽/缩放改由触屏三指长按承担（见 config/touch.lua）。
--
--   2. 多显示器：MONITOR2 / MONITOR3 的聚焦与移窗。本机只有 eDP-1，
--      variables.lua 里那两个变量已经不存在了，留着会引用 nil。
--
--   3. 小键盘与不存在的硬件键：code:82/86 是数字键盘的 +/-，
--      Surface 没有数字键盘；XF86Calculator / XF86AudioMicMute
--      对应的实体键这台机器也没有。
--
--   ★ 保留但值得注意：XF86Audio* / XF86MonBrightness* 保留 ——
--     Surface 侧边有【实体音量键】，亮度键在 Type Cover 上有。
--     这类"物理键优于触摸"的操作不该改成手势。

local mainMod = "SUPER"
local noctCall = "noctalia msg "

---------------------------
---- WINDOW MANAGEMENT ----
---------------------------

-- Window manipulation
hl.bind(mainMod .. " + Q",           hl.dsp.window.close())
hl.bind(mainMod .. " + ALT + Space", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F",           hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + J",           hl.dsp.layout("togglesplit"))

-- Change focus
hl.bind(mainMod .. " + Left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + Right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + Up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + Down",  hl.dsp.focus({ direction = "down" }))
hl.bind("ALT + Tab",           hl.dsp.window.cycle_next())
hl.bind(mainMod .. " + Tab",   hl.dsp.exec_cmd(noctCall .. "window-switcher"))

-- Move active window (within monitor only —— 单屏，没有"移动到别的显示器")
hl.bind(mainMod .. " + SHIFT + Up",    hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + Right", hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + Left",  hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + Down",  hl.dsp.window.move({ direction = "d" }))

-- Move window between workspaces
hl.bind(mainMod .. " + CONTROL + SHIFT + Right", hl.dsp.window.move({ workspace = "m+1" }))
hl.bind(mainMod .. " + CONTROL + SHIFT + Left",  hl.dsp.window.move({ workspace = "m-1" }))
for i = 1, NUM_WPM do
    local key = i % 10
    hl.bind(mainMod .. " + SHIFT + CONTROL + " .. key, hl.dsp.window.move({ workspace = "m~" .. i }))
end

-- 缩放（触屏上看小字用）。键盘 +/- 保留；数字键盘那两条已删（没有该硬件）。
local function zoomfunction(value)
    local zoomvalue = hl.get_config("cursor:zoom_factor")
    if (zoomvalue + value) > 3.0 then
        hl.config({ cursor = { zoom_factor = 3.0 } })
    elseif (zoomvalue + value) < 1.0 then
        hl.config({ cursor = { zoom_factor = 1.0 } })
    else
        hl.config({ cursor = { zoom_factor = zoomvalue + value } })
    end
end
hl.bind(mainMod .. " + Minus", function() zoomfunction(-0.3) end, { repeating = true})
hl.bind(mainMod .. " + Plus",  function() zoomfunction(0.3) end,  { repeating = true })

------------------
---- LAUNCHER ----
------------------

-- ★ launchPrefix 去掉了（上游是 "uwsm app -- "）。
--   本仓没有 uwsm 会话托管的前提下，这个前缀会让命令静默失败。
--   如果本机确实在用 uwsm 起会话，把这行取消注释即可：
-- local launchPrefix = "uwsm app -- "
local launchPrefix = ""

hl.bind(mainMod .. " + Return",     hl.dsp.exec_cmd(launchPrefix .. TERMINAL))
hl.bind(mainMod .. " + E",          hl.dsp.exec_cmd(launchPrefix .. FILE_MANAGER))
hl.bind(mainMod .. " + W",          hl.dsp.exec_cmd(launchPrefix .. BROWSER))
hl.bind("CONTROL + SHIFT + Escape", hl.dsp.exec_cmd(launchPrefix .. TERMINAL .. " -e btop"))
hl.bind(mainMod .. " + Z",          hl.dsp.exec_cmd(noctCall .. "settings-toggle"))
hl.bind(mainMod .. " + X",          hl.dsp.exec_cmd(noctCall .. "panel-toggle control-center"))
hl.bind(mainMod .. " + Space",      hl.dsp.exec_cmd(noctCall .. "panel-toggle launcher"))
hl.bind(mainMod .. " + period",     hl.dsp.exec_cmd(noctCall .. "panel-toggle launcher /emo"))
hl.bind(mainMod .. " + L",          hl.dsp.exec_cmd(noctCall .. "session lock"))
hl.bind(mainMod .. " + ALT + C",    hl.dsp.exec_cmd(noctCall .. "panel-toggle session"))

---------------------------
---- HARDWARE CONTROLS ----
---------------------------

-- Audio —— Surface 侧边有实体音量键，这几个 XF86 是给 Type Cover 的
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(noctCall .. "volume-up"),   { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(noctCall .. "volume-down"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd(noctCall .. "volume-mute"), { locked = true })

-- Media（Type Cover 上的播放键）
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd(noctCall .. "media toggle"),   { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd(noctCall .. "media toggle"),   { locked = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd(noctCall .. "media next"),     { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd(noctCall .. "media previous"), { locked = true })

-- Brightness
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(noctCall .. "brightness-up"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(noctCall .. "brightness-down"), { locked = true, repeating = true })

-------------------
---- UTILITIES ----
-------------------

-- Screen Capture
hl.bind("Print",                   hl.dsp.exec_cmd(noctCall .. "screenshot-region"))
hl.bind(mainMod .. " + Print",     hl.dsp.exec_cmd(noctCall .. "screenshot-fullscreen"))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd(noctCall .. "screenshot-region"))
hl.bind(mainMod .. " + ALT + P",   hl.dsp.exec_cmd(noctCall .. "screenshot-fullscreen"))

-- Screen Recording (wl-screenrec) —— SHIFT=框选，ALT=整屏，同键再按一次停止。
--    不加 launchPrefix：uwsm app 会把录屏进程丢进另一个 cgroup，pidfile 就追不上了。
local recCall = "~/.local/bin/hypr-screenrec "
hl.bind(mainMod .. " + SHIFT + R",   hl.dsp.exec_cmd(recCall .. "region"))
hl.bind(mainMod .. " + ALT + R",     hl.dsp.exec_cmd(recCall .. "screen"))
hl.bind(mainMod .. " + CONTROL + R", hl.dsp.exec_cmd(recCall .. "stop"))

-- Theming and Wallpaper
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd(noctCall .. "panel-toggle wallpaper"))

-- Clipboard
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd(noctCall .. "panel-toggle clipboard"))

-- Notifications
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd(noctCall .. "panel-toggle control-center notifications"))

-------------------------------
---- WORKSPACES & MONITORS ----
-------------------------------

-- Focus on the (single) monitor
hl.bind(mainMod .. " + 1", hl.dsp.focus({ monitor = MONITOR1 }))

-- Focus on workspace by position —— m~N = 本显示器上第 N 个【已存在】的工作区，
-- 不会凭空创建，正是动态工作区下的"按位置跳转"。
for i = 1, NUM_WPM do
    local key = i % 10
    hl.bind(mainMod .. " + CONTROL + " .. key, hl.dsp.focus({ workspace = "m~" .. i }))
end

-- Move to adjacent workspaces and next empty
hl.bind(mainMod .. " + CONTROL + Right", hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mainMod .. " + CONTROL + Left",  hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mainMod .. " + CONTROL + Down",  hl.dsp.focus({ workspace = "emptym" }))

-- Special workspace (scratchpad)
-- ★ 触屏那边【故意不绑】切 special 的手势 —— 误触会让空工作区盖住屏幕、
--   看起来像"窗口凭空消失"，而且它不会自己恢复（见 config/touch.lua 与 docs/08）。
--   键盘上用 SUPER+S 切是安全的（要按下去才会触发），保留。
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special" }))
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special())
