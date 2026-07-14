# Занятие 06.07.2026 "Дисковая подсистема"
## Домашнее задание

Работа с mdadm
## Цель:

научиться использовать утилиту для управления программными RAID-массивами в Linux;

Описание/Пошаговая инструкция выполнения домашнего задания:


## Задание

1. Добавьте в виртуальную машину несколько дисков

2. Соберите RAID-0/1/5/10 на выбор

3. Сломайте и почините RAID

4. Создайте GPT таблицу, пять разделов и смонтируйте их в системе.

## Решение

1. Исходная конфигурация  - в KVM в ВМ подключено 5 дисков, четыре по 100М и пятый 200М ):

```
kosogor@kosogor:~$ sudo fdisk -l
Disk /dev/vda: 30 GiB, 32212254720 bytes, 62914560 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: gpt
Disk identifier: CECAB29B-5441-4951-A5D9-434CDF025260

Device       Start      End  Sectors Size Type
/dev/vda1     2048     4095     2048   1M BIOS boot
/dev/vda2     4096  4198399  4194304   2G Linux filesystem
/dev/vda3  4198400 62912511 58714112  28G Linux filesystem


Disk /dev/mapper/ubuntu--vg-ubuntu--lv: 14 GiB, 15028191232 bytes, 29351936 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes


Disk /dev/vdb: 100 MiB, 104857600 bytes, 204800 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes


Disk /dev/vdc: 100 MiB, 104857600 bytes, 204800 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes


Disk /dev/vdd: 100 MiB, 104857600 bytes, 204800 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes


Disk /dev/vde: 100 MiB, 104857600 bytes, 204800 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes


Disk /dev/vdf: 200 MiB, 209715200 bytes, 409600 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
kosogor@kosogor:~$ 
kosogor@kosogor:~$ 
kosogor@kosogor:~$ 
kosogor@kosogor:~$ 
kosogor@kosogor:~$ lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sr0                        11:0    1  3,2G  0 rom  
vda                       253:0    0   30G  0 disk 
├─vda1                    253:1    0    1M  0 part 
├─vda2                    253:2    0    2G  0 part /boot
└─vda3                    253:3    0   28G  0 part 
  └─ubuntu--vg-ubuntu--lv 252:0    0   14G  0 lvm  /
vdb                       253:16   0  100M  0 disk 
vdc                       253:32   0  100M  0 disk 
vdd                       253:48   0  100M  0 disk 
vde                       253:64   0  100M  0 disk 
vdf                       253:80   0  200M  0 disk 
kosogor@kosogor:~$ 
kosogor@kosogor:~$ 
kosogor@kosogor:~$ sudo lshw -short | grep disk
/0/100/2.2/0/0         /dev/vda    disk           32GB Virtual I/O device
/0/100/2.5/0/0         /dev/vdb    disk           104MB Virtual I/O device
/0/100/2.6/0/0         /dev/vdc    disk           104MB Virtual I/O device
/0/100/2.7/0/0         /dev/vdd    disk           104MB Virtual I/O device
/0/100/3/0/0           /dev/vde    disk           104MB Virtual I/O device
/0/100/3.1/0/0         /dev/vdf    disk           209MB Virtual I/O device
/0/100/1f.2/0.0.0      /dev/cdrom  disk           QEMU DVD-ROM
/0/100/1f.2/0.0.0/0    /dev/cdrom  disk           
kosogor@kosogor:~$ 
```

## 2. Собираем RAID-6 из пяти дисков:

```
kosogor@kosogor:~$ sudo mdadm --create --verbose /dev/md0 -l 6 -n 5 /dev/vd{b,c,d,e,f}
mdadm: layout defaults to left-symmetric
mdadm: layout defaults to left-symmetric
mdadm: chunk size defaults to 512K
mdadm: size set to 100352K
mdadm: largest drive (/dev/vdf) exceeds size (100352K) by more than 1%
Continue creating array? y
mdadm: Defaulting to version 1.2 metadata
mdadm: array /dev/md0 started.
kosogor@kosogor:~$ 
kosogor@kosogor:~$ 
kosogor@kosogor:~$ cat /proc/mdstat
Personalities : [raid0] [raid1] [raid4] [raid5] [raid6] [raid10] [linear] 
md0 : active raid6 vdf[4] vde[3] vdd[2] vdc[1] vdb[0]
      301056 blocks super 1.2 level 6, 512k chunk, algorithm 2 [5/5] [UUUUU]
      
unused devices: <none>
kosogor@kosogor:~$ 
kosogor@kosogor:~$ mdadm -D /dev/md0
mdadm: must be super-user to perform this action
kosogor@kosogor:~$ sudo mdadm -D /dev/md0
/dev/md0:
           Version : 1.2
     Creation Time : Mon Jul 13 20:11:47 2026
        Raid Level : raid6
        Array Size : 301056 (294.00 MiB 308.28 MB)
     Used Dev Size : 100352 (98.00 MiB 102.76 MB)
      Raid Devices : 5
     Total Devices : 5
       Persistence : Superblock is persistent

       Update Time : Mon Jul 13 20:11:48 2026
             State : clean 
    Active Devices : 5
   Working Devices : 5
    Failed Devices : 0
     Spare Devices : 0

            Layout : left-symmetric
        Chunk Size : 512K

Consistency Policy : resync

              Name : kosogor:0  (local to host kosogor)
              UUID : 40aaa16a:a9941f73:1f4ff687:70e39a45
            Events : 17

    Number   Major   Minor   RaidDevice State
       0     253       16        0      active sync   /dev/vdb
       1     253       32        1      active sync   /dev/vdc
       2     253       48        2      active sync   /dev/vdd
       3     253       64        3      active sync   /dev/vde
       4     253       80        4      active sync   /dev/vdf
kosogor@kosogor:~$ 
```

## 3.1 Ломаем RAID командой 'mdadm --fail' и затем чиним RAID

