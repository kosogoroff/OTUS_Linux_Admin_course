# Занятие 16.07.2026 "ZFS"

Практические навыки работы с ZFS

## Цель:

научиться самостоятельно устанавливать ZFS, настраивать пулы, изучить основные возможности ZFS;

## Описание/Пошаговая инструкция выполнения домашнего задания:


## 🎯 Что нужно сделать?

### Определить алгоритм с наилучшим сжатием:

    определить, какие алгоритмы сжатия поддерживает zfs (gzip, zle, lzjb, lz4);
    создать 4 файловых системы, на каждой применить свой алгоритм сжатия;
    для сжатия использовать либо текстовый файл, либо группу файлов.

### Определить настройки пула.
    С помощью команды zfs import собрать pool ZFS.
    Командами zfs определить настройки:

    размер хранилища;
    тип pool;
    значение recordsize;
    какое сжатие используется;
    какая контрольная сумма используется.

### Работа со снапшотами:

    скопировать файл из удаленной директории;
    восстановить файл локально. zfs receive;
    найти зашифрованное сообщение в файле secret_message.

# Решение
0. Исходная конфигурация - в KVM к ВМ подключено 8 дисков), устанавливаем поддержку zfs :

```
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sr0                        11:0    1  3,2G  0 rom  /mnt/cdrom
vda                       253:0    0   30G  0 disk 
├─vda1                    253:1    0    1M  0 part 
├─vda2                    253:2    0    2G  0 part /boot
└─vda3                    253:3    0   28G  0 part 
  └─ubuntu--vg-ubuntu--lv 252:0    0   14G  0 lvm  /
vdb                       253:16   0  512M  0 disk 
vdc                       253:32   0  512M  0 disk 
vdd                       253:48   0  512M  0 disk 
vde                       253:64   0  512M  0 disk 
vdf                       253:80   0  512M  0 disk 
vdg                       253:96   0  512M  0 disk 
vdh                       253:112  0  512M  0 disk 
vdi                       253:128  0  512M  0 disk 
root@kosogor:/home/kosogor#

root@kosogor:/home/kosogor# apt install zfsutils-linux
Чтение списков пакетов… Готово
Построение дерева зависимостей… Готово
Чтение информации о состоянии… Готово         
Будут установлены следующие дополнительные пакеты:
  libnvpair3linux libuutil3linux libzfs4linux libzpool5linux zfs-zed
Предлагаемые пакеты:
  nfs-kernel-server samba-common-bin zfs-initramfs | zfs-dracut
Следующие НОВЫЕ пакеты будут установлены:
  libnvpair3linux libuutil3linux libzfs4linux libzpool5linux zfs-zed zfsutils-linux
Обновлено 0 пакетов, установлено 6 новых пакетов, для удаления отмечено 0 пакетов, и 142 пакетов не обновлено.
Необходимо скачать 2 355 kB архивов.
После данной операции объём занятого дискового пространства возрастёт на 7 399 kB.
Хотите продолжить? [Д/н] y
Пол:1 http://us.archive.ubuntu.com/ubuntu noble-updates/main amd64 libnvpair3linux amd64 2.2.2-0ubuntu9.4 [62,1 kB]
Пол:2 http://us.archive.ubuntu.com/ubuntu noble-updates/main amd64 libuutil3linux amd64 2.2.2-0ubuntu9.4 [53,2 kB]
Пол:3 http://us.archive.ubuntu.com/ubuntu noble-updates/main amd64 libzfs4linux amd64 2.2.2-0ubuntu9.4 [224 kB]
Пол:4 http://us.archive.ubuntu.com/ubuntu noble-updates/main amd64 libzpool5linux amd64 2.2.2-0ubuntu9.4 [1 397 kB]
Пол:5 http://us.archive.ubuntu.com/ubuntu noble-updates/main amd64 zfsutils-linux amd64 2.2.2-0ubuntu9.4 [551 kB]
Пол:6 http://us.archive.ubuntu.com/ubuntu noble-updates/main amd64 zfs-zed amd64 2.2.2-0ubuntu9.4 [67,9 kB]
Получено 2 355 kB за 3с (746 kB/s)         
Выбор ранее не выбранного пакета libnvpair3linux.
(Чтение базы данных … на данный момент установлено 84633 файла и каталога.)
Подготовка к распаковке …/0-libnvpair3linux_2.2.2-0ubuntu9.4_amd64.deb …
Распаковывается libnvpair3linux (2.2.2-0ubuntu9.4) …
Выбор ранее не выбранного пакета libuutil3linux.
Подготовка к распаковке …/1-libuutil3linux_2.2.2-0ubuntu9.4_amd64.deb …
Распаковывается libuutil3linux (2.2.2-0ubuntu9.4) …
Выбор ранее не выбранного пакета libzfs4linux.
Подготовка к распаковке …/2-libzfs4linux_2.2.2-0ubuntu9.4_amd64.deb …
Распаковывается libzfs4linux (2.2.2-0ubuntu9.4) …
Выбор ранее не выбранного пакета libzpool5linux.
Подготовка к распаковке …/3-libzpool5linux_2.2.2-0ubuntu9.4_amd64.deb …
Распаковывается libzpool5linux (2.2.2-0ubuntu9.4) …
Выбор ранее не выбранного пакета zfsutils-linux.
Подготовка к распаковке …/4-zfsutils-linux_2.2.2-0ubuntu9.4_amd64.deb …
Распаковывается zfsutils-linux (2.2.2-0ubuntu9.4) …
Выбор ранее не выбранного пакета zfs-zed.
Подготовка к распаковке …/5-zfs-zed_2.2.2-0ubuntu9.4_amd64.deb …
Распаковывается zfs-zed (2.2.2-0ubuntu9.4) …
Настраивается пакет libnvpair3linux (2.2.2-0ubuntu9.4) …
Настраивается пакет libuutil3linux (2.2.2-0ubuntu9.4) …
Настраивается пакет libzpool5linux (2.2.2-0ubuntu9.4) …
Настраивается пакет libzfs4linux (2.2.2-0ubuntu9.4) …
Настраивается пакет zfsutils-linux (2.2.2-0ubuntu9.4) …
insmod /lib/modules/6.8.0-100-generic/kernel/zfs/spl.ko.zst 
insmod /lib/modules/6.8.0-100-generic/kernel/zfs/zfs.ko.zst 
Created symlink /etc/systemd/system/zfs-import.target.wants/zfs-import-cache.service → /usr/lib/systemd/system/zfs-import-cache.service.
Created symlink /etc/systemd/system/zfs.target.wants/zfs-import.target → /usr/lib/systemd/system/zfs-import.target.
Created symlink /etc/systemd/system/zfs-mount.service.wants/zfs-load-module.service → /usr/lib/systemd/system/zfs-load-module.service.
Created symlink /etc/systemd/system/zfs.target.wants/zfs-load-module.service → /usr/lib/systemd/system/zfs-load-module.service.
Created symlink /etc/systemd/system/zfs.target.wants/zfs-mount.service → /usr/lib/systemd/system/zfs-mount.service.
Created symlink /etc/systemd/system/zfs.target.wants/zfs-share.service → /usr/lib/systemd/system/zfs-share.service.
Created symlink /etc/systemd/system/zfs-volumes.target.wants/zfs-volume-wait.service → /usr/lib/systemd/system/zfs-volume-wait.service.
Created symlink /etc/systemd/system/zfs.target.wants/zfs-volumes.target → /usr/lib/systemd/system/zfs-volumes.target.
Created symlink /etc/systemd/system/multi-user.target.wants/zfs.target → /usr/lib/systemd/system/zfs.target.
zfs-import-scan.service is a disabled or a static unit, not starting it.
Настраивается пакет zfs-zed (2.2.2-0ubuntu9.4) …
Created symlink /etc/systemd/system/zed.service → /usr/lib/systemd/system/zfs-zed.service.
Created symlink /etc/systemd/system/zfs.target.wants/zfs-zed.service → /usr/lib/systemd/system/zfs-zed.service.
Обрабатываются триггеры для man-db (2.12.0-4build2) …
Обрабатываются триггеры для libc-bin (2.39-0ubuntu8.7) …
needrestart is being skipped since dpkg has failed
root@kosogor:/home/kosogor#
```

