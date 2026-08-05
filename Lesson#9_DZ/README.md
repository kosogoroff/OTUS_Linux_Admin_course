# Занятие 30.07.2026 "Инициализация системы. Systemd"

Systemd - создание unit-файла

##Цель:

Научиться редактировать существующие и создавать новые unit-файлы;

## Описание/Пошаговая инструкция выполнения домашнего задания:

Для выполнения домашнего задания используйте методичку

Systemd


Выполнить следующие задания:

   1. Написать service, который будет раз в 30 секунд мониторить лог на предмет наличия ключевого слова 
    (файл лога и ключевое слово должны задаваться в /etc/default).
    
   2. Установить spawn-fcgi и создать unit-файл (spawn-fcgi.sevice) с помощью переделки init-скрипта 
    (https://gist.github.com/cea2k/1318020).
    
   3. Доработать unit-файл Nginx (nginx.service) для запуска нескольких инстансов сервера с разными 
    конфигурационными файлами одновременно.

# Решение

0. Исходная конфигурация - в KVM создана ВМ с ОС Ubuntu 24.04).

## 1. Создаём service, который будет раз в 30 секунд мониторить лог на предмет наличия ключевого слова. Для этого:


1.1 Создаём демонстрационный лог, в котором сервис будет искать искомое слово (копируем часть системного лога в этот файл и вставляем в него слово ALERT):

```
root@kosogor:/home/kosogor# journalctl -n 50 > /var/log/watchlog.log
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# vi /var/log/watchlog.log
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# cat /var/log/watchlog.log | grep ALERT
авг 05 10:11:16 kosogor systemd[1067]: Created slice app.slice - User Application Slice. ALERT
авг 05 10:11:16 kosogor systemd[1067]: ALERT Listening on keyboxd.socket - GnuPG public key management service.
авг 05 10:11:35 kosogor systemd[1]: systemd-timedated.service: Deactivated ALERT successfully.
авг 05 10:13:37 kosogor sshd[1147]: pam_unix(sshd:auth): ALERT authentication failure; logname= uid=0 euid=0 tty=ssh ruser= rhost=192.168.122.1  user=kosogor
авг 05 10:15:01 kosogor CRON[1229]: (root) CMD (ALERT command -v debian-sa1 > /dev/null && debian-sa1 1 1)
root@kosogor:/home/kosogor#
```

1.2 Создаём файл конфигурации сервиса :

```
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# cat > /etc/default/watchlog
# Configuration file for my watchlog service
# Place it to /etc/default

# File and word in that file that we will be monit
WORD="ALERT"
LOG=/var/log/watchlog.log
root@kosogor:/home/kosogor#
```

1.3 Создаём исполняемый файл-скрипт сервиса watchlog.service, который просматривает заданный в параметре LOG= файл лога и ищет в нём заданное в параметре WORD= слово.
Результаты работы выводит в системный лог.
Делаем скрипт исполняемым:

```
root@kosogor:/home/kosogor# cat > /opt/watchlog.sh
#!/bin/bash

WORD=$1
LOG=$2
DATE=`date`

if grep $WORD $LOG &> /dev/null
then
logger "$DATE: I found word, Master!"
else
exit 0
fi
root@kosogor:/home/kosogor#
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# chmod +x /opt/watchlog.sh
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# ll /opt/watchlog.sh
-rwxr-xr-x 1 root root 131 авг  5 10:18 /opt/watchlog.sh*
root@kosogor:/home/kosogor# 
```

1.4 Создаём в systemd конфигурацию сервиса watchlog.service с параметрами:

- конфигурация сервиса находится в файле /etc/default/watchlog
  
- исполняемый файл сервиса /opt/watchlog.sh
  
- при старте сервиса исполняемый файл запускается один раз :

```
root@kosogor:/home/kosogor# cat > /etc/systemd/system/watchlog.service
[Unit]
Description=My watchlog service

[Service]
Type=oneshot
EnvironmentFile=/etc/default/watchlog
ExecStart=/opt/watchlog.sh $WORD $LOG
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# cat /etc/systemd/system/watchlog.service
[Unit]
Description=My watchlog service

[Service]
Type=oneshot
EnvironmentFile=/etc/default/watchlog
ExecStart=/opt/watchlog.sh $WORD $LOG
root@kosogor:/home/kosogor#
```