Ломаем:
```
kosogor@kosogor:~$ sudo mdadm /dev/md0 --fail /dev/vdc
mdadm: set /dev/vdc faulty in /dev/md0
kosogor@kosogor:~$ 
kosogor@kosogor:~$ sudo mdadm /dev/md0 --fail /dev/vdd
mdadm: set /dev/vdd faulty in /dev/md0
kosogor@kosogor:~$ 
kosogor@kosogor:~$ 
kosogor@kosogor:~$ sudo mdadm -D /dev/md0
/dev/md0:
           Version : 1.2
     Creation Time : Mon Jul 13 20:11:47 2026
        Raid Level : raid6
        Array Size : 301056 (294.00 MiB 308.28 MB)
     Used Dev Size : 100352 (98.00 MiB 102.76 MB)
      Raid Devices : 5
     Total Devices : 5
       Persistence : Superblock is persistent

       Update Time : Mon Jul 13 20:15:35 2026
             State : clean, degraded 
    Active Devices : 3
   Working Devices : 3
    Failed Devices : 2
     Spare Devices : 0

            Layout : left-symmetric
        Chunk Size : 512K

Consistency Policy : resync

              Name : kosogor:0  (local to host kosogor)
              UUID : 40aaa16a:a9941f73:1f4ff687:70e39a45
            Events : 21

    Number   Major   Minor   RaidDevice State
       0     253       16        0      active sync   /dev/vdb
       -       0        0        1      removed
       -       0        0        2      removed
       3     253       64        3      active sync   /dev/vde
       4     253       80        4      active sync   /dev/vdf

       1     253       32        -      faulty   /dev/vdc
       2     253       48        -      faulty   /dev/vdd
kosogor@kosogor:~$ 
kosogor@kosogor:~$ 
kosogor@kosogor:~$ sudo mdadm /dev/md0 --remove /dev/vdc
mdadm: hot removed /dev/vdc from /dev/md0
kosogor@kosogor:~$ 
kosogor@kosogor:~$ sudo mdadm /dev/md0 --remove /dev/vdd
mdadm: hot removed /dev/vdd from /dev/md0
kosogor@kosogor:~$ 
kosogor@kosogor:~$ 
kosogor@kosogor:~$ sudo mdadm -D /dev/md0
/dev/md0:
           Version : 1.2
     Creation Time : Mon Jul 13 20:11:47 2026
        Raid Level : raid6
        Array Size : 301056 (294.00 MiB 308.28 MB)
     Used Dev Size : 100352 (98.00 MiB 102.76 MB)
      Raid Devices : 5
     Total Devices : 3
       Persistence : Superblock is persistent

       Update Time : Mon Jul 13 20:17:06 2026
             State : clean, degraded 
    Active Devices : 3
   Working Devices : 3
    Failed Devices : 0
     Spare Devices : 0

            Layout : left-symmetric
        Chunk Size : 512K

Consistency Policy : resync

              Name : kosogor:0  (local to host kosogor)
              UUID : 40aaa16a:a9941f73:1f4ff687:70e39a45
            Events : 23

    Number   Major   Minor   RaidDevice State
       0     253       16        0      active sync   /dev/vdb
       -       0        0        1      removed
       -       0        0        2      removed
       3     253       64        3      active sync   /dev/vde
       4     253       80        4      active sync   /dev/vdf
kosogor@kosogor:~$ 
```

Затем чиним:

```
kosogor@kosogor:~$ sudo mdadm /dev/md0 --add /dev/vdc
mdadm: added /dev/vdc
kosogor@kosogor:~$ sudo mdadm /dev/md0 --add /dev/vdd
mdadm: added /dev/vdd
kosogor@kosogor:~$ 
kosogor@kosogor:~$ 
kosogor@kosogor:~$ 
kosogor@kosogor:~$ sudo mdadm -D /dev/md0
/dev/md0:
           Version : 1.2
     Creation Time : Mon Jul 13 20:11:47 2026
        Raid Level : raid6
        Array Size : 301056 (294.00 MiB 308.28 MB)
     Used Dev Size : 100352 (98.00 MiB 102.76 MB)
      Raid Devices : 5
     Total Devices : 5
       Persistence : Superblock is persistent

       Update Time : Mon Jul 13 20:17:57 2026
             State : clean 
    Active Devices : 5
   Working Devices : 5
    Failed Devices : 0
     Spare Devices : 0

            Layout : left-symmetric
        Chunk Size : 512K

Consistency Policy : resync

              Name : kosogor:0  (local to host kosogor)
              UUID : 40aaa16a:a9941f73:1f4ff687:70e39a45
            Events : 61

    Number   Major   Minor   RaidDevice State
       0     253       16        0      active sync   /dev/vdb
       5     253       32        1      active sync   /dev/vdc
       6     253       48        2      active sync   /dev/vdd
       3     253       64        3      active sync   /dev/vde
       4     253       80        4      active sync   /dev/vdf
kosogor@kosogor:~$ 
```

## 3.2 Ломаем RAID отключением дисков от ВМ в KVM и затем чиним RAID

Ломаем (отключаем диск vdf ёмкостью 200М):
```
kosogor@kosogor:~$ sudo mdadm -D /dev/md0
/dev/md0:
           Version : 1.2
     Creation Time : Mon Jul 13 20:11:47 2026
        Raid Level : raid6
        Array Size : 301056 (294.00 MiB 308.28 MB)
     Used Dev Size : 100352 (98.00 MiB 102.76 MB)
      Raid Devices : 5
     Total Devices : 4
       Persistence : Superblock is persistent

       Update Time : Mon Jul 13 20:17:57 2026
             State : clean, degraded 
    Active Devices : 4
   Working Devices : 4
    Failed Devices : 0
     Spare Devices : 0

            Layout : left-symmetric
        Chunk Size : 512K

Consistency Policy : resync

              Name : kosogor:0  (local to host kosogor)
              UUID : 40aaa16a:a9941f73:1f4ff687:70e39a45
            Events : 61

    Number   Major   Minor   RaidDevice State
       0     253       16        0      active sync   /dev/vdb
       5     253       32        1      active sync   /dev/vdc
       6     253       48        2      active sync   /dev/vdd
       3     253       64        3      active sync   /dev/vde
       -       0        0        4      removed
kosogor@kosogor:~$ 
kosogor@kosogor:~$ cat /proc/mdstat
Personalities : [raid0] [raid1] [raid4] [raid5] [raid6] [raid10] [linear] 
md0 : active (auto-read-only) raid6 vdd[6] vdc[5] vde[3] vdb[0]
      301056 blocks super 1.2 level 6, 512k chunk, algorithm 2 [5/4] [UUUU_]
      
unused devices: <none>
kosogor@kosogor:~$ lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE  MOUNTPOINTS
sr0                        11:0    1  3,2G  0 rom   
vda                       253:0    0   30G  0 disk  
├─vda1                    253:1    0    1M  0 part  
├─vda2                    253:2    0    2G  0 part  /boot
└─vda3                    253:3    0   28G  0 part  
  └─ubuntu--vg-ubuntu--lv 252:0    0   14G  0 lvm   /
vdb                       253:16   0  100M  0 disk  
└─md0                       9:0    0  294M  0 raid6 
vdc                       253:32   0  100M  0 disk  
└─md0                       9:0    0  294M  0 raid6 
vdd                       253:48   0  100M  0 disk  
└─md0                       9:0    0  294M  0 raid6 
vde                       253:64   0  100M  0 disk  
└─md0                       9:0    0  294M  0 raid6 
kosogor@kosogor:~$ 
```

