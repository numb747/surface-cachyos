# surface-cachyos

**Microsoft Surface Pro 6 上的 CachyOS + Hyprland 配置，一份完整的、以平板为先的配置。**

不是一个"适配层"，也不是别人的 dotfiles 的伴生仓 —— 这台机器只用这一份。

---

## 这台机器

| | |
|---|---|
| 机器 | Microsoft Surface Pro 6（1796，Consumer） |
| 系统 | CachyOS · Hyprland 0.56.2（Lua 配置）· Wayland |
| 屏幕 | 2736×1824 `eDP-1` @ scale 2（逻辑 1368×912）· 物理 260×170mm · **默认竖屏** |
| 内核 | `linux-surface` 6.19.8（普通内核作兜底） |
| 主要用法 | **平板模式** —— 触屏是主要输入手段，Type Cover 可摘 |

## 跟旧的两仓配置什么关系

这份配置合并自两个仓，它们都保留着、继续服务别的机器：

| 旧仓 | 服务对象 | 本仓与它的关系 |
|---|---|---|
| `numb747/cachyOS-config` | 台机 `david`、笔记本 `monkey` | 本仓的 UI/终端/壁纸/OCR 层从它搬来，但**不再与它同步** |
| `numb747/surface-config` | 只有这台 Surface | 本仓取代了它 |

**为什么不再分成两个仓。**

旧结构是「主仓拥有文件 + 适配层往里注入挂钩」，代价是三件事：

1. **注入机制本身是负担。** `surface-config` 里那套标记块注入、`hook` 模块、
   `doctor.sh` 的「挂钩完整性」检查，存在的唯一理由是主仓的 `sync.sh --pull`
   会覆盖 `hyprland.lua` / `autostart.lua`。用户必须记住「同步主仓之后重跑
   `install.sh hook`」这个容易忘的步骤。合成一个仓之后，本仓直接拥有这些文件，
   没有"被覆盖"这回事，整套机制删掉。
2. **PC 假设在平板上是死代码或事故源。** 键位表 972 行几乎全是键盘和弦，
   其中一整节建立在「指针下 = 焦点窗口」这个触屏上不成立的不变式上。
3. **失效模式不同，但 doctor 已经在跨域。** 旧仓的 `doctor.sh` 里有 100+ 行
   在检查主仓的文件，说明"分开能让体检更专注"这个理由已经不成立了。

## 装了什么

| 能力 | 靠什么 |
|---|---|
| 触屏 | `linux-surface` 内核 + `iptsd`（IPTS 驱动不在主线） |
| 触屏手势 | `hyprgrass` 插件（Hyprland 原生手势不覆盖触屏） |
| 平板模式 | `tablet-mode` —— 摘/接 Type Cover 自动切换布局 |
| 虚拟键盘 | `wvkbd-deskintl` + `wvkbd-toggle` + `fcitx-virtualkeyboard-adapter` |
| 自动旋转 | `iio-sensor-proxy` + `iio-hyprland`（systemd 用户单元保证顺序） |
| 屏幕取字 | RapidOCR 常驻服务（`ocrd.socket`）+ `ocr-grab` |
| UI | noctalia（顶栏、启动器、面板、通知） |

## 快速开始

```bash
# 1. 先装系统层（内核、传感器栈、插件）。这些要 sudo，脚本只打印命令。
./setup/01-surface-kernel.sh          # 加 --run 才真执行
./setup/02-hyprgrass.sh               # ★ 只有打印，必须手敲，见 docs/04

# 2. 装配置（只写 $HOME，不需 sudo）
./install.sh
./install.sh system                   # 打印需要 sudo 的命令，自己跑

# 3. 体检
./doctor.sh                           # 退出码 0 = 全绿
```

## 命令

