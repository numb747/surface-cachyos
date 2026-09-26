# 07 · 触摸不灵敏，和那个害人的 PATH

两条独立的坑，症状都表现为"按了没反应 / 不灵敏"，很容易混在一起查。

---

## 坑 A：触摸被上报两次

### 症状

触摸不灵敏、滑动不跟手、拖窗口发飘。

### 根因

Surface 的触屏在 Linux 上有**两个** evdev 设备同时活着：

```
Touch:
    ipts-045e:001f-touchscreen            ← 内核 ipts 模块给的原始设备
    iptsd-virtual-touchscreen-045e:001f   ← iptsd 读完 hidraw 后造的
```

两个都带 `ID_INPUT_TOUCHSCREEN=1`，所以 Hyprland（经 libinput）**两个都监听**，
同一次触摸被上报两遍。

**决定性证据是几何信息不一致**：

| 设备 | 报告尺寸 | 比例 | 对不对 |
|---|---|---|---|
| 原始 IPTS | 292×165 mm | 1.77（16:9） | ✗ |
| iptsd 虚拟 | 259×171 mm | 1.51（3:2） | ✓ |

Surface Pro 6 是 **3:2** 屏。原始设备报的比例明显是错的，说明它的坐标映射
不正确 —— 两路事件的坐标互相打架。

### 修法

`udev/71-surface-ipts-ignore-raw.rules` 把原始的禁掉：

```bash
sudo install -m644 udev/71-surface-ipts-ignore-raw.rules \
     /etc/udev/rules.d/71-surface-ipts-ignore-raw.rules
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=input
```

**为什么禁掉原始设备不影响 iptsd**：iptsd 是走 **hidraw** 读数据的
（`/dev/hidraw*`），不依赖那个 evdev 设备。禁掉它只是让合成器别再重复收一份。

**规则必须精确匹配名字**：

```
ATTRS{name}=="IPTS 045E:001F Touchscreen"
```

同一颗芯片还会造出 `"IPTS 045E:001F"`（无 `Touchscreen` 后缀）和
`"IPTSD Virtual Touchscreen 045E:001F"`。**别用 `IPTS*` 通配符**，
那会误伤虚拟设备。

### 验证

```bash
sudo libinput list-devices | grep -iA2 ipts
# 应该只剩 IPTSD 那个

# 或者查属性（设备号可能变，按名字找）
udevadm info $(grep -l "IPTS 045E:001F Touchscreen" /sys/class/input/*/name \
               | sed 's|/name||;s|/sys/class/input/|/dev/input/|')
# ID_INPUT_TOUCHSCREEN 应从 1 变成 0
```

### 回滚

```bash
sudo rm /etc/udev/rules.d/71-surface-ipts-ignore-raw.rules
sudo udevadm control --reload-rules && sudo udevadm trigger --subsystem-match=input
```

---

## 坑 B：Hyprland 的 PATH 里没有 `~/.local/bin`

### 症状

`SUPER+K` 按了没反应。但手动在终端跑 `wvkbd-toggle` 完全正常。
**同一个脚本，终端能跑、快捷键不行。**

### 根因

Hyprland 进程的 PATH：

```
PATH=/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/bin/site_perl:/usr/bin/vendor_perl:/usr/bin/core_perl
```

**没有 `~/.local/bin`。** 而 `binds.lua:177` 写的是：

```lua
hl.bind(mainMod .. " + K", hl.dsp.exec_cmd("wvkbd-toggle"))   -- 裸命令名
```

找不到命令 → **静默失败**。不报错、不进日志、没有任何提示。

> 这跟 `docs/04` 里 fcitx 适配器那个坑是**同一个根源**：都是"环境变量里
> 没有用户目录，命令解析失败但不报错"。区别是适配器那次是 `system()`
> 继承的 PATH，这次是 Hyprland 自己的 PATH。

### 修法

**不要改配置文件。** `binds.lua` 归主仓管，`sync.sh --pull` 会冲掉。

正确做法是往 PATH 里**已有**的 `/usr/local/bin` 放软链：

```bash
sudo ln -sf ~/.local/bin/wvkbd-toggle /usr/local/bin/wvkbd-toggle
sudo ln -sf ~/.local/bin/tablet-mode  /usr/local/bin/tablet-mode
```

一劳永逸，不动任何配置文件，主仓同步也不影响。

> 另一个选项是往 `~/.config/uwsm/env` 加 `PATH=...`，但**那个文件归主仓管**
> （`manifest.map:83`），改了下次同步就没了。软链没这个问题。

### 验证

```bash
env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/bin \
  /bin/sh -c 'command -v wvkbd-toggle'
# 应打印 /usr/local/bin/wvkbd-toggle；没有输出就是还没修好
```

### 本仓的对应处理

- 我自己的配置里**全部改用绝对路径**（`touch.lua`、`touch-tablet.lua`），
  不依赖 PATH。
- `install.sh path` 模块打印上面那两条软链命令（要 sudo，不代跑）。
- `doctor.sh` 检查 `/usr/local/bin/wvkbd-toggle` 在不在。

---

## 坑 C：`hyprctl repl` 只校验参数，不真派发

排查上面两个坑时踩到的，单独记一笔。

```bash
hyprctl repl 'hl.dsp.exec_cmd("touch /tmp/probe") return "called"'
# 返回 called，但 /tmp/probe 【从未出现】
```

**所以 `hyprctl repl` 不能用来做"运行时开关"。** 我最初设计平板模式切换时
想用它动态 bind/unbind 手势 —— 那是假的，会"切了没反应"。

同理，在 repl 里用 `pcall` 测某个 API 调用是否合法，`true` 只说明**参数能解析**，
不代表**动作会执行**。要验证行为必须看副作用（文件、窗口状态、`hyprctl` 查询）。

可靠的状态传递方式是**标记文件 + `hyprctl reload`**（见 `docs/06`）。

---

## kitty 为什么点不动

顺带记一下，因为排查时容易误判成上面的坑。

kitty 用 `glfw-wayland.so` 做后端，而它的 wayland 接口列表里：

```
wl_pointer_interface      ✓
wl_keyboard_interface     ✓
wl_touch_interface        ✗  没有
```

**GLFW 的 Wayland 后端不实现 `wl_touch`**，所以 kitty 根本收不到触摸事件 ——
不是配置问题，是 kitty 不支持。

对比：**火狐支持触摸**（`/usr/lib/firefox/libxul.so` 里有 `wl_touch_interface`），
所以网页点按、滚动、缩放都正常。

平板模式下如果要在终端里干活，选支持 `wl_touch` 的终端（如 `foot`）。
不需要的话不用管 —— 虚拟键盘能打字，只是点不了。
