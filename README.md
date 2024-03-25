# debrt

Debian Router

## Summary

1. 关于为什么要写这个脚本?
实际上目前开源社区的网管类系统已经足够多了其中比较优秀的就有：基于BSD的OPNsense, pfSense基于Linux的VyOS, IPFire, OpenWRT。 这些网关系统都有各自的优势
有些有优秀的防火墙功能(如OPNsense)有的体验极好的WebGui体验和不错的硬件兼容(如OpenWRT)，还有一些系统有着一流的terminal路由配置界面()。这些都是作为一个专业网关所拥有的优秀特性。提供DebRT诚当是为普通Linux用户提供一个更加简单的选择而并非取代某一个具体的对象，主流的开源网关普遍优秀而复杂的设计，部分会作为单独的发行版(Distro)拥有独立的包管理，但这些单独的发行版软件仓库大多也是独立管理，但涉及到多个仓库同时运行时可能会出现软件/库版本冲突对用户使用造成的巨大的困扰。此外考虑到系统的复杂程度找到一个合适的OpenWRT需要自己手动编译，而OPNsense作为BSD的发行分支对于Linux用户任然有不少使用上的不便之处。此时需要一个能在通用操作系统上构建出来的简单网关，DebRT正是在这种使用场景下诞生的，DebRT完全使用Debian的网络配置服务"networking"来管理网络，软件包依赖Debian/Linux 通用系统 的apt仓库，防火墙是Linux用户熟悉的Iptables，其扩展性依赖于Debian/Linux Kernel, 只要能找到能运行该Debian系统即可完好的启动该网关。

2. 这个脚本拥有怎样的特性?
    . 可支持Debian 10及之后的stable版本
    . 可快速完成网络设备部署
    . 不提供任何管理界面
    . VLAN全部使用linux bridge网络功能实现
    . DNS/DHCP由dnsmasq实现
    . 网络监控由munin实现
    . VPN默认安装OpenVPN

3. 后续计划
    . 提供一个可重入的设置功能(端口设置, 路由设置, vlan设置)

### Bug & 优化

```bash
1. 输入空网口号可以通过校验
2. 同时输入多个网口号其中只有
3. 网口展示已划分vlan

4. 输入框不支持网口补全
5. 输入框不支持上一条选择

```