1. Создаём 4 пула zfs , задаём индивидуальные алгоритмы компрессии для каждого пула : 

```
root@kosogor:/home/kosogor# zpool create otus1 mirror /dev/vdb /dev/vdc
root@kosogor:/home/kosogor# zpool create otus2 mirror /dev/vdd /dev/vde
root@kosogor:/home/kosogor# zpool create otus3 mirror /dev/vdf /dev/vdg
root@kosogor:/home/kosogor# zpool create otus4 mirror /dev/vdh /dev/vdi
root@kosogor:/home/kosogor#
root@kosogor:/home/kosogor# zpool list
NAME    SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP    HEALTH  ALTROOT
otus1   480M   114K   480M        -         -     0%     0%  1.00x    ONLINE  -
otus2   480M   106K   480M        -         -     0%     0%  1.00x    ONLINE  -
otus3   480M   112K   480M        -         -     0%     0%  1.00x    ONLINE  -
otus4   480M   141K   480M        -         -     0%     0%  1.00x    ONLINE  -
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# zpool status
  pool: otus1
 state: ONLINE
config:

	NAME        STATE     READ WRITE CKSUM
	otus1       ONLINE       0     0     0
	  mirror-0  ONLINE       0     0     0
	    vdb     ONLINE       0     0     0
	    vdc     ONLINE       0     0     0

errors: No known data errors

  pool: otus2
 state: ONLINE
config:

	NAME        STATE     READ WRITE CKSUM
	otus2       ONLINE       0     0     0
	  mirror-0  ONLINE       0     0     0
	    vdd     ONLINE       0     0     0
	    vde     ONLINE       0     0     0

errors: No known data errors

  pool: otus3
 state: ONLINE
config:

	NAME        STATE     READ WRITE CKSUM
	otus3       ONLINE       0     0     0
	  mirror-0  ONLINE       0     0     0
	    vdf     ONLINE       0     0     0
	    vdg     ONLINE       0     0     0

errors: No known data errors

  pool: otus4
 state: ONLINE
config:

	NAME        STATE     READ WRITE CKSUM
	otus4       ONLINE       0     0     0
	  mirror-0  ONLINE       0     0     0
	    vdh     ONLINE       0     0     0
	    vdi     ONLINE       0     0     0

errors: No known data errors
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# zfs set compression=lzjb otus1
root@kosogor:/home/kosogor# zfs set compression=lz4 otus2
root@kosogor:/home/kosogor# zfs set compression=gzip-9 otus3
root@kosogor:/home/kosogor# zfs set compression=zle otus4
root@kosogor:/home/kosogor#
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# zfs get all | grep compression
otus1  compression           lzjb                       local
otus2  compression           lz4                        local
otus3  compression           gzip-9                     local
otus4  compression           zle                        local
root@kosogor:/home/kosogor#
```