Затем чиним (подключаем диск ёмкостью 100М):

```
kosogor@kosogor:~$ lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE  MOUNTPOINTS
sr0                        11:0    1  3,2G  0 rom   
vda                       253:0    0   30G  0 disk  
├─vda1                    253:1    0    1M  0 part  
├─vda2                    253:2    0    2G  0 part  /boot
└─vda3                    253:3    0   28G  0 part  
  └─ubuntu--vg-ubuntu--lv 252:0    0   14G  0 lvm   /
vdb                       253:16   0  100M  0 disk  
└─md0                       9:0    0  294M  0 raid6 
vdc                       253:32   0  100M  0 disk  
└─md0                       9:0    0  294M  0 raid6 
vdd                       253:48   0  100M  0 disk  
└─md0                       9:0    0  294M  0 raid6 
vde                       253:64   0  100M  0 disk  
└─md0                       9:0    0  294M  0 raid6 
vdg                       253:96   0  100M  0 disk  
kosogor@kosogor:~$ 
kosogor@kosogor:~$ 
kosogor@kosogor:~$ sudo mdadm /dev/md0 --add /dev/vdg
mdadm: added /dev/vdg
kosogor@kosogor:~$ 
kosogor@kosogor:~$ 
kosogor@kosogor:~$ cat /proc/mdstat
Personalities : [raid0] [raid1] [raid4] [raid5] [raid6] [raid10] [linear] 
md127 : inactive vdf[4](S)
      100352 blocks super 1.2
       
md0 : active raid6 vdg[7] vdd[6] vdc[5] vde[3] vdb[0]
      301056 blocks super 1.2 level 6, 512k chunk, algorithm 2 [5/5] [UUUUU]
      
unused devices: <none>
kosogor@kosogor:~$ 
kosogor@kosogor:~$ 
kosogor@kosogor:~$ sudo mdadm -D /dev/md0
/dev/md0:
           Version : 1.2
     Creation Time : Mon Jul 13 20:11:47 2026
        Raid Level : raid6
        Array Size : 301056 (294.00 MiB 308.28 MB)
     Used Dev Size : 100352 (98.00 MiB 102.76 MB)
      Raid Devices : 5
     Total Devices : 5
       Persistence : Superblock is persistent

       Update Time : Mon Jul 13 20:25:17 2026
             State : clean 
    Active Devices : 5
   Working Devices : 5
    Failed Devices : 0
     Spare Devices : 0

            Layout : left-symmetric
        Chunk Size : 512K

Consistency Policy : resync

              Name : kosogor:0  (local to host kosogor)
              UUID : 40aaa16a:a9941f73:1f4ff687:70e39a45
            Events : 81

    Number   Major   Minor   RaidDevice State
       0     253       16        0      active sync   /dev/vdb
       5     253       32        1      active sync   /dev/vdc
       6     253       48        2      active sync   /dev/vdd
       3     253       64        3      active sync   /dev/vde
       7     253       96        4      active sync   /dev/vdg
kosogor@kosogor:~$ 
kosogor@kosogor:~$ 
kosogor@kosogor:~$ sudo fdisk -l
Disk /dev/vda: 30 GiB, 32212254720 bytes, 62914560 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: gpt
Disk identifier: CECAB29B-5441-4951-A5D9-434CDF025260

Device       Start      End  Sectors Size Type
/dev/vda1     2048     4095     2048   1M BIOS boot
/dev/vda2     4096  4198399  4194304   2G Linux filesystem
/dev/vda3  4198400 62912511 58714112  28G Linux filesystem


Disk /dev/mapper/ubuntu--vg-ubuntu--lv: 14 GiB, 15028191232 bytes, 29351936 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes


Disk /dev/vdb: 100 MiB, 104857600 bytes, 204800 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes


Disk /dev/vdc: 100 MiB, 104857600 bytes, 204800 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes


Disk /dev/vdd: 100 MiB, 104857600 bytes, 204800 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes


Disk /dev/vde: 100 MiB, 104857600 bytes, 204800 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes


Disk /dev/md0: 294 MiB, 308281344 bytes, 602112 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 524288 bytes / 1572864 bytes


Disk /dev/vdg: 100 MiB, 104857600 bytes, 204800 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
kosogor@kosogor:~$ 
kosogor@kosogor:~$ 
kosogor@kosogor:~$ lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE  MOUNTPOINTS
sr0                        11:0    1  3,2G  0 rom   
vda                       253:0    0   30G  0 disk  
├─vda1                    253:1    0    1M  0 part  
├─vda2                    253:2    0    2G  0 part  /boot
└─vda3                    253:3    0   28G  0 part  
  └─ubuntu--vg-ubuntu--lv 252:0    0   14G  0 lvm   /
vdb                       253:16   0  100M  0 disk  
└─md0                       9:0    0  294M  0 raid6 
vdc                       253:32   0  100M  0 disk  
└─md0                       9:0    0  294M  0 raid6 
vdd                       253:48   0  100M  0 disk  
└─md0                       9:0    0  294M  0 raid6 
vde                       253:64   0  100M  0 disk  
└─md0                       9:0    0  294M  0 raid6 
vdg                       253:96   0  100M  0 disk  
└─md0                       9:0    0  294M  0 raid6 
kosogor@kosogor:~$ 
```

## 4. Создаём GPT таблицу, пять разделов и смонтируем их в системе.

