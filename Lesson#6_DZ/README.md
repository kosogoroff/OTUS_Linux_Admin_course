# Занятие 23.07.2026 "Управление пакетами. Дистрибьюция софта"

Сборка RPM-пакета и создание репозитория

## Цель:

Научиться собирать RPM-пакеты.

Создавать собственный RPM-репозиторий.

## Описание/Пошаговая инструкция выполнения домашнего задания:


## 🎯 Что нужно сделать?

-  создать свой RPM (можно взять свое приложение, либо собрать к примеру Apache с определенными опциями);

-  cоздать свой репозиторий и разместить там ранее собранный RPM;

-  реализовать это все либо в Vagrant, либо развернуть у себя через Nginx и дать ссылку на репозиторий.

# Решение

В процессе изучения темы выполнено четыре варианта домашнего задания:

### 1. На ОС AlmaLinux 9.8 (DNF/YUM/RPM-based) (в соответствии с предоставленной методичкой): 

- cборка пакета nginx с модулем сжатия Brotli, установка и настройка собранного nginx, проверка работоспособности собранного сервера, тестирование сжатия brotli при передаче файлов;

- создание RPM-пакета; создание репозитория YUM/RPM развёртывание его на установленном nginx, публикация в нём созданного пакета;

- на клиентской машине подключение репозитория как локального через file:// и по http:// с сервера nginx.

### 1.1. На ОС AlmaLinux 9.8 (DNF/YUM/RPM-based): 

- cборка пакета nginx в базовой конфигурации без дополнительных модулей и флагов (для упрощения процесса);

- создание RPM-пакета.

### 2. На ОС Ubuntu 24.04 (APT/DPKG-based): 

- cборка пакета nginx с модулем сжатия Brotli, установка и настройка собранного nginx, проверка работоспособности собранного сервера, тестирование сжатия brotli при передаче файлов;

- создание DEB-пакета; создание репозитория YUM/RPM развёртывание его на установленном nginx, публикация в нём созданного пакета;

- на клиентской машине подключение репозитория как локального через file:// и по http:// с сервера nginx.

### 2.1. На ОС Ubuntu 24.04 (APT/DPKG-based): 

- cборка пакета nginx в базовой конфигурации без дополнительных модулей и флагов (для упрощения процесса);

- создание DEB-пакета.


Далее приведены результаты.


# 1. На ОС AlmaLinux 9.8 (DNF/YUM/RPM-based) (в соответствии с предоставленной методичкой): 

## 0. Чистая ВМ с ОС AlmaLinux 9.8

```
[kosogor@almalinux-9 ~]$ cat /etc/os-release | grep PRETTY_NAME
PRETTY_NAME="AlmaLinux 9.8 (Olive Jaguar)"
[kosogor@almalinux-9 ~]$ uname -a
Linux almalinux-9 5.14.0-687.29.1.el9_8.x86_64 #1 SMP PREEMPT_DYNAMIC Thu Jul 23 16:18:48 EDT 2026 x86_64 x86_64 x86_64 GNU/Linux
[kosogor@almalinux-9 ~]$
```




# 2. На ОС Ubuntu 24.04 (APT/DPKG-based): 

Данный пункт выполнялся путём проб и ошибок с использованием поиска в Интернет и рекомендаций Яндекс ИИ, цель была собрать рабочий пакет
и проверить его работу.

## 0. Чистая ВМ с ОС Ubuntu 24.04

```
kosogor@vm1-server:~$ uname -a
Linux kosogor 6.8.0-100-generic #100-Ubuntu SMP PREEMPT_DYNAMIC Tue Jan 13 16:40:06 UTC 2026 x86_64 x86_64 x86_64 GNU/Linux
kosogor@vm1-server:~$ cat /etc/os-release | grep PRETTY_NAME
PRETTY_NAME="Ubuntu 24.04.4 LTS"
kosogor@vm1-server:~$
```

1. Установка необходимых для сборки пакетов:

