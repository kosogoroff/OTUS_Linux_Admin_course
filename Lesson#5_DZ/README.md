# Занятие 20.07.2026 "NFS, FUSE"

Работа с NFS

## Цель:

научиться самостоятельно разворачивать сервис NFS и подключать к нему клиентов;

Описание/Пошаговая инструкция выполнения домашнего задания:

## 🎯 Что нужно сделать?

    запустить 2 виртуальных машины (сервер NFS и клиента);
    на сервере NFS должна быть подготовлена и экспортирована директория;
    в экспортированной директории должна быть поддиректория с именем upload с правами на запись в неё;
    экспортированная директория должна автоматически монтироваться на клиенте при старте виртуальной машины (systemd, autofs или fstab — любым способом);
    монтирование и работа NFS на клиенте должна быть организована с использованием NFSv3.

## ⭐️ Задание со звездочкой*

настроить аутентификацию через KERBEROS с использованием NFSv4

# Решение
0. Исходная конфигурация - в KVM запущено две ВМ : vm1-server (IP 192.168.122.176) и vm2-client (IP 192.168.122.186) )

Сервер:
```
kosogor@vm1-server:~$ ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host noprefixroute 
       valid_lft forever preferred_lft forever
2: enp1s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 52:54:00:b3:35:16 brd ff:ff:ff:ff:ff:ff
    inet 192.168.122.176/24 metric 100 brd 192.168.122.255 scope global dynamic enp1s0
       valid_lft 2989sec preferred_lft 2989sec
    inet6 fe80::5054:ff:feb3:3516/64 scope link 
       valid_lft forever preferred_lft forever
kosogor@vm1-server:~$
kosogor@vm1-server:~$ ip a show dev enp1s0 | grep "inet\|UP"
2: enp1s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    inet 192.168.122.176/24 metric 100 brd 192.168.122.255 scope global dynamic enp1s0
    inet6 fe80::5054:ff:feb3:3516/64 scope link 
kosogor@vm1-server:~$ 
```

Клиент:
```
kosogor@vm2-client:~$ ip a show dev enp1s0
2: enp1s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 52:54:00:79:72:ce brd ff:ff:ff:ff:ff:ff
    inet 192.168.122.186/24 metric 100 brd 192.168.122.255 scope global dynamic enp1s0
       valid_lft 2714sec preferred_lft 2714sec
    inet6 fe80::5054:ff:fe79:72ce/64 scope link 
       valid_lft forever preferred_lft forever
kosogor@vm2-client:~$ 
```
   
1.1 Настраиваем сервер NFS:

```
root@vm1-server:/home/kosogor# apt install nfs-kernel-server
Чтение списков пакетов… Готово
Построение дерева зависимостей… Готово
Чтение информации о состоянии… Готово         
Будут установлены следующие дополнительные пакеты:
  keyutils libnfsidmap1 nfs-common rpcbind
Предлагаемые пакеты:
  watchdog
Следующие НОВЫЕ пакеты будут установлены:
  keyutils libnfsidmap1 nfs-common nfs-kernel-server rpcbind
Обновлено 0 пакетов, установлено 5 новых пакетов, для удаления отмечено 0 пакетов, и 142 пакетов не обновлено.
Необходимо скачать 569 kB архивов.
После данной операции объём занятого дискового пространства возрастёт на 2 022 kB.
Хотите продолжить? [Д/н] y
Пол:1 http://us.archive.ubuntu.com/ubuntu noble-updates/main amd64 libnfsidmap1 amd64 1:2.6.4-3ubuntu5.1 [48,3 kB]
Пол:2 http://us.archive.ubuntu.com/ubuntu noble/main amd64 rpcbind amd64 1.2.6-7ubuntu2 [46,5 kB]
Пол:3 http://us.archive.ubuntu.com/ubuntu noble/main amd64 keyutils amd64 1.6.3-3build1 [56,8 kB]
Пол:4 http://us.archive.ubuntu.com/ubuntu noble-updates/main amd64 nfs-common amd64 1:2.6.4-3ubuntu5.1 [248 kB]
Пол:5 http://us.archive.ubuntu.com/ubuntu noble-updates/main amd64 nfs-kernel-server amd64 1:2.6.4-3ubuntu5.1 [169 kB]
Получено 569 kB за 2с (284 kB/s)             
Выбор ранее не выбранного пакета libnfsidmap1:amd64.
(Чтение базы данных … на данный момент установлено 84633 файла и каталога.)
Подготовка к распаковке …/libnfsidmap1_1%3a2.6.4-3ubuntu5.1_amd64.deb …
Распаковывается libnfsidmap1:amd64 (1:2.6.4-3ubuntu5.1) …
Выбор ранее не выбранного пакета rpcbind.
Подготовка к распаковке …/rpcbind_1.2.6-7ubuntu2_amd64.deb …
Распаковывается rpcbind (1.2.6-7ubuntu2) …
Выбор ранее не выбранного пакета keyutils.
Подготовка к распаковке …/keyutils_1.6.3-3build1_amd64.deb …
Распаковывается keyutils (1.6.3-3build1) …
Выбор ранее не выбранного пакета nfs-common.
Подготовка к распаковке …/nfs-common_1%3a2.6.4-3ubuntu5.1_amd64.deb …
Распаковывается nfs-common (1:2.6.4-3ubuntu5.1) …
Выбор ранее не выбранного пакета nfs-kernel-server.
Подготовка к распаковке …/nfs-kernel-server_1%3a2.6.4-3ubuntu5.1_amd64.deb …
Распаковывается nfs-kernel-server (1:2.6.4-3ubuntu5.1) …
Настраивается пакет libnfsidmap1:amd64 (1:2.6.4-3ubuntu5.1) …
Настраивается пакет rpcbind (1.2.6-7ubuntu2) …
Created symlink /etc/systemd/system/multi-user.target.wants/rpcbind.service → /usr/lib/systemd/system/rpcbind.servic
e.
Created symlink /etc/systemd/system/sockets.target.wants/rpcbind.socket → /usr/lib/systemd/system/rpcbind.socket.
Настраивается пакет keyutils (1.6.3-3build1) …
Настраивается пакет nfs-common (1:2.6.4-3ubuntu5.1) …

Creating config file /etc/idmapd.conf with new version

Creating config file /etc/nfs.conf with new version
info: Selecting UID from range 100 to 999 ...

info: Adding system user `statd' (UID 111) ...
info: Adding new user `statd' (UID 111) with group `nogroup' ...
info: Not creating home directory `/var/lib/nfs'.
Created symlink /etc/systemd/system/multi-user.target.wants/nfs-client.target → /usr/lib/systemd/system/nfs-client.t
arget.
Created symlink /etc/systemd/system/remote-fs.target.wants/nfs-client.target → /usr/lib/systemd/system/nfs-client.ta
rget.
auth-rpcgss-module.service is a disabled or a static unit, not starting it.
nfs-idmapd.service is a disabled or a static unit, not starting it.
nfs-utils.service is a disabled or a static unit, not starting it.
proc-fs-nfsd.mount is a disabled or a static unit, not starting it.
rpc-gssd.service is a disabled or a static unit, not starting it.
rpc-statd-notify.service is a disabled or a static unit, not starting it.
rpc-statd.service is a disabled or a static unit, not starting it.
rpc-svcgssd.service is a disabled or a static unit, not starting it.
Настраивается пакет nfs-kernel-server (1:2.6.4-3ubuntu5.1) …
Created symlink /etc/systemd/system/nfs-mountd.service.requires/fsidd.service → /usr/lib/systemd/system/fsidd.servic
e.
Created symlink /etc/systemd/system/nfs-server.service.requires/fsidd.service → /usr/lib/systemd/system/fsidd.servic
e.
Created symlink /etc/systemd/system/nfs-client.target.wants/nfs-blkmap.service → /usr/lib/systemd/system/nfs-blkmap.
service.
Created symlink /etc/systemd/system/multi-user.target.wants/nfs-server.service → /usr/lib/systemd/system/nfs-server.
service.
nfs-mountd.service is a disabled or a static unit, not starting it.
nfsdcld.service is a disabled or a static unit, not starting it.

Creating config file /etc/exports with new version

Creating config file /etc/default/nfs-kernel-server with new version
Обрабатываются триггеры для man-db (2.12.0-4build2) …
Обрабатываются триггеры для libc-bin (2.39-0ubuntu8.7) …
Scanning processes...                                                                                               
Scanning linux images...                                                                                            

Running kernel seems to be up-to-date.

No services need to be restarted.

No containers need to be restarted.

No user sessions are running outdated binaries.

No VM guests are running outdated hypervisor (qemu) binaries on this host.
root@vm1-server:/home/kosogor# 
root@vm1-server:/home/kosogor# 
root@vm1-server:/home/kosogor# ss -tnplu | grep "2049\|111"
udp   UNCONN 0      0                     0.0.0.0:111        0.0.0.0:*    users:(("rpcbind",pid=1422,fd=5),("systemd",pid=1,fd=113))
udp   UNCONN 0      0                        [::]:111           [::]:*    users:(("rpcbind",pid=1422,fd=7),("systemd",pid=1,fd=116))
tcp   LISTEN 0      64                    0.0.0.0:2049       0.0.0.0:*                                                              
tcp   LISTEN 0      4096                  0.0.0.0:111        0.0.0.0:*    users:(("rpcbind",pid=1422,fd=4),("systemd",pid=1,fd=112))
tcp   LISTEN 0      64                       [::]:2049          [::]:*                                                              
tcp   LISTEN 0      4096                     [::]:111           [::]:*    users:(("rpcbind",pid=1422,fd=6),("systemd",pid=1,fd=114))
root@vm1-server:/home/kosogor# 
root@vm1-server:/home/kosogor# mkdir -p /srv/share/upload
root@vm1-server:/home/kosogor# chown -R nobody:nogroup /srv/share
root@vm1-server:/home/kosogor# chmod 0777 /srv/share/upload
root@vm1-server:/home/kosogor# 
root@vm1-server:/home/kosogor# cat /etc/exports
# /etc/exports: the access control list for filesystems which may be exported
#		to NFS clients.  See exports(5).
#
# Example for NFSv2 and NFSv3:
# /srv/homes       hostname1(rw,sync,no_subtree_check) hostname2(ro,sync,no_subtree_check)
#
# Example for NFSv4:
# /srv/nfs4        gss/krb5i(rw,sync,fsid=0,crossmnt,no_subtree_check)
# /srv/nfs4/homes  gss/krb5i(rw,sync,no_subtree_check)
#
root@vm1-server:/home/kosogor# 
root@vm1-server:/home/kosogor# cat << EOF >> /etc/exports 
/srv/share 192.168.122.186/32(rw,sync,root_squash)
EOF
root@vm1-server:/home/kosogor# 
root@vm1-server:/home/kosogor# cat /etc/exports
# /etc/exports: the access control list for filesystems which may be exported
#		to NFS clients.  See exports(5).
#
# Example for NFSv2 and NFSv3:
# /srv/homes       hostname1(rw,sync,no_subtree_check) hostname2(ro,sync,no_subtree_check)
#
# Example for NFSv4:
# /srv/nfs4        gss/krb5i(rw,sync,fsid=0,crossmnt,no_subtree_check)
# /srv/nfs4/homes  gss/krb5i(rw,sync,no_subtree_check)
#
/srv/share 192.168.122.186/32(rw,sync,root_squash)
root@vm1-server:/home/kosogor# 
root@vm1-server:/home/kosogor# exportfs -s
root@vm1-server:/home/kosogor# 
root@vm1-server:/home/kosogor# exportfs -r
exportfs: /etc/exports [1]: Neither 'subtree_check' or 'no_subtree_check' specified for export "192.168.122.186/32:/srv/share".
  Assuming default behaviour ('no_subtree_check').
  NOTE: this default has changed since nfs-utils version 1.0.x

root@vm1-server:/home/kosogor# exportfs -s
/srv/share  192.168.122.186/32(sync,wdelay,hide,no_subtree_check,sec=sys,rw,secure,root_squash,no_all_squash)
root@vm1-server:/home/kosogor#
```

1.2 Настраиваем клиент:

