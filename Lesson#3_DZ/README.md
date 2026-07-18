# Занятие 09.06.2026 "Файловые системы и LVM - 1"

Работа с LVM

## Цель:

создавать и управлять логическими томами в LVM;

## Описание/Пошаговая инструкция выполнения домашнего задания:

## 🎯 Задание

На виртуальной машине с Ubuntu 24.04 и LVM.

    Уменьшить том под / до 8G.
    Выделить том под /home.
    Выделить том под /var - сделать в mirror.
    /home - сделать том для снапшотов.
    Прописать монтирование в fstab. Попробовать с разными опциями и разными файловыми системами (на выбор).
    
    Работа со снапшотами:
    - сгенерить файлы в /home/;
    - снять снапшот;
    - удалить часть файлов;
    - восстановиться со снапшота.

## ⭐️Задание со звездочкой 

На дисках поставить btrfs/zfs — с кэшем, снапшотами и разметить там каталог /opt.

Логировать работу можно с помощью утилиты script.

# Решение
0. Исходная конфигурация - в KVM к ВМ подключено 4 диска):

```
root@kosogor:/home/kosogor# lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sr0                        11:0    1  3,2G  0 rom  
vda                       253:0    0   30G  0 disk 
├─vda1                    253:1    0    1M  0 part 
├─vda2                    253:2    0    2G  0 part /boot
└─vda3                    253:3    0   28G  0 part 
  └─ubuntu--vg-ubuntu--lv 252:0    0   14G  0 lvm  /
vdb                       253:16   0   10G  0 disk 
vdc                       253:32   0    2G  0 disk 
vdd                       253:48   0    1G  0 disk 
vde                       253:64   0    1G  0 disk 
root@kosogor:/home/kosogor# df -h
Filesystem                         Size  Used Avail Use% Mounted on
tmpfs                              392M  1,2M  391M   1% /run
/dev/mapper/ubuntu--vg-ubuntu--lv   14G  6,7G  6,3G  52% /
tmpfs                              2,0G     0  2,0G   0% /dev/shm
tmpfs                              5,0M     0  5,0M   0% /run/lock
/dev/vda2                          2,0G  304M  1,5G  17% /boot
tmpfs                              392M   12K  392M   1% /run/user/1000
root@kosogor:/home/kosogor#
```

## 1. Уменьшить том под / до 8G.

Для этого:

1.1 Создаём PV на диске /dev/vdb , новую временную группу томов vg_root и временный новый логический том lv_root ,
переписываем на него содержимое директории / (которая является точкой монтирования логического тома ubuntu-vg/ubuntu-lv )
```
root@kosogor:/home/kosogor# pvcreate /dev/vdb
  Physical volume "/dev/vdb" successfully created.
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# vgcreate vg_root /dev/vdb
  Volume group "vg_root" successfully created
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# pvs
  PV         VG        Fmt  Attr PSize   PFree  
  /dev/vda3  ubuntu-vg lvm2 a--  <28,00g  14,00g
  /dev/vdb   vg_root   lvm2 a--  <10,00g <10,00g
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# vgs
  VG        #PV #LV #SN Attr   VSize   VFree  
  ubuntu-vg   1   1   0 wz--n- <28,00g  14,00g
  vg_root     1   0   0 wz--n- <10,00g <10,00g
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# lvcreate -n lv_root -l +100%FREE /dev/vg_root
WARNING: ext4 signature detected on /dev/vg_root/lv_root at offset 1080. Wipe it? [y/n]: y
  Wiping ext4 signature on /dev/vg_root/lv_root.
  Logical volume "lv_root" created.
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# mkfs.ext4 /dev/vg_root/lv_root
mke2fs 1.47.0 (5-Feb-2023)
Discarding device blocks: done                            
Creating filesystem with 2620416 4k blocks and 655360 inodes
Filesystem UUID: 5a16b84b-2149-469f-aa1b-ad51640f224f
Superblock backups stored on blocks: 
	32768, 98304, 163840, 229376, 294912, 819200, 884736, 1605632

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (16384 blocks): done
Writing superblocks and filesystem accounting information: done 

root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# mount /dev/vg_root/lv_root /mnt
root@kosogor:/home/kosogor# ll /mnt
total 24
drwxr-xr-x  3 root root  4096 июл 18 17:03 ./
drwxr-xr-x 26 root root  4096 июл 18 16:37 ../
drwx------  2 root root 16384 июл 18 17:03 lost+found/
root@kosogor:/home/kosogor# rsync -avxHAX --progress / /mnt/
sending incremental file list
./
bin -> usr/bin
lib -> usr/lib
lib64 -> usr/lib64
sbin -> usr/sbin
swap.img
  3.095.396.352 100%  413,90MB/s    0:00:07 (xfr#1, ir-chk=1031/1037)
bin.usr-is-merged/
boot/
cdrom/
data-snap/
data/
dev/
etc/
etc/.pwd.lock
              0 100%    0,00kB/s    0:00:00 (xfr#2, ir-chk=1197/1228)
etc/.resolv.conf.systemd-resolved.bak
            862 100%    0,78kB/s    0:00:01 (xfr#3, ir-chk=1196/1228)
etc/.updated
            208 100%    0,19kB/s    0:00:01 (xfr#4, ir-chk=1195/1228)
etc/adduser.conf
          3.444 100%    3,12kB/s    0:00:01 (xfr#5, ir-chk=1194/1228)
etc/bash.bashrc
          2.319 100%    2,10kB/s    0:00:01 (xfr#6, ir-chk=1193/1228)
<...>
            707 100%    2,62kB/s    0:00:00 (xfr#145079, to-chk=16/174502)
var/mail/
var/opt/
var/snap/
var/spool/
var/spool/mail -> ../mail
var/spool/cron/
var/spool/cron/crontabs/
var/spool/rsyslog/
var/tmp/
var/tmp/systemd-private-2aa54f8e2320490f878fee9a45b4bf39-ModemManager.service-R90hHZ/
var/tmp/systemd-private-2aa54f8e2320490f878fee9a45b4bf39-ModemManager.service-R90hHZ/tmp/
var/tmp/systemd-private-2aa54f8e2320490f878fee9a45b4bf39-polkit.service-r3A33r/
var/tmp/systemd-private-2aa54f8e2320490f878fee9a45b4bf39-polkit.service-r3A33r/tmp/
var/tmp/systemd-private-2aa54f8e2320490f878fee9a45b4bf39-systemd-logind.service-xA3fxF/
var/tmp/systemd-private-2aa54f8e2320490f878fee9a45b4bf39-systemd-logind.service-xA3fxF/tmp/
var/tmp/systemd-private-2aa54f8e2320490f878fee9a45b4bf39-systemd-resolved.service-Xr9RpU/
var/tmp/systemd-private-2aa54f8e2320490f878fee9a45b4bf39-systemd-resolved.service-Xr9RpU/tmp/
var/tmp/systemd-private-2aa54f8e2320490f878fee9a45b4bf39-systemd-timesyncd.service-JoSaiL/
var/tmp/systemd-private-2aa54f8e2320490f878fee9a45b4bf39-systemd-timesyncd.service-JoSaiL/tmp/
var/tmp/systemd-private-2aa54f8e2320490f878fee9a45b4bf39-upower.service-KTRcO3/
var/tmp/systemd-private-2aa54f8e2320490f878fee9a45b4bf39-upower.service-KTRcO3/tmp/

sent 7.179.372.832 bytes  received 2.896.279 bytes  52.234.684,44 bytes/sec
total size is 7.171.396.130  speedup is 1,00
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# ll /mnt/
total 3022968
drwxr-xr-x  26 root root       4096 июл 18 16:37 ./
drwxr-xr-x  26 root root       4096 июл 18 16:37 ../
lrwxrwxrwx   1 root root          7 апр 22  2024 bin -> usr/bin/
drwxr-xr-x   2 root root       4096 фев 26  2024 bin.usr-is-merged/
drwxr-xr-x   2 root root       4096 июл 18 06:39 boot/
dr-xr-xr-x   2 root root       4096 фев 10 06:52 cdrom/
drwxr-xr-x   2 root root       4096 июл 18 16:19 data/
drwxr-xr-x   2 root root       4096 июл 18 16:37 data-snap/
drwxr-xr-x   2 root root       4096 июл 18 17:02 dev/
drwxr-xr-x 108 root root       4096 июл 18 06:39 etc/
drwxr-xr-x   3 root root       4096 июн 25 06:37 home/
lrwxrwxrwx   1 root root          7 апр 22  2024 lib -> usr/lib/
lrwxrwxrwx   1 root root          9 апр 22  2024 lib64 -> usr/lib64/
drwxr-xr-x   2 root root       4096 фев 26  2024 lib.usr-is-merged/
drwx------   2 root root      16384 июн 25 06:29 lost+found/
drwxr-xr-x   2 root root       4096 фев 10 00:16 media/
drwxr-xr-x   2 root root       4096 июл 18 17:03 mnt/
drwxr-xr-x   2 root root       4096 фев 10 00:16 opt/
dr-xr-xr-x   2 root root       4096 июл 17 03:11 proc/
drwxr-xr-x   7 root root       4096 июл 13 20:43 raid/
drwx------   4 root root       4096 июл 18 16:52 root/
drwxr-xr-x   2 root root       4096 июл 18 16:46 run/
lrwxrwxrwx   1 root root          8 апр 22  2024 sbin -> usr/sbin/
drwxr-xr-x   2 root root       4096 окт  3  2025 sbin.usr-is-merged/
drwxr-xr-x   2 root root       4096 июн 25 06:42 snap/
drwxr-xr-x   2 root root       4096 фев 10 00:16 srv/
-rw-------   1 root root 3095396352 июн 25 06:31 swap.img
dr-xr-xr-x   2 root root       4096 июл 17 03:11 sys/
drwxrwxrwt  13 root root       4096 июл 18 17:02 tmp/
drwxr-xr-x  12 root root       4096 фев 10 00:16 usr/
drwxr-xr-x  13 root root       4096 июн 25 06:41 var/
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# ll /
total 3022952
drwxr-xr-x  26 root root       4096 июл 18 16:37 ./
drwxr-xr-x  26 root root       4096 июл 18 16:37 ../
lrwxrwxrwx   1 root root          7 апр 22  2024 bin -> usr/bin/
drwxr-xr-x   2 root root       4096 фев 26  2024 bin.usr-is-merged/
drwxr-xr-x   4 root root       4096 июл 18 06:39 boot/
dr-xr-xr-x   2 root root       4096 фев 10 06:52 cdrom/
drwxr-xr-x   2 root root       4096 июл 18 16:19 data/
drwxr-xr-x   2 root root       4096 июл 18 16:37 data-snap/
drwxr-xr-x  22 root root       4220 июл 18 17:02 dev/
drwxr-xr-x 108 root root       4096 июл 18 06:39 etc/
drwxr-xr-x   3 root root       4096 июн 25 06:37 home/
lrwxrwxrwx   1 root root          7 апр 22  2024 lib -> usr/lib/
lrwxrwxrwx   1 root root          9 апр 22  2024 lib64 -> usr/lib64/
drwxr-xr-x   2 root root       4096 фев 26  2024 lib.usr-is-merged/
drwx------   2 root root      16384 июн 25 06:29 lost+found/
drwxr-xr-x   2 root root       4096 фев 10 00:16 media/
drwxr-xr-x  26 root root       4096 июл 18 16:37 mnt/
drwxr-xr-x   2 root root       4096 фев 10 00:16 opt/
dr-xr-xr-x 221 root root          0 июл 17 03:11 proc/
drwxr-xr-x   7 root root       4096 июл 13 20:43 raid/
drwx------   4 root root       4096 июл 18 16:52 root/
drwxr-xr-x  30 root root        980 июл 18 16:46 run/
lrwxrwxrwx   1 root root          8 апр 22  2024 sbin -> usr/sbin/
drwxr-xr-x   2 root root       4096 окт  3  2025 sbin.usr-is-merged/
drwxr-xr-x   2 root root       4096 июн 25 06:42 snap/
drwxr-xr-x   2 root root       4096 фев 10 00:16 srv/
-rw-------   1 root root 3095396352 июн 25 06:31 swap.img
dr-xr-xr-x  13 root root          0 июл 18 17:04 sys/
drwxrwxrwt  13 root root       4096 июл 18 17:08 tmp/
drwxr-xr-x  12 root root       4096 фев 10 00:16 usr/
drwxr-xr-x  13 root root       4096 июн 25 06:41 var/
root@kosogor:/home/kosogor# 
```