| 命令 | 作用 |
|---|---|
| `./install.sh` | 装全部模块（不含 system） |
| `./install.sh hypr tablet` | 只装指定模块 |
| `./install.sh --list` | 列模块 |
| `./install.sh --dry-run` | 只打印，不动文件 |
| `./install.sh system` | 打印需要 sudo 的命令 |
| `./doctor.sh` | 体检，退出码 0 = 全绿 |
| `./doctor.sh --quiet` | 只列失败项 |
| `./uninstall.sh --list-baks` | 看回滚点 |
| `./uninstall.sh` | 还原包管文件 |
| `tablet-mode {on,off,toggle,status,auto}` | 平板/PC 模式切换 |
| `tablet-rescue` | 界面被误触搞乱时复位 |

## 手势

**设计前提**：这台机器的触摸在**快速移动时会断触** —— 一次连贯滑动会被
`iptsd` 拆成很多 8–60ms 的小片段；而**按住不动很稳**（三指按住实测 3.4 秒不断）。
所以手势**只用点击和长按**，不用滑动。

还有一条硬规则：**不做破坏性动作**。触屏误触代价太大，关窗口、移动窗口到
别的工作区、切抽屉工作区全部不绑。

| 手势 | 动作 |
|---|---|
| 三指点击 | 启动器（应用 + 窗口搜索） |
| 三指长按 | 拖动窗口 |
| 四指点击 | 全屏 |
| 四指长按 | 控制中心 |
| 五指点击 | 剪贴板 |
| 底部边缘下滑 | 虚拟键盘 |
| **双指长按** | **救援 —— 复位界面** |
| 五指长按 | 退出平板模式 |

完整表与设计理由见 [`docs/06-平板模式.md`](docs/06-平板模式.md)，
触屏问题的排查过程见 [`docs/08-触摸断触.md`](docs/08-触摸断触.md)。

音量、亮度、开关屏**保持物理键** —— Surface 侧边有实体音量键，
这是唯一一类"物理键优于触摸"的操作。

## 设计约定

- **`manifest.map` 是单一事实来源** —— 路径只写一处，`install.sh` /
  `uninstall.sh` / `doctor.sh` 都读它。（旧仓的 manifest 是摆设，没有任何脚本
  解析它，所以 `tablet-mode` 悄悄漂移过一版而 doctor 报全绿。）
- **`doctor.sh` 比对内容，不只查存在** —— 同一个教训的直接后果。
- **幂等** —— 重复执行结果一致。
- **先备份** —— 覆盖前存成 `<名字>.bak-YYYYmmdd-HHMMSS`，就放在原文件旁边
  （所以别把那些备份归档走，挪走等于废掉回滚点）。
- **不代跑 sudo** —— `install.sh` 只写 `$HOME`；需要提权的项打印命令，自己执行。
- **不硬编码用户名** —— 包内用 `/home/charlen` 作占位，`install.sh` 按当前
  `$HOME` 改写（和旧主仓的 `rewrite_home()` 同一套做法）。

## 文档

| | |
|---|---|
| [`docs/00-背景.md`](docs/00-背景.md) | 这台机器、这份配置的来龙去脉 |
| [`docs/01-安装.md`](docs/01-安装.md) | 从零装到能用；内核升级后怎么办 |
| [`docs/02-触屏手势.md`](docs/02-触屏手势.md) | 手势表、`mouse = true` 为什么关键 |
| [`docs/03-虚拟键盘.md`](docs/03-虚拟键盘.md) | 输入法协议冲突，怎么绕开 |
| [`docs/04-坑.md`](docs/04-坑.md) | 实测踩过的坑 |
| [`docs/05-自动旋转.md`](docs/05-自动旋转.md) | 传感器链路，为什么用 systemd 单元 |
| [`docs/06-平板模式.md`](docs/06-平板模式.md) | 手势总表、切换机制、救援 |
| [`docs/07-触摸不灵敏与PATH.md`](docs/07-触摸不灵敏与PATH.md) | 触摸上报两次；Hyprland 的 PATH 缺 `~/.local/bin` |
| [`docs/08-触摸断触.md`](docs/08-触摸断触.md) | 断触的两个原因（硬件死线 + iptsd 检测缺陷）、补丁、为什么不做死线补偿 |

## 许可

MIT，见 [`LICENSE`](LICENSE)。