```
kosogor@vm2-client:~$ sudo apt install nfs-common
[sudo] password for kosogor: 
Чтение списков пакетов… Готово
Построение дерева зависимостей… Готово
Чтение информации о состоянии… Готово         
Будут установлены следующие дополнительные пакеты:
  keyutils libnfsidmap1 rpcbind
Предлагаемые пакеты:
  watchdog
Следующие НОВЫЕ пакеты будут установлены:
  keyutils libnfsidmap1 nfs-common rpcbind
Обновлено 0 пакетов, установлено 4 новых пакетов, для удаления отмечено 0 пакетов, и 142 пакетов не обновлено.
Необходимо скачать 400 kB архивов.
После данной операции объём занятого дискового пространства возрастёт на 1 416 kB.
Хотите продолжить? [Д/н] y
Пол:1 http://us.archive.ubuntu.com/ubuntu noble-updates/main amd64 libnfsidmap1 amd64 1:2.6.4-3ubuntu5.1 [48,3 kB]
Пол:2 http://us.archive.ubuntu.com/ubuntu noble/main amd64 rpcbind amd64 1.2.6-7ubuntu2 [46,5 kB]
Пол:3 http://us.archive.ubuntu.com/ubuntu noble/main amd64 keyutils amd64 1.6.3-3build1 [56,8 kB]
Пол:4 http://us.archive.ubuntu.com/ubuntu noble-updates/main amd64 nfs-common amd64 1:2.6.4-3ubuntu5.1 [248 kB]
Получено 400 kB за 2с (200 kB/s)           
Выбор ранее не выбранного пакета libnfsidmap1:amd64.
(Чтение базы данных … на данный момент установлено 84633 файла и каталога.)
Подготовка к распаковке …/libnfsidmap1_1%3a2.6.4-3ubuntu5.1_amd64.deb …
Распаковывается libnfsidmap1:amd64 (1:2.6.4-3ubuntu5.1) …
Выбор ранее не выбранного пакета rpcbind.
Подготовка к распаковке …/rpcbind_1.2.6-7ubuntu2_amd64.deb …
Распаковывается rpcbind (1.2.6-7ubuntu2) …
Выбор ранее не выбранного пакета keyutils.
Подготовка к распаковке …/keyutils_1.6.3-3build1_amd64.deb …
Распаковывается keyutils (1.6.3-3build1) …
Выбор ранее не выбранного пакета nfs-common.
Подготовка к распаковке …/nfs-common_1%3a2.6.4-3ubuntu5.1_amd64.deb …
Распаковывается nfs-common (1:2.6.4-3ubuntu5.1) …
Настраивается пакет libnfsidmap1:amd64 (1:2.6.4-3ubuntu5.1) …
Настраивается пакет rpcbind (1.2.6-7ubuntu2) …
Created symlink /etc/systemd/system/multi-user.target.wants/rpcbind.service → /usr/lib/systemd/system/rpc
bind.service.
Created symlink /etc/systemd/system/sockets.target.wants/rpcbind.socket → /usr/lib/systemd/system/rpcbind
.socket.
Настраивается пакет keyutils (1.6.3-3build1) …
Настраивается пакет nfs-common (1:2.6.4-3ubuntu5.1) …

Creating config file /etc/idmapd.conf with new version

Creating config file /etc/nfs.conf with new version
info: Selecting UID from range 100 to 999 ...

info: Adding system user `statd' (UID 111) ...
info: Adding new user `statd' (UID 111) with group `nogroup' ...
info: Not creating home directory `/var/lib/nfs'.
Created symlink /etc/systemd/system/multi-user.target.wants/nfs-client.target → /usr/lib/systemd/system/n
fs-client.target.
Created symlink /etc/systemd/system/remote-fs.target.wants/nfs-client.target → /usr/lib/systemd/system/nf
s-client.target.
auth-rpcgss-module.service is a disabled or a static unit, not starting it.
nfs-idmapd.service is a disabled or a static unit, not starting it.
nfs-utils.service is a disabled or a static unit, not starting it.
proc-fs-nfsd.mount is a disabled or a static unit, not starting it.
rpc-gssd.service is a disabled or a static unit, not starting it.
rpc-statd-notify.service is a disabled or a static unit, not starting it.
rpc-statd.service is a disabled or a static unit, not starting it.
rpc-svcgssd.service is a disabled or a static unit, not starting it.
Обрабатываются триггеры для man-db (2.12.0-4build2) …
Обрабатываются триггеры для libc-bin (2.39-0ubuntu8.7) …
Scanning processes...                                                                                    
Scanning linux images...                                                                                 

Running kernel seems to be up-to-date.

No services need to be restarted.

No containers need to be restarted.

No user sessions are running outdated binaries.

No VM guests are running outdated hypervisor (qemu) binaries on this host.
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ cat /etc/fstab
# /etc/fstab: static file system information.
#
# Use 'blkid' to print the universally unique identifier for a
# device; this may be used with UUID= as a more robust way to name devices
# that works even if disks are added and removed. See fstab(5).
#
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
# / was on /dev/ubuntu-vg/ubuntu-lv during curtin installation
/dev/disk/by-id/dm-uuid-LVM-Rbodyz3buDerPcLStwdQBbt9gJROubqfrd1RbzWCuQewPu7D99emGkse102wChLp / ext4 defaults 0 1
# /boot was on /dev/vda2 during curtin installation
/dev/disk/by-uuid/cc0344dc-7352-46de-acfa-f8b2e51180ae /boot ext4 defaults 0 1
/swap.img	none	swap	sw	0	0
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ sudo su
root@vm2-client:/home/kosogor# echo "192.168.122.176:/srv/share/ /mnt1 nfs vers=3,noauto,x-systemd.automount 0 0" >> /etc/fstab
root@vm2-client:/home/kosogor# 
root@vm2-client:/home/kosogor# exit
exit
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ cat /etc/fstab
# /etc/fstab: static file system information.
#
# Use 'blkid' to print the universally unique identifier for a
# device; this may be used with UUID= as a more robust way to name devices
# that works even if disks are added and removed. See fstab(5).
#
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
# / was on /dev/ubuntu-vg/ubuntu-lv during curtin installation
/dev/disk/by-id/dm-uuid-LVM-Rbodyz3buDerPcLStwdQBbt9gJROubqfrd1RbzWCuQewPu7D99emGkse102wChLp / ext4 defaults 0 1
# /boot was on /dev/vda2 during curtin installation
/dev/disk/by-uuid/cc0344dc-7352-46de-acfa-f8b2e51180ae /boot ext4 defaults 0 1
/swap.img	none	swap	sw	0	0
192.168.122.176:/srv/share/ /mnt1 nfs vers=3,noauto,x-systemd.automount 0 0
kosogor@vm2-client:~$
kosogor@vm2-client:~$ systemctl daemon-reload
==== AUTHENTICATING FOR org.freedesktop.systemd1.reload-daemon ====
Authentication is required to reload the systemd state.
Authenticating as: Eugene Kosogorov (kosogor)
Password: 
==== AUTHENTICATION COMPLETE ====
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ systemctl restart remote-fs.target
==== AUTHENTICATING FOR org.freedesktop.systemd1.manage-units ====
Authentication is required to restart 'remote-fs.target'.
Authenticating as: Eugene Kosogorov (kosogor)
Password: 
==== AUTHENTICATION COMPLETE ====
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ mount | grep mnt1
systemd-1 on /mnt1 type autofs (rw,relatime,fd=68,pgrp=1,timeout=0,minproto=5,maxproto=5,direct,pipe_ino=15540)
kosogor@vm2-client:~$ ll /mnt1
total 12
drwxr-xr-x  3 nobody nogroup 4096 июл 23 08:31 ./
drwxr-xr-x 24 root   root    4096 июл 23 08:54 ../
drwxrwxrwx  2 nobody nogroup 4096 июл 23 08:31 upload/
kosogor@vm2-client:~$ 
```

2. Проверка работоспособности
   
- Заходим на сервер.
  
     -- Заходим в каталог /srv/share/upload.

     -- Создаём тестовый файл touch check_file.

- Заходим на клиент.
  
     -- Заходим в каталог /mnt/upload. 

     -- Проверяем наличие ранее созданного файла.

     -- Создаём тестовый файл touch client_file. 

     --  Проверяем, что файл успешно создан.

```
root@vm1-server:/home/kosogor# touch /srv/share/upload/check_file
root@vm1-server:/home/kosogor# ll /srv/share/upload
total 8
drwxrwxrwx 2 nobody nogroup 4096 июл 23 08:58 ./
drwxr-xr-x 3 nobody nogroup 4096 июл 23 08:31 ../
-rw-r--r-- 1 root   root       0 июл 23 08:58 check_file
root@vm1-server:/home/kosogor# 
root@vm1-server:/home/kosogor#


kosogor@vm2-client:~$ ll /mnt1
total 12
drwxr-xr-x  3 nobody nogroup 4096 июл 23 08:31 ./
drwxr-xr-x 24 root   root    4096 июл 23 08:54 ../
drwxrwxrwx  2 nobody nogroup 4096 июл 23 08:31 upload/
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ ll /mnt1/upload
total 8
drwxrwxrwx 2 nobody nogroup 4096 июл 23 08:58 ./
drwxr-xr-x 3 nobody nogroup 4096 июл 23 08:31 ../
-rw-r--r-- 1 root   root       0 июл 23 08:58 check_file
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ touch /mnt1/upload/client_file
kosogor@vm2-client:~$ ll /mnt1/upload
total 8
drwxrwxrwx 2 nobody  nogroup 4096 июл 23 08:58 ./
drwxr-xr-x 3 nobody  nogroup 4096 июл 23 08:31 ../
-rw-r--r-- 1 root    root       0 июл 23 08:58 check_file
-rw-rw-r-- 1 kosogor kosogor    0 июл 23 08:58 client_file
kosogor@vm2-client:~$

root@vm1-server:/home/kosogor# ll /srv/share/upload
total 8
drwxrwxrwx 2 nobody  nogroup 4096 июл 23 08:58 ./
drwxr-xr-x 3 nobody  nogroup 4096 июл 23 08:31 ../
-rw-r--r-- 1 root    root       0 июл 23 08:58 check_file
-rw-rw-r-- 1 kosogor kosogor    0 июл 23 08:58 client_file
root@vm1-server:/home/kosogor# 
```

3. Предварительно проверяем клиент:
   
- перезагружаем клиент;
  
- заходим на клиент;
  
- заходим в каталог /mnt/upload;
  
- проверяем наличие ранее созданных файлов.

```
kosogor@vm2-client:~$ ll /mnt1/upload
total 8
drwxrwxrwx 2 nobody  nogroup 4096 июл 23 08:58 ./
drwxr-xr-x 3 nobody  nogroup 4096 июл 23 08:31 ../
-rw-r--r-- 1 root    root       0 июл 23 08:58 check_file
-rw-rw-r-- 1 kosogor kosogor    0 июл 23 08:58 client_file
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ sudo reboot

Broadcast message from root@vm2-client on pts/1 (Thu 2026-07-23 08:59:40 UTC):

The system will reboot now!

kosogor@vm2-client:~$ Connection to 192.168.122.186 closed by remote host.
Connection to 192.168.122.186 closed.
[admin_insta11@mv334 ~]$ ssh kosogor@192.168.122.186
kosogor@192.168.122.186's password: 
Welcome to Ubuntu 24.04.4 LTS (GNU/Linux 6.8.0-100-generic x86_64)

Last login: Thu Jul 23 07:21:39 2026 from 192.168.122.1
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ ll /mnt1/upload
total 8
drwxrwxrwx 2 nobody  nogroup 4096 июл 23 08:58 ./
drwxr-xr-x 3 nobody  nogroup 4096 июл 23 08:31 ../
-rw-r--r-- 1 root    root       0 июл 23 08:58 check_file
-rw-rw-r-- 1 kosogor kosogor    0 июл 23 08:58 client_file
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ mount | grep mnt1
systemd-1 on /mnt1 type autofs (rw,relatime,fd=58,pgrp=1,timeout=0,minproto=5,maxproto=5,direct,pipe_ino=3662)
192.168.122.176:/srv/share/ on /mnt1 type nfs (rw,relatime,vers=3,rsize=524288,wsize=524288,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,mountaddr=192.168.122.176,mountvers=3,mountport=33622,mountproto=udp,local_lock=none,addr=192.168.122.176)
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ 
```

4. Проверяем сервер:
   
- заходим на сервер в отдельном окне терминала;
  
- перезагружаем сервер;
  
- заходим на сервер;
  
- проверяем наличие файлов в каталоге /srv/share/upload/;
  
- проверяем экспорты exportfs -s;
  
- проверяем работу RPC showmount -a 192.168.122.176.

```
root@vm1-server:/home/kosogor# ll /srv/share/upload
total 8
drwxrwxrwx 2 nobody  nogroup 4096 июл 23 08:58 ./
drwxr-xr-x 3 nobody  nogroup 4096 июл 23 08:31 ../
-rw-r--r-- 1 root    root       0 июл 23 08:58 check_file
-rw-rw-r-- 1 kosogor kosogor    0 июл 23 08:58 client_file
root@vm1-server:/home/kosogor# 
root@vm1-server:/home/kosogor# 
root@vm1-server:/home/kosogor# sudo reboot

Broadcast message from root@vm1-server on pts/2 (Thu 2026-07-23 09:00:38 UTC):

The system will reboot now!


Broadcast message from root@vm1-server on pts/2 (Thu 2026-07-23 09:00:38 UTC):

The system will reboot now!

root@vm1-server:/home/kosogor# Connection to 192.168.122.176 closed by remote host.
Connection to 192.168.122.176 closed.
[root@mv334 iso]# 
[root@mv334 iso]# ssh kosogor@192.168.122.176
kosogor@192.168.122.176's password: 
Welcome to Ubuntu 24.04.4 LTS (GNU/Linux 6.8.0-100-generic x86_64)

Last login: Thu Jul 23 07:21:27 2026 from 192.168.122.1
kosogor@vm1-server:~$ 
kosogor@vm1-server:~$ 
kosogor@vm1-server:~$ sudo su
[sudo] password for kosogor: 
root@vm1-server:/home/kosogor# 
root@vm1-server:/home/kosogor# ll /srv/share/upload
total 8
drwxrwxrwx 2 nobody  nogroup 4096 июл 23 08:58 ./
drwxr-xr-x 3 nobody  nogroup 4096 июл 23 08:31 ../
-rw-r--r-- 1 root    root       0 июл 23 08:58 check_file
-rw-rw-r-- 1 kosogor kosogor    0 июл 23 08:58 client_file
root@vm1-server:/home/kosogor# 
root@vm1-server:/home/kosogor# exportfs -s
/srv/share  192.168.122.186/32(sync,wdelay,hide,no_subtree_check,sec=sys,rw,secure,root_squash,no_all_squash)
root@vm1-server:/home/kosogor# 
root@vm1-server:/home/kosogor# showmount -a 192.168.122.176
All mount points on 192.168.122.176:
192.168.122.186:/srv/share
root@vm1-server:/home/kosogor# 
```

4. Проверяем клиент:
   
- возвращаемся на клиент;
  
- перезагружаем клиент;
  
- заходим на клиент;
  
- проверяем работу RPC showmount -a 192.168.122.176;
  
- заходим в каталог /mnt/upload;
  
     -- проверяем статус монтирования mount | grep mnt;

     -- проверяем наличие ранее созданных файлов;

     -- создаём тестовый файл touch final_check;

     -- проверяем, что файл успешно создан.