1.2 Далее перемонтируем системные директории старой директории / на соответствующие скопированные в /mnt
системные директории, изменяем chroot на новую директорию /mnt , обновляем конфигурацию GRUB во всех
имеющихся ядрах и перегружаем сервер:

``` 

root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# for i in /proc/ /sys/ /dev/ /run/ /boot/; do mount --bind $i /mnt/$i; done
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# chroot /mnt/
root@kosogor:/# 
root@kosogor:/# grub-mkconfig -o /boot/grub/grub.cfg
Sourcing file `/etc/default/grub'
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-6.19.14-061914-generic
Found initrd image: /boot/initrd.img-6.19.14-061914-generic
Found linux image: /boot/vmlinuz-6.8.0-136-generic
Found initrd image: /boot/initrd.img-6.8.0-136-generic
Found linux image: /boot/vmlinuz-6.8.0-134-generic
Found initrd image: /boot/initrd.img-6.8.0-134-generic
Warning: os-prober will not be executed to detect other bootable partitions.
Systems on them will not be added to the GRUB boot configuration.
Check GRUB_DISABLE_OS_PROBER documentation entry.
Adding boot menu entry for UEFI Firmware Settings ...
done
root@kosogor:/# 
root@kosogor:/# 
root@kosogor:/# update-initramfs -u
update-initramfs: Generating /boot/initrd.img-6.19.14-061914-generic
root@kosogor:/# 
root@kosogor:/# uname -r
6.8.0-134-generic
root@kosogor:/# 
root@kosogor:/# update-initramfs -u -k 6.8.0-134-generic
update-initramfs: Generating /boot/initrd.img-6.8.0-134-generic
root@kosogor:/# 
root@kosogor:/# 
root@kosogor:/# lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sr0                        11:0    1  3,2G  0 rom  
vda                       253:0    0   30G  0 disk 
├─vda1                    253:1    0    1M  0 part 
├─vda2                    253:2    0    2G  0 part /boot
└─vda3                    253:3    0   28G  0 part 
  └─ubuntu--vg-ubuntu--lv 252:0    0   14G  0 lvm  
vdb                       253:16   0   10G  0 disk 
└─vg_root-lv_root         252:1    0   10G  0 lvm  /
vdc                       253:32   0    2G  0 disk 
vdd                       253:48   0    1G  0 disk 
vde                       253:64   0    1G  0 disk 
root@kosogor:/# 
root@kosogor:/# 
root@kosogor:/# exit
exit
root@kosogor:/home/kosogor# reboot
root@kosogor:/home/kosogor# Connection to 192.168.122.176 closed by remote host.
Connection to 192.168.122.176 closed.
[admin_insta11@mv334 ~]$ 
```

1.3 После перезагрузки временный том vg_root/lv_root становится точкой монтирования
корневой директории /  работающей ОС. Далее удаляем старый логический системный том ubuntu-vg/ubuntu-lv 
размером 14G и создаём новый с такими же именами размером 8G, создаём на нём 
файловую систему, монтируем новый том ubuntu-vg/ubuntu-lv и опять копируем на него всё
содержимое из / :

```
ssh kosogor@192.168.122.176
kosogor@192.168.122.176's password: 
Welcome to Ubuntu 24.04.4 LTS (GNU/Linux 6.8.0-136-generic x86_64)

Last login: Sat Jul 18 15:29:05 2026 from 192.168.122.1
kosogor@kosogor:~$ 
kosogor@kosogor:~$ sudo su
[sudo] password for kosogor: 
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sr0                        11:0    1  3,2G  1 rom  
vda                       253:0    0   30G  0 disk 
├─vda1                    253:1    0    1M  0 part 
├─vda2                    253:2    0    2G  0 part /boot
└─vda3                    253:3    0   28G  0 part 
  └─ubuntu--vg-ubuntu--lv 252:1    0   14G  0 lvm  
vdb                       253:16   0   10G  0 disk 
└─vg_root-lv_root         252:0    0   10G  0 lvm  /
vdc                       253:32   0    2G  0 disk 
vdd                       253:48   0    1G  0 disk 
vde                       253:64   0    1G  0 disk 
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# lvremove /dev/ubuntu-vg/ubuntu-lv
Do you really want to remove and DISCARD active logical volume ubuntu-vg/ubuntu-lv? [y/n]: y
  Logical volume "ubuntu-lv" successfully removed.
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# lvcreate -n ubuntu-vg/ubuntu-lv -L 8G /dev/ubuntu-vg
  Logical volume "ubuntu-lv" created.
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# mkfs.ext4 /dev/ubuntu-vg/ubuntu-lv
mke2fs 1.47.0 (5-Feb-2023)
Discarding device blocks: done                            
Creating filesystem with 2097152 4k blocks and 524288 inodes
Filesystem UUID: 641bf832-e47d-4f79-a696-3705e451e873
Superblock backups stored on blocks: 
	32768, 98304, 163840, 229376, 294912, 819200, 884736, 1605632

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (16384 blocks): done
Writing superblocks and filesystem accounting information: done 