1.5 Создаём в systemd конфигурацию таймера watchlog.service с параметрами:

- запускаемый таймером сервис watchlog.service

- таймер срабатывает каждые 30 секунд

```
root@kosogor:/home/kosogor# cat > /etc/systemd/system/watchlog.timer
[Unit]
Description=Run watchlog script every 30 second

[Timer]
# Run every 30 second
OnUnitActiveSec=30
Unit=watchlog.service

[Install]
WantedBy=multi-user.target
root@kosogor:/home/kosogor#
```

1.6 Запускаем таймер и проверяем работу таймера, сервиса и наполнения лога сервиса.

Сначала запускаем сервис watchlog.service - проверяем, что при он запускается однократно и пишет в свой лог:

```
root@kosogor:/home/kosogor# systemctl start watchlog.service
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# systemctl status watchlog.service
○ watchlog.service - My watchlog service
     Loaded: loaded (/etc/systemd/system/watchlog.service; static)
     Active: inactive (dead) since Wed 2026-08-05 10:34:10 UTC; 8s ago
TriggeredBy: ● watchlog.timer
    Process: 1503 ExecStart=/opt/watchlog.sh $WORD $LOG (code=exited, status=0/SUCCESS)
   Main PID: 1503 (code=exited, status=0/SUCCESS)
        CPU: 16ms

авг 05 10:34:10 kosogor systemd[1]: Starting watchlog.service - My watchlog service...
авг 05 10:34:10 kosogor systemd[1]: watchlog.service: Deactivated successfully.
авг 05 10:34:10 kosogor systemd[1]: Finished watchlog.service - My watchlog service.
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# cat /var/log/syslog | grep -i master
2026-08-05T10:31:34.032018+00:00 kosogor root: Ср 05 авг 2026 10:31:34 UTC: I found word, Master!
root@kosogor:/home/kosogor#
```

Затем запускаем таймер, проверяем, что он запускается каждые 30 секунд, при этом в syslog при каждом запуске появляются сообщения :

