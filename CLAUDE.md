# CLAUDE.md

给 Claude Code（或任何接手的人）看的仓库说明。**只写从这个仓看不到的东西。**

## 这是什么

Surface Pro 6 上的 CachyOS + Hyprland 配置，**一份独立完整的配置**，
不是别人的 dotfiles 的适配层。

**目标机器只有一台**，所以没有机型判断、没有多机差异层 —— 路径和硬件假设
可以直接写。

## 权威位置

工作副本在 Surface 上：

```
charlen@192.168.0.8:~/surface-cachyos
```

**改配置要在那儿改**，因为它是真相来源（"系统 → 包"方向）。
本机（monkey）不是这台机器的源。

## 合并自哪里（历史，别去找那两个仓同步）

| 旧仓 | 现在的关系 |
|---|---|
| `numb747/cachyOS-config` | UI/终端/壁纸/OCR 层从它搬来。**不再同步** |
| `numb747/surface-config` | 本仓取代了它 |

**为什么不再分成两个仓**（旧结构的三个代价，都实测过）：

1. **注入机制是纯负担。** 旧 `surface-config` 有 `inject_block` + `hook` 模块 +
   `doctor.sh` 的「挂钩完整性」检查，存在的唯一理由是主仓 `sync.sh --pull`
   会覆盖 `hyprland.lua` / `autostart.lua`。用户必须记住"同步主仓后重跑
   `install.sh hook`"。而且实测那两处挂钩**从来不是标记块注入的**
   （`require("config.touch")` 是手加的、`iio-hyprland` 走无标记的 awk 路径），
   即这套机制在真机上从未被验证过。本仓直接拥有这些文件，整套删掉。
2. **PC 假设在平板上是死代码或事故源。** 旧 `mykeys.lua` 972 行全是键盘和弦，
   其中一整节建立在「指针下 = 焦点窗口」这个触屏上不成立的不变式上。
3. **doctor 已经在跨域。** 旧仓 `doctor.sh` 里 100+ 行在检查主仓的文件，
   说明"分开能让体检更专注"这个理由不成立了。

## 不要做的事

- **不要在 `~/cachyOS-config` 上跑 `sync.sh --pull` 或裸 `install.sh`。**
  那个仓在两台 PC 上还有用途，它的 `CLAUDE.md` 明令禁止这两条。
  本仓不碰它。
- **不要把 `bin/tablet-mode` 之类改成依赖 `~/.local/bin` 的软链就完事。**
  udev 的 `RUN` 以 root 跑、环境最小，`/usr/local/bin` 里必须是**真文件**
  （可以是软链，但 root 要能穿透执行）。
- **不要给触屏绑滑动类手势，也不要绑破坏性动作。** 见下。

## 这台机器的硬约束

### 1. 触摸屏有硬件死线，划动穿过就断

触摸层有 4 条感应线完全没信号（竖屏时左起约 3.6–5cm 一条宽带、约 8cm 一条细线，
都是竖直的）。穿过死线的划动 100% 断开；强制断电后依旧，是硬件损坏。
另有一个 iptsd 检测缺陷会让死线以外也零星断开，已用补丁版 iptsd 缓解
（`setup/03-iptsd-patched.sh`）。完整数据与排除过程见 `docs/08`。

**结论**：
- 手势只用 `tap` / `longpress`。**不要加 `swipe`** —— 划动经过死线必断，手势收不到结束事件。
- **不做死线的软件补偿**（2026-09-27 评估过，性价比不够，理由见 `docs/08`）。
  除非用户改主意，否则别再提议。
- 别再往 `[Contacts]` 阈值上找办法：回放扫过 16 组，调低只会更糟。
- 死线位置是这块屏幕特有的。**换屏之后 `docs/08` 里的死线结论作废**，要重新测。

### 2. 触摸误触的后果不对称

关窗口、移动窗口到别的工作区、切抽屉工作区 —— 这三类**一律不绑**。
误触的代价（丢工作、窗口找不回、空工作区盖住屏幕且不自动恢复）
远大于它省下的那一次点击。2026-09-26 实际被这个坑过。

### 3. Hyprland 的 PATH 里没有 `~/.local/bin`

Hyprland 进程的 PATH 是 `/usr/local/sbin:/usr/local/bin:/usr/bin:...`，
写裸命令名会**静默失败**（不报错、不记日志、没反应）。
所以：
- Lua 配置里调脚本用 **`/usr/local/bin/...` 绝对路径**
- `/usr/local/bin` 里的文件由 `./install.sh system` 打印 sudo 命令手工装

## 约定

- **`manifest.map` 是单一事实来源**，`install.sh` / `uninstall.sh` / `doctor.sh`
  都**真的解析它**（`put_module()`）。加文件只改表一行。
  ★ 旧 `surface-config` 也有一份 manifest，但没有任何脚本读它 ——
  于是 `bin/tablet-mode` 悄悄漂移了一版（仓库改成 VID/PID 搜索，装机那份
  还硬编码端口 `1-7`）而 doctor 报全绿。**别让这张表退化成文档。**
- **`doctor.sh` 比对内容，不只是查存在性。** 同上的直接后果。
  例外：`state/noctalia/settings.toml` 是运行时状态（noctalia 一直在写），
  只查存在。
- **`install.sh` 只写 `$HOME`**，需要 sudo 的一律打印命令。
  想加一个要 sudo 的项，加进 `mod_system()` 的 `cat` 块，**不要**放进
  `manifest.map` 的目标路径里。
- **包内路径不写死用户名。** Lua 配置指 `/usr/local/bin`；
  确实需要 `$HOME` 绝对路径的（noctalia 的 `key_file` 等）由
  `install.sh` 的 `rewrite_home()` 按当前 `$HOME` 改写。
- **备份放原文件旁边**（`.bak-YYYYmmdd-HHMMSS`），别归档走，挪走等于废掉回滚点。

## 改手势之后必须做的两件事

1. `luac -p` 过一遍语法（`hl` 全局未定义的警告是预期的，运行时才注入）。
2. `hyprctl reload && hyprctl configerrors` —— 确认零报错。
   再截一张图确认画面没被弄乱（曾经有 reload 后屏幕偏移、窗口只见一半的情况）。

## 本机与仓库的差异清单

**当前没有。** 这份配置就是这台机器在跑的配置，`./doctor.sh` 应该全绿。
如果 doctor 报了不一致，那是真的漂移了，修它 —— 别加进"预期差异"清单。
（旧仓的 `CLAUDE.md` 里有一张 6 项的"预期差异"表，那是因为它在两台机器间
共用一份包。本仓只服务一台机器，不需要那种东西。）

## 用户

- 这台机器**主要当平板用**，触屏是主要输入手段。
- 用户在**平板上不方便执行 shell**（没有物理键盘时）。需要排障时优先
  通过 SSH 从外部操作，把提示打到屏幕上（`notify-send`）而不是让用户敲命令。