2. Загружаем одинаковый файл во все пулы и сравниваем размер занимаемый этим файлом при разных алгоритмах компрессии:

```
root@kosogor:/home/kosogor# for i in {1..4}; do wget -P /otus$i https://gutenberg.org/cache/epub/2600/pg2600.converter.log; done
--2026-07-19 16:18:48--  https://gutenberg.org/cache/epub/2600/pg2600.converter.log
Resolving gutenberg.org (gutenberg.org)... 152.19.134.47, 2610:28:3090:3000:0:bad:cafe:47
Connecting to gutenberg.org (gutenberg.org)|152.19.134.47|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 41250559 (39M) [text/plain]
Saving to: ‘/otus1/pg2600.converter.log’

pg2600.converter.log                       100%[=======================================================================================>]  39,34M  3,57MB/s    in 11s     

2026-07-19 16:19:00 (3,51 MB/s) - ‘/otus1/pg2600.converter.log’ saved [41250559/41250559]

--2026-07-19 16:19:00--  https://gutenberg.org/cache/epub/2600/pg2600.converter.log
Resolving gutenberg.org (gutenberg.org)... 152.19.134.47, 2610:28:3090:3000:0:bad:cafe:47
Connecting to gutenberg.org (gutenberg.org)|152.19.134.47|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 41250559 (39M) [text/plain]
Saving to: ‘/otus2/pg2600.converter.log’

pg2600.converter.log                       100%[=======================================================================================>]  39,34M  4,77MB/s    in 9,3s    

2026-07-19 16:19:11 (4,23 MB/s) - ‘/otus2/pg2600.converter.log’ saved [41250559/41250559]

--2026-07-19 16:19:11--  https://gutenberg.org/cache/epub/2600/pg2600.converter.log
Resolving gutenberg.org (gutenberg.org)... 152.19.134.47, 2610:28:3090:3000:0:bad:cafe:47
Connecting to gutenberg.org (gutenberg.org)|152.19.134.47|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 41250559 (39M) [text/plain]
Saving to: ‘/otus3/pg2600.converter.log’

pg2600.converter.log                       100%[=======================================================================================>]  39,34M  3,07MB/s    in 13s     

2026-07-19 16:19:24 (3,09 MB/s) - ‘/otus3/pg2600.converter.log’ saved [41250559/41250559]

--2026-07-19 16:19:24--  https://gutenberg.org/cache/epub/2600/pg2600.converter.log
Resolving gutenberg.org (gutenberg.org)... 152.19.134.47, 2610:28:3090:3000:0:bad:cafe:47
Connecting to gutenberg.org (gutenberg.org)|152.19.134.47|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 41250559 (39M) [text/plain]
Saving to: ‘/otus4/pg2600.converter.log’

pg2600.converter.log                       100%[=======================================================================================>]  39,34M  4,50MB/s    in 10s     

2026-07-19 16:19:35 (3,95 MB/s) - ‘/otus4/pg2600.converter.log’ saved [41250559/41250559]

root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor#
root@kosogor:/home/kosogor# ll /otus{1,2,3,4}
/otus1:
total 22133
drwxr-xr-x  2 root root        3 июл 19 16:18 ./
drwxr-xr-x 27 root root     4096 июн 25 09:30 ../
-rw-r--r--  1 root root 41250559 июл  2 07:31 pg2600.converter.log

/otus2:
total 18026
drwxr-xr-x  2 root root        3 июл 19 16:19 ./
drwxr-xr-x 27 root root     4096 июн 25 09:30 ../
-rw-r--r--  1 root root 41250559 июл  2 07:31 pg2600.converter.log

/otus3:
total 10977
drwxr-xr-x  2 root root        3 июл 19 16:19 ./
drwxr-xr-x 27 root root     4096 июн 25 09:30 ../
-rw-r--r--  1 root root 41250559 июл  2 07:31 pg2600.converter.log

/otus4:
total 40317
drwxr-xr-x  2 root root        3 июл 19 16:19 ./
drwxr-xr-x 27 root root     4096 июн 25 09:30 ../
-rw-r--r--  1 root root 41250559 июл  2 07:31 pg2600.converter.log
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sr0                        11:0    1  3,2G  0 rom  /mnt/cdrom
vda                       253:0    0   30G  0 disk 
├─vda1                    253:1    0    1M  0 part 
├─vda2                    253:2    0    2G  0 part /boot
└─vda3                    253:3    0   28G  0 part 
  └─ubuntu--vg-ubuntu--lv 252:0    0   14G  0 lvm  /
vdb                       253:16   0  512M  0 disk 
├─vdb1                    253:17   0  502M  0 part 
└─vdb9                    253:25   0    8M  0 part 
vdc                       253:32   0  512M  0 disk 
├─vdc1                    253:33   0  502M  0 part 
└─vdc9                    253:41   0    8M  0 part 
vdd                       253:48   0  512M  0 disk 
├─vdd1                    253:49   0  502M  0 part 
└─vdd9                    253:57   0    8M  0 part 
vde                       253:64   0  512M  0 disk 
├─vde1                    253:65   0  502M  0 part 
└─vde9                    253:73   0    8M  0 part 
vdf                       253:80   0  512M  0 disk 
├─vdf1                    253:81   0  502M  0 part 
└─vdf9                    253:89   0    8M  0 part 
vdg                       253:96   0  512M  0 disk 
├─vdg1                    253:97   0  502M  0 part 
└─vdg9                    253:105  0    8M  0 part 
vdh                       253:112  0  512M  0 disk 
├─vdh1                    253:113  0  502M  0 part 
└─vdh9                    253:121  0    8M  0 part 
vdi                       253:128  0  512M  0 disk 
├─vdi1                    253:129  0  502M  0 part 
└─vdi9                    253:137  0    8M  0 part 
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# lsblk -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,FSTYPE,MOUNTPOINTS
NAME                      MAJ:MIN RM  SIZE RO TYPE FSTYPE      MOUNTPOINTS
sr0                        11:0    1  3,2G  0 rom  iso9660     /mnt/cdrom
vda                       253:0    0   30G  0 disk             
├─vda1                    253:1    0    1M  0 part             
├─vda2                    253:2    0    2G  0 part ext4        /boot
└─vda3                    253:3    0   28G  0 part LVM2_member 
  └─ubuntu--vg-ubuntu--lv 252:0    0   14G  0 lvm  ext4        /
vdb                       253:16   0  512M  0 disk             
├─vdb1                    253:17   0  502M  0 part zfs_member  
└─vdb9                    253:25   0    8M  0 part             
vdc                       253:32   0  512M  0 disk             
├─vdc1                    253:33   0  502M  0 part zfs_member  
└─vdc9                    253:41   0    8M  0 part             
vdd                       253:48   0  512M  0 disk             
├─vdd1                    253:49   0  502M  0 part zfs_member  
└─vdd9                    253:57   0    8M  0 part             
vde                       253:64   0  512M  0 disk             
├─vde1                    253:65   0  502M  0 part zfs_member  
└─vde9                    253:73   0    8M  0 part             
vdf                       253:80   0  512M  0 disk             
├─vdf1                    253:81   0  502M  0 part zfs_member  
└─vdf9                    253:89   0    8M  0 part             
vdg                       253:96   0  512M  0 disk             
├─vdg1                    253:97   0  502M  0 part zfs_member  
└─vdg9                    253:105  0    8M  0 part             
vdh                       253:112  0  512M  0 disk             
├─vdh1                    253:113  0  502M  0 part zfs_member  
└─vdh9                    253:121  0    8M  0 part             
vdi                       253:128  0  512M  0 disk             
├─vdi1                    253:129  0  502M  0 part zfs_member  
└─vdi9                    253:137  0    8M  0 part             
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# zfs list
NAME    USED  AVAIL  REFER  MOUNTPOINT
otus1  21.8M   330M  21.6M  /otus1
otus2  17.7M   334M  17.6M  /otus2
otus3  10.9M   341M  10.7M  /otus3
otus4  39.5M   312M  39.4M  /otus4
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# zfs get all | grep compressratio | grep -v ref
otus1  compressratio         1.82x                      -
otus2  compressratio         2.23x                      -
otus3  compressratio         3.66x                      -
otus4  compressratio         1.00x                      -
root@kosogor:/home/kosogor# 
```