```
kosogor@vm2-client:~$ ll /mnt1/upload
total 8
drwxrwxrwx 2 nobody  nogroup 4096 июл 23 08:58 ./
drwxr-xr-x 3 nobody  nogroup 4096 июл 23 08:31 ../
-rw-r--r-- 1 root    root       0 июл 23 08:58 check_file
-rw-rw-r-- 1 kosogor kosogor    0 июл 23 08:58 client_file
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ sudo reboot

Broadcast message from root@vm2-client on pts/1 (Thu 2026-07-23 08:59:40 UTC):

The system will reboot now!

kosogor@vm2-client:~$ Connection to 192.168.122.186 closed by remote host.
Connection to 192.168.122.186 closed.
[admin_insta11@mv334 ~]$ ssh kosogor@192.168.122.186
kosogor@192.168.122.186's password: 
Welcome to Ubuntu 24.04.4 LTS (GNU/Linux 6.8.0-100-generic x86_64)

Last login: Thu Jul 23 07:21:39 2026 from 192.168.122.1
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ ll /mnt1/upload
total 8
drwxrwxrwx 2 nobody  nogroup 4096 июл 23 08:58 ./
drwxr-xr-x 3 nobody  nogroup 4096 июл 23 08:31 ../
-rw-r--r-- 1 root    root       0 июл 23 08:58 check_file
-rw-rw-r-- 1 kosogor kosogor    0 июл 23 08:58 client_file
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ mount | grep mnt1
systemd-1 on /mnt1 type autofs (rw,relatime,fd=58,pgrp=1,timeout=0,minproto=5,maxproto=5,direct,pipe_ino=3662)
192.168.122.176:/srv/share/ on /mnt1 type nfs (rw,relatime,vers=3,rsize=524288,wsize=524288,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,mountaddr=192.168.122.176,mountvers=3,mountport=33622,mountproto=udp,local_lock=none,addr=192.168.122.176)
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ showmount -a 192.168.122.176
All mount points on 192.168.122.176:
192.168.122.186:/srv/share
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ cd /mnt/upload
-bash: cd: /mnt/upload: No such file or directory
kosogor@vm2-client:~$ cd /mnt1/upload
kosogor@vm2-client:/mnt1/upload$ 
kosogor@vm2-client:/mnt1/upload$ mount | grep mnt
systemd-1 on /mnt1 type autofs (rw,relatime,fd=58,pgrp=1,timeout=0,minproto=5,maxproto=5,direct,pipe_ino=3662)
192.168.122.176:/srv/share/ on /mnt1 type nfs (rw,relatime,vers=3,rsize=524288,wsize=524288,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,mountaddr=192.168.122.176,mountvers=3,mountport=33622,mountproto=udp,local_lock=none,addr=192.168.122.176)
kosogor@vm2-client:/mnt1/upload$ 
kosogor@vm2-client:/mnt1/upload$ touch final_check
kosogor@vm2-client:/mnt1/upload$ ll
total 8
drwxrwxrwx 2 nobody  nogroup 4096 июл 23 09:03 ./
drwxr-xr-x 3 nobody  nogroup 4096 июл 23 08:31 ../
-rw-r--r-- 1 root    root       0 июл 23 08:58 check_file
-rw-rw-r-- 1 kosogor kosogor    0 июл 23 08:58 client_file
-rw-rw-r-- 1 kosogor kosogor    0 июл 23 09:03 final_check
kosogor@vm2-client:/mnt1/upload$ 


root@vm1-server:/home/kosogor# 
root@vm1-server:/home/kosogor# ll /srv/share/upload
total 8
drwxrwxrwx 2 nobody  nogroup 4096 июл 23 09:03 ./
drwxr-xr-x 3 nobody  nogroup 4096 июл 23 08:31 ../
-rw-r--r-- 1 root    root       0 июл 23 08:58 check_file
-rw-rw-r-- 1 kosogor kosogor    0 июл 23 08:58 client_file
-rw-rw-r-- 1 kosogor kosogor    0 июл 23 09:03 final_check
root@vm1-server:/home/kosogor# 
```

## 5. Создание двух скриптов для автоматизированного экспортирования директорий NFS на сервере и автоматизированного монтирования директорий NFS на клиенте

Далее необходимо создать два bash-скрипта:
- nfss_script.sh — для конфигурирования сервера
- nfsc_script.sh — для конфигурирования клиента, в которых описать bash-командами ранее выполненные шаги.

### 1) Созданные скрипты:

на сервере:

```
$ cat nfss_script.sh
#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Ошибка: неверный формат аргументов." >&2
  echo "Использование: $0 {-a|-d} <директория для экспортирования> [<client_ip_address/mask>]" >&2
  echo "  -a  — добавить экспорт директории по NFS" >&2
  echo "  -d  — удалить экспорт директории по NFS" >&2
  exit 1
}

check_directory() {
  local path="${export_dir}"
  local dirpath

  dirpath="$(dirname -- "${path}")"

  if [[ ! -d "${dirpath}" ]]; then
    echo "Директория не существует: ${dirpath}" >&2
    return 1
  else
    echo "Директория существует: ${dirpath}"
    return 0
  fi
}

# проверяем, что скрипт выполняется с правами root
if [[ $EUID -ne 0 ]]; then
  echo "Error: скрипт нужно запускать от root (например, через sudo)" >&2
  exit 1
fi

# Проверка количества аргументов
if [[ $# -lt 2 || $# -gt 3 ]]; then
  usage
fi

action="$1"
export_dir="$2"
ip_addr="${3:-*}"
server_ip=192.168.122.176

# Валидация первого аргумента
case "$action" in
  -a)
    # Сначала создаем и проверяем директорию
    mkdir -p $export_dir
    chown -R nobody:nogroup $export_dir
    chmod 0777 $export_dir

    if ! check_directory "${export_dir}"; then
       echo "Not added to NFS exports !"
       exit 1
    fi

    echo "Adding directory $export_dir to /etc/exports ..."

    # Сначала удаляем существующий экспорт этой директории, если он уже есть
    sed -i "\|${export_dir}|d" /etc/exports

    # Добавляем в файл /etc/exports
    cat << EOF >> /etc/exports
$export_dir ${ip_addr}(rw,sync,root_squash)
EOF

    # обновляем экспортируемые директории
    exportfs -r > /dev/null 2>&1
   
    # и выводим результаты
    echo
    echo "The following share added to NFS server configuration:"
    exportfs -s | grep ${export_dir}
    ;;
  -d)
    echo "Deletting directory $export_dir from /etc/exports ..."
    sed -i "\|${export_dir} |d" /etc/exports

    # обновляем экспортируемые директории
    exportfs -r > /dev/null 2>&1

    echo "Deleted ${export_dir}"
    ;;
  *)
    usage
    ;;
esac

# и выводим результаты

    echo
    echo "Available shared directories on the NFS server $server_ip :"
    showmount -e $server_ip



kosogor@vm1-server:~$
```

На клиенте:

```
kosogor@vm2-client:~$ cat nfsc_script.sh
#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Ошибка: неверный формат аргументов." >&2
  echo "Использование: $0 {-a|-d} <IP-адрес сервера NFS> <директория NFS-сервера> <точка_монтирования>" >&2
  echo "  -a  — примонтировать директорию сервера по NFS" >&2
  echo "  -d  — удалить монтирование директории по NFS" >&2
  exit 1
}

check_directory() {
  local path="${mount_point}"
  local dirpath

  dirpath="$(dirname -- "${path}")"

  if [[ ! -d "${dirpath}" ]]; then
    echo "Директория не существует: ${dirpath}" >&2
    return 1
  else
    return 0
  fi
}

# проверяем, что скрипт выполняется с правами root
if [[ $EUID -ne 0 ]]; then
  echo "Error: скрипт нужно запускать от root (например, через sudo)" >&2
  exit 1
fi

# Проверка количества аргументов
if [[ $# -ne 4 ]]; then
  usage
fi

action="$1"
export_dir="$3"
server_ip="$2"
mount_point="$4"

# Валидация первого аргумента
case "$action" in
  -a)
    # Сначала создаем и проверяем точку монтирования
    mkdir -p $mount_point

    if ! check_directory "${mount_point}"; then
       echo "Mount-point directory cannot be created !"
       exit 1
    fi

    # Проверяем наличие NFS mount на сервере
    if [[ $(showmount -e ${server_ip} | grep "${export_dir}") == "" ]]; then 
       echo "Error: На сервере ${server_ip} отсутствует NFS директория ${export_dir} !"; 
       echo
       echo "На сервере ${server_ip} имеются следующие NFS директории, доступные для монтирования :"
       showmount -e ${server_ip}
       exit 1
    fi

    
    echo "Монтируем NFS-директорию $export_dir в ${mount_point} ..."
   # umount ${mount_point} > /dev/null 2>&1
    mount -t nfs ${server_ip}:${export_dir} ${mount_point}

    # добавляем в /etc/fstab
    sed -i "\|${server_ip}:${export_dir} ${mount_point} |d" /etc/fstab
    echo "${server_ip}:${export_dir} ${mount_point} nfs vers=3,noauto,x-systemd.automount 0 0" >> /etc/fstab
   
    systemctl daemon-reload
    systemctl restart remote-fs.target
    # и выводим результаты
    echo
    echo "Примонтирована NFS директория :"
    mount -l | grep ${export_dir}
    echo
    echo "В файле /etc/fstab :"
    cat /etc/fstab | grep ${export_dir}
    ;;
  -d)
    echo "Отмонтирование NFS директории $export_dir ..."
    sed -i "\|${server_ip}:${export_dir} ${mount_point} |d" /etc/fstab
    systemctl daemon-reload
    systemctl restart remote-fs.target
    umount ${mount_point} > /dev/null 2>&1

    echo "Отмонтирована ${export_dir}"
    ;;
  *)
    usage
    ;;
esac
```

### 2) Проверяем работу созданных скриптов

На сервере NFS создаём и экспортируем скриптом две директории - на клиенте они становятся видны.
Затем вторым скриптом монтируем эти две директории на клиентской машине.
Далее в каждой из подмонтированных директорий создаём по два файла: один со стороны клиента, 
второй со стороны сервера. Проверяем, что оба файла видны и на клиенте, и на сервере.
Наконец, отмонтируем директории на клиенте тем же скриптом и удаляем экспорт директорий на сервере тем же скриптом.

Экспортируем первую директорию на сервере скриптом:
```
kosogor@vm1-server:~$ ./nfss_script.sh -a /srv/share/tmp1
Error: скрипт нужно запускать от root (например, через sudo)
kosogor@vm1-server:~$ 
kosogor@vm1-server:~$ sudo ./nfss_script.sh -a /srv/share/tmp1
[sudo] password for kosogor: 
Директория существует: /srv/share
Adding directory /srv/share/tmp1 to /etc/exports ...

The following share added to NFS server configuration:
/srv/share/tmp1  *(sync,wdelay,hide,no_subtree_check,sec=sys,rw,secure,root_squash,no_all_squash)

Available shared directories on the NFS server 192.168.122.176 :
Export list for 192.168.122.176:
/srv/share/tmp1 *
kosogor@vm1-server:~$ 
kosogor@vm1-server:~$ sudo ./nfss_script.sh -a /srv/share/tmp1 192.168.122.186/32
Директория существует: /srv/share
Adding directory /srv/share/tmp1 to /etc/exports ...

The following share added to NFS server configuration:
/srv/share/tmp1  192.168.122.186/32(sync,wdelay,hide,no_subtree_check,sec=sys,rw,secure,root_squash,no_all_squash)

Available shared directories on the NFS server 192.168.122.176 :
Export list for 192.168.122.176:
/srv/share/tmp1 192.168.122.186/32
kosogor@vm1-server:~$
kosogor@vm1-server:~$ ll /srv/share/tmp1
total 8
drwxrwxrwx 2 nobody nogroup 4096 июл 24 19:09 ./
drwxr-xr-x 4 nobody nogroup 4096 июл 23 10:36 ../
kosogor@vm1-server:~$
```

Примонтируем её скриптом на клиенте, после перезагрузки клиента монтирование сохраняется:

```
kosogor@vm2-client:~$ sudo ./nfsc_script.sh -a 192.168.122.176 /srv/share/tmp1 /mnt3
[sudo] password for kosogor: 
Монтируем NFS-директорию /srv/share/tmp1 в /mnt3 ...

Примонтирована NFS директория :
192.168.122.176:/srv/share/tmp1 on /mnt3 type nfs4 (rw,relatime,vers=4.2,rsize=524288,wsize=524288,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,clientaddr=192.168.122.186,local_lock=none,addr=192.168.122.176)

В файле /etc/fstab :
192.168.122.176:/srv/share/tmp1 /mnt3 nfs vers=3,noauto,x-systemd.automount 0 0
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ mount -l | grep mnt3
192.168.122.176:/srv/share/tmp1 on /mnt3 type nfs4 (rw,relatime,vers=4.2,rsize=524288,wsize=524288,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,clientaddr=192.168.122.186,local_lock=none,addr=192.168.122.176)
kosogor@vm2-client:~$ sudo reboot

Broadcast message from root@vm2-client on pts/1 (Fri 2026-07-24 19:07:47 UTC):

The system will reboot now!

kosogor@vm2-client:~$ Connection to 192.168.122.186 closed by remote host.
Connection to 192.168.122.186 closed.
[admin_insta11@mv334 ~]$ 
[admin_insta11@mv334 ~]$ ssh kosogor@192.168.122.186
kosogor@192.168.122.186's password: 
Welcome to Ubuntu 24.04.4 LTS (GNU/Linux 6.8.0-136-generic x86_64)

Last login: Thu Jul 23 09:00:00 2026 from 192.168.122.1
kosogor@vm2-client:~$ mount -l | grep mnt3
systemd-1 on /mnt3 type autofs (rw,relatime,fd=69,pgrp=1,timeout=0,minproto=5,maxproto=5,direct,pipe_ino=5323)
kosogor@vm2-client:~$
```

