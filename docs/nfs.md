# NFS

## FreeBSD

```bash
service rpcbind enable
service nfsd enable
service mountd enable

service rpcbind start
service nfsd start
service mountd start
```

/etc/rc.conf

`mountd_flags=-r`