```
root@kosogor:/home/kosogor# systemctl start watchlog.timer
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# journalctl | grep watchlog.s
авг 05 10:20:57 kosogor systemd[1]: Started watchlog.timer - Run watchlog script every 30 second.
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# systemctl enable watchlog.timer
Created symlink /etc/systemd/system/multi-user.target.wants/watchlog.timer → /etc/systemd/system/watchlog.timer.
root@kosogor:/home/kosogor#
root@kosogor:/home/kosogor# systemctl status watchlog.timer
● watchlog.timer - Run watchlog script every 30 second
     Loaded: loaded (/etc/systemd/system/watchlog.timer; enabled; preset: enabled)
     Active: active (waiting) since Wed 2026-08-05 10:26:22 UTC; 8min ago
    Trigger: Wed 2026-08-05 10:35:10 UTC; 2s left
   Triggers: ● watchlog.service

авг 05 10:26:22 kosogor systemd[1]: Started watchlog.timer - Run watchlog script every 30 second.
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# systemctl status watchlog.timer
● watchlog.timer - Run watchlog script every 30 second
     Loaded: loaded (/etc/systemd/system/watchlog.timer; enabled; preset: enabled)
     Active: active (waiting) since Wed 2026-08-05 10:26:22 UTC; 9min ago
    Trigger: Wed 2026-08-05 10:35:40 UTC; 17s left
   Triggers: ● watchlog.service

авг 05 10:26:22 kosogor systemd[1]: Started watchlog.timer - Run watchlog script every 30 second.
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# systemctl status watchlog.timer
● watchlog.timer - Run watchlog script every 30 second
     Loaded: loaded (/etc/systemd/system/watchlog.timer; enabled; preset: enabled)
     Active: active (waiting) since Wed 2026-08-05 10:26:22 UTC; 9min ago
    Trigger: Wed 2026-08-05 10:35:40 UTC; 2s left
   Triggers: ● watchlog.service

авг 05 10:26:22 kosogor systemd[1]: Started watchlog.timer - Run watchlog script every 30 second.
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# cat /var/log/syslog | grep -i master
2026-08-05T10:31:34.032018+00:00 kosogor root: Ср 05 авг 2026 10:31:34 UTC: I found word, Master!
2026-08-05T10:34:10.490545+00:00 kosogor root: Ср 05 авг 2026 10:34:10 UTC: I found word, Master!
2026-08-05T10:34:40.536501+00:00 kosogor root: Ср 05 авг 2026 10:34:40 UTC: I found word, Master!
2026-08-05T10:35:10.782160+00:00 kosogor root: Ср 05 авг 2026 10:35:10 UTC: I found word, Master!
2026-08-05T10:35:41.027353+00:00 kosogor root: Ср 05 авг 2026 10:35:41 UTC: I found word, Master!
2026-08-05T10:36:11.272793+00:00 kosogor root: Ср 05 авг 2026 10:36:11 UTC: I found word, Master!
2026-08-05T10:36:41.548309+00:00 kosogor root: Ср 05 авг 2026 10:36:41 UTC: I found word, Master!
2026-08-05T10:37:11.790089+00:00 kosogor root: Ср 05 авг 2026 10:37:11 UTC: I found word, Master!
2026-08-05T10:37:42.028862+00:00 kosogor root: Ср 05 авг 2026 10:37:42 UTC: I found word, Master!
2026-08-05T10:38:12.296557+00:00 kosogor root: Ср 05 авг 2026 10:38:12 UTC: I found word, Master!
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# systemctl disable watchlog.timer
Removed "/etc/systemd/system/multi-user.target.wants/watchlog.timer".
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# cat /var/log/syslog | grep -i master
2026-08-05T10:31:34.032018+00:00 kosogor root: Ср 05 авг 2026 10:31:34 UTC: I found word, Master!
2026-08-05T10:34:10.490545+00:00 kosogor root: Ср 05 авг 2026 10:34:10 UTC: I found word, Master!
2026-08-05T10:34:40.536501+00:00 kosogor root: Ср 05 авг 2026 10:34:40 UTC: I found word, Master!
2026-08-05T10:35:10.782160+00:00 kosogor root: Ср 05 авг 2026 10:35:10 UTC: I found word, Master!
2026-08-05T10:35:41.027353+00:00 kosogor root: Ср 05 авг 2026 10:35:41 UTC: I found word, Master!
2026-08-05T10:36:11.272793+00:00 kosogor root: Ср 05 авг 2026 10:36:11 UTC: I found word, Master!
2026-08-05T10:36:41.548309+00:00 kosogor root: Ср 05 авг 2026 10:36:41 UTC: I found word, Master!
2026-08-05T10:37:11.790089+00:00 kosogor root: Ср 05 авг 2026 10:37:11 UTC: I found word, Master!
2026-08-05T10:37:42.028862+00:00 kosogor root: Ср 05 авг 2026 10:37:42 UTC: I found word, Master!
2026-08-05T10:38:12.296557+00:00 kosogor root: Ср 05 авг 2026 10:38:12 UTC: I found word, Master!
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# systemctl stop watchlog.timer
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# systemctl status watchlog.timer
○ watchlog.timer - Run watchlog script every 30 second
     Loaded: loaded (/etc/systemd/system/watchlog.timer; disabled; preset: enabled)
     Active: inactive (dead)
    Trigger: n/a
   Triggers: ● watchlog.service

авг 05 10:20:57 kosogor systemd[1]: Started watchlog.timer - Run watchlog script every 30 second.
авг 05 10:25:59 kosogor systemd[1]: watchlog.timer: Deactivated successfully.
авг 05 10:25:59 kosogor systemd[1]: Stopped watchlog.timer - Run watchlog script every 30 second.
авг 05 10:26:22 kosogor systemd[1]: Started watchlog.timer - Run watchlog script every 30 second.
авг 05 10:40:30 kosogor systemd[1]: watchlog.timer: Deactivated successfully.
авг 05 10:40:30 kosogor systemd[1]: Stopped watchlog.timer - Run watchlog script every 30 second.
root@kosogor:/home/kosogor# 
```