Создаём в директории два файла: один со стороны клиента, другой со стороны сервера - оба файла видны и со тороны клиента, и со стороны сервера:

```
kosogor@vm2-client:~$ ll /mnt3
total 8
drwxrwxrwx  2 nobody nogroup 4096 июл 24 19:09 ./
drwxr-xr-x 26 root   root    4096 июл 24 18:28 ../
kosogor@vm2-client:~$


kosogor@vm2-client:~$ cat > created_fron_client.txt
1234567890
kosogor@vm2-client:~$

kosogor@vm1-server:~$ cat > created_fron_server.txt
0987654321
kosogor@vm1-server:~$ 
kosogor@vm1-server:~$ 
kosogor@vm1-server:~$ ll /srv/share/tmp1
total 16
drwxrwxrwx 2 nobody  nogroup 4096 июл 24 19:14 ./
drwxr-xr-x 4 nobody  nogroup 4096 июл 23 10:36 ../
-rw-rw-r-- 1 kosogor kosogor   11 июл 24 19:14 created_from_server.txt
-rw-rw-r-- 1 kosogor kosogor   11 июл 24 19:14 created_fron_client.txt
kosogor@vm1-server:~$


kosogor@vm2-client:~$ ll /mnt3
total 16
drwxrwxrwx  2 nobody  nogroup 4096 июл 24 19:14 ./
drwxr-xr-x 26 root    root    4096 июл 24 18:28 ../
-rw-rw-r--  1 kosogor kosogor   11 июл 24 19:14 created_from_server.txt
-rw-rw-r--  1 kosogor kosogor   11 июл 24 19:14 created_fron_client.txt
kosogor@vm2-client:~$
```

Аналогично экспортируем ещё одну директорию на сервере и монтируем её на клиенте созданныеми скриптами, также создаём
в ней два файла:

```
kosogor@vm1-server:~$ sudo ./nfss_script.sh -a /srv/share/tmp3
Директория существует: /srv/share
Adding directory /srv/share/tmp3 to /etc/exports ...

The following share added to NFS server configuration:
/srv/share/tmp3  *(sync,wdelay,hide,no_subtree_check,sec=sys,rw,secure,root_squash,no_all_squash)

Available shared directories on the NFS server 192.168.122.176 :
Export list for 192.168.122.176:
/srv/share/tmp3 *
/srv/share/tmp1 192.168.122.186/32
kosogor@vm1-server:~$


kosogor@vm2-client:~$ showmount -e 192.168.122.176
Export list for 192.168.122.176:
/srv/share/tmp3 *
/srv/share/tmp1 192.168.122.186/32
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ sudo ./nfsc_script.sh -a 192.168.122.176 /srv/share/tmp2 /mnt4
[sudo] password for kosogor: 
Error: На сервере 192.168.122.176 отсутствует NFS директория /srv/share/tmp2 !

На сервере 192.168.122.176 имеются следующие NFS директории, доступные для монтирования :
Export list for 192.168.122.176:
/srv/share/tmp3 *
/srv/share/tmp1 192.168.122.186/32
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ sudo ./nfsc_script.sh -a 192.168.122.176 /srv/share/tmp3 /mnt4
Монтируем NFS-директорию /srv/share/tmp3 в /mnt4 ...

Примонтирована NFS директория :
192.168.122.176:/srv/share/tmp3 on /mnt4 type nfs4 (rw,relatime,vers=4.2,rsize=524288,wsize=524288,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,clientaddr=192.168.122.186,local_lock=none,addr=192.168.122.176)

В файле /etc/fstab :
192.168.122.176:/srv/share/tmp3 /mnt4 nfs vers=3,noauto,x-systemd.automount 0 0
kosogor@vm2-client:~$
kosogor@vm2-client:~$ ll /mnt4
total 8
drwxrwxrwx  2 nobody nogroup 4096 июл 24 19:15 ./
drwxr-xr-x 27 root   root    4096 июл 24 19:16 ../
kosogor@vm2-client:~$
kosogor@vm2-client:~$ cat > /mnt4/created_fron_client.txt
ertgsdfsdfsfghrtetyufhj,vhnmcgbsfgsgfgbs
kosogor@vm2-client:~$


kosogor@vm1-server:~$ cat > /srv/share/tmp3/created_from_server.txt
jkfhskjfgskdjfgskdfgsdifgusldfigsdfgs
kosogor@vm1-server:~$ 
kosogor@vm1-server:~$ 
kosogor@vm1-server:~$ ll /srv/share/tmp3
total 16
drwxrwxrwx 2 nobody  nogroup 4096 июл 24 19:18 ./
drwxr-xr-x 5 nobody  nogroup 4096 июл 24 19:15 ../
-rw-rw-r-- 1 kosogor kosogor   38 июл 24 19:18 created_from_server.txt
-rw-rw-r-- 1 kosogor kosogor   41 июл 24 19:18 created_fron_client.txt
kosogor@vm1-server:~$ 


kosogor@vm2-client:~$ ll /mnt4
total 16
drwxrwxrwx  2 nobody  nogroup 4096 июл 24 19:18 ./
drwxr-xr-x 27 root    root    4096 июл 24 19:16 ../
-rw-rw-r--  1 kosogor kosogor   38 июл 24 19:18 created_from_server.txt
-rw-rw-r--  1 kosogor kosogor   41 июл 24 19:18 created_fron_client.txt
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$
```

Отмонтируем обе директории на клиенте скриптом и удаляем экспорт директорий на сервере скриптом:

```
kosogor@vm2-client:~$ sudo ./nfsc_script.sh -d 192.168.122.176 /srv/share/tmp3 /mnt4
Отмонтирование NFS директории /srv/share/tmp3 ...
Отмонтирована /srv/share/tmp3
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ ll /mnt4
total 8
drwxr-xr-x  2 root root 4096 июл 24 19:16 ./
drwxr-xr-x 27 root root 4096 июл 24 19:16 ../
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$
kosogor@vm2-client:~$ showmount -e 192.168.122.176
Export list for 192.168.122.176:
/srv/share/tmp3 *
/srv/share/tmp1 192.168.122.186/32
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ mount -l | grep /mnt
systemd-1 on /mnt1 type autofs (rw,relatime,fd=68,pgrp=1,timeout=0,minproto=5,maxproto=5,direct,pipe_ino=5320)
systemd-1 on /mnt3 type autofs (rw,relatime,fd=69,pgrp=1,timeout=0,minproto=5,maxproto=5,direct,pipe_ino=5323)
192.168.122.176:/srv/share/tmp1 on /mnt3 type nfs (rw,relatime,vers=3,rsize=524288,wsize=524288,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,mountaddr=192.168.122.176,mountvers=3,mountport=51293,mountproto=udp,local_lock=none,addr=192.168.122.176)
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ sudo ./nfsc_script.sh -d 192.168.122.176 /srv/share/tmp1 /mnt3
Отмонтирование NFS директории /srv/share/tmp1 ...
Отмонтирована /srv/share/tmp1
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ showmount -e 192.168.122.176
Export list for 192.168.122.176:
/srv/share/tmp1 192.168.122.186/32
kosogor@vm2-client:~$

kosogor@vm1-server:~$ sudo ./nfss_script.sh -d /srv/share/tmp3
Deletting directory /srv/share/tmp3 from /etc/exports ...
Deleted /srv/share/tmp3

Available shared directories on the NFS server 192.168.122.176 :
Export list for 192.168.122.176:
/srv/share/tmp1 192.168.122.186/32
kosogor@vm1-server:~$


kosogor@vm1-server:~$ sudo ./nfss_script.sh -d /srv/share/tmp1
Deletting directory /srv/share/tmp1 from /etc/exports ...
Deleted /srv/share/tmp1

Available shared directories on the NFS server 192.168.122.176 :
Export list for 192.168.122.176:
kosogor@vm1-server:~$ 
kosogor@vm1-server:~$ showmount -e 192.168.122.176
Export list for 192.168.122.176:
kosogor@vm1-server:~$


kosogor@vm2-client:~$ showmount -e 192.168.122.176
Export list for 192.168.122.176:
kosogor@vm2-client:~$
```

# 6. Пересборка ядра Linux для включения в ядре возможности использования протокола UDP при использовании NFSv3 (также этот раздел покрывает задачу со звёздочкой из домашнего задания в Занятию 1 "Пересорбать ядро из исходников")

Для пересборки ядра:

1. Ставим необходимые пакеты для компиляции и сборки ядра нужной версии:

sudo apt build-dep -y linux linux-image-unsigned-$(uname -r)

- linux — метапакет, который указывает на зависимость от ядра в целом.
- linux-image-unsigned-$(uname -r) — подставляет версию ядра, которое сейчас работает в системе (команда uname -r выводит её). Это гарантирует, что вы возьмёте зависимости именно под вашу версию, а не под какую-то другую.

2. Затем скачиваем исходники нужного ядра:

cd /usr/src
sudo apt-get source linux-image-unsigned-$(uname -r)

или, если у вас обычный (подписанный) образ ядра:

sudo apt-get source linux-headers-$(uname -r)

3. Далее получаем конфигурацию ядра рабочей системы, меняем нужные опции , собираем и устанавливаем ядро:

Шаг 1. Переходим в дерево исходников


cd /usr/src/linux-6.8.0

Шаг 2. Копируем рабочую конфигурацию ядра :

sudo zcat /proc/config.gz > .config

Примечание: файл /proc/config.gz появляется только если в ядре включена опция IKCONFIG_PROC. В большинстве дистрибутивов (Ubuntu, Debian и т.п.) её не включают, чтобы не раздувать ядро и не раскрывать детали сборки. Поэтому на обычных серверах и ВМ этого файла просто не бывает.

Раз /proc/config.gz нет, берём конфиг из /boot (это и есть штатный способ)

В Ubuntu конфиг хранится в /boot. Берём именно тот, под который работает ваша система:

cp /boot/config-$(uname -r) .config

Если вдруг такого файла нет, можно взять из папки заголовков:

cp /usr/src/linux-headers-$(uname -r)/.config .config

```
kosogor@vm1-server:~$ sudo zcat /proc/config.gz > .config
gzip: /proc/config.gz: No such file or directory
kosogor@vm2-client:/usr/src/linux-6.8.0$ ll /boot
total 197120
drwxr-xr-x  4 root root     4096 июл 24 06:14 ./
drwxr-xr-x 27 root root     4096 июл 24 19:16 ../
-rw-r--r--  1 root root   287599 янв 13  2026 config-6.8.0-100-generic
-rw-r--r--  1 root root   287560 июл  1 19:48 config-6.8.0-136-generic
drwxr-xr-x  5 root root     4096 июл 24 06:09 grub/
lrwxrwxrwx  1 root root       28 июл 24 06:09 initrd.img -> initrd.img-6.8.0-136-generic
-rw-r--r--  1 root root 76334230 июл 24 06:08 initrd.img-6.8.0-100-generic
-rw-r--r--  1 root root 76542102 июл 24 06:14 initrd.img-6.8.0-136-generic
lrwxrwxrwx  1 root root       28 июн 25 06:31 initrd.img.old -> initrd.img-6.8.0-100-generic
drwx------  2 root root    16384 июн 25 06:29 lost+found/
-rw-------  1 root root  9120274 янв 13  2026 System.map-6.8.0-100-generic
-rw-------  1 root root  9135033 июл  1 19:48 System.map-6.8.0-136-generic
lrwxrwxrwx  1 root root       25 июл 24 06:09 vmlinuz -> vmlinuz-6.8.0-136-generic
-rw-------  1 root root 15030664 янв 13  2026 vmlinuz-6.8.0-100-generic
-rw-------  1 root root 15063432 июл  1 19:50 vmlinuz-6.8.0-136-generic
lrwxrwxrwx  1 root root       25 июн 25 06:31 vmlinuz.old -> vmlinuz-6.8.0-100-generic
kosogor@vm2-client:/usr/src/linux-6.8.0$
kosogor@vm2-client:/usr/src/linux-6.8.0$ uname -r
6.8.0-136-generic
kosogor@vm2-client:/usr/src/linux-6.8.0$ 
kosogor@vm2-client:/usr/src/linux-6.8.0$ cd /usr/src/linux-6.8.0
kosogor@vm2-client:/usr/src/linux-6.8.0$ sudo cp /boot/config-6.8.0-136-generic .config
[sudo] password for kosogor: 
kosogor@vm2-client:/usr/src/linux-6.8.0$ 
kosogor@vm2-client:/usr/src/linux-6.8.0$ 
kosogor@vm2-client:/usr/src/linux-6.8.0$ ll .config
-rw-r--r-- 1 root root 287560 июл 25 18:41 .config
kosogor@vm2-client:/usr/src/linux-6.8.0$
```

В конфигурации изменяем опцию CONFIG_NFS_DISABLE_UDP_SUPPORT=y на CONFIG_NFS_DISABLE_UDP_SUPPORT=n .
А также изменяем опцию локальной версии на CONFIG_LOCALVERSION="-custom" , чтобы скомпилированная версия отличалась:

```
kosogor@vm2-client:/usr/src/linux-6.8.0$ 
kosogor@vm2-client:/usr/src/linux-6.8.0$ grep -i CONFIG_NFS_DISABLE_UDP_SUPPORT .config
CONFIG_NFS_DISABLE_UDP_SUPPORT=y
kosogor@vm2-client:/usr/src/linux-6.8.0$ 
kosogor@vm2-client:/usr/src/linux-6.8.0$ cat .config | grep -i "CONFIG_LOCALVERSION"
CONFIG_LOCALVERSION=""
# CONFIG_LOCALVERSION_AUTO is not set
kosogor@vm2-client:/usr/src/linux-6.8.0$ 
kosogor@vm2-client:/usr/src/linux-6.8.0$ sudo sed -i 's/^CONFIG_LOCALVERSION=.*$/CONFIG_LOCALVERSION="-custom"/' .config
kosogor@vm2-client:/usr/src/linux-6.8.0$ sudo sed -i 's/CONFIG_NFS_DISABLE_UDP_SUPPORT=y/CONFIG_NFS_DISABLE_UDP_SUPPORT=n/' .config
kosogor@vm2-client:/usr/src/linux-6.8.0$ 
kosogor@vm2-client:/usr/src/linux-6.8.0$ cat .config | grep -i "CONFIG_LOCALVERSION"
CONFIG_LOCALVERSION="-custom"
# CONFIG_LOCALVERSION_AUTO is not set
kosogor@vm2-client:/usr/src/linux-6.8.0$ grep -i CONFIG_NFS_DISABLE_UDP_SUPPORT .config
CONFIG_NFS_DISABLE_UDP_SUPPORT=n
kosogor@vm2-client:/usr/src/linux-6.8.0$ 
```

Шаг 3. Применяем дефолты для новых опций

Это нужно, чтобы не отвечать на сотни вопросов про новые опции ядра:

make olddefconfig

Но применение этой команды меняет изменённую опцию CONFIG_NFS_DISABLE_UDP_SUPPORT=n на "# CONFIG_LOCALVERSION_AUTO is not set",
что эквивалентно.

```
kosogor@vm2-client:/usr/src/linux-6.8.0$ 
kosogor@vm2-client:/usr/src/linux-6.8.0$ sudo make olddefconfig
#
# configuration written to .config
#
kosogor@vm2-client:/usr/src/linux-6.8.0$ 
kosogor@vm2-client:/usr/src/linux-6.8.0$ cat .config | grep -i "CONFIG_LOCALVERSION"
CONFIG_LOCALVERSION="-custom"
# CONFIG_LOCALVERSION_AUTO is not set
kosogor@vm2-client:/usr/src/linux-6.8.0$ grep -i CONFIG_NFS_DISABLE_UDP_SUPPORT .config
# CONFIG_NFS_DISABLE_UDP_SUPPORT is not set
kosogor@vm2-client:/usr/src/linux-6.8.0$ 
```

Шаг 5. Сборка ядра

Собираем ядро и модули (используем все ядра CPU, чтобы быстрее):

make clean    (эта команда нужна для очистки мусора, если сборка до этого уже выполнялась и была прервана - я выполнял сборку ядра трижды, пока получилось)

make -j$(nproc)

Команда make -j$(nproc) запускает сборку ядра параллельно — и сильно ускоряет процесс.

Сборка заняла время (зависит от CPU и количества модулей) порядка 3-5 часов и большое количество дискового пространства:

/usr/src/linux-6.8.0$ du -sh /usr/src/
26G	/usr/src/

Пришлось дважды увеличивать диск у ВМ  )))))

```
kosogor@vm2-client:/usr/src/linux-6.8.0$ sudo make clean
  CLEAN   arch/x86/crypto
  CLEAN   arch/x86/entry/vdso
  CLEAN   arch/x86/kernel/cpu
  CLEAN   arch/x86/kernel
  CLEAN   arch/x86/kvm
  CLEAN   arch/x86/purgatory
  CLEAN   arch/x86/realmode/rm
  CLEAN   arch/x86/tools
  CLEAN   certs
  CLEAN   crypto/asymmetric_keys
  CLEAN   fs/unicode
  CLEAN   init
  CLEAN   kernel/debug/kdb
  CLEAN   kernel
  CLEAN   security/apparmor
  CLEAN   security/selinux
  CLEAN   security/tomoyo
  CLEAN   usr
  CLEAN   .
kosogor@vm2-client:/usr/src/linux-6.8.0$
osogor@vm2-client:/usr/src/linux-6.8.0$ sudo make -j$(nproc) 2>&1 | tee build.log ; date | tee build.log
tee: build.log: Permission denied
  HOSTCC  scripts/basic/fixdep
  SYSHDR  arch/x86/include/generated/uapi/asm/unistd_32.h
  SYSHDR  arch/x86/include/generated/uapi/asm/unistd_64.h
  SYSHDR  arch/x86/include/generated/uapi/asm/unistd_x32.h
  SYSTBL  arch/x86/include/generated/asm/syscalls_32.h
  SYSHDR  arch/x86/include/generated/asm/unistd_32_ia32.h
  SYSHDR  arch/x86/include/generated/asm/unistd_64_x32.h
  SYSTBL  arch/x86/include/generated/asm/syscalls_64.h
  HYPERCALLS arch/x86/include/generated/asm/xen-hypercalls.h
  HOSTCC  arch/x86/tools/relocs_32.o
  DESCEND objtool
  HOSTCC  arch/x86/tools/relocs_64.o
  HOSTCC  /usr/src/linux-6.8.0/tools/objtool/fixdep.o
<... 5 часов сборки ...>
 BTF [M] drivers/gpu/drm/amd/amdxcp/amdxcp.ko
  LD [M]  drivers/gpu/drm/i915/i915.ko
  BTF [M] drivers/gpu/drm/radeon/radeon.ko
ld: final link failed: No space left on device
make[2]: *** [scripts/Makefile.modfinal:57: drivers/gpu/drm/amd/amdgpu/amdgpu.ko] Error 1
make[2]: *** Waiting for unfinished jobs....
  BTF [M] drivers/gpu/drm/i915/i915.ko
objcopy: drivers/gpu/drm/i915/stMQM7bz[.debug_str]: No space left on device
btf_encoder__write_elf: failed to add .BTF section to 'drivers/gpu/drm/i915/i915.ko': 2!
Failed to encode BTF
make[2]: *** [scripts/Makefile.modfinal:57: drivers/gpu/drm/i915/i915.ko] Error 1
make[2]: *** Deleting file 'drivers/gpu/drm/i915/i915.ko'
make[1]: *** [/usr/src/linux-6.8.0/Makefile:1879: modules] Error 2
make: *** [Makefile:240: __sub-make] Error 2
tee: build.log: Permission denied
Вс 26 июл 2026 17:37:37 UTC
kosogor@vm2-client:/usr/src/linux-6.8.0$ df -h
Filesystem                         Size  Used Avail Use% Mounted on
tmpfs                              392M   41M  352M  11% /run
/dev/mapper/ubuntu--vg-ubuntu--lv   28G   28G     0 100% /
tmpfs                              2,0G     0  2,0G   0% /dev/shm
tmpfs                              5,0M     0  5,0M   0% /run/lock
/dev/vda2                          2,0G  200M  1,6G  11% /boot
tmpfs                              392M   12K  392M   1% /run/user/1000
kosogor@vm2-client:/usr/src/linux-6.8.0$
kosogor@vm2-client:/usr/src/linux-6.8.0$ sudo make clean
[sudo] password for kosogor: 
  CLEAN   arch/x86/boot/compressed
  CLEAN   arch/x86/boot
  CLEAN   arch/x86/crypto
  CLEAN   arch/x86/entry/vdso
  CLEAN   arch/x86/kernel/cpu
  CLEAN   arch/x86/kernel
  CLEAN   arch/x86/kvm
  CLEAN   arch/x86/purgatory
  CLEAN   arch/x86/realmode/rm
  CLEAN   arch/x86/tools
  CLEAN   arch/x86/lib
  CLEAN   certs
  CLEAN   crypto/asymmetric_keys
  CLEAN   drivers/accessibility/speakup
  CLEAN   drivers/firmware/efi/libstub
  CLEAN   drivers/gpu/drm/radeon
  CLEAN   drivers/gpu/drm/xe
  CLEAN   drivers/net/wan
  CLEAN   drivers/scsi/aic7xxx
  CLEAN   drivers/scsi
  CLEAN   drivers/tty/vt
  CLEAN   fs/unicode
  CLEAN   init
  CLEAN   kernel/debug/kdb
  CLEAN   kernel
  CLEAN   lib/raid6
  CLEAN   lib
  CLEAN   net/wireless
  CLEAN   security/apparmor
  CLEAN   security/selinux
  CLEAN   security/tomoyo
  CLEAN   usr
  CLEAN   .
  CLEAN   modules.builtin modules.builtin.modinfo .vmlinux.objs .vmlinux.export.c
kosogor@vm2-client:/usr/src/linux-6.8.0$ du -sh /usr/src/
2,3G	/usr/src/
kosogor@vm2-client:/usr/src/linux-6.8.0$
```

ПОСЛЕ УВЕЛИЧЕНИЯ ДИСКА ВМ до 60G:

```
kosogor@vm2-client:~$ df -hT
Filesystem                        Type   Size  Used Avail Use% Mounted on
tmpfs                             tmpfs  392M  1,2M  391M   1% /run
/dev/mapper/ubuntu--vg-ubuntu--lv ext4    57G  9,4G   46G  18% /
tmpfs                             tmpfs  2,0G     0  2,0G   0% /dev/shm
tmpfs                             tmpfs  5,0M     0  5,0M   0% /run/lock
/dev/vda2                         ext4   2,0G  200M  1,6G  11% /boot
tmpfs                             tmpfs  392M   12K  392M   1% /run/user/1000
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ cd /usr/src
kosogor@vm2-client:/usr/src$ ll
total 233512
drwxr-xr-x 10 root root      4096 июл 25 17:19 ./
drwxr-xr-x 12 root root      4096 фев 10 00:16 ../
drwxr-xr-x 29 root root      4096 июл 27 02:49 linux-6.8.0/
-rw-r--r--  1 root root   8960450 июл  2 22:24 linux_6.8.0-136.136.diff.gz
-rw-r--r--  1 root root      9463 июл  2 22:24 linux_6.8.0-136.136.dsc
-rw-r--r--  1 root root 230060117 мар 15  2024 linux_6.8.0.orig.tar.gz
drwxr-xr-x 26 root root      4096 июн 25 06:30 linux-headers-6.8.0-100/
drwxr-xr-x  7 root root      4096 июн 25 06:30 linux-headers-6.8.0-100-generic/
drwxr-xr-x 26 root root      4096 июл 24 06:09 linux-headers-6.8.0-136/
drwxr-xr-x  7 root root      4096 июл 24 06:09 linux-headers-6.8.0-136-generic/
drwxr-xr-x  3 root root      4096 июн 10 06:42 linux-meta-6.8.0/
-rw-r--r--  1 root root      8426 июл  2 22:14 linux-meta_6.8.0-136.136.dsc
-rw-r--r--  1 root root     19872 июл  2 21:45 linux-meta_6.8.0-136.136.tar.xz
drwxr-xr-x  4 root root      4096 июл 25 17:00 python3.12/
drwxr-xr-x  6 root root      4096 июл 25 17:00 rustc-1.75.0/
kosogor@vm2-client:/usr/src$ cd linux-6.8.0
kosogor@vm2-client:/usr/src/linux-6.8.0$ 
kosogor@vm2-client:/usr/src/linux-6.8.0$ cat .config | grep -i "udp"
CONFIG_NET_UDP_TUNNEL=m
CONFIG_INET_UDP_DIAG=m
CONFIG_NF_CT_PROTO_UDPLITE=y
CONFIG_IP_VS_PROTO_UDP=y
CONFIG_TIPC_MEDIA_UDP=y
CONFIG_6LOWPAN_NHC_UDP=m
# CONFIG_6LOWPAN_GHC_UDP is not set
CONFIG_BAREUDP=m
CONFIG_SPEAKUP_SYNTH_AUDPTR=m
# CONFIG_NFS_DISABLE_UDP_SUPPORT is not set
kosogor@vm2-client:/usr/src/linux-6.8.0$ cat .config | grep -i "CONFIG_LOCALVERSION"
CONFIG_LOCALVERSION="-custom"
# CONFIG_LOCALVERSION_AUTO is not set
kosogor@vm2-client:/usr/src/linux-6.8.0$ 
kosogor@vm2-client:/usr/src/linux-6.8.0$ 
kosogor@vm2-client:/usr/src/linux-6.8.0$ make clean
kosogor@vm2-client:/usr/src/linux-6.8.0$ 
kosogor@vm2-client:/usr/src/linux-6.8.0$ 
kosogor@vm2-client:/usr/src/linux-6.8.0$ date | tee build.log
tee: build.log: Permission denied
Пн 27 июл 2026 03:20:02 UTC
kosogor@vm2-client:/usr/src/linux-6.8.0$ sudo date | tee build.log
tee: build.log: Permission denied
Пн 27 июл 2026 03:20:11 UTC
kosogor@vm2-client:/usr/src/linux-6.8.0$ date | sudo tee build.log
Пн 27 июл 2026 03:20:28 UTC
kosogor@vm2-client:/usr/src/linux-6.8.0$ 
kosogor@vm2-client:/usr/src/linux-6.8.0$ sudo make -j$(nproc) 2>&1 | sudo tee build.log ; date | sudo tee build.log
  HOSTCC  scripts/basic/fixdep
  SYSHDR  arch/x86/include/generated/uapi/asm/unistd_32.h
  SYSHDR  arch/x86/include/generated/uapi/asm/unistd_64.h
  SYSHDR  arch/x86/include/generated/uapi/asm/unistd_x32.h
  SYSTBL  arch/x86/include/generated/asm/syscalls_32.h
  SYSHDR  arch/x86/include/generated/asm/unistd_32_ia32.h
  SYSHDR  arch/x86/include/generated/asm/unistd_64_x32.h
  SYSTBL  arch/x86/include/generated/asm/syscalls_64.h
  HYPERCALLS arch/x86/include/generated/asm/xen-hypercalls.h

<... ещё 5 часов сборки ...>

  LD [M]  net/vmw_vsock/vsock_loopback.ko
  BTF [M] net/vmw_vsock/vmw_vsock_virtio_transport_common.ko
  BTF [M] net/vmw_vsock/hv_sock.ko
  BTF [M] net/vmw_vsock/vsock_loopback.ko
  LD [M]  net/nsh/nsh.ko
  LD [M]  net/hsr/hsr.ko
  LD [M]  net/qrtr/qrtr.ko
  BTF [M] net/nsh/nsh.ko
  BTF [M] net/hsr/hsr.ko
  BTF [M] net/qrtr/qrtr.ko
  LD [M]  net/qrtr/qrtr-smd.ko
  BTF [M] net/qrtr/qrtr-smd.ko
  LD [M]  net/qrtr/qrtr-tun.ko
  LD [M]  net/qrtr/qrtr-mhi.ko
  BTF [M] net/qrtr/qrtr-tun.ko
  BTF [M] net/qrtr/qrtr-mhi.ko
  LD [M]  virt/lib/irqbypass.ko
  BTF [M] virt/lib/irqbypass.ko
  LD [M]  ubuntu/ubuntu-host/ubuntu-host.ko
  BTF [M] ubuntu/ubuntu-host/ubuntu-host.ko
[sudo] password for kosogor: 
Пн 27 июл 2026 06:49:08 UTC
kosogor@vm2-client:/usr/src/linux-6.8.0$ 
```