```
kosogor@kosogor:~$ sudo parted -s /dev/md0 mklabel gpt
kosogor@kosogor:~$ lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE  MOUNTPOINTS
sr0                        11:0    1  3,2G  0 rom   
vda                       253:0    0   30G  0 disk  
├─vda1                    253:1    0    1M  0 part  
├─vda2                    253:2    0    2G  0 part  /boot
└─vda3                    253:3    0   28G  0 part  
  └─ubuntu--vg-ubuntu--lv 252:0    0   14G  0 lvm   /
vdb                       253:16   0  100M  0 disk  
└─md0                       9:0    0  294M  0 raid6 
vdc                       253:32   0  100M  0 disk  
└─md0                       9:0    0  294M  0 raid6 
vdd                       253:48   0  100M  0 disk  
└─md0                       9:0    0  294M  0 raid6 
vde                       253:64   0  100M  0 disk  
└─md0                       9:0    0  294M  0 raid6 
vdg                       253:96   0  100M  0 disk  
└─md0                       9:0    0  294M  0 raid6 
kosogor@kosogor:~$ man lsblk

kosogor@kosogor:~$ lsblk -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,FSTYPE,MOUNTPOINTS
NAME                      MAJ:MIN RM  SIZE RO TYPE  FSTYPE            MOUNTPOINTS
sr0                        11:0    1  3,2G  0 rom   iso9660           
vda                       253:0    0   30G  0 disk                    
├─vda1                    253:1    0    1M  0 part                    
├─vda2                    253:2    0    2G  0 part  ext4              /boot
└─vda3                    253:3    0   28G  0 part  LVM2_member       
  └─ubuntu--vg-ubuntu--lv 252:0    0   14G  0 lvm   ext4              /
vdb                       253:16   0  100M  0 disk  linux_raid_member 
└─md0                       9:0    0  294M  0 raid6                   
vdc                       253:32   0  100M  0 disk  linux_raid_member 
└─md0                       9:0    0  294M  0 raid6                   
vdd                       253:48   0  100M  0 disk  linux_raid_member 
└─md0                       9:0    0  294M  0 raid6                   
vde                       253:64   0  100M  0 disk  linux_raid_member 
└─md0                       9:0    0  294M  0 raid6                   
vdg                       253:96   0  100M  0 disk  linux_raid_member 
└─md0                       9:0    0  294M  0 raid6                   
kosogor@kosogor:~$ 
kosogor@kosogor:~$ 
kosogor@kosogor:~$ 
kosogor@kosogor:~$ 
kosogor@kosogor:~$ sudo parted /dev/md0 mkpart primary ext4 0% 20%
Warning: The resulting partition is not properly aligned for best performance: 34s % 3072s != 0s
Ignore/Cancel? i                                                          
Information: You may need to update /etc/fstab.

kosogor@kosogor:~$ sudo parted /dev/md0 mkpart primary ext4 20% 40%       
Information: You may need to update /etc/fstab.

kosogor@kosogor:~$ sudo parted /dev/md0 mkpart primary ext4 40% 60%      
Information: You may need to update /etc/fstab.

kosogor@kosogor:~$ sudo parted /dev/md0 mkpart primary ext4 60% 80%      
Information: You may need to update /etc/fstab.

kosogor@kosogor:~$ sudo parted /dev/md0 mkpart primary ext4 80% 100%     
Information: You may need to update /etc/fstab.

kosogor@kosogor:~$                                                        
kosogor@kosogor:~$ 
kosogor@kosogor:~$ lsblk -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,FSTYPE,MOUNTPOINTS
NAME                      MAJ:MIN RM  SIZE RO TYPE  FSTYPE            MOUNTPOINTS
sr0                        11:0    1  3,2G  0 rom   iso9660           
vda                       253:0    0   30G  0 disk                    
├─vda1                    253:1    0    1M  0 part                    
├─vda2                    253:2    0    2G  0 part  ext4              /boot
└─vda3                    253:3    0   28G  0 part  LVM2_member       
  └─ubuntu--vg-ubuntu--lv 252:0    0   14G  0 lvm   ext4              /
vdb                       253:16   0  100M  0 disk  linux_raid_member 
└─md0                       9:0    0  294M  0 raid6                   
  ├─md0p1                 259:1    0 58,8M  0 part                    
  ├─md0p2                 259:4    0   57M  0 part                    
  ├─md0p3                 259:5    0   60M  0 part                    
  ├─md0p4                 259:8    0 58,5M  0 part                    
  └─md0p5                 259:9    0 58,5M  0 part                    
vdc                       253:32   0  100M  0 disk  linux_raid_member 
└─md0                       9:0    0  294M  0 raid6                   
  ├─md0p1                 259:1    0 58,8M  0 part                    
  ├─md0p2                 259:4    0   57M  0 part                    
  ├─md0p3                 259:5    0   60M  0 part                    
  ├─md0p4                 259:8    0 58,5M  0 part                    
  └─md0p5                 259:9    0 58,5M  0 part                    
vdd                       253:48   0  100M  0 disk  linux_raid_member 
└─md0                       9:0    0  294M  0 raid6                   
  ├─md0p1                 259:1    0 58,8M  0 part                    
  ├─md0p2                 259:4    0   57M  0 part                    
  ├─md0p3                 259:5    0   60M  0 part                    
  ├─md0p4                 259:8    0 58,5M  0 part                    
  └─md0p5                 259:9    0 58,5M  0 part                    
vde                       253:64   0  100M  0 disk  linux_raid_member 
└─md0                       9:0    0  294M  0 raid6                   
  ├─md0p1                 259:1    0 58,8M  0 part                    
  ├─md0p2                 259:4    0   57M  0 part                    
  ├─md0p3                 259:5    0   60M  0 part                    
  ├─md0p4                 259:8    0 58,5M  0 part                    
  └─md0p5                 259:9    0 58,5M  0 part                    
vdg                       253:96   0  100M  0 disk  linux_raid_member 
└─md0                       9:0    0  294M  0 raid6                   
  ├─md0p1                 259:1    0 58,8M  0 part                    
  ├─md0p2                 259:4    0   57M  0 part                    
  ├─md0p3                 259:5    0   60M  0 part                    
  ├─md0p4                 259:8    0 58,5M  0 part                    
  └─md0p5                 259:9    0 58,5M  0 part                    
kosogor@kosogor:~$ for i in $(seq 1 5); do sudo mkfs.ext4 /dev/md0p$i; done
mke2fs 1.47.0 (5-Feb-2023)
/dev/md0p1 alignment is offset by 506880 bytes.
This may result in very poor performance, (re)-partitioning suggested.
Creating filesystem with 15048 4k blocks and 15056 inodes

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (1024 blocks): done
Writing superblocks and filesystem accounting information: done

mke2fs 1.47.0 (5-Feb-2023)
Creating filesystem with 14592 4k blocks and 14592 inodes

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (1024 blocks): done
Writing superblocks and filesystem accounting information: done

mke2fs 1.47.0 (5-Feb-2023)
Creating filesystem with 15360 4k blocks and 15360 inodes

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (1024 blocks): done
Writing superblocks and filesystem accounting information: done

mke2fs 1.47.0 (5-Feb-2023)
Creating filesystem with 14976 4k blocks and 14976 inodes

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (1024 blocks): done
Writing superblocks and filesystem accounting information: done

mke2fs 1.47.0 (5-Feb-2023)
Creating filesystem with 14971 4k blocks and 14976 inodes

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (1024 blocks): done
Writing superblocks and filesystem accounting information: done

kosogor@kosogor:~$ 
kosogor@kosogor:~$ 
kosogor@kosogor:~$ lsblk -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,FSTYPE,MOUNTPOINTS
NAME                      MAJ:MIN RM  SIZE RO TYPE  FSTYPE            MOUNTPOINTS
sr0                        11:0    1  3,2G  0 rom   iso9660           
vda                       253:0    0   30G  0 disk                    
├─vda1                    253:1    0    1M  0 part                    
├─vda2                    253:2    0    2G  0 part  ext4              /boot
└─vda3                    253:3    0   28G  0 part  LVM2_member       
  └─ubuntu--vg-ubuntu--lv 252:0    0   14G  0 lvm   ext4              /
vdb                       253:16   0  100M  0 disk  linux_raid_member 
└─md0                       9:0    0  294M  0 raid6                   
  ├─md0p1                 259:1    0 58,8M  0 part  ext4              
  ├─md0p2                 259:4    0   57M  0 part  ext4              
  ├─md0p3                 259:5    0   60M  0 part  ext4              
  ├─md0p4                 259:8    0 58,5M  0 part  ext4              
  └─md0p5                 259:9    0 58,5M  0 part  ext4              
vdc                       253:32   0  100M  0 disk  linux_raid_member 
└─md0                       9:0    0  294M  0 raid6                   
  ├─md0p1                 259:1    0 58,8M  0 part  ext4              
  ├─md0p2                 259:4    0   57M  0 part  ext4              
  ├─md0p3                 259:5    0   60M  0 part  ext4              
  ├─md0p4                 259:8    0 58,5M  0 part  ext4              
  └─md0p5                 259:9    0 58,5M  0 part  ext4              
vdd                       253:48   0  100M  0 disk  linux_raid_member 
└─md0                       9:0    0  294M  0 raid6                   
  ├─md0p1                 259:1    0 58,8M  0 part  ext4              
  ├─md0p2                 259:4    0   57M  0 part  ext4              
  ├─md0p3                 259:5    0   60M  0 part  ext4              
  ├─md0p4                 259:8    0 58,5M  0 part  ext4              
  └─md0p5                 259:9    0 58,5M  0 part  ext4              
vde                       253:64   0  100M  0 disk  linux_raid_member 
└─md0                       9:0    0  294M  0 raid6                   
  ├─md0p1                 259:1    0 58,8M  0 part  ext4              
  ├─md0p2                 259:4    0   57M  0 part  ext4              
  ├─md0p3                 259:5    0   60M  0 part  ext4              
  ├─md0p4                 259:8    0 58,5M  0 part  ext4              
  └─md0p5                 259:9    0 58,5M  0 part  ext4              
vdg                       253:96   0  100M  0 disk  linux_raid_member 
└─md0                       9:0    0  294M  0 raid6                   
  ├─md0p1                 259:1    0 58,8M  0 part  ext4              
  ├─md0p2                 259:4    0   57M  0 part  ext4              
  ├─md0p3                 259:5    0   60M  0 part  ext4              
  ├─md0p4                 259:8    0 58,5M  0 part  ext4              
  └─md0p5                 259:9    0 58,5M  0 part  ext4              
kosogor@kosogor:~$ 
kosogor@kosogor:~$ for i in $(seq 1 5); do sudo mount /dev/md0p$i /raid/part$i; done
kosogor@kosogor:~$ 
kosogor@kosogor:~$ 
kosogor@kosogor:~$ 
kosogor@kosogor:~$ 
kosogor@kosogor:~$ df -h
Filesystem                         Size  Used Avail Use% Mounted on
tmpfs                              392M  1,2M  390M   1% /run
/dev/mapper/ubuntu--vg-ubuntu--lv   14G  6,7G  6,4G  51% /
tmpfs                              2,0G     0  2,0G   0% /dev/shm
tmpfs                              5,0M     0  5,0M   0% /run/lock
/dev/vda2                          2,0G  303M  1,5G  17% /boot
tmpfs                              392M   12K  392M   1% /run/user/1000
/dev/md0p1                          52M   24K   47M   1% /raid/part1
/dev/md0p2                          50M   24K   46M   1% /raid/part2
/dev/md0p3                          53M   24K   48M   1% /raid/part3
/dev/md0p4                          51M   24K   47M   1% /raid/part4
/dev/md0p5                          51M   24K   47M   1% /raid/part5
kosogor@kosogor:~$ 
kosogor@kosogor:~$ 
kosogor@kosogor:~$ lsblk -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,FSTYPE,MOUNTPOINTS
NAME                      MAJ:MIN RM  SIZE RO TYPE  FSTYPE            MOUNTPOINTS
sr0                        11:0    1  3,2G  0 rom   iso9660           
vda                       253:0    0   30G  0 disk                    
├─vda1                    253:1    0    1M  0 part                    
├─vda2                    253:2    0    2G  0 part  ext4              /boot
└─vda3                    253:3    0   28G  0 part  LVM2_member       
  └─ubuntu--vg-ubuntu--lv 252:0    0   14G  0 lvm   ext4              /
vdb                       253:16   0  100M  0 disk  linux_raid_member 
└─md0                       9:0    0  294M  0 raid6                   
  ├─md0p1                 259:1    0 58,8M  0 part  ext4              /raid/part1
  ├─md0p2                 259:4    0   57M  0 part  ext4              /raid/part2
  ├─md0p3                 259:5    0   60M  0 part  ext4              /raid/part3
  ├─md0p4                 259:8    0 58,5M  0 part  ext4              /raid/part4
  └─md0p5                 259:9    0 58,5M  0 part  ext4              /raid/part5
vdc                       253:32   0  100M  0 disk  linux_raid_member 
└─md0                       9:0    0  294M  0 raid6                   
  ├─md0p1                 259:1    0 58,8M  0 part  ext4              /raid/part1
  ├─md0p2                 259:4    0   57M  0 part  ext4              /raid/part2
  ├─md0p3                 259:5    0   60M  0 part  ext4              /raid/part3
  ├─md0p4                 259:8    0 58,5M  0 part  ext4              /raid/part4
  └─md0p5                 259:9    0 58,5M  0 part  ext4              /raid/part5
vdd                       253:48   0  100M  0 disk  linux_raid_member 
└─md0                       9:0    0  294M  0 raid6                   
  ├─md0p1                 259:1    0 58,8M  0 part  ext4              /raid/part1
  ├─md0p2                 259:4    0   57M  0 part  ext4              /raid/part2
  ├─md0p3                 259:5    0   60M  0 part  ext4              /raid/part3
  ├─md0p4                 259:8    0 58,5M  0 part  ext4              /raid/part4
  └─md0p5                 259:9    0 58,5M  0 part  ext4              /raid/part5
vde                       253:64   0  100M  0 disk  linux_raid_member 
└─md0                       9:0    0  294M  0 raid6                   
  ├─md0p1                 259:1    0 58,8M  0 part  ext4              /raid/part1
  ├─md0p2                 259:4    0   57M  0 part  ext4              /raid/part2
  ├─md0p3                 259:5    0   60M  0 part  ext4              /raid/part3
  ├─md0p4                 259:8    0 58,5M  0 part  ext4              /raid/part4
  └─md0p5                 259:9    0 58,5M  0 part  ext4              /raid/part5
vdg                       253:96   0  100M  0 disk  linux_raid_member 
└─md0                       9:0    0  294M  0 raid6                   
  ├─md0p1                 259:1    0 58,8M  0 part  ext4              /raid/part1
  ├─md0p2                 259:4    0   57M  0 part  ext4              /raid/part2
  ├─md0p3                 259:5    0   60M  0 part  ext4              /raid/part3
  ├─md0p4                 259:8    0 58,5M  0 part  ext4              /raid/part4
  └─md0p5                 259:9    0 58,5M  0 part  ext4              /raid/part5
kosogor@kosogor:~$ 
```

