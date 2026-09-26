-- 自启
--
-- ★ 本仓【拥有】这个文件。旧的两仓模式下它归 cachyOS-config 管，
--   本仓只能靠一条 awk 命令把 iio-hyprland 插进下面这个函数体里
--   （按内容 grep 做幂等，没有标记块，改个缩进就会静默失效）。
--   合并之后直接写在这里。

hl.on("hyprland.start", function ()
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("noctalia")
    -- hyprgrass 是外部插件，Hyprland 不自己加载，每次启动要 reload 一次。
    hl.exec_cmd("hyprpm reload -n")
    -- 自动旋转。★ 这里【不】直接起 iio-hyprland，交给 systemd 用户单元
    -- （systemd/iio-hyprland.service，带 Wants=iio-sensor-proxy.service）。
    -- 理由：iio-sensor-proxy 是 D-Bus 激活的，直接 exec 会让 iio-hyprland
    -- 在它还没就绪时启动，表现为"开机偶发不旋转，重启一次就好"——
    -- 这种偶发最难查。用 unit 让 systemd 保证启动顺序。
    -- 见 docs/05-自动旋转.md。
    hl.exec_cmd("systemctl --user start iio-hyprland.service")
    hl.exec_cmd("xhost +SI:localuser:root")
end)
