-- Surface Pro 6 · CachyOS Hyprland 入口
--
-- ★ 本仓【拥有】这个文件。旧的两仓模式下它归 cachyOS-config 管，
--   本仓只能往里注入一行 require，而且每次 sync.sh --pull 之后要重跑
--   ./install.sh hook 才能把挂钩插回来。合并成一个仓之后没有这回事。
--
-- 顺序有讲究：
--   variables 必须在最前 —— 后面几个文件用它的 TERMINAL / MONITOR1 等变量。
--   monitors 在 variables 之后、binds 之前 —— 显示器要先定下来。
--   touch 在 inputs 之后 —— 两者都碰手势设置，touch 要能覆盖 inputs 的默认。

-- ── 上游 CachyOS 的文件（原样保留，没改过）────────────────────────────────
require("config.animations")
require("config.colors")
require("config.decorations")
require("config.environment")

-- ── 本仓改过的上游文件（每个文件头部写了改什么、为什么）────────────────────
require("config.variables")
require("config.monitors")
require("config.inputs")
require("config.misc")
require("config.binds")
require("config.windowrules")
require("config.workspaces")

-- ── 本机独有 ───────────────────────────────────────────────────────────────
require("config.autostart")   -- 自启（本仓拥有，旧模式下是往里插一行）
require("config.touch")       -- 触屏手势（上游没有这个文件）
require("mykeys")             -- 本机键位（PC 版 932 行精简而来）