После сборки можно проверить её успешность:
1) наличие скомпилированного ядра и его нормальный размер (10-15М)

```
kosogor@vm2-client:/usr/src/linux-6.8.0$ ls -lh arch/x86/boot/bzImage
-rw-r--r-- 1 root root 15M июл 27 06:13 arch/x86/boot/bzImage
kosogor@vm2-client:/usr/src/linux-6.8.0$
```
 
2) Наличие скомпилированных модулей:

```
kosogor@vm2-client:/usr/src/linux-6.8.0$ ll /lib/modules
total 20
drwxr-xr-x  5 root root 4096 июл 27 07:33 ./
drwxr-xr-x 91 root root 4096 июл 25 17:00 ../
drwxr-xr-x  5 root root 4096 июн 25 06:31 6.8.0-100-generic/
drwxr-xr-x  5 root root 4096 июл 24 06:09 6.8.0-136-generic/
drwxr-xr-x  3 root root 4096 июл 27 07:36 6.8.12-custom/
kosogor@vm2-client:/usr/src/linux-6.8.0$ ll /lib/modules/6.8.12-custom
total 6984
drwxr-xr-x  3 root root    4096 июл 27 07:36 ./
drwxr-xr-x  5 root root    4096 июл 27 07:33 ../
lrwxrwxrwx  1 root root      20 июл 27 07:33 build -> /usr/src/linux-6.8.0/
drwxr-xr-x 15 root root    4096 июл 27 07:33 kernel/
-rw-r--r--  1 root root 1695616 июл 27 07:36 modules.alias
-rw-r--r--  1 root root 1650073 июл 27 07:36 modules.alias.bin
-rw-r--r--  1 root root    9714 июл 27 07:33 modules.builtin
-rw-r--r--  1 root root   10690 июл 27 07:36 modules.builtin.alias.bin
-rw-r--r--  1 root root   11907 июл 27 07:36 modules.builtin.bin
-rw-r--r--  1 root root   87651 июл 27 07:33 modules.builtin.modinfo
-rw-r--r--  1 root root  780903 июл 27 07:36 modules.dep
-rw-r--r--  1 root root 1062524 июл 27 07:36 modules.dep.bin
-rw-r--r--  1 root root     337 июл 27 07:36 modules.devname
-rw-r--r--  1 root root  262957 июл 27 07:33 modules.order
-rw-r--r--  1 root root    2836 июл 27 07:36 modules.softdep
-rw-r--r--  1 root root  692862 июл 27 07:36 modules.symbols
-rw-r--r--  1 root root  845164 июл 27 07:36 modules.symbols.bin
kosogor@vm2-client:/usr/src/linux-6.8.0$ 
```

Шаг 6. Установка ядра и модулей

Из дерева исходников ставим модули и само ядро:

### 1. Установить модули в /lib/modules
sudo make modules_install

```
osogor@vm2-client:/usr/src/linux-6.8.0$ sudo make modules_install
[sudo] password for kosogor: 
  SYMLINK /lib/modules/6.8.12-custom/build
  INSTALL /lib/modules/6.8.12-custom/modules.order
  INSTALL /lib/modules/6.8.12-custom/modules.builtin
  INSTALL /lib/modules/6.8.12-custom/modules.builtin.modinfo
  INSTALL /lib/modules/6.8.12-custom/kernel/arch/x86/events/amd/amd-uncore.ko
  SIGN    /lib/modules/6.8.12-custom/kernel/arch/x86/events/amd/amd-uncore.ko
/bin/sh: 1: ./debian/scripts/sign-module: Permission denied
  INSTALL /lib/modules/6.8.12-custom/kernel/arch/x86/events/intel/intel-cstate.ko
  SIGN    /lib/modules/6.8.12-custom/kernel/arch/x86/events/intel/intel-cstate.ko
/bin/sh: 1: ./debian/scripts/sign-module: Permission denied
  INSTALL /lib/modules/6.8.12-custom/kernel/arch/x86/events/rapl.ko
  SIGN    /lib/modules/6.8.12-custom/kernel/arch/x86/events/rapl.ko
/bin/sh: 1: ./debian/scripts/sign-module: Permission denied
  INSTALL /lib/modules/6.8.12-custom/kernel/arch/x86/kernel/cpu/mce/mce-inject.ko
  SIGN    /lib/modules/6.8.12-custom/kernel/arch/x86/kernel/cpu/mce/mce-inject.ko
/bin/sh: 1: ./debian/scripts/sign-module: Permission denied
  INSTALL /lib/modules/6.8.12-custom/kernel/arch/x86/kernel/msr.ko
  SIGN    /lib/modules/6.8.12-custom/kernel/arch/x86/kernel/msr.ko
/bin/sh: 1: ./debian/scripts/sign-module: Permission denied
  INSTALL /lib/modules/6.8.12-custom/kernel/arch/x86/kernel/cpuid.ko
  SIGN    /lib/modules/6.8.12-custom/kernel/arch/x86/kernel/cpuid.ko
/bin/sh: 1: ./debian/scripts/sign-module: Permission denied
  INSTALL /lib/modules/6.8.12-custom/kernel/arch/x86/crypto/twofish-x86_64.ko
<...>
```

При работе команды "sudo make modules_install", для каждого модуля может выдаваться ошибка "/bin/sh: 1: ./debian/scripts/sign-module: Permission denied" - это проблема подписи модулей в Ubuntu сборке.
При этом модули всё равно копируются (INSTALL .../mt9m001.ko идёт перед ошибкой) — ошибка только на этапе подписи.
sign-module ещё и требует ключи подписи (.priv / .der), иначе он всё равно «упадёт» дальше по цепочке. Если ключей нет — подписать не получится.
Если не включён Secure Boot (а в KVM‑ВМ он почти всегда выключен по умолчанию), подпись вообще не нужна.
Проверить, что Secure Boot выключен, можно так:
dmidecode -t processor | grep -i secure  
или смотреть в настройках ВМ либо в гостевой ОС:
mokutil --test

Можно запустить команду 

sudo make MODULES_SIGN=n modules_install

тогда модули будут сразу устанавливаться без попытки подписи.


После команды  sudo make modules_install

модули появляются в папке

ls -lh /lib/modules/

```
kosogor@vm2-client:/usr/src/linux-6.8.0$ ls -lh /lib/modules/6.8.12-custom/
total 6,9M
lrwxrwxrwx  1 root root   20 июл 27 07:33 build -> /usr/src/linux-6.8.0
drwxr-xr-x 15 root root 4,0K июл 27 07:33 kernel
-rw-r--r--  1 root root 1,7M июл 27 07:36 modules.alias
-rw-r--r--  1 root root 1,6M июл 27 07:36 modules.alias.bin
-rw-r--r--  1 root root 9,5K июл 27 07:33 modules.builtin
-rw-r--r--  1 root root  11K июл 27 07:36 modules.builtin.alias.bin
-rw-r--r--  1 root root  12K июл 27 07:36 modules.builtin.bin
-rw-r--r--  1 root root  86K июл 27 07:33 modules.builtin.modinfo
-rw-r--r--  1 root root 763K июл 27 07:36 modules.dep
-rw-r--r--  1 root root 1,1M июл 27 07:36 modules.dep.bin
-rw-r--r--  1 root root  337 июл 27 07:36 modules.devname
-rw-r--r--  1 root root 257K июл 27 07:33 modules.order
-rw-r--r--  1 root root 2,8K июл 27 07:36 modules.softdep
-rw-r--r--  1 root root 677K июл 27 07:36 modules.symbols
-rw-r--r--  1 root root 826K июл 27 07:36 modules.symbols.bin
kosogor@vm2-client:/usr/src/linux-6.8.0$
kosogor@vm2-client:/usr/src/linux-6.8.0$ ls -lh /lib/modules/6.8.12-custom/kernel/drivers/media/i2c/mt9*.ko
-rw-r--r-- 1 root root 591K июл 27 07:34 /lib/modules/6.8.12-custom/kernel/drivers/media/i2c/mt9m001.ko
-rw-r--r-- 1 root root 604K июл 27 07:34 /lib/modules/6.8.12-custom/kernel/drivers/media/i2c/mt9m111.ko
-rw-r--r-- 1 root root 644K июл 27 07:34 /lib/modules/6.8.12-custom/kernel/drivers/media/i2c/mt9m114.ko
-rw-r--r-- 1 root root 617K июл 27 07:34 /lib/modules/6.8.12-custom/kernel/drivers/media/i2c/mt9p031.ko
-rw-r--r-- 1 root root 561K июл 27 07:34 /lib/modules/6.8.12-custom/kernel/drivers/media/i2c/mt9t112.ko
-rw-r--r-- 1 root root 524K июл 27 07:34 /lib/modules/6.8.12-custom/kernel/drivers/media/i2c/mt9v011.ko
-rw-r--r-- 1 root root 579K июл 27 07:34 /lib/modules/6.8.12-custom/kernel/drivers/media/i2c/mt9v032.ko
-rw-r--r-- 1 root root 575K июл 27 07:34 /lib/modules/6.8.12-custom/kernel/drivers/media/i2c/mt9v111.ko
kosogor@vm2-client:/usr/src/linux-6.8.0$ 
```

### 2. Установить само ядро и обновить initramfs
sudo make install


make install создаст в /boot файлы vmlinuz-*, System.map-*, config-* и обновит символические ссылки.
Обновит initramfs

```
kosogor@vm2-client:/usr/src/linux-6.8.0$ sudo make install
  INSTALL /boot
run-parts: executing /etc/kernel/postinst.d/dkms 6.8.12-custom /boot/vmlinuz-6.8.12-custom
 * dkms: running auto installation service for kernel 6.8.12-custom
 * dkms: autoinstall for kernel 6.8.12-custom                                                                           [ OK ] 
run-parts: executing /etc/kernel/postinst.d/initramfs-tools 6.8.12-custom /boot/vmlinuz-6.8.12-custom
update-initramfs: Generating /boot/initrd.img-6.8.12-custom
run-parts: executing /etc/kernel/postinst.d/unattended-upgrades 6.8.12-custom /boot/vmlinuz-6.8.12-custom
run-parts: executing /etc/kernel/postinst.d/update-notifier 6.8.12-custom /boot/vmlinuz-6.8.12-custom
run-parts: executing /etc/kernel/postinst.d/xx-update-initrd-links 6.8.12-custom /boot/vmlinuz-6.8.12-custom
I: /boot/initrd.img.old is now a symlink to initrd.img-6.8.0-136-generic
I: /boot/initrd.img is now a symlink to initrd.img-6.8.12-custom
run-parts: executing /etc/kernel/postinst.d/zz-update-grub 6.8.12-custom /boot/vmlinuz-6.8.12-custom
Sourcing file `/etc/default/grub'
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-6.8.12-custom
Found initrd image: /boot/initrd.img-6.8.12-custom
Found linux image: /boot/vmlinuz-6.8.0-136-generic
Found initrd image: /boot/initrd.img-6.8.0-136-generic
Found linux image: /boot/vmlinuz-6.8.0-100-generic
Found initrd image: /boot/initrd.img-6.8.0-100-generic
Warning: os-prober will not be executed to detect other bootable partitions.
Systems on them will not be added to the GRUB boot configuration.
Check GRUB_DISABLE_OS_PROBER documentation entry.
Adding boot menu entry for UEFI Firmware Settings ...
done
kosogor@vm2-client:/usr/src/linux-6.8.0$ 
```

Шаг 7. Обновляем GRUB

sudo update-grub

```
kosogor@vm2-client:/usr/src/linux-6.8.0$ sudo update-grub
Sourcing file `/etc/default/grub'
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-6.8.12-custom
Found initrd image: /boot/initrd.img-6.8.12-custom
Found linux image: /boot/vmlinuz-6.8.0-136-generic
Found initrd image: /boot/initrd.img-6.8.0-136-generic
Found linux image: /boot/vmlinuz-6.8.0-100-generic
Found initrd image: /boot/initrd.img-6.8.0-100-generic
Warning: os-prober will not be executed to detect other bootable partitions.
Systems on them will not be added to the GRUB boot configuration.
Check GRUB_DISABLE_OS_PROBER documentation entry.
Adding boot menu entry for UEFI Firmware Settings ...
done
kosogor@vm2-client:/usr/src/linux-6.8.0$ 
```

Проверить можно:

1) новое ядро появилось в директории /boot :

