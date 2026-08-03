# Занятие  27.07.2026 "Загрузка системы"

Работа с загрузчиком

## Цель:

научиться попадать в систему без пароля;
устанавливать систему с LVM и переименовывать в VG;

## Описание/Пошаговая инструкция выполнения домашнего задания:

## 🎯Что нужно сделать?

    Включить отображение меню Grub.
    Попасть в систему без пароля несколькими способами.
    Установить систему с LVM, после чего переименовать VG.

# Решение
0. Исходная конфигурация - ВМ c Ubuntu 24.04)

1. Изменяем параметры отображения меню GRUB, применяем новые параметры и перезагружаем ВМ:

```
root@kosogor:/home/kosogor# ll /boot/
total 96812
drwxr-xr-x  4 root root     4096 июн 25 06:31 ./
drwxr-xr-x 23 root root     4096 июн 25 06:31 ../
-rw-r--r--  1 root root   287599 янв 13 13:56 config-6.8.0-100-generic
drwxr-xr-x  5 root root     4096 июн 25 06:31 grub/
lrwxrwxrwx  1 root root       28 июн 25 06:31 initrd.img -> initrd.img-6.8.0-100-generic
-rw-r--r--  1 root root 74658580 июн 25 06:31 initrd.img-6.8.0-100-generic
lrwxrwxrwx  1 root root       28 июн 25 06:31 initrd.img.old -> initrd.img-6.8.0-100-generic
drwx------  2 root root    16384 июн 25 06:29 lost+found/
-rw-------  1 root root  9120274 янв 13 13:56 System.map-6.8.0-100-generic
lrwxrwxrwx  1 root root       25 июн 25 06:31 vmlinuz -> vmlinuz-6.8.0-100-generic
-rw-------  1 root root 15030664 янв 13 14:42 vmlinuz-6.8.0-100-generic
lrwxrwxrwx  1 root root       25 июн 25 06:31 vmlinuz.old -> vmlinuz-6.8.0-100-generic
root@kosogor:/home/kosogor# ll /boot/grub
total 2400
drwxr-xr-x 5 root root    4096 июн 25 06:31 ./
drwxr-xr-x 4 root root    4096 июн 25 06:31 ../
drwxr-xr-x 2 root root    4096 июн 25 06:31 fonts/
-rw-r--r-- 1 root root     712 июн 25 06:30 gfxblacklist.txt
-rw------- 1 root root    6795 июн 25 06:31 grub.cfg
-rw-r--r-- 1 root root    1024 июн 25 06:42 grubenv
drwxr-xr-x 2 root root   12288 июн 25 06:31 i386-pc/
drwxr-xr-x 2 root root    4096 июн 25 06:31 locale/
-rw-r--r-- 1 root root 2411806 июн 25 06:31 unicode.pf2
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# ll /etc/default/
total 92
drwxr-xr-x   3 root root 4096 июн 25 09:31 ./
drwxr-xr-x 108 root root 4096 июн 25 07:26 ../
-rw-r--r--   1 root root  328 мая 28  2025 amd64-microcode
-rw-r--r--   1 root root  149 июл  8  2025 apport
-rw-r--r--   1 root root  285 фев 10 00:26 console-setup
-rw-r--r--   1 root root  150 фев 10 00:34 cron
-rw-r--r--   1 root root  460 июн  5  2024 cryptdisks
-rw-r--r--   1 root root  297 дек  5  2023 dbus
-rw-r--r--   1 root root 1538 июн 25 06:31 grub
drwxr-xr-x   2 root root 4096 мар 17  2025 grub.d/
-rw-r--r--   1 root root 1538 июн 25 06:31 grub.ucf-dist
-rw-r--r--   1 root root 1029 мая 22  2025 intel-microcode
-rw-r--r--   1 root root  174 июн 25 06:30 keyboard
lrwxrwxrwx   1 root root   14 фев 10 00:26 locale -> ../locale.conf
-rw-r--r--   1 root root  854 фев 10 00:26 mdadm
-rw-r--r--   1 root root  682 фев 10 00:34 motd-news
-rw-r--r--   1 root root  152 апр 24  2023 networkd-dispatcher
-rw-r--r--   1 root root 2691 фев 11  2025 open-iscsi
-rw-r--r--   1 root root  363 окт 12  2022 pollinate
-rw-r--r--   1 root root 2062 фев 10 00:34 rsync
-rw-r--r--   1 root root  133 июл 21  2025 ssh
-rw-r--r--   1 root root  284 фев 10 00:34 sysstat
-rw-r--r--   1 root root 1897 фев 10 00:34 ufw
-rw-r--r--   1 root root 1117 фев 22  2024 useradd
root@kosogor:/home/kosogor# ll /etc/default/grub.d
total 8
drwxr-xr-x 2 root root 4096 мар 17  2025 ./
drwxr-xr-x 3 root root 4096 июн 25 09:31 ../
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# cat /etc/default/grub | grep -v '#'

GRUB_DEFAULT=0
GRUB_TIMEOUT_STYLE=hidden
GRUB_TIMEOUT=0
GRUB_DISTRIBUTOR=`( . /etc/os-release; echo ${NAME:-Ubuntu} ) 2>/dev/null || echo Ubuntu`
GRUB_CMDLINE_LINUX_DEFAULT=""
GRUB_CMDLINE_LINUX=""







root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# vi /etc/default/grub
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# cat /etc/default/grub | grep -v '#'

GRUB_DEFAULT=0
GRUB_TIMEOUT=10
GRUB_DISTRIBUTOR=`( . /etc/os-release; echo ${NAME:-Ubuntu} ) 2>/dev/null || echo Ubuntu`
GRUB_CMDLINE_LINUX_DEFAULT=""
GRUB_CMDLINE_LINUX=""







root@kosogor:/home/kosogor# update-grub
Sourcing file `/etc/default/grub'
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-6.8.0-100-generic
Found initrd image: /boot/initrd.img-6.8.0-100-generic
Warning: os-prober will not be executed to detect other bootable partitions.
Systems on them will not be added to the GRUB boot configuration.
Check GRUB_DISABLE_OS_PROBER documentation entry.
Adding boot menu entry for UEFI Firmware Settings ...
done
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# reboot