```
kosogor@vm1-server:~$ sudo apt update
Пол:1 http://security.ubuntu.com/ubuntu noble-security InRelease [126 kB]
Пол:2 http://security.ubuntu.com/ubuntu noble-security/main amd64 Components [46,4 kB]
<...>
Чтение информации о состоянии… Готово         
Может быть обновлено 35 пакетов. Запустите «apt list --upgradable» для их показа.
kosogor@vm1-server:~$
kosogor@vm1-server:~$ sudo apt install -y build-essential devscripts fakeroot git libbrotli-dev libpcre3-dev libssl-dev debhelper dh-autoreconf quilt
Чтение списков пакетов… Готово
Построение дерева зависимостей… Готово
<...>

No VM guests are running outdated hypervisor (qemu) binaries on this host.
kosogor@vm1-server:~$
kosogor@vm1-server:~$ mkdir ~/nginx-brotli-build && cd ~/nginx-brotli-build
kosogor@vm1-server:~$
kosogor@vm1-server:~/nginx-brotli-build$ apt-get source nginx
Чтение списков пакетов… Готово
ВНИМАНИЕ: работа над пакетом «nginx» ведётся в системе управления версиями «Git»:
https://salsa.debian.org/nginx-team/nginx.git
<...>
kosogor@vm1-server:~/nginx-brotli-build$ ll
total 1208
drwxrwxr-x  3 kosogor kosogor    4096 июл 29 16:55 ./
drwxr-x---  5 kosogor kosogor    4096 июл 29 16:53 ../
drwxrwxr-x 10 kosogor kosogor    4096 июл 29 16:55 nginx-1.24.0/
-rw-r--r--  1 kosogor kosogor  103744 июл 20 21:54 nginx_1.24.0-2ubuntu7.15.debian.tar.xz
-rw-r--r--  1 kosogor kosogor    3624 июл 20 21:54 nginx_1.24.0-2ubuntu7.15.dsc
-rw-r--r--  1 kosogor kosogor 1112471 июн 28  2023 nginx_1.24.0.orig.tar.gz
kosogor@vm1-server:~/nginx-brotli-build$ cd nginx-*
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$ ll
total 852
drwxrwxr-x 10 kosogor kosogor   4096 июл 29 16:55 ./
drwxrwxr-x  3 kosogor kosogor   4096 июл 29 16:55 ../
drwxrwxr-x  6 kosogor kosogor   4096 июл 29 16:55 auto/
-rw-rw-r--  1 kosogor kosogor 323312 апр 11  2023 CHANGES
-rw-rw-r--  1 kosogor kosogor 494234 апр 11  2023 CHANGES.ru
drwxrwxr-x  2 kosogor kosogor   4096 июл 29 16:55 conf/
-rwxrwxr-x  1 kosogor kosogor   2611 апр 11  2023 configure*
drwxrwxr-x  4 kosogor kosogor   4096 июл 29 16:55 contrib/
drwxrwxr-x 16 kosogor kosogor   4096 июл 20 19:12 debian/
drwxrwxr-x  2 kosogor kosogor   4096 июл 29 16:55 html/
-rw-rw-r--  1 kosogor kosogor   1397 апр 11  2023 LICENSE
drwxrwxr-x  2 kosogor kosogor   4096 июл 29 16:55 man/
drwxrwxr-x 29 kosogor kosogor   4096 июл 29 16:55 .pc/
-rw-rw-r--  1 kosogor kosogor     49 апр 11  2023 README
drwxrwxr-x  9 kosogor kosogor   4096 июл 29 16:55 src/
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$ git clone --depth 1 https://github.com/google/ngx_brotli.git
Cloning into 'ngx_brotli'...
remote: Enumerating objects: 21, done.
remote: Counting objects: 100% (21/21), done.
remote: Compressing objects: 100% (19/19), done.
remote: Total 21 (delta 4), reused 9 (delta 1), pack-reused 0 (from 0)
Receiving objects: 100% (21/21), 17.86 KiB | 163.00 KiB/s, done.
Resolving deltas: 100% (4/4), done.
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$ 
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$ sudo apt-get build-dep nginx -y
[sudo] password for kosogor: 
Чтение списков пакетов… Готово
Чтение списков пакетов… Готово
Построение дерева зависимостей… Готово
Чтение информации о состоянии… Готово         
Следующие НОВЫЕ пакеты будут установлены:
  geoip-bin icu-devtools libaom-dev libbz2-dev libdav1d-dev libdav1d7 libde265-dev libdeflate-dev libexpat1-dev libfontconfig-dev libfreetype-dev
<...>
No VM guests are running outdated hypervisor (qemu) binaries on this host.
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$ ls -la ngx_brotli/
total 56
drwxrwxr-x  7 kosogor kosogor 4096 июл 29 17:16 .
drwxrwxr-x 11 kosogor kosogor 4096 июл 29 17:15 ..
-rw-rw-r--  1 kosogor kosogor 1593 июл 29 17:16 config
-rw-rw-r--  1 kosogor kosogor 1466 июл 29 17:16 CONTRIBUTING.md
drwxrwxr-x  3 kosogor kosogor 4096 июл 29 17:16 deps
drwxrwxr-x  2 kosogor kosogor 4096 июл 29 17:16 filter
drwxrwxr-x  8 kosogor kosogor 4096 июл 29 17:16 .git
-rw-rw-r--  1 kosogor kosogor   90 июл 29 17:16 .gitmodules
-rw-rw-r--  1 kosogor kosogor 1435 июл 29 17:16 LICENSE
-rw-rw-r--  1 kosogor kosogor 7170 июл 29 17:16 README.md
drwxrwxr-x  2 kosogor kosogor 4096 июл 29 17:16 script
drwxrwxr-x  2 kosogor kosogor 4096 июл 29 17:16 static
-rw-rw-r--  1 kosogor kosogor  895 июл 29 17:16 .travis.yml
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$ cd ~/nginx-brotli-build/nginx-1.24.0
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$ find ngx_brotli/deps -type f ! -name '*.c' ! -name '*.h' ! -name '*.cc' ! -name '*.hpp' -delete
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$ 
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$ rm -rf ngx_brotli/deps
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$ 
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$ du -sh ~/nginx-brotli-build/nginx-1.24.0/ngx_brotli
320K	/home/kosogor/nginx-brotli-build/nginx-1.24.0/ngx_brotli
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$ 
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$ ls -la ngx_brotli
total 52
drwxrwxr-x  6 kosogor kosogor 4096 июл 29 17:19 .
drwxrwxr-x 11 kosogor kosogor 4096 июл 29 17:15 ..
-rw-rw-r--  1 kosogor kosogor 1593 июл 29 17:16 config
-rw-rw-r--  1 kosogor kosogor 1466 июл 29 17:16 CONTRIBUTING.md
drwxrwxr-x  2 kosogor kosogor 4096 июл 29 17:16 filter
drwxrwxr-x  8 kosogor kosogor 4096 июл 29 17:16 .git
-rw-rw-r--  1 kosogor kosogor   90 июл 29 17:16 .gitmodules
-rw-rw-r--  1 kosogor kosogor 1435 июл 29 17:16 LICENSE
-rw-rw-r--  1 kosogor kosogor 7170 июл 29 17:16 README.md
drwxrwxr-x  2 kosogor kosogor 4096 июл 29 17:16 script
drwxrwxr-x  2 kosogor kosogor 4096 июл 29 17:16 static
-rw-rw-r--  1 kosogor kosogor  895 июл 29 17:16 .travis.yml
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$ ls -la ngx_brotli/filter
total 36
drwxrwxr-x 2 kosogor kosogor  4096 июл 29 17:16 .
drwxrwxr-x 6 kosogor kosogor  4096 июл 29 17:19 ..
-rw-rw-r-- 1 kosogor kosogor  4072 июл 29 17:16 config
-rw-rw-r-- 1 kosogor kosogor 24158 июл 29 17:16 ngx_http_brotli_filter_module.c
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$ ls -la ngx_brotli/static
total 24
drwxrwxr-x 2 kosogor kosogor  4096 июл 29 17:16 .
drwxrwxr-x 6 kosogor kosogor  4096 июл 29 17:19 ..
-rw-rw-r-- 1 kosogor kosogor  1997 июл 29 17:16 config
-rw-rw-r-- 1 kosogor kosogor 10494 июл 29 17:16 ngx_http_brotli_static_module.c
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$ cat debian/rules | grep -i add-module
			--add-module=$(CURDIR)/ngx_brotli
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$ ./configure \
  --prefix=/usr \
  --conf-path=/etc/nginx/nginx.conf \
  --error-log-path=/var/log/nginx/error.log \
  --pid-path=/run/nginx.pid \
  --lock-path=/run/lock/nginx.lock \
  --http-log-path=/var/log/nginx/access.log \
  --with-http_ssl_module \
  --add-module=$(pwd)/ngx_brotli
checking for OS
 + Linux 6.8.12-custom x86_64
checking for C compiler ... found
 + using GNU C compiler
 + gcc version: 13.3.0 (Ubuntu 13.3.0-6ubuntu2~24.04.1) 
checking for gcc -pipe switch ... found
checking for -Wl,-E switch ... found
checking for gcc builtin atomic operations ... found
<...>
creating objs/Makefile

Configuration summary
  + using system PCRE2 library
  + using system OpenSSL library
  + using system zlib library

  nginx path prefix: "/usr"
  nginx binary file: "/usr/sbin/nginx"
  nginx modules path: "/usr/modules"
  nginx configuration prefix: "/etc/nginx"
  nginx configuration file: "/etc/nginx/nginx.conf"
  nginx pid file: "/run/nginx.pid"
  nginx error log file: "/var/log/nginx/error.log"
  nginx http access log file: "/var/log/nginx/access.log"
  nginx http client request body temporary files: "client_body_temp"
  nginx http proxy temporary files: "proxy_temp"
  nginx http fastcgi temporary files: "fastcgi_temp"
  nginx http uwsgi temporary files: "uwsgi_temp"
  nginx http scgi temporary files: "scgi_temp"

kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$ make -j$(nproc)
make -f objs/Makefile
make[1]: Entering directory '/home/kosogor/nginx-brotli-build/nginx-1.24.0'
cc -c -pipe  -O -W -Wall -Wpointer-arith -Wno-unused-parameter -Werror -g  -Wno-deprecated-declarations -I src/core -I src/event -I src/event/modules -I src/os/unix -I objs \
	-o objs/src/core/nginx.o \
	src/core/nginx.c
<...>
objs/ngx_modules.o \
-lcrypt -L/home/kosogor/nginx-brotli-build/nginx-1.24.0/ngx_brotli/deps/brotli/c/../out -lbrotlienc -lbrotlicommon -lm -lpcre2-8 -lssl -lcrypto -lz \
-Wl,-E
make[1]: Leaving directory '/home/kosogor/nginx-brotli-build/nginx-1.24.0'
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$ sudo make install
make -f objs/Makefile install
make[1]: Entering directory '/home/kosogor/nginx-brotli-build/nginx-1.24.0'
test -d '/usr' || mkdir -p '/usr'
test -d '/usr/sbin' \
	|| mkdir -p '/usr/sbin'
test ! -f '/usr/sbin/nginx' \
	|| mv '/usr/sbin/nginx' \
		'/usr/sbin/nginx.old'
cp objs/nginx '/usr/sbin/nginx'
test -d '/etc/nginx' \
	|| mkdir -p '/etc/nginx'
cp conf/koi-win '/etc/nginx'
cp conf/koi-utf '/etc/nginx'
cp conf/win-utf '/etc/nginx'
test -f '/etc/nginx/mime.types' \
	|| cp conf/mime.types '/etc/nginx'
cp conf/mime.types '/etc/nginx/mime.types.default'
<...>
make[1]: Leaving directory '/home/kosogor/nginx-brotli-build/nginx-1.24.0'
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$ /usr/sbin/nginx -V
nginx version: nginx/1.24.0 (Ubuntu)
built by gcc 13.3.0 (Ubuntu 13.3.0-6ubuntu2~24.04.1) 
built with OpenSSL 3.0.13 30 Jan 2024
TLS SNI support enabled
configure arguments: --prefix=/usr --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --pid-path=/run/nginx.pid --lock-path=/run/lock/nginx.lock --http-log-path=/var/log/nginx/access.log --with-http_ssl_module --add-module=/home/kosogor/nginx-brotli-build/nginx-1.24.0/ngx_brotli
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$

```