root@kosogor:/home/kosogor# df -hT
Filesystem                  Type   Size  Used Avail Use% Mounted on
tmpfs                       tmpfs  392M  1,2M  391M   1% /run
/dev/mapper/vg_root-lv_root ext4   9,8G  7,1G  2,2G  77% /
tmpfs                       tmpfs  2,0G     0  2,0G   0% /dev/shm
tmpfs                       tmpfs  5,0M     0  5,0M   0% /run/lock
/dev/vda2                   ext4   2,0G  335M  1,5G  19% /boot
tmpfs                       tmpfs  392M   12K  392M   1% /run/user/1000
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sr0                        11:0    1  3,2G  1 rom  
vda                       253:0    0   30G  0 disk 
├─vda1                    253:1    0    1M  0 part 
├─vda2                    253:2    0    2G  0 part /boot
└─vda3                    253:3    0   28G  0 part 
  └─ubuntu--vg-ubuntu--lv 252:1    0    8G  0 lvm  
vdb                       253:16   0   10G  0 disk 
└─vg_root-lv_root         252:0    0   10G  0 lvm  /
vdc                       253:32   0    2G  0 disk 
vdd                       253:48   0    1G  0 disk 
vde                       253:64   0    1G  0 disk 
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# mount /dev/ubuntu-vg/ubuntu-lv /mnt
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# df -hT
Filesystem                        Type   Size  Used Avail Use% Mounted on
tmpfs                             tmpfs  392M  1,2M  391M   1% /run
/dev/mapper/vg_root-lv_root       ext4   9,8G  7,1G  2,2G  77% /
tmpfs                             tmpfs  2,0G     0  2,0G   0% /dev/shm
tmpfs                             tmpfs  5,0M     0  5,0M   0% /run/lock
/dev/vda2                         ext4   2,0G  335M  1,5G  19% /boot
tmpfs                             tmpfs  392M   12K  392M   1% /run/user/1000
/dev/mapper/ubuntu--vg-ubuntu--lv ext4   7,8G   24K  7,4G   1% /mnt
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# ll /
total 3022952
drwxr-xr-x  26 root root       4096 июл 18 16:37 ./
drwxr-xr-x  26 root root       4096 июл 18 16:37 ../
lrwxrwxrwx   1 root root          7 апр 22  2024 bin -> usr/bin/
drwxr-xr-x   2 root root       4096 фев 26  2024 bin.usr-is-merged/
drwxr-xr-x   4 root root       4096 июл 18 17:17 boot/
dr-xr-xr-x   2 root root       4096 фев 10 06:52 cdrom/
drwxr-xr-x   2 root root       4096 июл 18 16:19 data/
drwxr-xr-x   2 root root       4096 июл 18 16:37 data-snap/
drwxr-xr-x  22 root root       4220 июл 18 17:23 dev/
drwxr-xr-x 108 root root       4096 июл 18 06:39 etc/
drwxr-xr-x   3 root root       4096 июн 25 06:37 home/
lrwxrwxrwx   1 root root          7 апр 22  2024 lib -> usr/lib/
lrwxrwxrwx   1 root root          9 апр 22  2024 lib64 -> usr/lib64/
drwxr-xr-x   2 root root       4096 фев 26  2024 lib.usr-is-merged/
drwx------   2 root root      16384 июн 25 06:29 lost+found/
drwxr-xr-x   2 root root       4096 фев 10 00:16 media/
drwxr-xr-x   3 root root       4096 июл 18 17:24 mnt/
drwxr-xr-x   2 root root       4096 фев 10 00:16 opt/
dr-xr-xr-x 213 root root          0 июл 18 17:21 proc/
drwxr-xr-x   7 root root       4096 июл 13 20:43 raid/
drwx------   4 root root       4096 июл 18 16:52 root/
drwxr-xr-x  27 root root        820 июл 18 17:21 run/
lrwxrwxrwx   1 root root          8 апр 22  2024 sbin -> usr/sbin/
drwxr-xr-x   2 root root       4096 окт  3  2025 sbin.usr-is-merged/
drwxr-xr-x   2 root root       4096 июн 25 06:42 snap/
drwxr-xr-x   2 root root       4096 фев 10 00:16 srv/
-rw-------   1 root root 3095396352 июн 25 06:31 swap.img
dr-xr-xr-x  13 root root          0 июл 18 17:21 sys/
drwxrwxrwt  12 root root       4096 июл 18 17:21 tmp/
drwxr-xr-x  12 root root       4096 фев 10 00:16 usr/
drwxr-xr-x  13 root root       4096 июн 25 06:41 var/
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# ll /mnt
total 24
drwxr-xr-x  3 root root  4096 июл 18 17:24 ./
drwxr-xr-x 26 root root  4096 июл 18 16:37 ../
drwx------  2 root root 16384 июл 18 17:24 lost+found/
root@kosogor:/home/kosogor#
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# rsync -avxHAX --progress / /mnt/
sending incremental file list
./
bin -> usr/bin
lib -> usr/lib
lib64 -> usr/lib64
sbin -> usr/sbin
swap.img
  3.095.396.352 100%  174,24MB/s    0:00:16 (xfr#1, ir-chk=1025/1031)
bin.usr-is-merged/
<...>
var/log/unattended-upgrades/unattended-upgrades.log.1.gz
            707 100%    1,35kB/s    0:00:00 (xfr#145084, to-chk=14/174503)
var/mail/
var/opt/
var/snap/
var/spool/
var/spool/mail -> ../mail
var/spool/cron/
var/spool/cron/crontabs/
var/spool/rsyslog/
var/tmp/
var/tmp/systemd-private-7faf98d5f4ba4d18970c511fa48eb731-ModemManager.service-e8wstc/
var/tmp/systemd-private-7faf98d5f4ba4d18970c511fa48eb731-ModemManager.service-e8wstc/tmp/
var/tmp/systemd-private-7faf98d5f4ba4d18970c511fa48eb731-polkit.service-3c6G39/
var/tmp/systemd-private-7faf98d5f4ba4d18970c511fa48eb731-polkit.service-3c6G39/tmp/
var/tmp/systemd-private-7faf98d5f4ba4d18970c511fa48eb731-systemd-logind.service-hF0tGA/
var/tmp/systemd-private-7faf98d5f4ba4d18970c511fa48eb731-systemd-logind.service-hF0tGA/tmp/
var/tmp/systemd-private-7faf98d5f4ba4d18970c511fa48eb731-systemd-resolved.service-JCgI1f/
var/tmp/systemd-private-7faf98d5f4ba4d18970c511fa48eb731-systemd-resolved.service-JCgI1f/tmp/
var/tmp/systemd-private-7faf98d5f4ba4d18970c511fa48eb731-systemd-timesyncd.service-tbX1ex/
var/tmp/systemd-private-7faf98d5f4ba4d18970c511fa48eb731-systemd-timesyncd.service-tbX1ex/tmp/

sent 7.204.782.830 bytes  received 2.896.865 bytes  41.783.650,41 bytes/sec
total size is 7.196.804.912  speedup is 1,00
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# df -hT
Filesystem                        Type   Size  Used Avail Use% Mounted on
tmpfs                             tmpfs  392M  1,2M  391M   1% /run
/dev/mapper/vg_root-lv_root       ext4   9,8G  7,1G  2,2G  77% /
tmpfs                             tmpfs  2,0G     0  2,0G   0% /dev/shm
tmpfs                             tmpfs  5,0M     0  5,0M   0% /run/lock
/dev/vda2                         ext4   2,0G  335M  1,5G  19% /boot
tmpfs                             tmpfs  392M   12K  392M   1% /run/user/1000
/dev/mapper/ubuntu--vg-ubuntu--lv ext4   7,8G  7,1G  316M  96% /mnt
root@kosogor:/home/kosogor#
```

1.4 Далее опять перемонтируем системные директории старой директории / на соответствующие скопированные в /mnt
системные директории, изменяем chroot на новую директорию /mnt , обновляем конфигурацию GRUB во всех
имеющихся ядрах и перегружаем сервер. 
3. Но перед перезагрузкой сервера сразу же создаём группу томов из дисков vdc и vdd и новый
логический том с зеркалом для переноса на него данных /var (Примечание: пришлось увеличить размер диска vdd в KVM с 1G до 2G,
иначе зеркало создавалось недостаточного размера для копирования всех данных из директории /var, размер которых был 1,2G),
конфигурируем в /etc/fstab для автоматического монтирования. После перезагрузки директория /var
автоматически монтируется:

```
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# for i in /proc/ /sys/ /dev/ /run/ /boot/; do mount --bind $i /mnt/$i; done
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# chroot /mnt/
root@kosogor:/# 
root@kosogor:/# grub-mkconfig -o /boot/grub/grub.cfg
Sourcing file `/etc/default/grub'
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-6.19.14-061914-generic
Found initrd image: /boot/initrd.img-6.19.14-061914-generic
Found linux image: /boot/vmlinuz-6.8.0-136-generic
Found initrd image: /boot/initrd.img-6.8.0-136-generic
Found linux image: /boot/vmlinuz-6.8.0-134-generic
Found initrd image: /boot/initrd.img-6.8.0-134-generic
Warning: os-prober will not be executed to detect other bootable partitions.
Systems on them will not be added to the GRUB boot configuration.
Check GRUB_DISABLE_OS_PROBER documentation entry.
Adding boot menu entry for UEFI Firmware Settings ...
done
root@kosogor:/# update-initramfs -u
update-initramfs: Generating /boot/initrd.img-6.19.14-061914-generic
W: Couldn't identify type of root file system for fsck hook
root@kosogor:/# uname -r
6.8.0-136-generic
root@kosogor:/# update-initramfs -u -k 6.8.0-134-generic
update-initramfs: Generating /boot/initrd.img-6.8.0-134-generic
W: Couldn't identify type of root file system for fsck hook
root@kosogor:/# 
root@kosogor:/# update-initramfs -u -k 6.8.0-136-generic
update-initramfs: Generating /boot/initrd.img-6.8.0-136-generic
W: Couldn't identify type of root file system for fsck hook
root@kosogor:/# 

root@kosogor:/# lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sr0                        11:0    1  3,2G  1 rom  
vda                       253:0    0   30G  0 disk 
├─vda1                    253:1    0    1M  0 part 
├─vda2                    253:2    0    2G  0 part /boot
└─vda3                    253:3    0   28G  0 part 
  └─ubuntu--vg-ubuntu--lv 252:1    0    8G  0 lvm  /
vdb                       253:16   0   10G  0 disk 
└─vg_root-lv_root         252:0    0   10G  0 lvm  
vdc                       253:32   0    2G  0 disk 
vdd                       253:48   0    2G  0 disk 
vde                       253:64   0    1G  0 disk 
root@kosogor:/# 
root@kosogor:/# pvcreate /dev/sdc /dev/sdd
  No device found for /dev/sdc.
  No device found for /dev/sdd.
root@kosogor:/# pvcreate /dev/vdc /dev/vdd
  Physical volume "/dev/vdc" successfully created.
  Physical volume "/dev/vdd" successfully created.
root@kosogor:/# 
root@kosogor:/# 
root@kosogor:/# vgcreate vg_var /dev/vdc /dev/vdd
  Volume group "vg_var" successfully created
root@kosogor:/# 
root@kosogor:/# pvs
  PV         VG        Fmt  Attr PSize    PFree   
  /dev/vda3  ubuntu-vg lvm2 a--   <28,00g  <20,00g
  /dev/vdb   vg_root   lvm2 a--   <10,00g       0 
  /dev/vdc   vg_var    lvm2 a--    <2,00g   <2,00g
  /dev/vdd   vg_var    lvm2 a--  1020,00m 1020,00m
root@kosogor:/# 
root@kosogor:/# vgs
  VG        #PV #LV #SN Attr   VSize   VFree  
  ubuntu-vg   1   1   0 wz--n- <28,00g <20,00g
  vg_root     1   1   0 wz--n- <10,00g      0 
  vg_var      2   0   0 wz--n-   2,99g   2,99g
root@kosogor:/# 
root@kosogor:/# lvcreate -L 1,5G -m1 -n lv_var vg_var
  Rounding up size to full physical extent 1,50 GiB
  Logical volume "lv_var" created.
root@kosogor:/# 
root@kosogor:/# lvs
  LV        VG        Attr       LSize   Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  ubuntu-lv ubuntu-vg -wi-ao----   8,00g                                                    
  lv_root   vg_root   -wi-ao---- <10,00g                                                    
  lv_var    vg_var    rwi-a-r--- <1,50g                                    100,00          
root@kosogor:/# 
root@kosogor:/# mkfs.ext4 /dev/vg_var/lv_var
mke2fs 1.47.0 (5-Feb-2023)
Discarding device blocks: done                            
Creating filesystem with 243712 4k blocks and 60928 inodes
Filesystem UUID: 3c5adf27-3024-4a97-99e3-753bee5ab232
Superblock backups stored on blocks: 
	32768, 98304, 163840, 229376

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done

root@kosogor:/# 
root@kosogor:/# mount /dev/vg_var/lv_var /mnt
root@kosogor:/# 
root@kosogor:/# mount /dev/vg_var/lv_var /mnt
root@kosogor:/# 
root@kosogor:/# df -hT
Filesystem                        Type   Size  Used Avail Use% Mounted on
/dev/mapper/ubuntu--vg-ubuntu--lv ext4   7,8G  7,1G  316M  96% /
tmpfs                             tmpfs  392M  1,2M  391M   1% /run
/dev/vda2                         ext4   2,0G  334M  1,5G  19% /boot
/dev/mapper/vg_var-lv_var         ext4   1,5G   24K  1,4G   1% /mnt
root@kosogor:/# 
root@kosogor:/# cp -aR /var/* /mnt/
root@kosogor:/# 
root@kosogor:/# df -hT
Filesystem                        Type   Size  Used Avail Use% Mounted on
/dev/mapper/ubuntu--vg-ubuntu--lv ext4   7,8G  7,1G  316M  96% /
tmpfs                             tmpfs  392M  1,2M  391M   1% /run
/dev/vda2                         ext4   2,0G  334M  1,5G  19% /boot
/dev/mapper/vg_var-lv_var         ext4   1,5G  1,2G  215M  85% /mnt
root@kosogor:/# 
root@kosogor:/# du -sh /var/
1,2G	/var/
root@kosogor:/# du -sh /mnt/
1,2G	/mnt/
root@kosogor:/# 
root@kosogor:/# cat /etc/fstab
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
root@kosogor:/# 
root@kosogor:/# echo "`blkid | grep var: | awk '{print $2}'` /var ext4 defaults 0 0" >> /etc/fstab
root@kosogor:/# 
root@kosogor:/# cat /etc/fstab
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
UUID="d6199d43-5ea2-4d23-bbfa-87b2802bc487" /var ext4 defaults 0 0
root@kosogor:/# 
root@kosogor:/# 
root@kosogor:/# reboot
Running in chroot, ignoring request.
root@kosogor:/# exit
exit
root@kosogor:/home/kosogor# reboot

Broadcast message from root@kosogor on pts/1 (Sat 2026-07-18 18:32:51 UTC):

The system will reboot now!

root@kosogor:/home/kosogor# Connection to 192.168.122.176 closed by remote host.
Connection to 192.168.122.176 closed.
```

1.5 После перезагрузки новый том ubuntu-vg/ubuntu-lv с уменьшенным до 8G размером становится точкой монтирования
корневой директории /  работающей ОС. А также директория /var теперь располагается на логическом томе vg_var/lv_var ,
который организован в виде зеркала из двух дисков vdb и vdc. Далее удаляем временный логический системный том lv_root/vg_root :

```
[admin_insta11@mv334 ~]$ ssh kosogor@192.168.122.176
kosogor@192.168.122.176's password: 
Welcome to Ubuntu 24.04.4 LTS (GNU/Linux 6.8.0-136-generic x86_64)

Last login: Sat Jul 18 17:21:36 2026 from 192.168.122.1
kosogor@kosogor:~$ 
kosogor@kosogor:~$ 
kosogor@kosogor:~$ sudo su
[sudo] password for kosogor: 
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sr0                        11:0    1  3,2G  1 rom  
vda                       253:0    0   30G  0 disk 
├─vda1                    253:1    0    1M  0 part 
├─vda2                    253:2    0    2G  0 part /boot
└─vda3                    253:3    0   28G  0 part 
  └─ubuntu--vg-ubuntu--lv 252:2    0    8G  0 lvm  /
vdb                       253:16   0   10G  0 disk 
└─vg_root-lv_root         252:1    0   10G  0 lvm  
vdc                       253:32   0    2G  0 disk 
└─vg_var-lv_var           252:0    0  1,5G  0 lvm  /var
vdd                       253:48   0    1G  0 disk 
vde                       253:64   0    1G  0 disk 
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# ll /var
total 72
drwxr-xr-x 14 root root    4096 июл 18 18:33 ./
drwxr-xr-x 26 root root    4096 июл 18 16:37 ../
drwxr-xr-x  2 root root    4096 июл 18 15:40 backups/
drwxr-xr-x 16 root root    4096 июн 25 07:22 cache/
drwxrwsrwt  2 root root    4096 июл 11 06:25 crash/
drwxr-xr-x 44 root root    4096 июл  2 09:07 lib/
drwxrwsr-x  2 root staff   4096 апр 22  2024 local/
lrwxrwxrwx  1 root root       9 фев 10 00:16 lock -> /run/lock/
drwxrwxr-x 10 root syslog  4096 июл 18 18:33 log/
drwx------  2 root root   16384 июл 18 18:10 lost+found/
drwxrwsr-x  2 root mail    4096 фев 10 00:16 mail/
drwxr-xr-x  2 root root    4096 фев 10 00:16 opt/
lrwxrwxrwx  1 root root       4 фев 10 00:16 run -> /run/
drwxr-xr-x  2 root root    4096 ноя 21  2025 snap/
drwxr-xr-x  4 root root    4096 фев 10 00:34 spool/
drwxrwxrwt  7 root root    4096 июл 18 18:33 tmp/
-rw-r--r--  1 root root     208 фев 10 00:16 .updated
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# lvremove /dev/vg_root/lv_root
Do you really want to remove and DISCARD active logical volume vg_root/lv_root? [y/n]: y
  Logical volume "lv_root" successfully removed.
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# vgremove /dev/vg_root
  Volume group "vg_root" successfully removed
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# pvremove /dev/sdb
  No device found for /dev/sdb.
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# pvremove /dev/vdb
  Labels on physical volume "/dev/vdb" successfully wiped.
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sr0                        11:0    1  3,2G  1 rom  
vda                       253:0    0   30G  0 disk 
├─vda1                    253:1    0    1M  0 part 
├─vda2                    253:2    0    2G  0 part /boot
└─vda3                    253:3    0   28G  0 part 
  └─ubuntu--vg-ubuntu--lv 252:2    0    8G  0 lvm  /
vdb                       253:16   0   10G  0 disk 
vdc                       253:32   0    2G  0 disk 
└─vg_var-lv_var           252:0    0  1,5G  0 lvm  /var
vdd                       253:48   0    1G  0 disk 
vde                       253:64   0    1G  0 disk 
root@kosogor:/home/kosogor# vgs
  VG        #PV #LV #SN Attr   VSize   VFree  
  ubuntu-vg   1   1   0 wz--n- <28,00g <20,00g
  vg_var      2   1   0 wz--n-   2,99g   1,49g
root@kosogor:/home/kosogor# 
```

2. Далее выделяем логический том под /home (аналогично как делали для /var , но без зеркала), также
конфигурируем в /etc/fstab для автоматического монтирования. После перезагрузки директория /home
автоматически монтируется :

```
root@kosogor:/home/kosogor# lvcreate -n LogVol_Home -L 2G /dev/ubuntu-vg
  Logical volume "LogVol_Home" created.
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# mkfs.ext4 /dev/ubuntu-vg/LogVol_Home
mke2fs 1.47.0 (5-Feb-2023)
Discarding device blocks: done                            
Creating filesystem with 524288 4k blocks and 131072 inodes
Filesystem UUID: 39308c75-4344-4067-b1da-256a75276927
Superblock backups stored on blocks: 
	32768, 98304, 163840, 229376, 294912

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (16384 blocks): done
Writing superblocks and filesystem accounting information: done 

root@kosogor:/home/kosogor# mount /dev/ubuntu-vg/LogVol_Home /mnt/
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# cp -aR /home/* /mnt/
root@kosogor:/home/kosogor# rm -rf /home/*
root@kosogor:/home/kosogor# umount /mnt
root@kosogor:/home/kosogor# mount /dev/ubuntu-vg/LogVol_Home /home/
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# cat /etc/fstab
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
UUID="d6199d43-5ea2-4d23-bbfa-87b2802bc487" /var ext4 defaults 0 0
root@kosogor:/#
root@kosogor:/home/kosogor# echo "`blkid | grep Home | awk '{print $2}'` /home xfs defaults 0 0" >> /etc/fstab
root@kosogor:/#
root@kosogor:/# cat /etc/fstab
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
UUID="d6199d43-5ea2-4d23-bbfa-87b2802bc487" /var ext4 defaults 0 0
UUID="39308c75-4344-4067-b1da-256a75276927" /home ext4 defaults 0 0
root@kosogor:/# 
root@kosogor:/# 
root@kosogor:/# reboot

Broadcast message from root@kosogor on pts/1 (Sat 2026-07-18 18:47:35 UTC):

The system will reboot now!

root@kosogor:/# 

Session terminated
[admin_insta11@mv334 ~]$ 
[admin_insta11@mv334 ~]$ 
[admin_insta11@mv334 ~]$ ssh kosogor@192.168.122.176
kosogor@192.168.122.176's password: 
Welcome to Ubuntu 24.04.4 LTS (GNU/Linux 6.8.0-136-generic x86_64)

Last login: Sat Jul 18 18:42:28 2026 from 192.168.122.1
kosogor@kosogor:~$ 
kosogor@kosogor:~$ sudo su
[sudo] password for kosogor: 
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# df -hT
Filesystem                         Type   Size  Used Avail Use% Mounted on
tmpfs                              tmpfs  392M  1,2M  391M   1% /run
/dev/mapper/ubuntu--vg-ubuntu--lv  ext4   7,8G  6,9G  510M  94% /
tmpfs                              tmpfs  2,0G     0  2,0G   0% /dev/shm
tmpfs                              tmpfs  5,0M     0  5,0M   0% /run/lock
/dev/mapper/ubuntu--vg-LogVol_Home ext4   2,0G  194M  1,6G  11% /home
/dev/mapper/vg_var-lv_var          ext4   1,5G  564M  819M  41% /var
/dev/vda2                          ext4   2,0G  334M  1,5G  19% /boot
tmpfs                              tmpfs  392M   12K  392M   1% /run/user/1000
root@kosogor:/home/kosogor#
```

## 6. Работа со снапшотами:
    - сгенерить файлы в /home/;
    - снять снапшот;
    - удалить часть файлов;
    - восстановиться со снапшота :

```
root@kosogor:/home/kosogor# ll /home
total 28
drwxr-xr-x  4 root    root     4096 июл 18 18:39 ./
drwxr-xr-x 26 root    root     4096 июл 18 16:37 ../
drwxr-x---  5 kosogor kosogor  4096 июл 14 08:03 kosogor/
drwx------  2 root    root    16384 июл 18 18:38 lost+found/
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# touch /home/file{1..20}
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# ll /home
total 28
drwxr-xr-x  4 root    root     4096 июл 18 19:10 ./
drwxr-xr-x 26 root    root     4096 июл 18 16:37 ../
-rw-r--r--  1 root    root        0 июл 18 19:10 file1
-rw-r--r--  1 root    root        0 июл 18 19:10 file10
-rw-r--r--  1 root    root        0 июл 18 19:10 file11
-rw-r--r--  1 root    root        0 июл 18 19:10 file12
-rw-r--r--  1 root    root        0 июл 18 19:10 file13
-rw-r--r--  1 root    root        0 июл 18 19:10 file14
-rw-r--r--  1 root    root        0 июл 18 19:10 file15
-rw-r--r--  1 root    root        0 июл 18 19:10 file16
-rw-r--r--  1 root    root        0 июл 18 19:10 file17
-rw-r--r--  1 root    root        0 июл 18 19:10 file18
-rw-r--r--  1 root    root        0 июл 18 19:10 file19
-rw-r--r--  1 root    root        0 июл 18 19:10 file2
-rw-r--r--  1 root    root        0 июл 18 19:10 file20
-rw-r--r--  1 root    root        0 июл 18 19:10 file3
-rw-r--r--  1 root    root        0 июл 18 19:10 file4
-rw-r--r--  1 root    root        0 июл 18 19:10 file5
-rw-r--r--  1 root    root        0 июл 18 19:10 file6
-rw-r--r--  1 root    root        0 июл 18 19:10 file7
-rw-r--r--  1 root    root        0 июл 18 19:10 file8
-rw-r--r--  1 root    root        0 июл 18 19:10 file9
drwxr-x---  5 kosogor kosogor  4096 июл 14 08:03 kosogor/
drwx------  2 root    root    16384 июл 18 18:38 lost+found/
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# lvs
  LV          VG        Attr       LSize Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  LogVol_Home ubuntu-vg -wi-ao---- 2,00g                                                    
  ubuntu-lv   ubuntu-vg -wi-ao---- 8,00g                                                    
  lv_var      vg_var    -wi-ao---- 1,50g                                                    
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# lvcreate -L 100MB -s -n home_snap /dev/ubuntu-vg/LogVol_Home
  Logical volume "home_snap" created.
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# lvs
  LV          VG        Attr       LSize   Pool Origin      Data%  Meta%  Move Log Cpy%Sync Convert
  LogVol_Home ubuntu-vg owi-aos---   2,00g                                                         
  home_snap   ubuntu-vg swi-a-s--- 100,00m      LogVol_Home 0,01                                   
  ubuntu-lv   ubuntu-vg -wi-ao----   8,00g                                                         
  lv_var      vg_var    -wi-ao----   1,50g                                                         
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# rm -f /home/file{11..20}
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# ll /home
total 28
drwxr-xr-x  4 root    root     4096 июл 18 19:11 ./
drwxr-xr-x 26 root    root     4096 июл 18 16:37 ../
-rw-r--r--  1 root    root        0 июл 18 19:10 file1
-rw-r--r--  1 root    root        0 июл 18 19:10 file10
-rw-r--r--  1 root    root        0 июл 18 19:10 file2
-rw-r--r--  1 root    root        0 июл 18 19:10 file3
-rw-r--r--  1 root    root        0 июл 18 19:10 file4
-rw-r--r--  1 root    root        0 июл 18 19:10 file5
-rw-r--r--  1 root    root        0 июл 18 19:10 file6
-rw-r--r--  1 root    root        0 июл 18 19:10 file7
-rw-r--r--  1 root    root        0 июл 18 19:10 file8
-rw-r--r--  1 root    root        0 июл 18 19:10 file9
drwxr-x---  5 kosogor kosogor  4096 июл 14 08:03 kosogor/
drwx------  2 root    root    16384 июл 18 18:38 lost+found/
root@kosogor:/home/kosogor# 
root@kosogor:/# 
root@kosogor:/# umount /home
root@kosogor:/# lvconvert --merge /dev/ubuntu-vg/home_snap
  Merging of volume ubuntu-vg/home_snap started.
  ubuntu-vg/LogVol_Home: Merged: 100,00%
root@kosogor:/# 
root@kosogor:/# mount /dev/mapper/ubuntu--vg-LogVol_Home /home
root@kosogor:/# 
root@kosogor:/# ls -al /home
total 28
drwxr-xr-x  4 root    root     4096 июл 18 19:10 .
drwxr-xr-x 26 root    root     4096 июл 18 16:37 ..
-rw-r--r--  1 root    root        0 июл 18 19:10 file1
-rw-r--r--  1 root    root        0 июл 18 19:10 file10
-rw-r--r--  1 root    root        0 июл 18 19:10 file11
-rw-r--r--  1 root    root        0 июл 18 19:10 file12
-rw-r--r--  1 root    root        0 июл 18 19:10 file13
-rw-r--r--  1 root    root        0 июл 18 19:10 file14
-rw-r--r--  1 root    root        0 июл 18 19:10 file15
-rw-r--r--  1 root    root        0 июл 18 19:10 file16
-rw-r--r--  1 root    root        0 июл 18 19:10 file17
-rw-r--r--  1 root    root        0 июл 18 19:10 file18
-rw-r--r--  1 root    root        0 июл 18 19:10 file19
-rw-r--r--  1 root    root        0 июл 18 19:10 file2
-rw-r--r--  1 root    root        0 июл 18 19:10 file20
-rw-r--r--  1 root    root        0 июл 18 19:10 file3
-rw-r--r--  1 root    root        0 июл 18 19:10 file4
-rw-r--r--  1 root    root        0 июл 18 19:10 file5
-rw-r--r--  1 root    root        0 июл 18 19:10 file6
-rw-r--r--  1 root    root        0 июл 18 19:10 file7
-rw-r--r--  1 root    root        0 июл 18 19:10 file8
-rw-r--r--  1 root    root        0 июл 18 19:10 file9
drwxr-x---  5 kosogor kosogor  4096 июл 14 08:03 kosogor
drwx------  2 root    root    16384 июл 18 18:38 lost+found
root@kosogor:/# 
```