3. Скачивание, импортирование и определение настроек пула zfs:

```
root@kosogor:/home/kosogor# wget -O archive.tar.gz --no-check-certificate 'https://drive.usercontent.google.com/download?id=1MvrcEp-WgAQe57aDEzxSRalPAwbNN1Bb&export=download'
--2026-07-19 16:34:50--  https://drive.usercontent.google.com/download?id=1MvrcEp-WgAQe57aDEzxSRalPAwbNN1Bb&export=download
Resolving drive.usercontent.google.com (drive.usercontent.google.com)... 173.194.73.132, 2a00:1450:4010:c0d::84
Connecting to drive.usercontent.google.com (drive.usercontent.google.com)|173.194.73.132|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 7275140 (6,9M) [application/octet-stream]
Saving to: ‘archive.tar.gz’

archive.tar.gz                             100%[=======================================================================================>]   6,94M  4,46MB/s    in 1,6s    

2026-07-19 16:34:59 (4,46 MB/s) - ‘archive.tar.gz’ saved [7275140/7275140]

root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# ll
total 7136
drwxr-x--- 4 kosogor kosogor    4096 июл 19 16:34 ./
drwxr-xr-x 3 root    root       4096 июн 25 06:37 ../
-rw-r--r-- 1 root    root    7275140 дек  6  2023 archive.tar.gz
-rw-r--r-- 1 kosogor kosogor     220 мар 31  2024 .bash_logout
-rw-r--r-- 1 kosogor kosogor    3771 мар 31  2024 .bashrc
drwx------ 2 kosogor kosogor    4096 июн 25 06:42 .cache/
-rw-r--r-- 1 kosogor kosogor     807 мар 31  2024 .profile
drwx------ 2 kosogor kosogor    4096 июн 25 06:42 .ssh/
-rw-r--r-- 1 kosogor kosogor       0 июн 25 06:43 .sudo_as_admin_successful
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# tar -xzvf archive.tar.gz
zpoolexport/
zpoolexport/filea
zpoolexport/fileb
root@kosogor:/home/kosogor# ll zpoolexport/
total 1024016
drwxr-xr-x 2 root    root         4096 мая 15  2020 ./
drwxr-x--- 5 kosogor kosogor      4096 июл 19 16:35 ../
-rw-r--r-- 1 root    root    524288000 мая 15  2020 filea
-rw-r--r-- 1 root    root    524288000 мая 15  2020 fileb
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# zpool import -d zpoolexport/
   pool: otus
     id: 6554193320433390805
  state: ONLINE
status: Some supported features are not enabled on the pool.
	(Note that they may be intentionally disabled if the
	'compatibility' property is set.)
 action: The pool can be imported using its name or numeric identifier, though
	some features will not be available without an explicit 'zpool upgrade'.
 config:

	otus                                 ONLINE
	  mirror-0                           ONLINE
	    /home/kosogor/zpoolexport/filea  ONLINE
	    /home/kosogor/zpoolexport/fileb  ONLINE
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# zpool import -d zpoolexport/ otus
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# zpool status
  pool: otus
 state: ONLINE
status: Some supported and requested features are not enabled on the pool.
	The pool can still be used, but some features are unavailable.
action: Enable all features using 'zpool upgrade'. Once this is done,
	the pool may no longer be accessible by software that does not support
	the features. See zpool-features(7) for details.
config:

	NAME                                 STATE     READ WRITE CKSUM
	otus                                 ONLINE       0     0     0
	  mirror-0                           ONLINE       0     0     0
	    /home/kosogor/zpoolexport/filea  ONLINE       0     0     0
	    /home/kosogor/zpoolexport/fileb  ONLINE       0     0     0

errors: No known data errors

  pool: otus1
 state: ONLINE
config:

	NAME        STATE     READ WRITE CKSUM
	otus1       ONLINE       0     0     0
	  mirror-0  ONLINE       0     0     0
	    vdb     ONLINE       0     0     0
	    vdc     ONLINE       0     0     0

errors: No known data errors

  pool: otus2
 state: ONLINE
config:

	NAME        STATE     READ WRITE CKSUM
	otus2       ONLINE       0     0     0
	  mirror-0  ONLINE       0     0     0
	    vdd     ONLINE       0     0     0
	    vde     ONLINE       0     0     0

errors: No known data errors

  pool: otus3
 state: ONLINE
config:

	NAME        STATE     READ WRITE CKSUM
	otus3       ONLINE       0     0     0
	  mirror-0  ONLINE       0     0     0
	    vdf     ONLINE       0     0     0
	    vdg     ONLINE       0     0     0

errors: No known data errors

  pool: otus4
 state: ONLINE
config:

	NAME        STATE     READ WRITE CKSUM
	otus4       ONLINE       0     0     0
	  mirror-0  ONLINE       0     0     0
	    vdh     ONLINE       0     0     0
	    vdi     ONLINE       0     0     0

errors: No known data errors
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# ll /
total 3022943
drwxr-xr-x  28 root root       4096 июл 19 16:38 ./
drwxr-xr-x  28 root root       4096 июл 19 16:38 ../
lrwxrwxrwx   1 root root          7 апр 22  2024 bin -> usr/bin/
drwxr-xr-x   2 root root       4096 фев 26  2024 bin.usr-is-merged/
drwxr-xr-x   4 root root       4096 июн 25 06:31 boot/
dr-xr-xr-x   2 root root       4096 фев 10 06:52 cdrom/
drwxr-xr-x  21 root root       4580 июн 25 09:30 dev/
drwxr-xr-x 109 root root       4096 июн 25 09:25 etc/
drwxr-xr-x   3 root root       4096 июн 25 06:37 home/
lrwxrwxrwx   1 root root          7 апр 22  2024 lib -> usr/lib/
lrwxrwxrwx   1 root root          9 апр 22  2024 lib64 -> usr/lib64/
drwxr-xr-x   2 root root       4096 фев 26  2024 lib.usr-is-merged/
drwx------   2 root root      16384 июн 25 06:29 lost+found/
drwxr-xr-x   2 root root       4096 фев 10 00:16 media/
drwxr-xr-x   3 root root       4096 июн 25 07:22 mnt/
drwxr-xr-x   2 root root       4096 фев 10 00:16 opt/
drwxr-xr-x   3 root root          3 мая 15  2020 otus/
drwxr-xr-x   2 root root          3 июл 19 16:18 otus1/
drwxr-xr-x   2 root root          3 июл 19 16:19 otus2/
drwxr-xr-x   2 root root          3 июл 19 16:19 otus3/
drwxr-xr-x   2 root root          3 июл 19 16:19 otus4/
dr-xr-xr-x 428 root root          0 июн 25 06:41 proc/
drwx------   3 root root       4096 июн 25 09:09 root/
drwxr-xr-x  30 root root        980 июл 19 16:22 run/
lrwxrwxrwx   1 root root          8 апр 22  2024 sbin -> usr/sbin/
drwxr-xr-x   2 root root       4096 окт  3  2025 sbin.usr-is-merged/
drwxr-xr-x   2 root root       4096 июн 25 06:42 snap/
drwxr-xr-x   2 root root       4096 фев 10 00:16 srv/
-rw-------   1 root root 3095396352 июн 25 06:31 swap.img
dr-xr-xr-x  13 root root          0 июл 19 16:26 sys/
drwxrwxrwt  14 root root       4096 июл 19 16:16 tmp/
drwxr-xr-x  12 root root       4096 фев 10 00:16 usr/
drwxr-xr-x  13 root root       4096 июн 25 06:41 var/
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# ll /otus
total 7
drwxr-xr-x   3 root root    3 мая 15  2020 ./
drwxr-xr-x  28 root root 4096 июл 19 16:38 ../
drwxr-xr-x 102 root root  102 мая 15  2020 hometask2/
root@kosogor:/home/kosogor#
root@kosogor:/home/kosogor# zpool status
  pool: otus
 state: ONLINE
status: Some supported and requested features are not enabled on the pool.
	The pool can still be used, but some features are unavailable.
action: Enable all features using 'zpool upgrade'. Once this is done,
	the pool may no longer be accessible by software that does not support
	the features. See zpool-features(7) for details.
config:

	NAME                                 STATE     READ WRITE CKSUM
	otus                                 ONLINE       0     0     0
	  mirror-0                           ONLINE       0     0     0
	    /home/kosogor/zpoolexport/filea  ONLINE       0     0     0
	    /home/kosogor/zpoolexport/fileb  ONLINE       0     0     0

errors: No known data errors

  pool: otus1
 state: ONLINE
config:

	NAME        STATE     READ WRITE CKSUM
	otus1       ONLINE       0     0     0
	  mirror-0  ONLINE       0     0     0
	    vdb     ONLINE       0     0     0
	    vdc     ONLINE       0     0     0

errors: No known data errors

  pool: otus2
 state: ONLINE
config:

	NAME        STATE     READ WRITE CKSUM
	otus2       ONLINE       0     0     0
	  mirror-0  ONLINE       0     0     0
	    vdd     ONLINE       0     0     0
	    vde     ONLINE       0     0     0

errors: No known data errors

  pool: otus3
 state: ONLINE
config:

	NAME        STATE     READ WRITE CKSUM
	otus3       ONLINE       0     0     0
	  mirror-0  ONLINE       0     0     0
	    vdf     ONLINE       0     0     0
	    vdg     ONLINE       0     0     0

errors: No known data errors

  pool: otus4
 state: ONLINE
config:

	NAME        STATE     READ WRITE CKSUM
	otus4       ONLINE       0     0     0
	  mirror-0  ONLINE       0     0     0
	    vdh     ONLINE       0     0     0
	    vdi     ONLINE       0     0     0

errors: No known data errors
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# zfs get all otus
NAME  PROPERTY              VALUE                      SOURCE
otus  type                  filesystem                 -
otus  creation              Пт мая 15  4:00 2020  -
otus  used                  2.04M                      -
otus  available             350M                       -
otus  referenced            24K                        -
otus  compressratio         1.00x                      -
otus  mounted               yes                        -
otus  quota                 none                       default
otus  reservation           none                       default
otus  recordsize            128K                       local
otus  mountpoint            /otus                      default
otus  sharenfs              off                        default
otus  checksum              sha256                     local
otus  compression           zle                        local
otus  atime                 on                         default
otus  devices               on                         default
otus  exec                  on                         default
otus  setuid                on                         default
otus  readonly              off                        default
otus  zoned                 off                        default
otus  snapdir               hidden                     default
otus  aclmode               discard                    default
otus  aclinherit            restricted                 default
otus  createtxg             1                          -
otus  canmount              on                         default
otus  xattr                 on                         default
otus  copies                1                          default
otus  version               5                          -
otus  utf8only              off                        -
otus  normalization         none                       -
otus  casesensitivity       sensitive                  -
otus  vscan                 off                        default
otus  nbmand                off                        default
otus  sharesmb              off                        default
otus  refquota              none                       default
otus  refreservation        none                       default
otus  guid                  14592242904030363272       -
otus  primarycache          all                        default
otus  secondarycache        all                        default
otus  usedbysnapshots       0B                         -
otus  usedbydataset         24K                        -
otus  usedbychildren        2.02M                      -
otus  usedbyrefreservation  0B                         -
otus  logbias               latency                    default
otus  objsetid              54                         -
otus  dedup                 off                        default
otus  mlslabel              none                       default
otus  sync                  standard                   default
otus  dnodesize             legacy                     default
otus  refcompressratio      1.00x                      -
otus  written               24K                        -
otus  logicalused           1021K                      -
otus  logicalreferenced     12K                        -
otus  volmode               default                    default
otus  filesystem_limit      none                       default
otus  snapshot_limit        none                       default
otus  filesystem_count      none                       default
otus  snapshot_count        none                       default
otus  snapdev               hidden                     default
otus  acltype               off                        default
otus  context               none                       default
otus  fscontext             none                       default
otus  defcontext            none                       default
otus  rootcontext           none                       default
otus  relatime              on                         default
otus  redundant_metadata    all                        default
otus  overlay               on                         default
otus  encryption            off                        default
otus  keylocation           none                       default
otus  keyformat             none                       default
otus  pbkdf2iters           0                          default
otus  special_small_blocks  0                          default
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# zfs get available otus
NAME  PROPERTY   VALUE  SOURCE
otus  available  350M   -
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# zfs get readonly otus
NAME  PROPERTY  VALUE   SOURCE
otus  readonly  off     default
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# zfs get recordsize otus
NAME  PROPERTY    VALUE    SOURCE
otus  recordsize  128K     local
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# zfs get compression otus
NAME  PROPERTY     VALUE           SOURCE
otus  compression  zle             local
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# zfs get checksum otus
NAME  PROPERTY  VALUE      SOURCE
otus  checksum  sha256     local
root@kosogor:/home/kosogor# 
```

