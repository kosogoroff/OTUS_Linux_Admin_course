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
    (https://gist.github.com/cea2k/1318020).  Для справки файл spawn-fcgi init.d shell script приведён ниже:

   ```
#!/bin/sh
#
# php-cgi - php-fastcgi swaping via  spawn-fcgi
#
# chkconfig:   - 85 15
# description:  Run php-cgi as app server
# processname: php-cgi
# config:      /etc/sysconfig/phpfastcgi (defaults RH style)
# pidfile:     /var/run/php_cgi.pid
# Note: See how to use this script :
# http://www.cyberciti.biz/faq/rhel-fedora-install-configure-nginx-php5/
# Source function library.
. /etc/rc.d/init.d/functions
 
# Source networking configuration.
. /etc/sysconfig/network
 
# Check that networking is up.
[ "$NETWORKING" = "no" ] && exit 0
 
spawnfcgi="/usr/bin/spawn-fcgi"
php_cgi="/usr/bin/php-cgi"
prog=$(basename $php_cgi)
server_ip=127.0.0.1
server_port=9000
server_user=nginx
server_group=nginx
server_childs=5
pidfile="/var/run/php_cgi.pid"
 
# do not edit, put changes in /etc/sysconfig/phpfastcgi
[ -f /etc/sysconfig/phpfastcgi ] && . /etc/sysconfig/phpfastcgi
 
start() {
    [ -x $php_cgi ] || exit 1
    [ -x $spawnfcgi ] || exit 2
    echo -n $"Starting $prog: "
    daemon $spawnfcgi -a ${server_ip} -p ${server_port} -u ${server_user} -g ${server_group} -P ${pidfile} -C ${server_childs} -f ${php_cgi}
    retval=$?
    echo
    return $retval
}
 
stop() {
    echo -n $"Stopping $prog: "
    killproc -p ${pidfile} $prog -QUIT
    retval=$?
    echo
    [ -f ${pidfile} ] && /bin/rm -f ${pidfile}
    return $retval
}
 
restart(){
	stop
	sleep 2
	start
}
 
rh_status(){
	status -p ${pidfile} $prog
}
 
case "$1" in
    start)
        start;;
    stop)
        stop;;
    restart)
        restart;;
    status)
        rh_status;;
    *)
        echo $"Usage: $0 {start|stop|restart|status}"
        exit 3
esac

   ```
    
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

1.4 Создаём в systemd новый юнит - конфигурацию для сервиса watchlog.service со следующими параметрами:

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
root@kosogor:/home/kosogor# systemctl enable watchlog.timer
Created symlink /etc/systemd/system/multi-user.target.wants/watchlog.timer → /etc/systemd/system/watchlog.timer.
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

## 2. Установить spawn-fcgi и создать unit-файл (spawn-fcgi.sevice) с помощью переделки init-скрипта 

2.1 Устанавливаем необходимые пакеты для spawn-fcgi . Создаём конфигурацию для запуска spawn-fcgi :

```
kosogor@kosogor:~$ sudo su
[sudo] password for kosogor: 
Sorry, try again.
[sudo] password for kosogor: 
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# apt install spawn-fcgi php php-cgi php-cli apache2 libapache2-mod-fcgid -y
Чтение списков пакетов… Готово
Построение дерева зависимостей… Готово
Чтение информации о состоянии… Готово         
Следующие пакеты устанавливались автоматически и больше не требуются:
  libfwupd2 libgusb2
Для их удаления используйте «sudo apt autoremove».
Будут установлены следующие дополнительные пакеты:
  apache2-bin apache2-data apache2-utils libapache2-mod-php8.3 libapr1t64 libaprutil1-dbd-sqlite3 libaprutil1-ldap libaprutil1t64 liblua5.4-0 php-common
  php8.3 php8.3-cgi php8.3-cli php8.3-common php8.3-opcache php8.3-readline ssl-cert
Предлагаемые пакеты:
  apache2-doc apache2-suexec-pristine | apache2-suexec-custom www-browser php-pear
Следующие НОВЫЕ пакеты будут установлены:
  apache2 apache2-bin apache2-data apache2-utils libapache2-mod-fcgid libapache2-mod-php8.3 libapr1t64 libaprutil1-dbd-sqlite3 libaprutil1-ldap
  libaprutil1t64 liblua5.4-0 php php-cgi php-cli php-common php8.3 php8.3-cgi php8.3-cli php8.3-common php8.3-opcache php8.3-readline spawn-fcgi ssl-cert
Обновлено 0 пакетов, установлено 23 новых пакетов, для удаления отмечено 0 пакетов, и 0 пакетов не обновлено.
Необходимо скачать 8 972 kB архивов.
После данной операции объём занятого дискового пространства возрастёт на 42,2 MB.
Пол:1 http://us.archive.ubuntu.com/ubuntu noble-updates/main amd64 libapr1t64 amd64 1.7.2-3.1ubuntu0.1 [108 kB]

<...  ЧАСТЬ ЛОГА УСТАНОВКИ УДАЛЕНА ...>

No containers need to be restarted.

User sessions running outdated binaries:
 kosogor @ session #1: login[885]
 kosogor @ user manager service: systemd[1068]

No VM guests are running outdated hypervisor (qemu) binaries on this host.
root@kosogor:/home/kosogor#
root@kosogor:/home/kosogor# cat > /etc/spawn-fcgi/fcgi.conf
bash: /etc/spawn-fcgi/fcgi.conf: No such file or directory
root@kosogor:/home/kosogor# mkdir /etc/spawn-fcgi/
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# cat > /etc/spawn-fcgi/fcgi.conf
# You must set some working options before the "spawn-fcgi" service will work.
# If SOCKET points to a file, then this file is cleaned up by the init script.
#
# See spawn-fcgi(1) for all possible options.
#
# Example :
SOCKET=/var/run/php-fcgi.sock
OPTIONS="-u www-data -g www-data -s $SOCKET -S -M 0600 -C 32 -F 1 -- /usr/bin/php-cgi
root@kosogor:/home/kosogor#
```

2.2 Создаём в systemd новый юнит - конфигурацию для запуска сервиса spawn-fcgi , запускаем сервис с помощью systemctl :

```
root@kosogor:/home/kosogor# cat /etc/systemd/system/spawn-fcgi.service
cat: /etc/systemd/system/spawn-fcgi.service: No such file or directory
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# cat > /etc/systemd/system/spawn-fcgi.service
[Unit]
Description=Spawn-fcgi startup service by Otus
After=network.target

[Service]
Type=simple
PIDFile=/var/run/spawn-fcgi.pid
EnvironmentFile=/etc/spawn-fcgi/fcgi.conf
ExecStart=/usr/bin/spawn-fcgi -n $OPTIONS
KillMode=process

[Install]
WantedBy=multi-user.target
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# systemctl start spawn-fcgi
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# systemctl status spawn-fcgi
● spawn-fcgi.service - Spawn-fcgi startup service by Otus
     Loaded: loaded (/etc/systemd/system/spawn-fcgi.service; disabled; preset: enabled)
     Active: active (running) since Wed 2026-08-05 11:53:01 UTC; 10s ago
   Main PID: 38266 (php-cgi)
      Tasks: 33 (limit: 4602)
     Memory: 14.7M (peak: 15.0M)
        CPU: 43ms
     CGroup: /system.slice/spawn-fcgi.service
             ├─38266 /usr/bin/php-cgi
             ├─38267 /usr/bin/php-cgi
             ├─38268 /usr/bin/php-cgi
             ├─38269 /usr/bin/php-cgi
             ├─38270 /usr/bin/php-cgi
             ├─38271 /usr/bin/php-cgi
             ├─38272 /usr/bin/php-cgi
             ├─38273 /usr/bin/php-cgi
             ├─38274 /usr/bin/php-cgi
             ├─38275 /usr/bin/php-cgi
             ├─38276 /usr/bin/php-cgi
             ├─38277 /usr/bin/php-cgi
             ├─38278 /usr/bin/php-cgi
<...>
root@kosogor:/home/kosogor# 
```

##3. Дорабатываем unit-файл Nginx (nginx.service) для запуска нескольких инстансов сервера с разными 
    конфигурационными файлами одновременно.

3.1 Устанавливаем пакет nginx:

```
root@kosogor:/home/kosogor# cat kosogor@kosogor:~$ sudo su
[sudo] password for kosogor:


root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# apt install nginx -y
Чтение списков пакетов… Готово
Построение дерева зависимостей… Готово
Чтение информации о состоянии… Готово         
Уже установлен пакет nginx самой новой версии (1.24.0-2ubuntu7.15).
Следующие пакеты устанавливались автоматически и больше не требуются:
  libfwupd2 libgusb2
Для их удаления используйте «sudo apt autoremove».
Обновлено 0 пакетов, установлено 0 новых пакетов, для удаления отмечено 0 пакетов, и 0 пакетов не обновлено.
root@kosogor:/home/kosogor#
root@kosogor:/home/kosogor# dpkg -l | grep nginx
ii  nginx                                 1.24.0-2ubuntu7.15                               amd64        small, powerful, scalable web/proxy server
ii  nginx-common                          1.24.0-2ubuntu7.15                               all          small, powerful, scalable web/proxy server - common files
root@kosogor:/home/kosogor#
```

3.2 Создаём в systemd новый юнит для работы с шаблонами для запуска нескольких экземпляров nginx :

```
root@kosogor:/home/kosogor# cat /etc/systemd/system/nginx@.service
# Stop dance for nginx
# =======================
#
# ExecStop sends SIGSTOP (graceful stop) to the nginx process.
# If, after 5s (--retry QUIT/5) nginx is still running, systemd takes control
# and sends SIGTERM (fast shutdown) to the main process.
# After another 5s (TimeoutStopSec=5), and if nginx is alive, systemd sends
# SIGKILL to all the remaining processes in the process group (KillMode=mixed).
#
# nginx signals reference doc:
# http://nginx.org/en/docs/control.html
#
[Unit]
Description=A high performance web server and a reverse proxy server
Documentation=man:nginx(8)
After=network.target nss-lookup.target

[Service]
Type=forking
PIDFile=/run/nginx-%I.pid
ExecStartPre=/usr/sbin/nginx -t -c /etc/nginx/nginx-%I.conf -q -g 'daemon on; master_process on;'
ExecStart=/usr/sbin/nginx -c /etc/nginx/nginx-%I.conf -g 'daemon on; master_process on;'
ExecReload=/usr/sbin/nginx -c /etc/nginx/nginx-%I.conf -g 'daemon on; master_process on;' -s reload
ExecStop=-/sbin/start-stop-daemon --quiet --stop --retry QUIT/5 --pidfile /run/nginx-%I.pid
TimeoutStopSec=5
KillMode=mixed

[Install]
WantedBy=multi-user.target
root@kosogor:/home/kosogor#
```

3.3 На основе исходной конфигурации /etc/nginx/nginx.conf создаём две конфигурации для двух инстансов nginx :

Базовая конфигурация nginx (использоваться не будет):
```
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# cat /etc/nginx/nginx.conf
user www-data;
worker_processes auto;
pid /run/nginx.pid;
error_log /var/log/nginx/error.log;
include /etc/nginx/modules-enabled/*.conf;

events {
	worker_connections 768;
	# multi_accept on;
}

http {

	##
	# Basic Settings
	##

	sendfile on;
	tcp_nopush on;
	types_hash_max_size 2048;
	# server_tokens off;

	# server_names_hash_bucket_size 64;
	# server_name_in_redirect off;

	include /etc/nginx/mime.types;
	default_type application/octet-stream;

	##
	# SSL Settings
	##

	ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3; # Dropping SSLv3, ref: POODLE
	ssl_prefer_server_ciphers on;

	##
	# Logging Settings
	##

	access_log /var/log/nginx/access.log;

	##
	# Gzip Settings
	##

	gzip on;

	# gzip_vary on;
	# gzip_proxied any;
	# gzip_comp_level 6;
	# gzip_buffers 16 8k;
	# gzip_http_version 1.1;
	# gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

	##
	# Virtual Host Configs
	##

	include /etc/nginx/conf.d/*.conf;
	include /etc/nginx/sites-enabled/*;
}
root@kosogor:/home/kosogor#
```

Копируем её и создаём две новых (отличаются разными файлами .pid и разными прослушиваемыми портами 9001 и 9002 ):

```
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# cp /etc/nginx/nginx.conf /etc/nginx/nginx-first.conf
root@kosogor:/home/kosogor# cp /etc/nginx/nginx.conf /etc/nginx/nginx-second.conf
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# cat /etc/nginx/nginx-first.conf
user www-data;
worker_processes auto;
pid /run/nginx-first.pid;
error_log /var/log/nginx/error.log;
include /etc/nginx/modules-enabled/*.conf;

events {
	worker_connections 768;
	# multi_accept on;
}

http {

	##
	# Basic Settings
	##

	sendfile on;
	tcp_nopush on;
	types_hash_max_size 2048;
	# server_tokens off;

	# server_names_hash_bucket_size 64;
	# server_name_in_redirect off;

	include /etc/nginx/mime.types;
	default_type application/octet-stream;

	##
	# SSL Settings
	##

	ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3; # Dropping SSLv3, ref: POODLE
	ssl_prefer_server_ciphers on;

	##
	# Logging Settings
	##

	access_log /var/log/nginx/access.log;

	##
	# Gzip Settings
	##

	gzip on;

	# gzip_vary on;
	# gzip_proxied any;
	# gzip_comp_level 6;
	# gzip_buffers 16 8k;
	# gzip_http_version 1.1;
	# gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

	##
	# Virtual Host Configs
	##

	server {
		listen 9001;
	}


	include /etc/nginx/conf.d/*.conf;
	#	include /etc/nginx/sites-enabled/*;
}
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# vi /etc/nginx/nginx-second.conf
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# cat /etc/nginx/nginx-second.conf
user www-data;
worker_processes auto;
pid /run/nginx-second.pid;
error_log /var/log/nginx/error.log;
include /etc/nginx/modules-enabled/*.conf;

events {
	worker_connections 768;
	# multi_accept on;
}

http {

	##
	# Basic Settings
	##

	sendfile on;
	tcp_nopush on;
	types_hash_max_size 2048;
	# server_tokens off;

	# server_names_hash_bucket_size 64;
	# server_name_in_redirect off;

	include /etc/nginx/mime.types;
	default_type application/octet-stream;

	##
	# SSL Settings
	##

	ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3; # Dropping SSLv3, ref: POODLE
	ssl_prefer_server_ciphers on;

	##
	# Logging Settings
	##

	access_log /var/log/nginx/access.log;

	##
	# Gzip Settings
	##

	gzip on;

	# gzip_vary on;
	# gzip_proxied any;
	# gzip_comp_level 6;
	# gzip_buffers 16 8k;
	# gzip_http_version 1.1;
	# gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

	##
	# Virtual Host Configs
	##

	server {
		listen 9002;
	}


	include /etc/nginx/conf.d/*.conf;
	#	include /etc/nginx/sites-enabled/*;
}
root@kosogor:/home/kosogor#
```

3.4 Запускаем два инстанса nginx с разными конфигурациями и проверяем :

```
root@kosogor:/home/kosogor# systemctl start nginx@first
root@kosogor:/home/kosogor#
root@kosogor:/home/kosogor# systemctl status nginx@first
● nginx@first.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/etc/systemd/system/nginx@.service; disabled; preset: enabled)
     Active: active (running) since Wed 2026-08-05 12:08:47 UTC; 5s ago
       Docs: man:nginx(8)
    Process: 38682 ExecStartPre=/usr/sbin/nginx -t -c /etc/nginx/nginx-first.conf -q -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
    Process: 38684 ExecStart=/usr/sbin/nginx -c /etc/nginx/nginx-first.conf -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
   Main PID: 38685 (nginx)
      Tasks: 4 (limit: 4602)
     Memory: 3.0M (peak: 3.6M)
        CPU: 28ms
     CGroup: /system.slice/system-nginx.slice/nginx@first.service
             ├─38685 "nginx: master process /usr/sbin/nginx -c /etc/nginx/nginx-first.conf -g daemon on; master_process on;"
             ├─38686 "nginx: worker process"
             ├─38687 "nginx: worker process"
             └─38688 "nginx: worker process"

авг 05 12:08:47 kosogor systemd[1]: Starting nginx@first.service - A high performance web server and a reverse proxy server...
авг 05 12:08:47 kosogor systemd[1]: Started nginx@first.service - A high performance web server and a reverse proxy server.
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# systemctl start nginx@second
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# systemctl status nginx@second
● nginx@second.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/etc/systemd/system/nginx@.service; disabled; preset: enabled)
     Active: active (running) since Wed 2026-08-05 12:09:16 UTC; 8s ago
       Docs: man:nginx(8)
    Process: 38760 ExecStartPre=/usr/sbin/nginx -t -c /etc/nginx/nginx-second.conf -q -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
    Process: 38762 ExecStart=/usr/sbin/nginx -c /etc/nginx/nginx-second.conf -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
   Main PID: 38763 (nginx)
      Tasks: 4 (limit: 4602)
     Memory: 3.0M (peak: 3.6M)
        CPU: 25ms
     CGroup: /system.slice/system-nginx.slice/nginx@second.service
             ├─38763 "nginx: master process /usr/sbin/nginx -c /etc/nginx/nginx-second.conf -g daemon on; master_process on;"
             ├─38764 "nginx: worker process"
             ├─38765 "nginx: worker process"
             └─38766 "nginx: worker process"

авг 05 12:09:16 kosogor systemd[1]: Starting nginx@second.service - A high performance web server and a reverse proxy server...
авг 05 12:09:16 kosogor systemd[1]: Started nginx@second.service - A high performance web server and a reverse proxy server.
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# ss -tnulp | grep nginx
tcp   LISTEN 0      511                   0.0.0.0:9001      0.0.0.0:*    users:(("nginx",pid=38688,fd=5),("nginx",pid=38687,fd=5),("nginx",pid=38686,fd=5),("nginx",pid=38685,fd=5))                                                                                         
tcp   LISTEN 0      511                   0.0.0.0:9002      0.0.0.0:*    users:(("nginx",pid=38766,fd=5),("nginx",pid=38765,fd=5),("nginx",pid=38764,fd=5),("nginx",pid=38763,fd=5))                                                                                         
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# ps afx | grep nginx
  38779 pts/1    S+     0:00                              \_ grep --color=auto nginx
  38685 ?        Ss     0:00 nginx: master process /usr/sbin/nginx -c /etc/nginx/nginx-first.conf -g daemon on; master_process on;
  38686 ?        S      0:00  \_ nginx: worker process
  38687 ?        S      0:00  \_ nginx: worker process
  38688 ?        S      0:00  \_ nginx: worker process
  38763 ?        Ss     0:00 nginx: master process /usr/sbin/nginx -c /etc/nginx/nginx-second.conf -g daemon on; master_process on;
  38764 ?        S      0:00  \_ nginx: worker process
  38765 ?        S      0:00  \_ nginx: worker process
  38766 ?        S      0:00  \_ nginx: worker process
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# journalctl -u nginx@first
авг 05 12:08:47 kosogor systemd[1]: Starting nginx@first.service - A high performance web server and a reverse proxy server...
авг 05 12:08:47 kosogor systemd[1]: Started nginx@first.service - A high performance web server and a reverse proxy server.
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# journalctl -u nginx@second
авг 05 12:09:16 kosogor systemd[1]: Starting nginx@second.service - A high performance web server and a reverse proxy server...
авг 05 12:09:16 kosogor systemd[1]: Started nginx@second.service - A high performance web server and a reverse proxy server.
root@kosogor:/home/kosogor#
```

3.5 В логе nginx содержатся ошибки от первоначальной попытки запуска nginx с дефолтной конфигурацией при его установке - запуск был неудачным, из-за конфликта
прослушиваемого порта 80 с Apache2, который автоматически установился в разделе 2 при установке spawn-fcgi :

```
root@kosogor:/home/kosogor# ll /var/log/nginx/error.log
-rw-r----- 1 www-data adm 1029 авг  5 11:58 /var/log/nginx/error.log
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# cat /var/log/nginx/error.log
2026/08/05 11:58:29 [emerg] 38527#38527: bind() to 0.0.0.0:80 failed (98: Address already in use)
2026/08/05 11:58:29 [emerg] 38527#38527: bind() to [::]:80 failed (98: Address already in use)
2026/08/05 11:58:29 [emerg] 38527#38527: bind() to 0.0.0.0:80 failed (98: Address already in use)
2026/08/05 11:58:29 [emerg] 38527#38527: bind() to [::]:80 failed (98: Address already in use)
2026/08/05 11:58:29 [emerg] 38527#38527: bind() to 0.0.0.0:80 failed (98: Address already in use)
2026/08/05 11:58:29 [emerg] 38527#38527: bind() to [::]:80 failed (98: Address already in use)
2026/08/05 11:58:29 [emerg] 38527#38527: bind() to 0.0.0.0:80 failed (98: Address already in use)
2026/08/05 11:58:29 [emerg] 38527#38527: bind() to [::]:80 failed (98: Address already in use)
2026/08/05 11:58:29 [emerg] 38527#38527: bind() to 0.0.0.0:80 failed (98: Address already in use)
2026/08/05 11:58:29 [emerg] 38527#38527: bind() to [::]:80 failed (98: Address already in use)
2026/08/05 11:58:29 [emerg] 38527#38527: still could not bind()
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# ll /etc/nginx/conf.d/*.conf
ls: cannot access '/etc/nginx/conf.d/*.conf': No such file or directory
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# 
root@kosogor:/home/kosogor# ss -tnulp | grep ':80 '
tcp   LISTEN 0      511                         *:80              *:*    users:(("apache2",pid=38185,fd=4),("apache2",pid=38184,fd=4),("apache2",pid=38183,fd=4),("apache2",pid=38182,fd=4),("apache2",pid=38181,fd=4),("apache2",pid=38179,fd=4),("apache2",pid=38177,fd=4))
root@kosogor:/home/kosogor#
```
