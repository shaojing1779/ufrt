# Debian as NAS

## nas

### zfs

```bash
apt install zfsutils-linux
# 查看Pool
zpool list
# 查看volumes
zfs list
# 从data pool创建文件系统
zfs create data/tank

# 获取data/tank的安装点
zfs get mountpoint data/tank
# 检查是否已挂载
zfs get mounted data/tank
zfs set mountpoint=/YOUR-MOUNT-POINT pool/fs
zfs set mountpoint=/my_vms data/tank
cd /my_vms
df /my_vms
zfs get mountpoint data/tank
zfs get mounted data/tank

# 使用-a选项可以挂载所有ZFS托管文件系统。
zfs mount -a
# 查看挂载情况
zfs mount
# 卸载ZFS文件系统
zfs unmount data/tank

# 加载已有pool
zpool import -f pool-vm

```

### virt-zfs support

```bash
apt install libvirt-daemon-driver-storage-zfs

# define Pool zfs-pool-vm
[virsh]
pool-define-as --name zfs-pool-vm --source-name filepool --type zfs
pool-start zfs-pool-vm
pool-info zfs-pool-vm
pool-autostart zfs-pool-vm
vol-list zfs-pool-vm

```

### qcow2 as zfs-vol && zfs-vol as qcow2

```bash
[virsh]
# img 2 zvol
vol-upload --pool zfs-pool-vm --vol vol1 --file /home/novel/FreeBSD-10.0-RELEASE-amd64-memstick.img
# zvol 2 img
vol-download --pool zfs-pool-vm --vol vol1 --file /home/novel/zfsfilepool_vol1.img
# create vol
vol-create-as --pool zfs-pool-vm --name vol2 --capacity 1G
# delete vol
vol-delete --pool zfs-pool-vm vol2

```

### libvirt

```bash
# Define VM
<disk type='volume' device='disk'>
    <source pool='zfs-pool-vm' volume='vol1'/>
    <target dev='vdb' bus='virtio'/>
</disk>

# Define Pool
<pool type='zfs'>
  <name>zfs-pool-vm</name>
  <uuid>ad0e1ea6-6ab8-4e06-a04a-631ac340539f</uuid>
  <capacity unit='bytes'>255550554112</capacity>
  <allocation unit='bytes'>16516222976</allocation>
  <available unit='bytes'>239034331136</available>
  <source>
    <name>pool-vm</name>
  </source>
  <target>
    <path>/dev/zvol/pool-vm</path>
  </target>
</pool>
```
