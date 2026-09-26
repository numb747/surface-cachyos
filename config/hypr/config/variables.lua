-- 全局变量
--
-- ★ 这是从 CachyOS 上游 skel 改出来的，改动：
--   1. 单显示器。上游留了 MONITOR1/2/3 三个槽位，Surface 只有一个 eDP-1，
--      多出来的会让 binds.lua 生成一批指不到东西的键位。
--   2. 默认应用改成平板上真装的。上游假设 gnome-text-editor / gnome-calculator，
--      本机没装（装了也用不上，触屏上写文档不现实）。
--   3. NUM_WPM 从 9 降到 4。平板上没人会用 SUPER+CTRL+8 跳工作区。

-- ── 默认应用 ───────────────────────────────────────────────────────────────
-- TERMINAL 用 kitty：它的 Wayland 后端【没有实现 wl_touch】，
-- 所以触屏点不动终端里的东西（不是配置错，是 kitty 不支持 —— 见 docs/07）。
-- 纯平板形态下要用终端的话，选支持 wl_touch 的（如 foot）；
-- 接上 Type Cover 时 kitty 完全正常，所以默认值仍是它。
TERMINAL     = "kitty"
FILE_MANAGER = "dolphin"
BROWSER      = "firefox"
-- 平板上没有方便的文字编辑器，留 htop 之类也怪；指向 kitty 起 nvim 更合理，
-- 反正真写东西会接键盘。EDITOR 只在少数地方被引用。
EDITOR       = "kitty -e nvim"
CALCULATOR   = "gnome-calculator"

-- ── 显示器 ─────────────────────────────────────────────────────────────────
-- Surface Pro 6 只有一个输出。用固定名字而不是空串：
-- 空串在 hyprctl 里表示"自动选第一个"，单屏时能work，但显式写出来更好排查。
MONITOR1        = "eDP-1"
PRIMARY_MONITOR = MONITOR1

-- ── 工作区 ─────────────────────────────────────────────────────────────────
-- ★ 本配置为纯动态工作区（workspaces.lua 不定义 persistent 规则），
--   所以这个值不决定"有几个桌面"，只决定生成多少个【按位置跳转】的键位：
--     SUPER + CTRL  + 1..N        跳到本显示器第 N 个已存在的工作区
--     SUPER + SHIFT + CTRL + 1..N 把当前窗口丢到第 N 个
--   绑满 9 个没有代价（位置不存在时按下即空操作），但平板上够不着，
--   而且这些键位在触屏上毫无意义。降到 4 减少噪音。
NUM_WPM = 4