2. Сборка DEB-пакета в данном варианте была осложнена внесёнными в пакет изменениями при добавлении модулю, с помощью стандартной утилиты debuild DEB-пакет собрать не удалось. DEB-пакет с ограниченными возможностями (например, не создающего настройки systemctl при установке) удалось создать с помощью утилиты fpm:

```
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$ sudo apt install ruby-dev build-essential
Чтение списков пакетов… Готово
Построение дерева зависимостей… Готово
Чтение информации о состоянии… Готово         
Уже установлен пакет build-essential самой новой версии (12.10ubuntu1).
Будут установлены следующие дополнительные пакеты:
  fonts-lato javascript-common libgmp-dev libgmpxx4ldbl libjs-jquery libruby libruby3.2 rake ruby ruby-net-telnet ruby-rubygems ruby-sdbm ruby-webrick
<...>
No user sessions are running outdated binaries.

No VM guests are running outdated hypervisor (qemu) binaries on this host.
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$ 
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$ 
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$ sudo gem install fpm
Fetching stud-0.0.23.gem
Fetching mustache-0.99.8.gem
Fetching insist-1.0.0.gem
<...>
Done installing documentation for stud, mustache, insist, dotenv, clamp, cabin, pleaserun, backports, arr-pm, fpm after 4 seconds
10 gems installed
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$ 
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$ sudo fpm -s dir -t deb   --name nginx-brotli   --version 1.24.0   --iteration 1   --architecture amd64   --depends "libc6"   --depends "libpcre3"   --depends "zlib1g"   --description "Nginx with ngx_brotli module (custom build)"   -p ./   /usr/sbin/nginx   /etc/nginx   /var/log/nginx
Debian packaging tools generally labels all files in /etc as config files, as mandated by policy, so fpm defaults to this behavior for deb packages. You can disable this default behavior with --deb-no-default-config-files flag {:level=>:warn}
Created package {:path=>"./nginx-brotli_1.24.0-1_amd64.deb"}
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$ ls -lh ./nginx-brotli_1.24.0-1_amd64.deb
-rw-r--r-- 1 root root 2,0M июл 29 17:50 ./nginx-brotli_1.24.0-1_amd64.deb
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$ sudo dpkg -i ./nginx-brotli_1.24.0-1_amd64.deb
Выбор ранее не выбранного пакета nginx-brotli.
(Чтение базы данных … на данный момент установлено 151786 файлов и каталогов.)
Подготовка к распаковке …/nginx-brotli_1.24.0-1_amd64.deb …
Распаковывается nginx-brotli (1.24.0-1) …
Настраивается пакет nginx-brotli (1.24.0-1) …
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$ sudo nginx -t
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$ /usr/sbin/nginx -V
nginx version: nginx/1.24.0 (Ubuntu)
built by gcc 13.3.0 (Ubuntu 13.3.0-6ubuntu2~24.04.1) 
built with OpenSSL 3.0.13 30 Jan 2024
TLS SNI support enabled
configure arguments: --prefix=/usr --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --pid-path=/run/nginx.pid --lock-path=/run/lock/nginx.lock --http-log-path=/var/log/nginx/access.log --with-http_ssl_module --add-module=/home/kosogor/nginx-brotli-build/nginx-1.24.0/ngx_brotli
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$
```

3. Затем вручную было создана конфигурация systemctl для запуска сервиса nginx, сервис был запущен, сконфигурирован его автозапуск при загрузке ОС, а также отключена перезапись этого пакета при обновлениях:

```
root@vm1-server:/home/kosogor/nginx-brotli-build/nginx-1.24.0# sudo cat > /etc/systemd/system/nginx-brotli.service
[Unit]
Description=Nginx with Brotli (custom build)
After=network.target

[Service]
Type=forking
PIDFile=/run/nginx.pid
ExecStart=/usr/sbin/nginx
ExecReload=/usr/sbin/nginx -s reload
ExecStop=/usr/sbin/nginx -s stop

[Install]
WantedBy=multi-user.target
root@vm1-server:/home/kosogor/nginx-brotli-build/nginx-1.24.0# 
root@vm1-server:/home/kosogor/nginx-brotli-build/nginx-1.24.0# sudo systemctl daemon-reload
root@vm1-server:/home/kosogor/nginx-brotli-build/nginx-1.24.0# sudo systemctl start nginx-brotli
root@vm1-server:/home/kosogor/nginx-brotli-build/nginx-1.24.0# sudo systemctl status nginx-brotli
● nginx-brotli.service - Nginx with Brotli (custom build)
     Loaded: loaded (/etc/systemd/system/nginx-brotli.service; disabled; preset: enabled)
     Active: active (running) since Wed 2026-07-29 18:05:16 UTC; 10s ago
    Process: 12056 ExecStart=/usr/sbin/nginx (code=exited, status=0/SUCCESS)
<...>
root@vm1-server:/home/kosogor/nginx-brotli-build/nginx-1.24.0# sudo systemctl enable --now nginx-brotli
Created symlink /etc/systemd/system/multi-user.target.wants/nginx-brotli.service → /etc/systemd/system/nginx-brotli.service.
root@vm1-server:/home/kosogor/nginx-brotli-build/nginx-1.24.0#
root@vm1-server:/home/kosogor/nginx-brotli-build/nginx-1.24.0# sudo apt-mark hold nginx-brotli
nginx-brotli помечен как зафиксированный.
root@vm1-server:/home/kosogor/nginx-brotli-build/nginx-1.24.0#
root@vm1-server:/home/kosogor/nginx-brotli-build/nginx-1.24.0# apt-mark showhold
nginx-brotli
root@vm1-server:/home/kosogor/nginx-brotli-build/nginx-1.24.0#
```

После запуска установленного сервера nginx с модулем brotli была проверена его работа и сжатие тестового файла brotli-test-big.txt при передаче:

```
root@vm1-server:/home/kosogor/nginx-brotli-build/nginx-1.24.0# mkdir -p /usr/share/nginx/html
root@vm1-server:/home/kosogor/nginx-brotli-build/nginx-1.24.0#


root@vm1-server:/home/kosogor/nginx-brotli-build/nginx-1.24.0# yes "test brotli static module — repeat this line many times to make the file large enough for compression" | head -n 1000 > /usr/share/nginx/html/brotli-test-big.txt
root@vm1-server:/home/kosogor/nginx-brotli-build/nginx-1.24.0#

root@vm1-server:/home/kosogor/nginx-brotli-build/nginx-1.24.0# cat /etc/nginx/nginx.conf

#user  nobody;
worker_processes  1;

#error_log  logs/error.log;
#error_log  logs/error.log  notice;
#error_log  logs/error.log  info;

#pid        logs/nginx.pid;


events {
    worker_connections  1024;
}


http {
    include       mime.types;
    default_type  application/octet-stream;

    #log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
    #                  '$status $body_bytes_sent "$http_referer" '
    #                  '"$http_user_agent" "$http_x_forwarded_for"';

    #access_log  logs/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    #keepalive_timeout  0;
    keepalive_timeout  65;

    #gzip  on;

    server {
        listen       80;
        server_name  localhost;

        #charset koi8-r;

        #access_log  logs/host.access.log  main;

        location / {
            root   /usr/share/nginx/html;
            index  index.html index.htm;
	    autoindex on;
	    brotli on;
            brotli_comp_level 4;
	    brotli_types text/plain text/css application/json application/javascript text/xml application/xml application/xhtml+xml text/javascript image/svg+xml text/calendar application/octet-stream;

        }

        #error_page  404              /404.html;

        # redirect server error pages to the static page /50x.html
        #
        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }

        # proxy the PHP scripts to Apache listening on 127.0.0.1:80
        #
        #location ~ \.php$ {
        #    proxy_pass   http://127.0.0.1;
        #}

        # pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
        #
        #location ~ \.php$ {
        #    root           html;
        #    fastcgi_pass   127.0.0.1:9000;
        #    fastcgi_index  index.php;
        #    fastcgi_param  SCRIPT_FILENAME  /scripts$fastcgi_script_name;
        #    include        fastcgi_params;
        #}

        # deny access to .htaccess files, if Apache's document root
        # concurs with nginx's one
        #
        #location ~ /\.ht {
        #    deny  all;
        #}
    }


    # another virtual host using mix of IP-, name-, and port-based configuration
    #
    #server {
    #    listen       8000;
    #    listen       somename:8080;
    #    server_name  somename  alias  another.alias;

    #    location / {
    #        root   html;
    #        index  index.html index.htm;
    #    }
    #}


    # HTTPS server
    #
    #server {
    #    listen       443 ssl;
    #    server_name  localhost;

    #    ssl_certificate      cert.pem;
    #    ssl_certificate_key  cert.key;

    #    ssl_session_cache    shared:SSL:1m;
    #    ssl_session_timeout  5m;

    #    ssl_ciphers  HIGH:!aNULL:!MD5;
    #    ssl_prefer_server_ciphers  on;

    #    location / {
    #        root   html;
    #        index  index.html index.htm;
    #    }
    #}

}
root@vm1-server:/home/kosogor/nginx-brotli-build/nginx-1.24.0# 
root@vm1-server:/home/kosogor/nginx-brotli-build/nginx-1.24.0# curl -H "Accept-Encoding: br" -D - -o /dev/null http://localhost/brotli-test-big.txt
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
Date: Wed, 29 Jul 2026 18:34:18 GMT
Content-Type: text/plain
Last-Modified: Wed, 29 Jul 2026 18:16:42 GMT
Transfer-Encoding: chunked
Connection: keep-alive
ETag: W/"6a6a438a-19640"
Content-Encoding: br

100    92    0    92    0     0  15096      0 --:--:-- --:--:-- --:--:-- 15333
root@vm1-server:/home/kosogor/nginx-brotli-build/nginx-1.24.0# 
root@vm1-server:/home/kosogor/nginx-brotli-build/nginx-1.24.0# 
root@vm1-server:/home/kosogor/nginx-brotli-build/nginx-1.24.0# curl -H "Accept-Encoding: br" -o /tmp/test-br.bin -w "%{size_download}\n" http://localhost/brotli-test-big.txt
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100    92    0    92    0     0  67997      0 --:--:-- --:--:-- --:--:-- 92000
92
root@vm1-server:/home/kosogor/nginx-brotli-build/nginx-1.24.0# 

root@vm1-server:/home/kosogor/nginx-brotli-build/nginx-1.24.0# curl -H "Accept-Encoding: br" -i http://localhost/brotli-test-big.txt | head -n 15
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100    92    0    92    0     0  48041      0 --:--:-- --:--:-- --:--:-- 92000
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
Date: Wed, 29 Jul 2026 18:38:59 GMT
Content-Type: text/plain
Last-Modified: Wed, 29 Jul 2026 18:16:42 GMT
Transfer-Encoding: chunked
Connection: keep-alive
ETag: W/"6a6a438a-19640"
Content-Encoding: br

���
   �n~F�֌'4t+Y��P�8����`�ݫ��Q)�mE���g����?M)uZ�6nPu��U�/e��
                                                           ��]���G,z�{)�b�-
