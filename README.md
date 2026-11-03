# ZN M2 OpenWrt 自制固件（纯有线 / 无 WiFi）

为兆能 **ZN M2**（IPQ6000，1G 内存改版，128M NAND）定制的云编译仓库。

- 源码：[VIKINGYFY/immortalwrt](https://github.com/VIKINGYFY/immortalwrt) `main` 分支（qualcommax/ipq60xx，NSS 硬件加速，内核 6.12 系列）
- 定位：弱电箱纯有线 PPPoE 主路由 —— **无 WiFi、无 USB**
- 核心插件：**PassWall（编译时拉官方最新版）+ Xray + sing-box + Hysteria 全部烘焙进固件**，避免刷机后在线更新组件双份占用闪存
- 其他必备：luci-app-cpufreq（CPU 性能优化调节）、UPnP、DDNSTO、TTYD、定时重启、文件传输、IP/MAC 绑定
- 主题：**Argon**（luci-theme-argon + argon-config，首次启动默认启用）
- **Root 密码留空**（编译时强制清空；注意空密码时 SSH 密码登录会被系统拒绝，网页/TTYD 可直接登录）
- **v1 不含 MosDNS**（先保 PassWall 稳定）；Turbo ACC 不需要，NSS 加速已替代它

## 怎么触发编译

- 改动 `configs/` 下的配置并推送，或
- 在 Actions 页手动运行 **Build ZN-M2 OpenWrt**，或
- 给本仓库点 Star（watch 触发）

首编约 2–3 小时，产物在 Actions 的 Artifacts 和 Release 里。

## 刷机警告（必读）

这是从旧 4.4.60 固件跨代升级到 qualcommax 新固件：

- **不能保留配置 sysupgrade**，须走 U-Boot 网页恢复刷入 factory/ubi 包
- 刷前备份：现有配置、PPPoE 宽带账号密码、DDNSTO 令牌、PassWall 节点订阅
- 刷后默认管理地址以固件为准（源码默认 192.168.1.1）

## 文件说明

- `.github/workflows/build-zn-m2.yml` — 云编译流水线
- `configs/zn_m2_nowifi.config` — 设备与插件配置（改插件改这里）
- `diy-part1.sh` — 编译前添加 PassWall 官方 feeds
- `diy-part2.sh` — 编译前拉取 DDNSTO 插件并做小调整