## 5. После перезагрузки ВМ/сервера Ubuntu 24.04 созданный RAID-массив /dev/md0 переименовывается в /dev/md127 

Оказалось, что после перезагрузки ВМ.сервера Ubuntu 24.04 созданный RAID-массив /dev/md0 переименовывается в /dev/md127

```
kosogor@kosogor:~$ lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE  MOUNTPOINTS
sr0                        11:0    1  3,2G  0 rom   
vda                       253:0    0   30G  0 disk  
├─vda1                    253:1    0    1M  0 part  
├─vda2                    253:2    0    2G  0 part  /boot
└─vda3                    253:3    0   28G  0 part  
  └─ubuntu--vg-ubuntu--lv 252:0    0   14G  0 lvm   /
vdb                       253:16   0  100M  0 disk  
└─md0                       9:0    0  294M  0 raid6 
  ├─md0p1                 259:0    0 58,8M  0 part  
  ├─md0p2                 259:1    0   57M  0 part  
  ├─md0p3                 259:2    0   60M  0 part  
  ├─md0p4                 259:3    0 58,5M  0 part  
  └─md0p5                 259:4    0 58,5M  0 part  
vdc                       253:32   0  100M  0 disk  
└─md0                       9:0    0  294M  0 raid6 
  ├─md0p1                 259:0    0 58,8M  0 part  
  ├─md0p2                 259:1    0   57M  0 part  
  ├─md0p3                 259:2    0   60M  0 part  
  ├─md0p4                 259:3    0 58,5M  0 part  
  └─md0p5                 259:4    0 58,5M  0 part  
vdd                       253:48   0  100M  0 disk  
└─md0                       9:0    0  294M  0 raid6 
  ├─md0p1                 259:0    0 58,8M  0 part  
  ├─md0p2                 259:1    0   57M  0 part  
  ├─md0p3                 259:2    0   60M  0 part  
  ├─md0p4                 259:3    0 58,5M  0 part  
  └─md0p5                 259:4    0 58,5M  0 part  
vde                       253:64   0  100M  0 disk  
└─md0                       9:0    0  294M  0 raid6 
  ├─md0p1                 259:0    0 58,8M  0 part  
  ├─md0p2                 259:1    0   57M  0 part  
  ├─md0p3                 259:2    0   60M  0 part  
  ├─md0p4                 259:3    0 58,5M  0 part  
  └─md0p5                 259:4    0 58,5M  0 part  
vdf                       253:80   0  100M  0 disk  
└─md0                       9:0    0  294M  0 raid6 
  ├─md0p1                 259:0    0 58,8M  0 part  
  ├─md0p2                 259:1    0   57M  0 part  
  ├─md0p3                 259:2    0   60M  0 part  
  ├─md0p4                 259:3    0 58,5M  0 part  
  └─md0p5                 259:4    0 58,5M  0 part  
kosogor@kosogor:~$ 
kosogor@kosogor:~$ 
kosogor@kosogor:~$ sudo reboot

Broadcast message from root@kosogor on pts/1 (Tue 2026-07-14 07:51:05 UTC):

The system will reboot now!

kosogor@kosogor:~$ Connection to 192.168.122.176 closed by remote host.
Connection to 192.168.122.176 closed.
[admin_insta11@mv334 ~]$ 
[admin_insta11@mv334 ~]$ ssh kosogor@192.168.122.176
kosogor@192.168.122.176's password: 
Welcome to Ubuntu 24.04.4 LTS (GNU/Linux 6.8.0-134-generic x86_64)

Last login: Tue Jul 14 07:43:43 2026 from 192.168.122.1
kosogor@kosogor:~$ lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE  MOUNTPOINTS
sr0                        11:0    1  3,2G  0 rom   
vda                       253:0    0   30G  0 disk  
├─vda1                    253:1    0    1M  0 part  
├─vda2                    253:2    0    2G  0 part  /boot
└─vda3                    253:3    0   28G  0 part  
  └─ubuntu--vg-ubuntu--lv 252:0    0   14G  0 lvm   /
vdb                       253:16   0  100M  0 disk  
└─md127                     9:127  0  294M  0 raid6 
  ├─md127p1               259:0    0 58,8M  0 part  
  ├─md127p2               259:1    0   57M  0 part  
  ├─md127p3               259:2    0   60M  0 part  
  ├─md127p4               259:3    0 58,5M  0 part  
  └─md127p5               259:4    0 58,5M  0 part  
vdc                       253:32   0  100M  0 disk  
└─md127                     9:127  0  294M  0 raid6 
  ├─md127p1               259:0    0 58,8M  0 part  
  ├─md127p2               259:1    0   57M  0 part  
  ├─md127p3               259:2    0   60M  0 part  
  ├─md127p4               259:3    0 58,5M  0 part  
  └─md127p5               259:4    0 58,5M  0 part  
vdd                       253:48   0  100M  0 disk  
└─md127                     9:127  0  294M  0 raid6 
  ├─md127p1               259:0    0 58,8M  0 part  
  ├─md127p2               259:1    0   57M  0 part  
  ├─md127p3               259:2    0   60M  0 part  
  ├─md127p4               259:3    0 58,5M  0 part  
  └─md127p5               259:4    0 58,5M  0 part  
vde                       253:64   0  100M  0 disk  
└─md127                     9:127  0  294M  0 raid6 
  ├─md127p1               259:0    0 58,8M  0 part  
  ├─md127p2               259:1    0   57M  0 part  
  ├─md127p3               259:2    0   60M  0 part  
  ├─md127p4               259:3    0 58,5M  0 part  
  └─md127p5               259:4    0 58,5M  0 part  
vdf                       253:80   0  100M  0 disk  
└─md127                     9:127  0  294M  0 raid6 
  ├─md127p1               259:0    0 58,8M  0 part  
  ├─md127p2               259:1    0   57M  0 part  
  ├─md127p3               259:2    0   60M  0 part  
  ├─md127p4               259:3    0 58,5M  0 part  
  └─md127p5               259:4    0 58,5M  0 part  
kosogor@kosogor:~$ 
```