root@vm1-server:/home/kosogor/nginx-brotli-build/nginx-1.24.0# 
root@vm1-server:/home/kosogor/nginx-brotli-build/nginx-1.24.0# curl -H "Accept-Encoding: gzip,deflate" -i http://localhost/brotli-test-big.txt | head -n 15
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
Date: Wed, 29 Jul 2026 18:39:57 GMT
Content-Type: text/plain
Content-Length: 104000
Last-Modified: Wed, 29 Jul 2026 18:16:42 GMT
Connection: keep-alive
ETag: "6a6a438a-19640"
Accept-Ranges: bytes

test brotli static module — repeat this line many times to make the file large enough for compression
test brotli static module — repeat this line many times to make the file large enough for compression
test brotli static module — repeat this line many times to make the file large enough for compression
test brotli static module — repeat this line many times to make the file large enough for compression
test brotli static module — repeat this line many times to make the file large enough for compression
 63  101k   63 65536    0     0  45.5M      0 --:--:-- --:--:-- --:--:-- 62.5M
curl: (23) Failure writing output to destination
root@vm1-server:/home/kosogor/nginx-brotli-build/nginx-1.24.0#
```

4. Затем на этом же ВМ был организован репозиторий для DEB-пакетов, в него был добавлен DEB-пакет nginx-brotli с помощью утилиты dpkg-scanpackages:

```
root@vm1-server:/home/kosogor/nginx-brotli-build/nginx-1.24.0# 
root@vm1-server:/home/kosogor/nginx-brotli-build/nginx-1.24.0# 
root@vm1-server:/home/kosogor/nginx-brotli-build/nginx-1.24.0# sudo mkdir -p /var/local/repo/nginx-brotli
root@vm1-server:/home/kosogor/nginx-brotli-build/nginx-1.24.0# 
root@vm1-server:/home/kosogor/nginx-brotli-build/nginx-1.24.0# sudo cp /home/kosogor/nginx-brotli-build/nginx-1.24.0/nginx-brotli_1.24.0-1_amd64.deb /var/local/repo/nginx-brotli/
root@vm1-server:/home/kosogor/nginx-brotli-build/nginx-1.24.0#
root@vm1-server:/home/kosogor/nginx-brotli-build/nginx-1.24.0# sudo apt install dpkg-dev
Чтение списков пакетов… Готово
Построение дерева зависимостей… Готово
Чтение информации о состоянии… Готово         
Уже установлен пакет dpkg-dev самой новой версии (1.22.6ubuntu6.6).
dpkg-dev помечен как установленный вручную.
Обновлено 0 пакетов, установлено 0 новых пакетов, для удаления отмечено 0 пакетов, и 35 пакетов не обновлено.
root@vm1-server:/home/kosogor/nginx-brotli-build/nginx-1.24.0# 
root@vm1-server:/home/kosogor/nginx-brotli-build/nginx-1.24.0# cd /var/local/repo/nginx-brotli
root@vm1-server:/var/local/repo/nginx-brotli# 
root@vm1-server:/var/local/repo/nginx-brotli# sudo dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz
dpkg-scanpackages: warning: Packages in archive but missing from override file:
dpkg-scanpackages: warning:   nginx-brotli
dpkg-scanpackages: info: Wrote 1 entries to output Packages file.
root@vm1-server:/var/local/repo/nginx-brotli# ls -lh Packages.gz
-rw-r--r-- 1 root staff 404 июл 29 18:53 Packages.gz
root@vm1-server:/var/local/repo/nginx-brotli#
```

5. Затем созданные репозиторий был подключен на клиентской машине (в данном случае, клиентской машиной являлся тот же компьютер) двумя способами:
как локальный репозиторий через file:// и через http:// с использованием сконфигурированного сервера nginx с модулем brontli :

```
root@vm1-server:/var/local/repo/nginx-brotli# echo "deb [trusted=yes] file:///var/local/repo/nginx-brotli ./" | sudo tee /etc/apt/sources.list.d/local-nginx-brotli.list
deb [trusted=yes] file:///var/local/repo/nginx-brotli ./
root@vm1-server:/var/local/repo/nginx-brotli# 
root@vm1-server:/var/local/repo/nginx-brotli# sudo apt update
Пол:1 file:/var/local/repo/nginx-brotli ./ InRelease
Игн:1 file:/var/local/repo/nginx-brotli ./ InRelease
Пол:2 file:/var/local/repo/nginx-brotli ./ Release
Игн:2 file:/var/local/repo/nginx-brotli ./ Release
Пол:3 file:/var/local/repo/nginx-brotli ./ Packages
Игн:3 file:/var/local/repo/nginx-brotli ./ Packages
Пол:4 file:/var/local/repo/nginx-brotli ./ Translation-ru_RU
Игн:4 file:/var/local/repo/nginx-brotli ./ Translation-ru_RU
Пол:5 file:/var/local/repo/nginx-brotli ./ Translation-ru
Игн:5 file:/var/local/repo/nginx-brotli ./ Translation-ru
Пол:6 file:/var/local/repo/nginx-brotli ./ Translation-en
Игн:6 file:/var/local/repo/nginx-brotli ./ Translation-en
Пол:3 file:/var/local/repo/nginx-brotli ./ Packages
Игн:3 file:/var/local/repo/nginx-brotli ./ Packages
Пол:4 file:/var/local/repo/nginx-brotli ./ Translation-ru_RU
Игн:4 file:/var/local/repo/nginx-brotli ./ Translation-ru_RU
Пол:5 file:/var/local/repo/nginx-brotli ./ Translation-ru
Игн:5 file:/var/local/repo/nginx-brotli ./ Translation-ru
Пол:6 file:/var/local/repo/nginx-brotli ./ Translation-en
Игн:6 file:/var/local/repo/nginx-brotli ./ Translation-en
Пол:3 file:/var/local/repo/nginx-brotli ./ Packages
Игн:3 file:/var/local/repo/nginx-brotli ./ Packages
Пол:4 file:/var/local/repo/nginx-brotli ./ Translation-ru_RU
Игн:4 file:/var/local/repo/nginx-brotli ./ Translation-ru_RU
Пол:5 file:/var/local/repo/nginx-brotli ./ Translation-ru
Игн:5 file:/var/local/repo/nginx-brotli ./ Translation-ru
Пол:6 file:/var/local/repo/nginx-brotli ./ Translation-en
Игн:6 file:/var/local/repo/nginx-brotli ./ Translation-en
Пол:3 file:/var/local/repo/nginx-brotli ./ Packages [404 B]
Пол:4 file:/var/local/repo/nginx-brotli ./ Translation-ru_RU
Игн:4 file:/var/local/repo/nginx-brotli ./ Translation-ru_RU
Пол:5 file:/var/local/repo/nginx-brotli ./ Translation-ru
Игн:5 file:/var/local/repo/nginx-brotli ./ Translation-ru
Пол:6 file:/var/local/repo/nginx-brotli ./ Translation-en
Игн:6 file:/var/local/repo/nginx-brotli ./ Translation-en
Пол:4 file:/var/local/repo/nginx-brotli ./ Translation-ru_RU
Игн:4 file:/var/local/repo/nginx-brotli ./ Translation-ru_RU
Пол:5 file:/var/local/repo/nginx-brotli ./ Translation-ru
Игн:5 file:/var/local/repo/nginx-brotli ./ Translation-ru
Пол:6 file:/var/local/repo/nginx-brotli ./ Translation-en
Игн:6 file:/var/local/repo/nginx-brotli ./ Translation-en
Пол:4 file:/var/local/repo/nginx-brotli ./ Translation-ru_RU
Игн:4 file:/var/local/repo/nginx-brotli ./ Translation-ru_RU
Пол:5 file:/var/local/repo/nginx-brotli ./ Translation-ru
Игн:5 file:/var/local/repo/nginx-brotli ./ Translation-ru
Пол:6 file:/var/local/repo/nginx-brotli ./ Translation-en
Игн:6 file:/var/local/repo/nginx-brotli ./ Translation-en
Пол:4 file:/var/local/repo/nginx-brotli ./ Translation-ru_RU
Игн:4 file:/var/local/repo/nginx-brotli ./ Translation-ru_RU
Пол:5 file:/var/local/repo/nginx-brotli ./ Translation-ru
Игн:5 file:/var/local/repo/nginx-brotli ./ Translation-ru
Пол:6 file:/var/local/repo/nginx-brotli ./ Translation-en
Игн:6 file:/var/local/repo/nginx-brotli ./ Translation-en
Сущ:7 http://security.ubuntu.com/ubuntu noble-security InRelease
Сущ:8 http://us.archive.ubuntu.com/ubuntu noble InRelease
Сущ:9 http://us.archive.ubuntu.com/ubuntu noble-updates InRelease
Сущ:10 http://us.archive.ubuntu.com/ubuntu noble-backports InRelease
Сущ:11 http://us.archive.ubuntu.com/ubuntu noble-proposed InRelease
Чтение списков пакетов… Готово            
Построение дерева зависимостей… Готово
Чтение информации о состоянии… Готово         
Может быть обновлено 35 пакетов. Запустите «apt list --upgradable» для их показа.
root@vm1-server:/var/local/repo/nginx-brotli# 
root@vm1-server:/var/local/repo/nginx-brotli# apt show nginx-brotli
Package: nginx-brotli
Version: 1.24.0-1
Priority: optional
Section: default
Maintainer: <root@vm1-server>
Installed-Size: 4 525 kB
Depends: libc6, libpcre3, zlib1g
Homepage: http://example.com/no-uri-given
License: unknown
Vendor: none
Download-Size: 2 029 kB
APT-Manual-Installed: yes
APT-Sources: file:/var/local/repo/nginx-brotli ./ Packages
Description: Nginx with ngx_brotli module (custom build)

