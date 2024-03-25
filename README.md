# debrt

Debian Router

## Summary

1. 关于为什么要写这个脚本?
    提供Debian网关快速部署方式

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
    . ipv6支持 & 测试

### Bug & 优化

```bash
1. 输入空网口号可以通过校验
2. 同时输入多个网口号其中只有
3. 网口展示已划分vlan

4. 输入框不支持网口补全
5. 输入框不支持上一条选择

```