```
kosogor@vm2-client:/usr/src/linux-6.8.0$ sudo ls -al /boot
total 747652
drwxr-xr-x  4 root root      4096 июл 27 07:40 .
drwxr-xr-x 27 root root      4096 июл 27 03:16 ..
-rw-r--r--  1 root root    287599 янв 13  2026 config-6.8.0-100-generic
-rw-r--r--  1 root root    287560 июл  1 19:48 config-6.8.0-136-generic
-rw-r--r--  1 root root    287157 июл 27 07:39 config-6.8.12-custom
drwxr-xr-x  5 root root      4096 июл 27 07:41 grub
lrwxrwxrwx  1 root root        24 июл 27 07:40 initrd.img -> initrd.img-6.8.12-custom
-rw-r--r--  1 root root  76334230 июл 24 06:08 initrd.img-6.8.0-100-generic
-rw-r--r--  1 root root  76542102 июл 24 06:14 initrd.img-6.8.0-136-generic
-rw-r--r--  1 root root 540289613 июл 27 07:40 initrd.img-6.8.12-custom
lrwxrwxrwx  1 root root        28 июл 27 07:40 initrd.img.old -> initrd.img-6.8.0-136-generic
drwx------  2 root root     16384 июн 25 06:29 lost+found
-rw-------  1 root root   9120274 янв 13  2026 System.map-6.8.0-100-generic
-rw-------  1 root root   9135033 июл  1 19:48 System.map-6.8.0-136-generic
-rw-r--r--  1 root root   8364746 июл 27 07:39 System.map-6.8.12-custom
lrwxrwxrwx  1 root root        21 июл 27 07:39 vmlinuz -> vmlinuz-6.8.12-custom
-rw-------  1 root root  15030664 янв 13  2026 vmlinuz-6.8.0-100-generic
-rw-------  1 root root  15063432 июл  1 19:50 vmlinuz-6.8.0-136-generic
-rw-r--r--  1 root root  14787072 июл 27 07:39 vmlinuz-6.8.12-custom
lrwxrwxrwx  1 root root        25 июл 24 06:09 vmlinuz.old -> vmlinuz-6.8.0-136-generic
kosogor@vm2-client:/usr/src/linux-6.8.0$
```

2) Установленные модули появились в директории

```
kosogor@vm2-client:/usr/src/linux-6.8.0$ ll /lib/modules/6.8.12-custom
total 6984
drwxr-xr-x  3 root root    4096 июл 27 07:36 ./
drwxr-xr-x  5 root root    4096 июл 27 07:33 ../
lrwxrwxrwx  1 root root      20 июл 27 07:33 build -> /usr/src/linux-6.8.0/
drwxr-xr-x 15 root root    4096 июл 27 07:33 kernel/
-rw-r--r--  1 root root 1695616 июл 27 07:36 modules.alias
-rw-r--r--  1 root root 1650073 июл 27 07:36 modules.alias.bin
-rw-r--r--  1 root root    9714 июл 27 07:33 modules.builtin
-rw-r--r--  1 root root   10690 июл 27 07:36 modules.builtin.alias.bin
-rw-r--r--  1 root root   11907 июл 27 07:36 modules.builtin.bin
-rw-r--r--  1 root root   87651 июл 27 07:33 modules.builtin.modinfo
-rw-r--r--  1 root root  780903 июл 27 07:36 modules.dep
-rw-r--r--  1 root root 1062524 июл 27 07:36 modules.dep.bin
-rw-r--r--  1 root root     337 июл 27 07:36 modules.devname
-rw-r--r--  1 root root  262957 июл 27 07:33 modules.order
-rw-r--r--  1 root root    2836 июл 27 07:36 modules.softdep
-rw-r--r--  1 root root  692862 июл 27 07:36 modules.symbols
-rw-r--r--  1 root root  845164 июл 27 07:36 modules.symbols.bin
kosogor@vm2-client:/usr/src/linux-6.8.0$ 
```

3) В GRUB появилась конфигурация нового ядра:

```
kosogor@vm2-client:/usr/src/linux-6.8.0$ sudo grep -i '6.8.12-custom' /boot/grub/grub.cfg
	linux	/vmlinuz-6.8.12-custom root=/dev/mapper/ubuntu--vg-ubuntu--lv ro  
	initrd	/initrd.img-6.8.12-custom
	menuentry 'Ubuntu, with Linux 6.8.12-custom' --class ubuntu --class gnu-linux --class gnu --class os $menuentry_id_option 'gnulinux-6.8.12-custom-advanced-81b03913-c2cc-42ef-8d87-f4f3e7b946b5' {
		echo	'Loading Linux 6.8.12-custom ...'
		linux	/vmlinuz-6.8.12-custom root=/dev/mapper/ubuntu--vg-ubuntu--lv ro  
		initrd	/initrd.img-6.8.12-custom
	menuentry 'Ubuntu, with Linux 6.8.12-custom (recovery mode)' --class ubuntu --class gnu-linux --class gnu --class os $menuentry_id_option 'gnulinux-6.8.12-custom-recovery-81b03913-c2cc-42ef-8d87-f4f3e7b946b5' {
		echo	'Loading Linux 6.8.12-custom ...'
		linux	/vmlinuz-6.8.12-custom root=/dev/mapper/ubuntu--vg-ubuntu--lv ro recovery nomodeset dis_ucode_ldr 
		initrd	/initrd.img-6.8.12-custom
kosogor@vm2-client:/usr/src/linux-6.8.0$
```

## 3. Перегружаем ВМ и проверяем, что новое ядро установилось и нужная опция изменена:

```
kosogor@vm2-client:/usr/src/linux-6.8.0$ sudo reboot

Broadcast message from root@vm2-client on pts/1 (Mon 2026-07-27 08:25:38 UTC):

The system will reboot now!

kosogor@vm2-client:/usr/src/linux-6.8.0$ Connection to 192.168.122.186 closed by remote host.
Connection to 192.168.122.186 closed.
[admin_insta11@mv334 ~]$ ssh kosogor@192.168.122.186
kosogor@192.168.122.186's password: 
Welcome to Ubuntu 24.04.4 LTS (GNU/Linux 6.8.12-custom x86_64)

Last login: Mon Jul 27 03:21:39 2026 from 192.168.122.1
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ uname -r
6.8.12-custom
kosogor@vm2-client:~$ lsmod | head
Module                  Size  Used by
qrtr                   53248  2
intel_rapl_msr         20480  0
intel_rapl_common      40960  1 intel_rapl_msr
intel_pmc_core        118784  0
intel_vsec             20480  1 intel_pmc_core
pmt_telemetry          16384  1 intel_pmc_core
pmt_class              12288  1 pmt_telemetry
kvm_intel             475136  0
cfg80211             1318912  0
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ sudo modprobe -v mt9m001
[sudo] password for kosogor: 
insmod /lib/modules/6.8.12-custom/kernel/drivers/media/mc/mc.ko 
insmod /lib/modules/6.8.12-custom/kernel/drivers/media/v4l2-core/videodev.ko 
insmod /lib/modules/6.8.12-custom/kernel/drivers/media/v4l2-core/v4l2-async.ko 
insmod /lib/modules/6.8.12-custom/kernel/drivers/media/i2c/mt9m001.ko 
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ sudo dkms status
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ sudo ls -al /boot
total 747652
drwxr-xr-x  4 root root      4096 июл 27 07:40 .
drwxr-xr-x 27 root root      4096 июл 27 03:16 ..
-rw-r--r--  1 root root    287599 янв 13  2026 config-6.8.0-100-generic
-rw-r--r--  1 root root    287560 июл  1 19:48 config-6.8.0-136-generic
-rw-r--r--  1 root root    287157 июл 27 07:39 config-6.8.12-custom
drwxr-xr-x  5 root root      4096 июл 27 07:41 grub
lrwxrwxrwx  1 root root        24 июл 27 07:40 initrd.img -> initrd.img-6.8.12-custom
-rw-r--r--  1 root root  76334230 июл 24 06:08 initrd.img-6.8.0-100-generic
-rw-r--r--  1 root root  76542102 июл 24 06:14 initrd.img-6.8.0-136-generic
-rw-r--r--  1 root root 540289613 июл 27 07:40 initrd.img-6.8.12-custom
lrwxrwxrwx  1 root root        28 июл 27 07:40 initrd.img.old -> initrd.img-6.8.0-136-generic
drwx------  2 root root     16384 июн 25 06:29 lost+found
-rw-------  1 root root   9120274 янв 13  2026 System.map-6.8.0-100-generic
-rw-------  1 root root   9135033 июл  1 19:48 System.map-6.8.0-136-generic
-rw-r--r--  1 root root   8364746 июл 27 07:39 System.map-6.8.12-custom
lrwxrwxrwx  1 root root        21 июл 27 07:39 vmlinuz -> vmlinuz-6.8.12-custom
-rw-------  1 root root  15030664 янв 13  2026 vmlinuz-6.8.0-100-generic
-rw-------  1 root root  15063432 июл  1 19:50 vmlinuz-6.8.0-136-generic
-rw-r--r--  1 root root  14787072 июл 27 07:39 vmlinuz-6.8.12-custom
lrwxrwxrwx  1 root root        25 июл 24 06:09 vmlinuz.old -> vmlinuz-6.8.0-136-generic
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ sudo cat /boot/config-6.8.12-custom | grep -i "udp"
CONFIG_NET_UDP_TUNNEL=m
CONFIG_INET_UDP_DIAG=m
CONFIG_NF_CT_PROTO_UDPLITE=y
CONFIG_IP_VS_PROTO_UDP=y
CONFIG_TIPC_MEDIA_UDP=y
CONFIG_6LOWPAN_NHC_UDP=m
# CONFIG_6LOWPAN_GHC_UDP is not set
CONFIG_BAREUDP=m
CONFIG_SPEAKUP_SYNTH_AUDPTR=m
# CONFIG_NFS_DISABLE_UDP_SUPPORT is not set
kosogor@vm2-client:~$ 
```

## 4. Копируем собранное кастомное ядро на вторую ВМ, на которой находится NFS сервер (собирать ядро повторно на второй ВМ нет НИКАКИХ СИЛ):

На ВМ с NFS-клиентом, на которой собиралось ядро, создаём архив с нужными файлами и дерикториями
/boot/vmlinuz-6.8.12-custom
/boot/initrd.img-6.8.12-custom
/lib/modules/6.8.12-custom/
/usr/src/linux-6.8.0/.config

копируем на вторую ВМ (виртуальные машины клонированы одна от другой, поэтому одинаковые версии ОС, и ядро подходит от одной ВМ к другой),

```
kosogor@vm2-client:~$ sudo tar --create --gzip --file kernel-6.8.12-custom.tar.gz --absolute-names /boot/vmlinuz-6.8.12-custom /boot/initrd.img-6.8.12-custom /lib/modules/6.8.12-custom/
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ ll kernel-6.8.12-custom.tar.gz
-rw-r--r-- 1 root root 2897676358 июл 27 10:06 kernel-6.8.12-custom.tar.gz
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ scp kernel-6.8.12-custom.tar.gz kosogor@192.168.122.176:/tmp/
The authenticity of host '192.168.122.176 (192.168.122.176)' can't be established.
ED25519 key fingerprint is SHA256:fRiBZ/lsR/UjRjO9pHkcI63aUnoEa0W6VkcBOTAn4qE.
This key is not known by any other names.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '192.168.122.176' (ED25519) to the list of known hosts.
kosogor@192.168.122.176's password: 
kernel-6.8.12-custom.tar.gz                                                                  100% 2763MB  20.0MB/s   02:18    
kosogor@vm2-client:~$ scp kernel-6.8.12-custom.tar.gz kosogor@192.168.122.176:/tmp/
kosogor@192.168.122.176's password: 
kernel-6.8.12-custom.tar.gz                                                                  100% 2763MB  59.7MB/s   00:46    
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ rsync -avz /usr/src/linux-6.8.0/.config kosogor@192.168.122.176:/tmp/config-6.8.12-custom
kosogor@192.168.122.176's password: 
sending incremental file list
.config

sent 73.628 bytes  received 35 bytes  7.015,52 bytes/sec
total size is 287.157  speedup is 3,90
kosogor@vm2-client:~$
```

После копирования на второй ВМ распаковываем архив, помещаем файлы ядра и модулей в нужные места, убеждаемся, что всё скопировалось, обновляем initramfs на всякий случай, перегружаем ВМ и убеждаемся, что кастомное ядро также установилось:

```
kosogor@vm1-server:~$ sudo ls -al /boot
[sudo] password for kosogor: 
total 195488
drwxr-xr-x  4 root root     4096 июл 24 06:48 .
drwxr-xr-x 23 root root     4096 июн 25 06:31 ..
-rw-r--r--  1 root root   287599 янв 13  2026 config-6.8.0-100-generic
-rw-r--r--  1 root root   287560 июл  1 19:48 config-6.8.0-136-generic
drwxr-xr-x  5 root root     4096 июл 24 06:43 grub
lrwxrwxrwx  1 root root       28 июл 24 06:43 initrd.img -> initrd.img-6.8.0-136-generic
-rw-r--r--  1 root root 74662648 июл 24 06:42 initrd.img-6.8.0-100-generic
-rw-r--r--  1 root root 76542085 июл 24 06:48 initrd.img-6.8.0-136-generic
lrwxrwxrwx  1 root root       28 июн 25 06:31 initrd.img.old -> initrd.img-6.8.0-100-generic
drwx------  2 root root    16384 июн 25 06:29 lost+found
-rw-------  1 root root  9120274 янв 13  2026 System.map-6.8.0-100-generic
-rw-------  1 root root  9135033 июл  1 19:48 System.map-6.8.0-136-generic
lrwxrwxrwx  1 root root       25 июл 24 06:43 vmlinuz -> vmlinuz-6.8.0-136-generic
-rw-------  1 root root 15030664 янв 13  2026 vmlinuz-6.8.0-100-generic
-rw-------  1 root root 15063432 июл  1 19:50 vmlinuz-6.8.0-136-generic
lrwxrwxrwx  1 root root       25 июн 25 06:31 vmlinuz.old -> vmlinuz-6.8.0-100-generic
kosogor@vm1-server:~$ 
kosogor@vm1-server:~$ cd /tmp/
kosogor@vm1-server:/tmp$ ll kernel-6.8.12-custom.tar.gz
total 2829824
-rw-r--r--  1 kosogor kosogor 2897676358 июл 27 10:10 kernel-6.8.12-custom.tar.gz
kosogor@vm1-server:~$ lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sr0                        11:0    1  3,2G  1 rom  
vda                       253:0    0   30G  0 disk 
├─vda1                    253:1    0    1M  0 part 
├─vda2                    253:2    0    2G  0 part /boot
└─vda3                    253:3    0   28G  0 part 
  └─ubuntu--vg-ubuntu--lv 252:0    0   28G  0 lvm  /
kosogor@vm1-server:~$
kosogor@vm1-server:~$ df -h
Filesystem                         Size  Used Avail Use% Mounted on
tmpfs                              392M  1,2M  391M   1% /run
/dev/mapper/ubuntu--vg-ubuntu--lv   28G  9,0G   18G  35% /
tmpfs                              2,0G     0  2,0G   0% /dev/shm
tmpfs                              5,0M     0  5,0M   0% /run/lock
/dev/vda2                          2,0G  199M  1,6G  11% /boot
tmpfs                              392M   12K  392M   1% /run/user/1000
kosogor@vm1-server:~$
kosogor@vm1-server:/tmp$ sudo tar --extract --absolute-names --gzip --file kernel-6.8.12-custom.tar.gz
kosogor@vm1-server:/tmp$
kosogor@vm1-server:/tmp$ sudo mv config-6.8.12-custom /boot/
kosogor@vm1-server:/tmp$
kosogor@vm1-server:/tmp$ df -h
Filesystem                         Size  Used Avail Use% Mounted on
tmpfs                              392M  1,2M  391M   1% /run
/dev/mapper/ubuntu--vg-ubuntu--lv   28G   16G   11G  61% /
tmpfs                              2,0G     0  2,0G   0% /dev/shm
tmpfs                              5,0M     0  5,0M   0% /run/lock
/dev/vda2                          2,0G  728M  1,1G  40% /boot
tmpfs                              392M   12K  392M   1% /run/user/1000
kosogor@vm1-server:/tmp$ 
kosogor@vm1-server:/tmp$ 
kosogor@vm1-server:/tmp$ ll /boot
total 737896
drwxr-xr-x  4 root    root         4096 июл 27 10:54 ./
drwxr-xr-x 23 root    root         4096 июл 27 10:40 ../
-rw-r--r--  1 root    root       287599 янв 13  2026 config-6.8.0-100-generic
-rw-r--r--  1 root    root       287560 июл  1 19:48 config-6.8.0-136-generic
-rw-r--r--  1 kosogor kosogor    287157 июл 25 18:45 config-6.8.12-custom
drwxr-xr-x  5 root    root         4096 июл 24 06:43 grub/
lrwxrwxrwx  1 root    root           28 июл 24 06:43 initrd.img -> initrd.img-6.8.0-136-generic
-rw-r--r--  1 root    root     74662648 июл 24 06:42 initrd.img-6.8.0-100-generic
-rw-r--r--  1 root    root     76542085 июл 24 06:48 initrd.img-6.8.0-136-generic
-rw-r--r--  1 root    root    540336256 июл 27 10:54 initrd.img-6.8.12-custom
lrwxrwxrwx  1 root    root           28 июн 25 06:31 initrd.img.old -> initrd.img-6.8.0-100-generic
drwx------  2 root    root        16384 июн 25 06:29 lost+found/
-rw-------  1 root    root      9120274 янв 13  2026 System.map-6.8.0-100-generic
-rw-------  1 root    root      9135033 июл  1 19:48 System.map-6.8.0-136-generic
lrwxrwxrwx  1 root    root           25 июл 24 06:43 vmlinuz -> vmlinuz-6.8.0-136-generic
-rw-------  1 root    root     15030664 янв 13  2026 vmlinuz-6.8.0-100-generic
-rw-------  1 root    root     15063432 июл  1 19:50 vmlinuz-6.8.0-136-generic
-rw-r--r--  1 root    root     14787072 июл 27 07:39 vmlinuz-6.8.12-custom
lrwxrwxrwx  1 root    root           25 июн 25 06:31 vmlinuz.old -> vmlinuz-6.8.0-100-generic
kosogor@vm1-server:/tmp$ 
kosogor@vm1-server:/tmp$ ll /lib/modules
total 20
drwxr-xr-x  5 root root 4096 июл 27 10:43 ./
drwxr-xr-x 79 root root 4096 июл 24 06:47 ../
drwxr-xr-x  5 root root 4096 июн 25 06:31 6.8.0-100-generic/
drwxr-xr-x  5 root root 4096 июл 24 06:43 6.8.0-136-generic/
drwxr-xr-x  3 root root 4096 июл 27 07:36 6.8.12-custom/
kosogor@vm1-server:/tmp$ 
kosogor@vm1-server:/tmp$ sudo update-initramfs -c -k 6.8.12-custom
update-initramfs: Generating /boot/initrd.img-6.8.12-custom
kosogor@vm1-server:/tmp$ 
kosogor@vm1-server:/tmp$ sudo update-grub
Sourcing file `/etc/default/grub'
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-6.8.12-custom
Found initrd image: /boot/initrd.img-6.8.12-custom
Found linux image: /boot/vmlinuz-6.8.0-136-generic
Found initrd image: /boot/initrd.img-6.8.0-136-generic
Found linux image: /boot/vmlinuz-6.8.0-100-generic
Found initrd image: /boot/initrd.img-6.8.0-100-generic
Warning: os-prober will not be executed to detect other bootable partitions.
Systems on them will not be added to the GRUB boot configuration.
Check GRUB_DISABLE_OS_PROBER documentation entry.
Adding boot menu entry for UEFI Firmware Settings ...
done
kosogor@vm1-server:/tmp$ reboot
Call to Reboot failed: Interactive authentication required.
kosogor@vm1-server:/tmp$ sudo reboot

Broadcast message from root@vm1-server on pts/1 (Mon 2026-07-27 10:55:54 UTC):

The system will reboot now!

kosogor@vm1-server:/tmp$ Connection to 192.168.122.176 closed by remote host.
Connection to 192.168.122.176 closed.
[admin_insta11@mv334 ~]$ 
[admin_insta11@mv334 ~]$ ssh kosogor@192.168.122.176
kosogor@192.168.122.176's password: 
Welcome to Ubuntu 24.04.4 LTS (GNU/Linux 6.8.12-custom x86_64)

Last login: Mon Jul 27 10:27:03 2026 from 192.168.122.1
kosogor@vm1-server:~$ 
kosogor@vm1-server:~$ uname -r
6.8.12-custom
kosogor@vm1-server:~$
kosogor@vm1-server:~$ grep -i "udp" /boot/config-6.8.12-custom
CONFIG_NET_UDP_TUNNEL=m
CONFIG_INET_UDP_DIAG=m
CONFIG_NF_CT_PROTO_UDPLITE=y
CONFIG_IP_VS_PROTO_UDP=y
CONFIG_TIPC_MEDIA_UDP=y
CONFIG_6LOWPAN_NHC_UDP=m
# CONFIG_6LOWPAN_GHC_UDP is not set
CONFIG_BAREUDP=m
CONFIG_SPEAKUP_SYNTH_AUDPTR=m
# CONFIG_NFS_DISABLE_UDP_SUPPORT is not set
kosogor@vm1-server:~$ 
```

## 5. Окончательная настройка NFS-сервера и монтирование директории на NFS-клиенте по протоколу NFSv3 с использованием UDP:

Несмотря на включенные опции CONFIG_NFS_DISABLE_UDP_SUPPORT=n в ядре обеих ВМ, монтирование шары по протоколу NFSv3 с использованием UDP
сразу не получилось:

На клиенте:
```
kosogor@vm2-client:~$ sudo mount -t nfs -o udp,vers=3 192.168.122.176:/srv/share/tmp3 /mnt/nfs
[sudo] password for kosogor: 
Created symlink /run/systemd/system/remote-fs.target.wants/rpc-statd.service → /usr/lib/systemd/system/rpc-statd.service.
mount.nfs: requested NFS version or transport protocol is not supported for /mnt/nfs
kosogor@vm2-client:~$ 
```

и на самом сервере также по UDP монтирование не получилось, хотя по TCP монтируется нормально. Сервер NFS слушает только порты TCP:
```
kosogor@vm1-server:~$ 
kosogor@vm1-server:~$ sudo mount -t nfs -o proto=udp,vers=3 192.168.122.176:/srv/share/tmp3 /mnt/nfs
mount.nfs: requested NFS version or transport protocol is not supported for /mnt/nfs
kosogor@vm1-server:~$ sudo mount -t nfs -o proto=tcp,vers=3 192.168.122.176:/srv/share/tmp3 /mnt/nfs
kosogor@vm1-server:~$ sudo umount /mnt/nfs
kosogor@vm1-server:~$
kosogor@vm1-server:~$ ss -an | grep 2049
tcp   LISTEN 0      64                                                    0.0.0.0:2049              0.0.0.0:*           
tcp   LISTEN 0      64                                                       [::]:2049                 [::]:*           
kosogor@vm1-server:~$ 
```

Решение проблемы следующее (взято ИИ из интернета):

```
Сервер NFS запущен без аргумента -u , поэтому не слушает порты UDP:
    /usr/sbin/rpc.nfsd -t 892 → UDP выключен.
    /usr/sbin/rpc.nfsd -u -t 892 → UDP включён.

Если там нет -u — вот и причина: nfsd просто не создаёт UDP‑сокет.
Правильный способ: переопределить unit через systemctl edit

Это самый надёжный вариант, который ты сможешь потом легко откатить.

Создай override:

sudo systemctl edit nfs-server

Вставь ровно этот блок:

[Service]
ExecStart=
ExecStart=/usr/sbin/rpc.nfsd -u -t

Пустая строка ExecStart= обязательна: она сбрасывает оригинальный запуск без аргументов.

Сохрани и выйди из редактора.

Примени изменения:

sudo systemctl daemon-reload
sudo systemctl restart nfs-server
```

После применение указанного решения и перезагрузки сервера он стал прослушивать UDP порты, и монтирование протоколу NFSv3 с использованием UDP
получилось:

На NFS-сервере:
```
kosogor@vm1-server:~$ sudo systemctl edit nfs-server.service
Successfully installed edited file '/etc/systemd/system/nfs-server.service.d/override.conf'.
kosogor@vm1-server:~$ 
kosogor@vm1-server:~$ 
kosogor@vm1-server:~$ 
kosogor@vm1-server:~$ sudo systemctl restart nfs-server
kosogor@vm1-server:~$ 
kosogor@vm1-server:~$ 
kosogor@vm1-server:~$ ss -an | grep 2049
udp   UNCONN 0      0                                                     0.0.0.0:2049              0.0.0.0:*           
udp   UNCONN 0      0                                                        [::]:2049                 [::]:*           
tcp   LISTEN 0      64                                                    0.0.0.0:2049              0.0.0.0:*           
tcp   LISTEN 0      64                                                       [::]:2049                 [::]:*           
kosogor@vm1-server:~$ 
kosogor@vm1-server:~$ 
kosogor@vm1-server:~$ sudo mount -t nfs -o proto=udp,vers=3 192.168.122.176:/srv/share/tmp3 /mnt/nfs
kosogor@vm1-server:~$ 
kosogor@vm1-server:~$ 
kosogor@vm1-server:~$ mount -l | grep -i udp
192.168.122.176:/srv/share/tmp3 on /mnt/nfs type nfs (rw,relatime,vers=3,rsize=32768,wsize=32768,namlen=255,hard,proto=udp,timeo=11,retrans=3,sec=sys,mountaddr=192.168.122.176,mountvers=3,mountport=33285,mountproto=udp,local_lock=none,addr=192.168.122.176)
kosogor@vm1-server:~$ 
```

На NFS-клиенте:
```
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ sudo mount -t nfs -o proto=udp,vers=3 192.168.122.176:/srv/share/tmp3 /mnt/nfs
[sudo] password for kosogor: 
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ ll /mnt/nfs
total 16
drwxrwxrwx 2 nobody nogroup 4096 июл 24 19:18 ./
drwxr-xr-x 4 root   root    4096 июл 25 16:43 ../
-rw-rw-r-- 1 nobody nogroup   38 июл 24 19:18 created_from_server.txt
-rw-rw-r-- 1 nobody nogroup   41 июл 24 19:18 created_fron_client.txt
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ 
kosogor@vm2-client:~$ mount -l | grep -i nfs
192.168.122.176:/srv/share/tmp3 on /mnt/nfs type nfs (rw,relatime,vers=3,rsize=32768,wsize=32768,namlen=255,hard,proto=udp,timeo=11,retrans=3,sec=sys,mountaddr=192.168.122.176,mountvers=3,mountport=33285,mountproto=udp,local_lock=none,addr=192.168.122.176)
kosogor@vm2-client:~$
kosogor@vm2-client:~$ sudo umount /mnt/nfs
kosogor@vm2-client:~$ ll /mnt/nfs
total 8
drwxr-xr-x 2 root root 4096 июл 25 16:43 ./
drwxr-xr-x 4 root root 4096 июл 25 16:43 ../
kosogor@vm2-client:~$ 
```