Это можно исправить, вручную пересобрав массив следующими командами: 

```
mdadm -S /dev/md127
mdadm -As
mount -a
```

Но после следующей перезагрузки RAID-массив опять переименовывается.

Рекомендованное в Интернете решение
```
После сборки RAID-массива сделать добавить строку его конфигурации в файл /etc/mdadm/mdadm.conf :

mdadm --examine --scan >> /etc/mdadm/mdadm.conf
```
не помогло, после перезагрузки RAID-массив опять переименовывается:

```
kosogor@kosogor:~$ sudo cat /etc/mdadm/mdadm.conf
# mdadm.conf
#
# !NB! Run update-initramfs -u after updating this file.
# !NB! This will ensure that initramfs has an uptodate copy.
#
# Please refer to mdadm.conf(5) for information about this file.
#

# by default (built-in), scan all partitions (/proc/partitions) and all
# containers for MD superblocks. alternatively, specify devices to scan, using
# wildcards if desired.
#DEVICE partitions containers

# automatically tag new arrays as belonging to the local system
HOMEHOST <system>

# instruct the monitoring daemon where to send mail alerts
MAILADDR root

# definitions of existing MD arrays

# This configuration was auto-generated on Tue, 10 Feb 2026 00:26:20 +0000 by mkconf
ARRAY /dev/md0  metadata=1.2 UUID=40aaa16a:a9941f73:1f4ff687:70e39a45
kosogor@kosogor:~$ 
kosogor@kosogor:~$ sudo reboot

Broadcast message from root@kosogor on pts/1 (Tue 2026-07-14 07:55:06 UTC):

The system will reboot now!

kosogor@kosogor:~$ Connection to 192.168.122.176 closed by remote host.
Connection to 192.168.122.176 closed.
[admin_insta11@mv334 ~]$ 
[admin_insta11@mv334 ~]$ 
[admin_insta11@mv334 ~]$ ssh kosogor@192.168.122.176
kosogor@192.168.122.176's password: 
Welcome to Ubuntu 24.04.4 LTS (GNU/Linux 6.8.0-134-generic x86_64)

Last login: Tue Jul 14 07:51:21 2026 from 192.168.122.1
kosogor@kosogor:~$ 
kosogor@kosogor:~$ 
kosogor@kosogor:~$ lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE  MOUNTPOINTS
sr0                        11:0    1  3,2G  0 rom   
vda                       253:0    0   30G  0 disk  
├─vda1                    253:1    0    1M  0 part  
├─vda2                    253:2    0    2G  0 part  /boot
└─vda3                    253:3    0   28G  0 part  
  └─ubuntu--vg-ubuntu--lv 252:0    0   14G  0 lvm   /
vdb                       253:16   0  100M  0 disk  
└─md127                     9:127  0  294M  0 raid6 
  ├─md127p1               259:0    0 58,8M  0 part  
  ├─md127p2               259:1    0   57M  0 part  
  ├─md127p3               259:2    0   60M  0 part  
  ├─md127p4               259:3    0 58,5M  0 part  
  └─md127p5               259:4    0 58,5M  0 part  
vdc                       253:32   0  100M  0 disk  
└─md127                     9:127  0  294M  0 raid6 
  ├─md127p1               259:0    0 58,8M  0 part  
  ├─md127p2               259:1    0   57M  0 part  
  ├─md127p3               259:2    0   60M  0 part  
  ├─md127p4               259:3    0 58,5M  0 part  
  └─md127p5               259:4    0 58,5M  0 part  
vdd                       253:48   0  100M  0 disk  
└─md127                     9:127  0  294M  0 raid6 
  ├─md127p1               259:0    0 58,8M  0 part  
  ├─md127p2               259:1    0   57M  0 part  
  ├─md127p3               259:2    0   60M  0 part  
  ├─md127p4               259:3    0 58,5M  0 part  
  └─md127p5               259:4    0 58,5M  0 part  
vde                       253:64   0  100M  0 disk  
└─md127                     9:127  0  294M  0 raid6 
  ├─md127p1               259:0    0 58,8M  0 part  
  ├─md127p2               259:1    0   57M  0 part  
  ├─md127p3               259:2    0   60M  0 part  
  ├─md127p4               259:3    0 58,5M  0 part  
  └─md127p5               259:4    0 58,5M  0 part  
vdf                       253:80   0  100M  0 disk  
└─md127                     9:127  0  294M  0 raid6 
  ├─md127p1               259:0    0 58,8M  0 part  
  ├─md127p2               259:1    0   57M  0 part  
  ├─md127p3               259:2    0   60M  0 part  
  ├─md127p4               259:3    0 58,5M  0 part  
  └─md127p5               259:4    0 58,5M  0 part  
kosogor@kosogor:~$
```