Broadcast message from root@kosogor on pts/3 (Mon 2026-08-03 15:46:35 UTC):

The system will reboot now!

root@kosogor:/home/kosogor# Connection to 192.168.122.176 closed by remote host.
Connection to 192.168.122.176 closed.
[admin_insta11@mv334 ~]$ 
```

2. После перезагрузки ВМ перед загрузкой ОС появляется меню GRUB:

<img width="1035" height="947" alt="изображение" src="https://github.com/user-attachments/assets/d9d35149-3095-4091-a2d2-a03b75a6d2ab" />

В этом меню нажимаем 'e' - попадаем в меню редактирования настроек загрузки:

<img width="1037" height="947" alt="изображение" src="https://github.com/user-attachments/assets/a3c6ed7e-5e4c-454d-b9d9-93044a9a10b2" />

В нём редактируем строку загрузки Linux, добавляем параметр init=/bin/bash :

<img width="1037" height="793" alt="изображение" src="https://github.com/user-attachments/assets/d11af3f0-c41d-4320-a2d4-4ed4db869776" />

и после этого нажимаем Ctrl+X для загрузки. Linux загружается в однопользовательском режиме, появляется командная строка, в которой основная
файловая система подмонтирована как Read-only. Перемонтируем её как Read-Write:

<img width="1035" height="729" alt="изображение" src="https://github.com/user-attachments/assets/89c2fc10-ed28-42ed-9657-6792d1a523d6" />

После этого можно записывать/редактировать файлы на основной подмонтированной системе.

3. Ещё раз перезагружаем ОС. На этот раз в меню загрузки GRUB выбираем меню 'Advanced options for Ubuntu', и в нём выбираем 'Recovery mode' :

<img width="1031" height="769" alt="изображение" src="https://github.com/user-attachments/assets/63e228cd-5413-4854-be2d-287928d64225" />

Далее появляется меню выбора опций восстановления - выбираем 'root' (с наложившимися артефактами строк загрузки, но рабочее)? 
в нём выбираем пункт 'root' :

<img width="1033" height="744" alt="изображение" src="https://github.com/user-attachments/assets/1be78619-7a72-4a6d-b580-3c6ef23b7091" />