4. Работа со снапшотом, поиск сообщения от преподавателя

```
root@kosogor:/home/kosogor# wget -O otus_task2.file --no-check-certificate https://drive.usercontent.google.com/download?id=1wgxjih8YZ-cqLqaZVa0lA3h3Y029c3oI&export=download
[1] 5143
root@kosogor:/home/kosogor# 
Redirecting output to ‘wget-log’.

[1]+  Done                    wget -O otus_task2.file --no-check-certificate https://drive.usercontent.google.com/download?id=1wgxjih8YZ-cqLqaZVa0lA3h3Y029c3oI
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# ll
total 12452
drwxr-x--- 5 kosogor kosogor    4096 июл 19 16:44 ./
drwxr-xr-x 3 root    root       4096 июн 25 06:37 ../
-rw-r--r-- 1 root    root    7275140 дек  6  2023 archive.tar.gz
-rw-r--r-- 1 kosogor kosogor     220 мар 31  2024 .bash_logout
-rw-r--r-- 1 kosogor kosogor    3771 мар 31  2024 .bashrc
drwx------ 2 kosogor kosogor    4096 июн 25 06:42 .cache/
-rw-r--r-- 1 root    root    5432736 дек  6  2023 otus_task2.file
-rw-r--r-- 1 kosogor kosogor     807 мар 31  2024 .profile
drwx------ 2 kosogor kosogor    4096 июн 25 06:42 .ssh/
-rw-r--r-- 1 kosogor kosogor       0 июн 25 06:43 .sudo_as_admin_successful
-rw-r--r-- 1 root    root       1910 июл 19 16:45 wget-log
drwxr-xr-x 2 root    root       4096 мая 15  2020 zpoolexport/
root@kosogor:/home/kosogor#
root@kosogor:/home/kosogor# zfs receive otus/test@today < otus_task2.file
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# ll /otus
total 9
drwxr-xr-x   4 root root    4 июл 19 16:51 ./
drwxr-xr-x  28 root root 4096 июл 19 16:38 ../
drwxr-xr-x 102 root root  102 мая 15  2020 hometask2/
drwxr-xr-x   3 root root   11 мая 15  2020 test/
root@kosogor:/home/kosogor# ll /otus/test
total 2591
drwxr-xr-x 3 root    root         11 мая 15  2020 ./
drwxr-xr-x 4 root    root          4 июл 19 16:51 ../
-rw-r--r-- 1 root    root          0 мая 15  2020 10M.file
-rw-r--r-- 1 root    root     727040 мая 15  2020 cinderella.tar
-rw-r--r-- 1 root    root         65 мая 15  2020 for_examaple.txt
-rw-r--r-- 1 root    root          0 мая 15  2020 homework4.txt
-rw-r--r-- 1 root    root     309987 мая 15  2020 Limbo.txt
-rw-r--r-- 1 root    root     509836 мая 15  2020 Moby_Dick.txt
drwxr-xr-x 3 kosogor kosogor       4 дек 18  2017 task1/
-rw-r--r-- 1 root    root    1209374 мая  6  2016 War_and_Peace.txt
-rw-r--r-- 1 root    root     398635 мая 15  2020 world.sql
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# find /otus/test -name "secret_message"
/otus/test/task1/file_mess/secret_message
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# cat /otus/test/task1/file_mess/secret_message
https://otus.ru/lessons/linux-hl/

root@kosogor:/home/kosogor# 
```