root@vm1-server:/var/local/repo/nginx-brotli# 
root@vm1-server:/var/local/repo/nginx-brotli# systemctl reload nginx-brotli
root@vm1-server:/var/local/repo/nginx-brotli# 
root@vm1-server:/var/local/repo/nginx-brotli# cat /etc/nginx/nginx.conf

#user  nobody;
worker_processes  1;

#error_log  logs/error.log;
#error_log  logs/error.log  notice;
#error_log  logs/error.log  info;

#pid        logs/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;

    #log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
    #                  '$status $body_bytes_sent "$http_referer" '
    #                  '"$http_user_agent" "$http_x_forwarded_for"';

    #access_log  logs/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    #keepalive_timeout  0;
    keepalive_timeout  65;

    #gzip  on;

    server {
        listen       80;
        server_name  localhost;

        #charset koi8-r;

        #access_log  logs/host.access.log  main;

        location / {
            root   /usr/share/nginx/html;
            index  index.html index.htm;
	    autoindex on;
	    brotli on;
            brotli_comp_level 4;
	    gzip on;
            gzip_comp_level 6;
	    brotli_types text/plain text/css application/json application/javascript text/xml application/xml application/xhtml+xml text/javascript image/svg+xml text/calendar application/octet-stream;

        }

		location /repo/nginx-brotli/ {
	        alias /var/local/repo/nginx-brotli/;
	        autoindex on;
        }

        #error_page  404              /404.html;

        # redirect server error pages to the static page /50x.html
        #
        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }
    }

}
root@vm1-server:/var/local/repo/nginx-brotli# systemctl reload nginx-brotli
root@vm1-server:/var/local/repo/nginx-brotli# 
root@vm1-server:/var/local/repo/nginx-brotli# curl -sI http://localhost/repo/nginx-brotli/Packages.gz
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
Date: Wed, 29 Jul 2026 19:17:49 GMT
Content-Type: application/octet-stream
Content-Length: 404
Last-Modified: Wed, 29 Jul 2026 18:53:57 GMT
Connection: keep-alive
ETag: "6a6a4c45-194"
Accept-Ranges: bytes