Пишут, что файл /etc/mdadm/mdadm.conf имеет второстепенное значение.


Рекомендованное в Интернете решение

```
В initramfs используется свой mdadm.conf , который не содержит явного определения вашего массива, система может
пересобрать его заново с новой нумерацией. Нужно после сборки массива обновить initramfs командой

update-initramfs -u
```

помогло.


После обновления initramfs (причём именно в нужном ядре 6.8.0-100, с которым запускается система) RAID-массив /dev/md0 
перестал переименовываться после ребута:

```
kosogor@kosogor:~$ sudo cat /etc/mdadm/mdadm.conf
# mdadm.conf
#
# !NB! Run update-initramfs -u after updating this file.
# !NB! This will ensure that initramfs has an uptodate copy.
#
# Please refer to mdadm.conf(5) for information about this file.
#

# by default (built-in), scan all partitions (/proc/partitions) and all
# containers for MD superblocks. alternatively, specify devices to scan, using
# wildcards if desired.
#DEVICE partitions containers

# automatically tag new arrays as belonging to the local system
HOMEHOST <system>

# instruct the monitoring daemon where to send mail alerts
MAILADDR root

# definitions of existing MD arrays

# This configuration was auto-generated on Tue, 10 Feb 2026 00:26:20 +0000 by mkconf
kosogor@kosogor:~$ 
kosogor@kosogor:~$ sudo mdadm -S /dev/md127
mdadm: stopped /dev/md127
kosogor@kosogor:~$ sudo mdadm -As
mdadm: /dev/md/0 has been started with 5 drives.
kosogor@kosogor:~$ sudo mount -a
kosogor@kosogor:~$ lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE  MOUNTPOINTS
sr0                        11:0    1  3,2G  0 rom   
vda                       253:0    0   30G  0 disk  
├─vda1                    253:1    0    1M  0 part  
├─vda2                    253:2    0    2G  0 part  /boot
└─vda3                    253:3    0   28G  0 part  
  └─ubuntu--vg-ubuntu--lv 252:0    0   14G  0 lvm   /
vdb                       253:16   0  100M  0 disk  
└─md0                       9:0    0  294M  0 raid6 
  ├─md0p1                 259:0    0 58,8M  0 part  
  ├─md0p2                 259:1    0   57M  0 part  
  ├─md0p3                 259:2    0   60M  0 part  
  ├─md0p4                 259:3    0 58,5M  0 part  
  └─md0p5                 259:4    0 58,5M  0 part  
vdc                       253:32   0  100M  0 disk  
└─md0                       9:0    0  294M  0 raid6 
  ├─md0p1                 259:0    0 58,8M  0 part  
  ├─md0p2                 259:1    0   57M  0 part  
  ├─md0p3                 259:2    0   60M  0 part  
  ├─md0p4                 259:3    0 58,5M  0 part  
  └─md0p5                 259:4    0 58,5M  0 part  
vdd                       253:48   0  100M  0 disk  
└─md0                       9:0    0  294M  0 raid6 
  ├─md0p1                 259:0    0 58,8M  0 part  
  ├─md0p2                 259:1    0   57M  0 part  
  ├─md0p3                 259:2    0   60M  0 part  
  ├─md0p4                 259:3    0 58,5M  0 part  
  └─md0p5                 259:4    0 58,5M  0 part  
vde                       253:64   0  100M  0 disk  
└─md0                       9:0    0  294M  0 raid6 
  ├─md0p1                 259:0    0 58,8M  0 part  
  ├─md0p2                 259:1    0   57M  0 part  
  ├─md0p3                 259:2    0   60M  0 part  
  ├─md0p4                 259:3    0 58,5M  0 part  
  └─md0p5                 259:4    0 58,5M  0 part  
vdf                       253:80   0  100M  0 disk  
└─md0                       9:0    0  294M  0 raid6 
  ├─md0p1                 259:0    0 58,8M  0 part  
  ├─md0p2                 259:1    0   57M  0 part  
  ├─md0p3                 259:2    0   60M  0 part  
  ├─md0p4                 259:3    0 58,5M  0 part  
  └─md0p5                 259:4    0 58,5M  0 part  
kosogor@kosogor:~$ sudo update-initramfs -u
update-initramfs: Generating /boot/initrd.img-6.19.14-061914-generic
kosogor@kosogor:~$ uname -r
6.8.0-134-generic
kosogor@kosogor:~$ 
kosogor@kosogor:~$ sudo update-initramfs -u -k 6.8.0-134-generic
update-initramfs: Generating /boot/initrd.img-6.8.0-134-generic
kosogor@kosogor:~$ 
kosogor@kosogor:~$ sudo reboot

Broadcast message from root@kosogor on pts/1 (Tue 2026-07-14 08:04:27 UTC):

The system will reboot now!

kosogor@kosogor:~$ Connection to 192.168.122.176 closed by remote host.
Connection to 192.168.122.176 closed.
[admin_insta11@mv334 ~]$ 
[admin_insta11@mv334 ~]$ ssh kosogor@192.168.122.176
kosogor@192.168.122.176's password: 
Welcome to Ubuntu 24.04.4 LTS (GNU/Linux 6.8.0-134-generic x86_64)

Last login: Tue Jul 14 07:55:21 2026 from 192.168.122.1
kosogor@kosogor:~$ 
kosogor@kosogor:~$ lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE  MOUNTPOINTS
sr0                        11:0    1  3,2G  0 rom   
vda                       253:0    0   30G  0 disk  
├─vda1                    253:1    0    1M  0 part  
├─vda2                    253:2    0    2G  0 part  /boot
└─vda3                    253:3    0   28G  0 part  
  └─ubuntu--vg-ubuntu--lv 252:0    0   14G  0 lvm   /
vdb                       253:16   0  100M  0 disk  
└─md0                       9:0    0  294M  0 raid6 
  ├─md0p1                 259:0    0 58,8M  0 part  
  ├─md0p2                 259:1    0   57M  0 part  
  ├─md0p3                 259:2    0   60M  0 part  
  ├─md0p4                 259:3    0 58,5M  0 part  
  └─md0p5                 259:4    0 58,5M  0 part  
vdc                       253:32   0  100M  0 disk  
└─md0                       9:0    0  294M  0 raid6 
  ├─md0p1                 259:0    0 58,8M  0 part  
  ├─md0p2                 259:1    0   57M  0 part  
  ├─md0p3                 259:2    0   60M  0 part  
  ├─md0p4                 259:3    0 58,5M  0 part  
  └─md0p5                 259:4    0 58,5M  0 part  
vdd                       253:48   0  100M  0 disk  
└─md0                       9:0    0  294M  0 raid6 
  ├─md0p1                 259:0    0 58,8M  0 part  
  ├─md0p2                 259:1    0   57M  0 part  
  ├─md0p3                 259:2    0   60M  0 part  
  ├─md0p4                 259:3    0 58,5M  0 part  
  └─md0p5                 259:4    0 58,5M  0 part  
vde                       253:64   0  100M  0 disk  
└─md0                       9:0    0  294M  0 raid6 
  ├─md0p1                 259:0    0 58,8M  0 part  
  ├─md0p2                 259:1    0   57M  0 part  
  ├─md0p3                 259:2    0   60M  0 part  
  ├─md0p4                 259:3    0 58,5M  0 part  
  └─md0p5                 259:4    0 58,5M  0 part  
vdf                       253:80   0  100M  0 disk  
└─md0                       9:0    0  294M  0 raid6 
  ├─md0p1                 259:0    0 58,8M  0 part  
  ├─md0p2                 259:1    0   57M  0 part  
  ├─md0p3                 259:2    0   60M  0 part  
  ├─md0p4                 259:3    0 58,5M  0 part  
  └─md0p5                 259:4    0 58,5M  0 part  
kosogor@kosogor:~$
```