5. Общая конфигурация созданных пулов zfs :

```
root@kosogor:/home/kosogor# lsblk -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,FSTYPE,MOUNTPOINTS
NAME                      MAJ:MIN RM  SIZE RO TYPE FSTYPE      MOUNTPOINTS
sr0                        11:0    1  3,2G  0 rom  iso9660     /mnt/cdrom
vda                       253:0    0   30G  0 disk             
├─vda1                    253:1    0    1M  0 part             
├─vda2                    253:2    0    2G  0 part ext4        /boot
└─vda3                    253:3    0   28G  0 part LVM2_member 
  └─ubuntu--vg-ubuntu--lv 252:0    0   14G  0 lvm  ext4        /
vdb                       253:16   0  512M  0 disk             
├─vdb1                    253:17   0  502M  0 part zfs_member  
└─vdb9                    253:25   0    8M  0 part             
vdc                       253:32   0  512M  0 disk             
├─vdc1                    253:33   0  502M  0 part zfs_member  
└─vdc9                    253:41   0    8M  0 part             
vdd                       253:48   0  512M  0 disk             
├─vdd1                    253:49   0  502M  0 part zfs_member  
└─vdd9                    253:57   0    8M  0 part             
vde                       253:64   0  512M  0 disk             
├─vde1                    253:65   0  502M  0 part zfs_member  
└─vde9                    253:73   0    8M  0 part             
vdf                       253:80   0  512M  0 disk             
├─vdf1                    253:81   0  502M  0 part zfs_member  
└─vdf9                    253:89   0    8M  0 part             
vdg                       253:96   0  512M  0 disk             
├─vdg1                    253:97   0  502M  0 part zfs_member  
└─vdg9                    253:105  0    8M  0 part             
vdh                       253:112  0  512M  0 disk             
├─vdh1                    253:113  0  502M  0 part zfs_member  
└─vdh9                    253:121  0    8M  0 part             
vdi                       253:128  0  512M  0 disk             
├─vdi1                    253:129  0  502M  0 part zfs_member  
└─vdi9                    253:137  0    8M  0 part             
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# df -hT
Filesystem                        Type     Size  Used Avail Use% Mounted on
tmpfs                             tmpfs    392M  1,4M  391M   1% /run
/dev/mapper/ubuntu--vg-ubuntu--lv ext4      14G  7,6G  5,5G  59% /
tmpfs                             tmpfs    2,0G     0  2,0G   0% /dev/shm
tmpfs                             tmpfs    5,0M     0  5,0M   0% /run/lock
/dev/vda2                         ext4     2,0G  102M  1,7G   6% /boot
tmpfs                             tmpfs    392M   12K  392M   1% /run/user/1000
/dev/sr0                          iso9660  3,2G  3,2G     0 100% /mnt/cdrom
otus1                             zfs      352M   22M  331M   7% /otus1
otus2                             zfs      352M   18M  335M   6% /otus2
otus3                             zfs      352M   11M  342M   4% /otus3
otus4                             zfs      352M   40M  313M  12% /otus4
otus                              zfs      348M  128K  347M   1% /otus
otus/hometask2                    zfs      349M  2,0M  347M   1% /otus/hometask2
otus/test                         zfs      350M  2,9M  347M   1% /otus/test
root@kosogor:/home/kosogor#
root@kosogor:/home/kosogor# zpool status 
  pool: otus
 state: ONLINE
status: Some supported and requested features are not enabled on the pool.
	The pool can still be used, but some features are unavailable.
action: Enable all features using 'zpool upgrade'. Once this is done,
	the pool may no longer be accessible by software that does not support
	the features. See zpool-features(7) for details.
config:

	NAME                                 STATE     READ WRITE CKSUM
	otus                                 ONLINE       0     0     0
	  mirror-0                           ONLINE       0     0     0
	    /home/kosogor/zpoolexport/filea  ONLINE       0     0     0
	    /home/kosogor/zpoolexport/fileb  ONLINE       0     0     0

errors: No known data errors

  pool: otus1
 state: ONLINE
config:

	NAME        STATE     READ WRITE CKSUM
	otus1       ONLINE       0     0     0
	  mirror-0  ONLINE       0     0     0
	    vdb     ONLINE       0     0     0
	    vdc     ONLINE       0     0     0

errors: No known data errors

  pool: otus2
 state: ONLINE
config:

	NAME        STATE     READ WRITE CKSUM
	otus2       ONLINE       0     0     0
	  mirror-0  ONLINE       0     0     0
	    vdd     ONLINE       0     0     0
	    vde     ONLINE       0     0     0

errors: No known data errors

  pool: otus3
 state: ONLINE
config:

	NAME        STATE     READ WRITE CKSUM
	otus3       ONLINE       0     0     0
	  mirror-0  ONLINE       0     0     0
	    vdf     ONLINE       0     0     0
	    vdg     ONLINE       0     0     0

errors: No known data errors

  pool: otus4
 state: ONLINE
config:

	NAME        STATE     READ WRITE CKSUM
	otus4       ONLINE       0     0     0
	  mirror-0  ONLINE       0     0     0
	    vdh     ONLINE       0     0     0
	    vdi     ONLINE       0     0     0

errors: No known data errors
root@kosogor:/home/kosogor# 
```
