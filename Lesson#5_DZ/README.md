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