root@vm1-server:/var/local/repo/nginx-brotli# echo "deb [trusted=yes] http://localhost/repo/nginx-brotli ./ " | sudo tee /etc/apt/sources.list.d/local-nginx-brotli.list
deb [trusted=yes] http://localhost/repo/nginx-brotli ./ 
root@vm1-server:/var/local/repo/nginx-brotli# 
root@vm1-server:/var/local/repo/nginx-brotli# sudo apt update
Игн:1 http://localhost/repo/nginx-brotli ./ InRelease
Игн:2 http://localhost/repo/nginx-brotli ./ Release
Игн:3 http://localhost/repo/nginx-brotli ./ Packages
Игн:4 http://localhost/repo/nginx-brotli ./ Translation-en
Игн:5 http://localhost/repo/nginx-brotli ./ Translation-ru_RU
Игн:6 http://localhost/repo/nginx-brotli ./ Translation-ru
Игн:3 http://localhost/repo/nginx-brotli ./ Packages
Игн:4 http://localhost/repo/nginx-brotli ./ Translation-en
Игн:5 http://localhost/repo/nginx-brotli ./ Translation-ru_RU
Игн:6 http://localhost/repo/nginx-brotli ./ Translation-ru
Игн:3 http://localhost/repo/nginx-brotli ./ Packages
Игн:4 http://localhost/repo/nginx-brotli ./ Translation-en
Игн:5 http://localhost/repo/nginx-brotli ./ Translation-ru_RU
Игн:6 http://localhost/repo/nginx-brotli ./ Translation-ru
Пол:3 http://localhost/repo/nginx-brotli ./ Packages [404 B]
Игн:4 http://localhost/repo/nginx-brotli ./ Translation-en
Игн:5 http://localhost/repo/nginx-brotli ./ Translation-ru_RU
Игн:6 http://localhost/repo/nginx-brotli ./ Translation-ru
Игн:4 http://localhost/repo/nginx-brotli ./ Translation-en
Игн:5 http://localhost/repo/nginx-brotli ./ Translation-ru_RU
Игн:6 http://localhost/repo/nginx-brotli ./ Translation-ru
Игн:4 http://localhost/repo/nginx-brotli ./ Translation-en
Игн:5 http://localhost/repo/nginx-brotli ./ Translation-ru_RU
Игн:6 http://localhost/repo/nginx-brotli ./ Translation-ru
Игн:4 http://localhost/repo/nginx-brotli ./ Translation-en
Игн:5 http://localhost/repo/nginx-brotli ./ Translation-ru_RU
Игн:6 http://localhost/repo/nginx-brotli ./ Translation-ru
Сущ:7 http://security.ubuntu.com/ubuntu noble-security InRelease
Сущ:8 http://us.archive.ubuntu.com/ubuntu noble InRelease
Сущ:9 http://us.archive.ubuntu.com/ubuntu noble-updates InRelease
Сущ:10 http://us.archive.ubuntu.com/ubuntu noble-backports InRelease
Сущ:11 http://us.archive.ubuntu.com/ubuntu noble-proposed InRelease
Получено 404 B за 2с (185 B/s)            
Чтение списков пакетов… Готово
Построение дерева зависимостей… Готово
Чтение информации о состоянии… Готово         
Может быть обновлено 35 пакетов. Запустите «apt list --upgradable» для их показа.
root@vm1-server:/var/local/repo/nginx-brotli# 
root@vm1-server:/var/local/repo/nginx-brotli# 
root@vm1-server:/var/local/repo/nginx-brotli# apt-cache policy nginx-brotli
nginx-brotli:
  Установлен: 1.24.0-1
  Кандидат:   1.24.0-1
  Таблица версий:
 *** 1.24.0-1 500
        500 http://localhost/repo/nginx-brotli ./ Packages
        100 /var/lib/dpkg/status
root@vm1-server:/var/local/repo/nginx-brotli# 
root@vm1-server:/var/local/repo/nginx-brotli# ll /etc/apt/sources.list.d/*brotli.list
-rw-r--r-- 1 root root 57 июл 29 19:25 /etc/apt/sources.list.d/local-nginx-brotli.list
root@vm1-server:/var/local/repo/nginx-brotli# 
root@vm1-server:/var/local/repo/nginx-brotli# 
root@vm1-server:/var/local/repo/nginx-brotli# echo "deb [trusted=yes] file:///var/local/repo/nginx-brotli ./" | sudo tee /etc/apt/sources.list.d/local-nginx-brotli_2.list
deb [trusted=yes] file:///var/local/repo/nginx-brotli ./
root@vm1-server:/var/local/repo/nginx-brotli# 
root@vm1-server:/var/local/repo/nginx-brotli# 
root@vm1-server:/var/local/repo/nginx-brotli# ll /etc/apt/sources.list.d/*brotli.list
-rw-r--r-- 1 root root 57 июл 29 19:25 /etc/apt/sources.list.d/local-nginx-brotli.list
root@vm1-server:/var/local/repo/nginx-brotli# 
root@vm1-server:/var/local/repo/nginx-brotli# echo "deb [trusted=yes] file:///var/local/repo/nginx-brotli ./" | sudo tee /etc/apt/sources.list.d/local-nginx-brotli_2.list
deb [trusted=yes] file:///var/local/repo/nginx-brotli ./
root@vm1-server:/var/local/repo/nginx-brotli# 
root@vm1-server:/var/local/repo/nginx-brotli# 
root@vm1-server:/var/local/repo/nginx-brotli# ll /etc/apt/sources.list.d/*brotli*.list
-rw-r--r-- 1 root root 57 июл 29 19:49 /etc/apt/sources.list.d/local-nginx-brotli_2.list
-rw-r--r-- 1 root root 57 июл 29 19:25 /etc/apt/sources.list.d/local-nginx-brotli.list
root@vm1-server:/var/local/repo/nginx-brotli# 
root@vm1-server:/var/local/repo/nginx-brotli# 
root@vm1-server:/var/local/repo/nginx-brotli# sudo apt update
Пол:1 file:/var/local/repo/nginx-brotli ./ InRelease
Игн:1 file:/var/local/repo/nginx-brotli ./ InRelease
Пол:2 file:/var/local/repo/nginx-brotli ./ Release
Игн:2 file:/var/local/repo/nginx-brotli ./ Release
Пол:3 file:/var/local/repo/nginx-brotli ./ Packages
Игн:3 file:/var/local/repo/nginx-brotli ./ Packages
Пол:4 file:/var/local/repo/nginx-brotli ./ Translation-ru
Игн:4 file:/var/local/repo/nginx-brotli ./ Translation-ru
Пол:5 file:/var/local/repo/nginx-brotli ./ Translation-ru_RU
Игн:5 file:/var/local/repo/nginx-brotli ./ Translation-ru_RU
Пол:6 file:/var/local/repo/nginx-brotli ./ Translation-en
Игн:6 file:/var/local/repo/nginx-brotli ./ Translation-en        
Игн:7 http://localhost/repo/nginx-brotli ./ InRelease            
Пол:3 file:/var/local/repo/nginx-brotli ./ Packages
Игн:3 file:/var/local/repo/nginx-brotli ./ Packages
Пол:4 file:/var/local/repo/nginx-brotli ./ Translation-ru
Игн:4 file:/var/local/repo/nginx-brotli ./ Translation-ru        
Игн:8 http://localhost/repo/nginx-brotli ./ Release              
Пол:5 file:/var/local/repo/nginx-brotli ./ Translation-ru_RU
Игн:5 file:/var/local/repo/nginx-brotli ./ Translation-ru_RU
Пол:6 file:/var/local/repo/nginx-brotli ./ Translation-en
Игн:6 file:/var/local/repo/nginx-brotli ./ Translation-en        
Пол:3 file:/var/local/repo/nginx-brotli ./ Packages              
Игн:9 http://localhost/repo/nginx-brotli ./ Packages       
Игн:3 file:/var/local/repo/nginx-brotli ./ Packages        
Пол:4 file:/var/local/repo/nginx-brotli ./ Translation-ru  
Игн:10 http://localhost/repo/nginx-brotli ./ Translation-ru
Игн:11 http://localhost/repo/nginx-brotli ./ Translation-en
Игн:4 file:/var/local/repo/nginx-brotli ./ Translation-ru
Пол:5 file:/var/local/repo/nginx-brotli ./ Translation-ru_RU
Игн:5 file:/var/local/repo/nginx-brotli ./ Translation-ru_RU        
Пол:6 file:/var/local/repo/nginx-brotli ./ Translation-en           
Игн:6 file:/var/local/repo/nginx-brotli ./ Translation-en
Пол:3 file:/var/local/repo/nginx-brotli ./ Packages [404 B]
Игн:12 http://localhost/repo/nginx-brotli ./ Translation-ru_RU      
Игн:9 http://localhost/repo/nginx-brotli ./ Packages
Игн:10 http://localhost/repo/nginx-brotli ./ Translation-ru
Пол:4 file:/var/local/repo/nginx-brotli ./ Translation-ru
Игн:4 file:/var/local/repo/nginx-brotli ./ Translation-ru
Пол:5 file:/var/local/repo/nginx-brotli ./ Translation-ru_RU
Игн:5 file:/var/local/repo/nginx-brotli ./ Translation-ru_RU        
Пол:6 file:/var/local/repo/nginx-brotli ./ Translation-en           
Игн:6 file:/var/local/repo/nginx-brotli ./ Translation-en
Игн:11 http://localhost/repo/nginx-brotli ./ Translation-en
Пол:4 file:/var/local/repo/nginx-brotli ./ Translation-ru
Игн:4 file:/var/local/repo/nginx-brotli ./ Translation-ru
Игн:12 http://localhost/repo/nginx-brotli ./ Translation-ru_RU
Пол:5 file:/var/local/repo/nginx-brotli ./ Translation-ru_RU
Игн:5 file:/var/local/repo/nginx-brotli ./ Translation-ru_RU        
Пол:6 file:/var/local/repo/nginx-brotli ./ Translation-en           
Игн:6 file:/var/local/repo/nginx-brotli ./ Translation-en        
Пол:4 file:/var/local/repo/nginx-brotli ./ Translation-ru        
Игн:4 file:/var/local/repo/nginx-brotli ./ Translation-ru        
Пол:5 file:/var/local/repo/nginx-brotli ./ Translation-ru_RU     
Игн:5 file:/var/local/repo/nginx-brotli ./ Translation-ru_RU        
Пол:6 file:/var/local/repo/nginx-brotli ./ Translation-en           
Игн:6 file:/var/local/repo/nginx-brotli ./ Translation-en        
Пол:4 file:/var/local/repo/nginx-brotli ./ Translation-ru        
Игн:4 file:/var/local/repo/nginx-brotli ./ Translation-ru        
Пол:5 file:/var/local/repo/nginx-brotli ./ Translation-ru_RU     
Игн:9 http://localhost/repo/nginx-brotli ./ Packages                
Игн:5 file:/var/local/repo/nginx-brotli ./ Translation-ru_RU        
Пол:6 file:/var/local/repo/nginx-brotli ./ Translation-en           
Игн:10 http://localhost/repo/nginx-brotli ./ Translation-ru      
Игн:6 file:/var/local/repo/nginx-brotli ./ Translation-en        
Игн:11 http://localhost/repo/nginx-brotli ./ Translation-en      
Игн:12 http://localhost/repo/nginx-brotli ./ Translation-ru_RU
Сущ:9 http://localhost/repo/nginx-brotli ./ Packages
Игн:10 http://localhost/repo/nginx-brotli ./ Translation-ru
Игн:11 http://localhost/repo/nginx-brotli ./ Translation-en        
Игн:12 http://localhost/repo/nginx-brotli ./ Translation-ru_RU
Игн:10 http://localhost/repo/nginx-brotli ./ Translation-ru
Игн:11 http://localhost/repo/nginx-brotli ./ Translation-en
Игн:12 http://localhost/repo/nginx-brotli ./ Translation-ru_RU
Игн:10 http://localhost/repo/nginx-brotli ./ Translation-ru
Игн:11 http://localhost/repo/nginx-brotli ./ Translation-en
Игн:12 http://localhost/repo/nginx-brotli ./ Translation-ru_RU
Игн:10 http://localhost/repo/nginx-brotli ./ Translation-ru
Игн:11 http://localhost/repo/nginx-brotli ./ Translation-en
Игн:12 http://localhost/repo/nginx-brotli ./ Translation-ru_RU
Сущ:13 http://security.ubuntu.com/ubuntu noble-security InRelease
Сущ:14 http://us.archive.ubuntu.com/ubuntu noble InRelease
Сущ:15 http://us.archive.ubuntu.com/ubuntu noble-updates InRelease
Сущ:16 http://us.archive.ubuntu.com/ubuntu noble-backports InRelease
Сущ:17 http://us.archive.ubuntu.com/ubuntu noble-proposed InRelease
Чтение списков пакетов… Готово            
Построение дерева зависимостей… Готово
Чтение информации о состоянии… Готово         
Может быть обновлено 35 пакетов. Запустите «apt list --upgradable» для их показа.
root@vm1-server:/var/local/repo/nginx-brotli# 
root@vm1-server:/var/local/repo/nginx-brotli# 
root@vm1-server:/var/local/repo/nginx-brotli# apt-cache policy nginx-brotli
nginx-brotli:
  Установлен: 1.24.0-1
  Кандидат:   1.24.0-1
  Таблица версий:
 *** 1.24.0-1 500
        500 http://localhost/repo/nginx-brotli ./ Packages
        500 file:/var/local/repo/nginx-brotli ./ Packages
        100 /var/lib/dpkg/status
root@vm1-server:/var/local/repo/nginx-brotli# 
root@vm1-server:/var/local/repo/nginx-brotli# 
root@vm1-server:/var/local/repo/nginx-brotli# cat /etc/apt/sources.list.d/*brotli*.list
deb [trusted=yes] file:///var/local/repo/nginx-brotli ./
deb [trusted=yes] http://localhost/repo/nginx-brotli ./ 
root@vm1-server:/var/local/repo/nginx-brotli# 
```

-  на клиентской машине подключение репозитория как локального через file:// и по http:// с сервера nginx.
