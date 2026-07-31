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

### 1. Работа с пакетом PRM и с репозиторием пакетов YUM/DNF/RPM в ОС AlmaLinux 9.8 (DNF/YUM/RPM-based) (в соответствии с предоставленной методичкой): 

- cборка пакета nginx с модулем сжатия Brotli, установка и настройка собранного nginx, проверка работоспособности собранного сервера, тестирование сжатия brotli при передаче файлов;

- создание RPM-пакета;
  
- создание репозитория YUM/RPM развёртывание его на установленном nginx, публикация в нём созданного пакета;

- на клиентской машине подключение репозитория как локального через file:// и по http:// с сервера nginx.


### 2. Работа с пакетом DEB и с репозиторием пакетов APT/DEB в  ОС Ubuntu 24.04 (APT/DPKG-based): 

- cборка пакета nginx с модулем сжатия Brotli, установка и настройка собранного nginx, проверка работоспособности собранного сервера, тестирование сжатия brotli при передаче файлов;

- создание DEB-пакета с помощью утилиты fpm ;
  
- создание репозитория APT/DEB развёртывание его на установленном nginx, публикация в нём созданного пакета;

- на клиентской машине подключение репозитория как локального через file:// и по http:// с сервера nginx.


### 2.1. Повторная сборка пакета DEB в помощью утилиты debuild и работа с репозиторием пакетов APT/DEB в ОС Ubuntu 24.04 (APT/DPKG-based): 

- cборка пакета nginx в базовой конфигурации без дополнительных модулей и флагов (для упрощения процесса);

- создание DEB-пакета;
  
- дополнительно проведена повторная cборка пакета nginx в базовой конфигурации без дополнительных модулей и создание DEB-пакета в Docker.

### 2.2. Повторная сборка пакета DEB в помощью утилиты debuild и работа с репозиторием пакетов APT/DEB в ОС Ubuntu 24.04 (APT/DPKG-based): 

- установка Docker, создание Dockerfile на основе опыта предыдущего пункта 2.1;

- cборка пакета nginx в базовой конфигурации без дополнительных модулей и флагов в Docker;

- создание DEB-пакета в Docker и выгрузка готовых DEB-пакетов из  Docker.

Таким образом, процесс от компиляции исходного выбранного пакета до создания пакета DEB либо RPM, и далее размещения созданного пакета в соответствующем
репозитории и подключения созданного репозитория к соответствующим клиентским машинам был пройден полностью несколько раз для DNF/YUM/RPM-based и для APT/DPKG-based
семейств ОС Linux.


Далее приведены результаты.


# 1. Работа с пакетом PRM и с репозиторием пакетов YUM/DNF/RPM в ОС AlmaLinux 9.8 (DNF/YUM/RPM-based) (в соответствии с предоставленной методичкой): 


### Примечание:
в качестве исходников для компиляции и сборки пакета используется установленный пакет .src.rpm для ngnix.
Вся информация по компиляции, сборке и установке пакета содержится в файле /SPECS/*.spec этого пакета
(например, в нём необходимо добавить информацию о добавлении дополнительного модуля).

## 0. Чистая ВМ с ОС AlmaLinux 9.8

```
[kosogor@almalinux-9 ~]$ cat /etc/os-release | grep PRETTY_NAME
PRETTY_NAME="AlmaLinux 9.8 (Olive Jaguar)"
[kosogor@almalinux-9 ~]$ uname -a
Linux almalinux-9 5.14.0-687.29.1.el9_8.x86_64 #1 SMP PREEMPT_DYNAMIC Thu Jul 23 16:18:48 EDT 2026 x86_64 x86_64 x86_64 GNU/Linux
[kosogor@almalinux-9 ~]$
```

1. Установка необходимых для сборки пакетов, установка окружения и зависимостей, необходимых для компиляции и сборки пакета nginx:

```
[root@almalinux-9 ~]# yum install -y rpmdevtools rpm-build createrepo yum-utils cmake gcc git
Последняя проверка окончания срока действия метаданных: 1:09:25 назад, Ср 29 июл 2026 13:44:09.
Зависимости разрешены.
============================================================================================================================================================
 Пакет                                       Архитектура                  Версия                                      Репозиторий                     Размер
============================================================================================================================================================
Установка:
 cmake                                       x86_64                       3.31.8-3.el9                                appstream                        13 M
 createrepo_c                                x86_64                       0.20.1-4.el9                                appstream                        71 k
 gcc
<...>

Выполнено!
[root@almalinux-9 ~]#
```

2. Скачивание и установка пакета с исходниками nginx, установка окружения для компиляции nginx, скачивание проекта brotli :

```
[root@almalinux-9 ~]# mkdir rpm && cd rpm
[root@almalinux-9 rpm]# yumdownloader --source nginx
подключение репозитория appstream-source
подключение репозитория baseos-source
подключение репозитория extras-source
AlmaLinux 9 - AppStream - Source                                                                                            215 kB/s | 906 kB     00:04    
AlmaLinux 9 - BaseOS - Source                                                                                               170 kB/s | 455 kB     00:02    
AlmaLinux 9 - Extras - Source                                                                                               2.8 kB/s | 9.7 kB     00:03    
nginx-1.20.1-28.el9_8.4.alma.1.src.rpm                                                                                      1.3 MB/s | 1.1 MB     00:00    
[root@almalinux-9 rpm]#
[root@almalinux-9 rpm]# ll
итого 1104
-rw-r--r--. 1 root root 1126804 июл 29 14:55 nginx-1.20.1-28.el9_8.4.alma.1.src.rpm
[root@almalinux-9 rpm]# rpm -Uvh nginx*.src.rpm
Обновление / установка...
   1:nginx-2:1.20.1-28.el9_8.4.alma.1 предупреждение: user mockbuild does not exist - using root
предупреждение: group mock does not exist - using root
предупреждение: user mockbuild does not exist - using root
<...>
################################# [100%]
[root@almalinux-9 rpm]# ll
Итого 1104
-rw-r--r--. 1 root root 1126804 июл 29 14:55 nginx-1.20.1-28.el9_8.4.alma.1.src.rpm
[root@almalinux-9 rpm]# ll ..
итого 4
-rw-------. 1 root root 1140 июл 29 10:19 anaconda-ks.cfg
drwxr-xr-x. 2 root root   52 июл 29 14:55 rpm
drwxr-xr-x. 4 root root   34 июл 29 14:58 rpmbuild
[root@almalinux-9 rpm]# cd ..
[root@almalinux-9 ~]# yum-builddep nginx
подключение репозитория appstream-source
подключение репозитория baseos-source
подключение репозитория extras-source
Последняя проверка окончания срока действия метаданных: 0:03:21 назад, Ср 29 июл 2026 14:55:49.
Пакет make-1:4.3-8.el9.x86_64 уже установлен.
Пакет gcc-11.5.0-14.el9.alma.1.x86_64 уже установлен.
Пакет systemd-252-67.el9_8.4.alma.1.x86_64 уже установлен.
Пакет systemd-rpm-macros-252-67.el9_8.4.alma.1.noarch уже установлен.
Пакет gnupg2-2.3.3-5.el9_7.x86_64 уже установлен.
Зависимости разрешены.
============================================================================================================================================================
 Пакет                                           Архитектура                Версия                                      Репозиторий                   Размер
============================================================================================================================================================
Установка:
 gd-devel                                        x86_64                     2.3.2-3.el9                                 appstream                      37 k
 libxslt-devel                                   x86_64                     1.1.34-14.el9_8.1
<...>
Выполнено!
[root@almalinux-9 ~]# 
[root@almalinux-9 ~]# git clone --recurse-submodules -j8 https://github.com/google/ngx_brotli
Клонирование в «ngx_brotli»...
remote: Enumerating objects: 237, done.
remote: Counting objects: 100% (72/72), done.
remote: Compressing objects: 100% (22/22), done.
remote: Total 237 (delta 55), reused 50 (delta 50), pack-reused 165 (from 1)
Получение объектов: 100% (237/237), 78.03 КиБ | 579.00 КиБ/с, готово.
Определение изменений: 100% (116/116), готово.
Подмодуль «deps/brotli» (https://github.com/google/brotli.git) зарегистрирован по пути «deps/brotli»
Клонирование в «/root/ngx_brotli/deps/brotli»...
remote: Enumerating objects: 9541, done.        
remote: Counting objects: 100% (205/205), done.        
remote: Compressing objects: 100% (117/117), done.        
remote: Total 9541 (delta 132), reused 89 (delta 88), pack-reused 9336 (from 3)        
Получение объектов: 100% (9541/9541), 41.89 МиБ | 5.19 МиБ/с, готово.
Определение изменений: 100% (6143/6143), готово.
Submodule path 'deps/brotli': checked out 'ed738e842d2fbdf2d6459e39267a633c4a9b2f5d'
[root@almalinux-9 ~]# 
```

3. Подготовка необходимых директорий, файла spec и компиляция модуля brotli, а затем компиляция и сборка основного пакета nginx с модулем brotli :

```
[root@almalinux-9 ~]# cd ngx_brotli/deps/brotli
[root@almalinux-9 brotli]# mkdir out && cd out
[root@almalinux-9 out]# cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_C_FLAGS="-Ofast -m64 -march=native \
 -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" -DCMAKE_CXX_FLAGS="-Ofast -m64 \
-march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" \
 -DCMAKE_INSTALL_PREFIX=./installed ..
-- The C compiler identification is GNU 11.5.0
-- Detecting C compiler ABI info
-- Detecting C compiler ABI info - done
-- Check for working C compiler: /usr/bin/cc - skipped
-- Detecting C compile features
-- Detecting C compile features - done
-- Build type is 'Release'
-- Performing Test BROTLI_EMSCRIPTEN
-- Performing Test BROTLI_EMSCRIPTEN - Failed
-- Compiler is not EMSCRIPTEN
-- Looking for log2
-- Looking for log2 - not found
-- Looking for log2
-- Looking for log2 - found
-- Configuring done (1.1s)
-- Generating done (0.0s)
CMake Warning:
  Manually-specified variables were not used by the project:

    CMAKE_CXX_FLAGS


-- Build files have been written to: /root/ngx_brotli/deps/brotli/out
[root@almalinux-9 out]# ll
итого 140
-rw-r--r--.  1 root root 17989 июл 29 15:02 CMakeCache.txt
drwxr-xr-x. 37 root root  4096 июл 29 15:02 CMakeFiles
-rw-r--r--.  1 root root  4478 июл 29 15:02 cmake_install.cmake
-rw-r--r--.  1 root root 39592 июл 29 15:02 CTestTestfile.cmake
-rw-r--r--.  1 root root  2510 июл 29 15:02 DartConfiguration.tcl
-rw-r--r--.  1 root root   336 июл 29 15:02 libbrotlicommon.pc
-rw-r--r--.  1 root root   363 июл 29 15:02 libbrotlidec.pc
-rw-r--r--.  1 root root   363 июл 29 15:02 libbrotlienc.pc
-rw-r--r--.  1 root root 52445 июл 29 15:02 Makefile
drwxr-xr-x.  3 root root    23 июл 29 15:02 Testing
[root@almalinux-9 out]# 
[root@almalinux-9 out]# cmake --build . --config Release -j 2 --target brotlienc
[  6%] Building C object CMakeFiles/brotlicommon.dir/c/common/constants.c.o
[  6%] Building C object CMakeFiles/brotlicommon.dir/c/common/context.c.o
[ 13%] Building C object CMakeFiles/brotlicommon.dir/c/common/dictionary.c.o
[ 13%] Building C object CMakeFiles/brotlicommon.dir/c/common/platform.c.o
<...>
[100%] Linking C static library libbrotlienc.a
[100%] Built target brotlienc
[root@almalinux-9 out]# ll
итого 2592
-rw-r--r--.  1 root root   17989 июл 29 15:02 CMakeCache.txt
drwxr-xr-x. 37 root root    4096 июл 29 15:02 CMakeFiles
-rw-r--r--.  1 root root    4478 июл 29 15:02 cmake_install.cmake
-rw-r--r--.  1 root root   39592 июл 29 15:02 CTestTestfile.cmake
-rw-r--r--.  1 root root    2510 июл 29 15:02 DartConfiguration.tcl
-rw-r--r--.  1 root root  124424 июл 29 15:02 libbrotlicommon.a
-rw-r--r--.  1 root root     336 июл 29 15:02 libbrotlicommon.pc
-rw-r--r--.  1 root root     363 июл 29 15:02 libbrotlidec.pc
-rw-r--r--.  1 root root 2383766 июл 29 15:02 libbrotlienc.a
-rw-r--r--.  1 root root     363 июл 29 15:02 libbrotlienc.pc
-rw-r--r--.  1 root root   52445 июл 29 15:02 Makefile
drwxr-xr-x.  3 root root      23 июл 29 15:02 Testing
[root@almalinux-9 out]# 
[root@almalinux-9 out]# cd ../../../..
[root@almalinux-9 ~]# find / -name spec
/usr/share/doc/rpm/spec
[root@almalinux-9 ~]# ll rpmbuild/SPECS
итого 52
-rw-r--r--. 1 root root 49189 июл  8 00:34 nginx.spec
[root@almalinux-9 ~]# vi rpmbuild/SPECS/nginx.spec
[root@almalinux-9 ~]# cat rpmbuild/SPECS/nginx.spec | grep add-module
    --add-module=/root/ngx_brotli \
[root@almalinux-9 ~]# 
[root@almalinux-9 ~]# cd ~/rpmbuild/SPECS/
[root@almalinux-9 SPECS]#
[root@almalinux-9 ~]# cd ~/rpmbuild/SPECS/
[root@almalinux-9 SPECS]# 
[root@almalinux-9 SPECS]# rpmbuild -ba nginx.spec -D 'debug_package %{nil}'
setting SOURCE_DATE_EPOCH=1783382400
Выполняется(%prep): /bin/sh -e /var/tmp/rpm-tmp.4WkgTr
+ umask 022
+ cd /root/rpmbuild/BUILD
<...>
perl(strict) perl(warnings)
Проверка на неупакованный(е) файл(ы): /usr/lib/rpm/check-files /root/rpmbuild/BUILDROOT/nginx-1.20.1-28.el9.4.alma.1.x86_64
Записан: /root/rpmbuild/SRPMS/nginx-1.20.1-28.el9.4.alma.1.src.rpm
Записан: /root/rpmbuild/RPMS/x86_64/nginx-core-1.20.1-28.el9.4.alma.1.x86_64.rpm
Записан: /root/rpmbuild/RPMS/x86_64/nginx-mod-stream-1.20.1-28.el9.4.alma.1.x86_64.rpm
Записан: /root/rpmbuild/RPMS/x86_64/nginx-1.20.1-28.el9.4.alma.1.x86_64.rpm
Записан: /root/rpmbuild/RPMS/x86_64/nginx-mod-mail-1.20.1-28.el9.4.alma.1.x86_64.rpm
Записан: /root/rpmbuild/RPMS/x86_64/nginx-mod-http-perl-1.20.1-28.el9.4.alma.1.x86_64.rpm
Записан: /root/rpmbuild/RPMS/x86_64/nginx-mod-http-image-filter-1.20.1-28.el9.4.alma.1.x86_64.rpm
Записан: /root/rpmbuild/RPMS/x86_64/nginx-mod-http-xslt-filter-1.20.1-28.el9.4.alma.1.x86_64.rpm
Записан: /root/rpmbuild/RPMS/noarch/nginx-filesystem-1.20.1-28.el9.4.alma.1.noarch.rpm
Записан: /root/rpmbuild/RPMS/noarch/nginx-all-modules-1.20.1-28.el9.4.alma.1.noarch.rpm
Записан: /root/rpmbuild/RPMS/x86_64/nginx-mod-devel-1.20.1-28.el9.4.alma.1.x86_64.rpm
Выполняется(%clean): /bin/sh -e /var/tmp/rpm-tmp.joKSXj
+ umask 022
+ cd /root/rpmbuild/BUILD
+ cd nginx-1.20.1
+ /usr/bin/rm -rf /root/rpmbuild/BUILDROOT/nginx-1.20.1-28.el9.4.alma.1.x86_64
+ RPM_EC=0
++ jobs -p
+ exit 0
[root@almalinux-9 SPECS]# 
[root@almalinux-9 SPECS]#
[root@almalinux-9 SPECS]# cd ~
[root@almalinux-9 ~]# ll rpmbuild/RPMS/x86_64/
итого 2020
-rw-r--r--. 1 root root   38286 июл 29 15:20 nginx-1.20.1-28.el9.4.alma.1.x86_64.rpm
-rw-r--r--. 1 root root 1033130 июл 29 15:20 nginx-core-1.20.1-28.el9.4.alma.1.x86_64.rpm
-rw-r--r--. 1 root root  763092 июл 29 15:20 nginx-mod-devel-1.20.1-28.el9.4.alma.1.x86_64.rpm
-rw-r--r--. 1 root root   21363 июл 29 15:20 nginx-mod-http-image-filter-1.20.1-28.el9.4.alma.1.x86_64.rpm
-rw-r--r--. 1 root root   32894 июл 29 15:20 nginx-mod-http-perl-1.20.1-28.el9.4.alma.1.x86_64.rpm
-rw-r--r--. 1 root root   20169 июл 29 15:20 nginx-mod-http-xslt-filter-1.20.1-28.el9.4.alma.1.x86_64.rpm
-rw-r--r--. 1 root root   55773 июл 29 15:20 nginx-mod-mail-1.20.1-28.el9.4.alma.1.x86_64.rpm
-rw-r--r--. 1 root root   82360 июл 29 15:20 nginx-mod-stream-1.20.1-28.el9.4.alma.1.x86_64.rpm
[root@almalinux-9 ~]# 
[root@almalinux-9 ~]# ~/rpmbuild/RPMS/noarch/*
-bash: /root/rpmbuild/RPMS/noarch/nginx-all-modules-1.20.1-28.el9.4.alma.1.noarch.rpm: Отказано в доступе
[root@almalinux-9 ~]# ll ~/rpmbuild/RPMS/noarch/*
-rw-r--r--. 1 root root  9377 июл 29 15:20 /root/rpmbuild/RPMS/noarch/nginx-all-modules-1.20.1-28.el9.4.alma.1.noarch.rpm
-rw-r--r--. 1 root root 10977 июл 29 15:20 /root/rpmbuild/RPMS/noarch/nginx-filesystem-1.20.1-28.el9.4.alma.1.noarch.rpm
[root@almalinux-9 ~]# 
[root@almalinux-9 ~]# cp ~/rpmbuild/RPMS/noarch/* ~/rpmbuild/RPMS/x86_64/
[root@almalinux-9 ~]# 
[root@almalinux-9 ~]# ll rpmbuild/RPMS/x86_64/
итого 2044
-rw-r--r--. 1 root root   38286 июл 29 15:20 nginx-1.20.1-28.el9.4.alma.1.x86_64.rpm
-rw-r--r--. 1 root root    9377 июл 29 15:23 nginx-all-modules-1.20.1-28.el9.4.alma.1.noarch.rpm
-rw-r--r--. 1 root root 1033130 июл 29 15:20 nginx-core-1.20.1-28.el9.4.alma.1.x86_64.rpm
-rw-r--r--. 1 root root   10977 июл 29 15:23 nginx-filesystem-1.20.1-28.el9.4.alma.1.noarch.rpm
-rw-r--r--. 1 root root  763092 июл 29 15:20 nginx-mod-devel-1.20.1-28.el9.4.alma.1.x86_64.rpm
-rw-r--r--. 1 root root   21363 июл 29 15:20 nginx-mod-http-image-filter-1.20.1-28.el9.4.alma.1.x86_64.rpm
-rw-r--r--. 1 root root   32894 июл 29 15:20 nginx-mod-http-perl-1.20.1-28.el9.4.alma.1.x86_64.rpm
-rw-r--r--. 1 root root   20169 июл 29 15:20 nginx-mod-http-xslt-filter-1.20.1-28.el9.4.alma.1.x86_64.rpm
-rw-r--r--. 1 root root   55773 июл 29 15:20 nginx-mod-mail-1.20.1-28.el9.4.alma.1.x86_64.rpm
-rw-r--r--. 1 root root   82360 июл 29 15:20 nginx-mod-stream-1.20.1-28.el9.4.alma.1.x86_64.rpm
[root@almalinux-9 ~]#
```

3. Установка собранного пакета в систему:

```
[root@almalinux-9 x86_64]# yum localinstall *.rpm
Последняя проверка окончания срока действия метаданных: 1:43:04 назад, Ср 29 июл 2026 13:44:09.
Зависимости разрешены.
============================================================================================================================================================
 Пакет                                          Архитектура               Версия                                      Репозиторий                     Размер
============================================================================================================================================================
Установка:
 nginx                                          x86_64                    2:1.20.1-28.el9.4.alma.1                    @commandline                     37 k
 nginx-all-modules                              noarch                    2:1.20.1-28.el9.4.alma.1                    @commandline                    9.2 k
 nginx-core                                     x86_64                    2:1.20.1-28.el9.4.alma.1                    @commandline                    1.0 M
 nginx-filesystem                               noarch                    2:1.20.1-28.el9.4.alma.1                    @commandline                     11 k
 nginx-mod-devel                                x86_64                    2:1.20.1-28.el9.4.alma.1                    @commandline                    745 k
 nginx-mod-http-image-filter                    x86_64                    2:1.20.1-28.el9.4.alma.1                    @commandline                     21 k
 nginx-mod-http-perl                            x86_64                    2:1.20.1-28.el9.4.alma.1                    @commandline                     32 k
 nginx-mod-http-xslt-filter                     x86_64                    2:1.20.1-28.el9.4.alma.1                    @commandline                     20 k
 nginx-mod-mail                                 x86_64                    2:1.20.1-28.el9.4.alma.1                    @commandline                     54 k
 nginx-mod-stream                               x86_64                    2:1.20.1-28.el9.4.alma.1                    @commandline                     80 k
Установка зависимостей:
 almalinux-logos-httpd                          noarch                    90.7-1.el9                                  appstream                        18 k

Результат транзакции
============================================================================================================================================================
Установка  11 Пакетов
<...>
Установлен:
  almalinux-logos-httpd-90.7-1.el9.noarch                                          nginx-2:1.20.1-28.el9.4.alma.1.x86_64                                   
  nginx-all-modules-2:1.20.1-28.el9.4.alma.1.noarch                                nginx-core-2:1.20.1-28.el9.4.alma.1.x86_64                              
  nginx-filesystem-2:1.20.1-28.el9.4.alma.1.noarch                                 nginx-mod-devel-2:1.20.1-28.el9.4.alma.1.x86_64                         
  nginx-mod-http-image-filter-2:1.20.1-28.el9.4.alma.1.x86_64                      nginx-mod-http-perl-2:1.20.1-28.el9.4.alma.1.x86_64                     
  nginx-mod-http-xslt-filter-2:1.20.1-28.el9.4.alma.1.x86_64                       nginx-mod-mail-2:1.20.1-28.el9.4.alma.1.x86_64                          
  nginx-mod-stream-2:1.20.1-28.el9.4.alma.1.x86_64                                

Выполнено!
```

4. Включаем и настраиваем установленный nginx, конфигурируем, создаём тестовый файл и проверяем работы компрессии brotli - компрессия работает:

```
[root@almalinux-9 x86_64]#  systemctl start nginx
[root@almalinux-9 x86_64]#  systemctl status nginx
● nginx.service - The nginx HTTP and reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; preset: disabled)
     Active: active (running) since Wed 2026-07-29 15:27:45 MSK; 3s ago
<...>
[root@almalinux-9 x86_64]# nginx -V
nginx version: nginx/1.20.1
built by gcc 11.5.0 20240719 (Red Hat 11.5.0-14) (GCC) 
built with OpenSSL 3.5.5 27 Jan 2026
TLS SNI support enabled
configure arguments: --prefix=/usr/share/nginx --sbin-path=/usr/sbin/nginx --modules-path=/usr/lib64/nginx/modules --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --http-client-body-temp-path=/var/lib/nginx/tmp/client_body --http-proxy-temp-path=/var/lib/nginx/tmp/proxy --http-fastcgi-temp-path=/var/lib/nginx/tmp/fastcgi --http-uwsgi-temp-path=/var/lib/nginx/tmp/uwsgi --http-scgi-temp-path=/var/lib/nginx/tmp/scgi --pid-path=/run/nginx.pid --lock-path=/run/lock/subsys/nginx --user=nginx --group=nginx --with-compat --with-debug --with-file-aio --with-http_addition_module --with-http_auth_request_module --with-http_dav_module --with-http_degradation_module --with-http_flv_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_image_filter_module=dynamic --with-http_mp4_module --with-http_perl_module=dynamic --with-http_random_index_module --with-http_realip_module --with-http_secure_link_module --with-http_slice_module --with-http_ssl_module --with-http_stub_status_module --with-http_sub_module --with-http_v2_module --with-http_xslt_module=dynamic --with-mail=dynamic --with-mail_ssl_module --with-pcre --with-pcre-jit --with-stream=dynamic --with-stream_ssl_module --with-stream_ssl_preread_module --with-threads --add-module=/root/ngx_brotli --with-cc-opt='-O2 -flto=auto -ffat-lto-objects -fexceptions -g -grecord-gcc-switches -pipe -Wall -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -Wp,-D_GLIBCXX_ASSERTIONS -specs=/usr/lib/rpm/redhat/redhat-hardened-cc1 -fstack-protector-strong -specs=/usr/lib/rpm/redhat/redhat-annobin-cc1 -m64 -march=x86-64-v2 -mtune=generic -fasynchronous-unwind-tables -fstack-clash-protection -fcf-protection' --with-ld-opt='-Wl,-z,relro -Wl,--as-needed -Wl,-z,now -specs=/usr/lib/rpm/redhat/redhat-hardened-ld -specs=/usr/lib/rpm/redhat/redhat-annobin-cc1 -Wl,-E'
[root@almalinux-9 x86_64]# 
[root@almalinux-9 x86_64]# 
[root@almalinux-9 x86_64]# 
[root@almalinux-9 x86_64]# echo "test brotli compression" > /usr/share/nginx/html/brotli-test.txt
[root@almalinux-9 x86_64]#
[root@almalinux-9 x86_64]#  systemctl cat nginx
# /usr/lib/systemd/system/nginx.service
[Unit]
Description=The nginx HTTP and reverse proxy server
After=network-online.target remote-fs.target nss-lookup.target
Wants=network-online.target

[Service]
Type=forking
PIDFile=/run/nginx.pid
# Nginx will fail to start if /run/nginx.pid already exists but has the wrong
# SELinux context. This might happen when running `nginx -t` from the cmdline.
# https://bugzilla.redhat.com/show_bug.cgi?id=1268621
ExecStartPre=/usr/bin/rm -f /run/nginx.pid
ExecStartPre=/usr/sbin/nginx -t
ExecStart=/usr/sbin/nginx
ExecReload=/usr/sbin/nginx -s reload
KillSignal=SIGQUIT
TimeoutStopSec=5
KillMode=mixed
PrivateTmp=true

[Install]
WantedBy=multi-user.target
[root@almalinux-9 x86_64]# 
[root@almalinux-9 x86_64]# vi /etc/nginx/nginx.conf
[root@almalinux-9 x86_64]#
[root@almalinux-9 x86_64]# cat /etc/nginx/nginx.conf
# For more information on configuration, see:
#   * Official English Documentation: http://nginx.org/en/docs/
#   * Official Russian Documentation: http://nginx.org/ru/docs/

user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

# Load dynamic modules. See /usr/share/doc/nginx/README.dynamic.
include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    # Включаем Brotli глобально
    brotli on;
    brotli_comp_level 6;  # 6 — хороший баланс скорость/сжатие (4 был для теста)
    
    # Явно указываем типы, которые хотим сжимать
    brotli_types
        text/plain
        text/css
        text/javascript
        application/javascript
        application/json
        application/xml
        font/ttf font/woff font/woff2;


    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 4096;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    # Load modular configuration files from the /etc/nginx/conf.d directory.
    # See http://nginx.org/en/docs/ngx_core_module.html#include
    # for more information.
    include /etc/nginx/conf.d/*.conf;

    server {
        listen       80;
        listen       [::]:80;
        server_name  _;
        root         /usr/share/nginx/html;
        
      	index index.html index.htm;

        # В корне сайта автоиндекс выключен (никакой директивы нет → значит off)
        location / {
            index index.html index.htm;
            # Если в / нет index.html, будет 403 Forbidden, а не список файлов
        }

        # А вот тут ты явно включаешь автоиндекс только для этой папки
        location /repo/ {
            autoindex on;
            autoindex_exact_size off;
        }

        # Load configuration files for the default server block.
        include /etc/nginx/default.d/*.conf;

        error_page 404 /404.html;
        location = /404.html {
        }

        error_page 500 502 503 504 /50x.html;
        location = /50x.html {
        }
    }
} 
[root@almalinux-9 x86_64]# 
[root@almalinux-9 x86_64]#  systemctl restart nginx
[root@almalinux-9 x86_64]# 
[root@almalinux-9 x86_64]# 
[root@almalinux-9 x86_64]#  systemctl status nginx
● nginx.service - The nginx HTTP and reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; preset: disabled)
     Active: active (running) since Wed 2026-07-29 15:38:15 MSK; 5s ago
    Process: 36770 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
<...>
[root@almalinux-9 x86_64]# grep -A 5 'server {' /etc/nginx/nginx.conf | grep root
        root         /usr/share/nginx/html;
[root@almalinux-9 x86_64]#
root@almalinux-9 x86_64]# nginx -t
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
[root@almalinux-9 x86_64]# 
[root@almalinux-9 x86_64]#  systemctl reload nginx
[root@almalinux-9 x86_64]# 
[root@almalinux-9 x86_64]# curl -v -H "Accept-Encoding: br" http://localhost/brotli-test-big.txt 2>&1 | grep -i 'x-brotli-big-test\|content-encoding'
< X-Brotli-Big-Test: YES
< Content-Encoding: br
[root@almalinux-9 x86_64]#
[root@almalinux-9 x86_64]# yes "test brotli static module — repeat this line many times to make the file large enough for compression" | head -n 1000 > /usr/share/nginx/html/brotli-test-big.txt
[root@almalinux-9 x86_64]#
[root@almalinux-9 x86_64]# nginx -t
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
[root@almalinux-9 x86_64]# 
[root@almalinux-9 x86_64]#  systemctl reload nginx
[root@almalinux-9 x86_64]# 
[root@almalinux-9 x86_64]# curl -H "Accept-Encoding: gzip,deflate" -o /dev/null -w "%{size_download}\n" http://localhost/brotli-test-big.txt
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100  101k  100  101k    0     0  11.0M      0 --:--:-- --:--:-- --:--:-- 11.0M
104000
[root@almalinux-9 x86_64]# curl -H "Accept-Encoding: br" -o /dev/null -w "%{size_download}\n" http://localhost/brotli-test-big.txt
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100    92    0    92    0     0  13142      0 --:--:-- --:--:-- --:--:-- 13142
92
[root@almalinux-9 x86_64]#
```

5. Создаём репозиторий для RPM-файлов, размещаем в нём файлы созданного пакета, разрешаем на firewall порт 80 для внешнего доступа к серверу nginx:

```
[root@almalinux-9 x86_64]# mkdir /usr/share/nginx/html/repo
[root@almalinux-9 x86_64]# cp ~/rpmbuild/RPMS/x86_64/*.rpm /usr/share/nginx/html/repo/
[root@almalinux-9 x86_64]# createrepo /usr/share/nginx/html/repo/
Directory walk started
Directory walk done - 10 packages
Temporary output repo path: /usr/share/nginx/html/repo/.repodata/
Preparing sqlite DBs
Pool started (with 5 workers)
Pool finished
[root@almalinux-9 x86_64]# 
[root@almalinux-9 x86_64]# vi /etc/nginx/nginx.conf
[root@almalinux-9 x86_64]# 
[root@almalinux-9 x86_64]# nginx -t
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
[root@almalinux-9 x86_64]# 
[root@almalinux-9 x86_64]#  systemctl reload nginx
[root@almalinux-9 x86_64]# 
[root@almalinux-9 x86_64]# cat /etc/nginx/nginx.conf
# For more information on configuration, see:
#   * Official English Documentation: http://nginx.org/en/docs/
#   * Official Russian Documentation: http://nginx.org/ru/docs/

user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

# Load dynamic modules. See /usr/share/doc/nginx/README.dynamic.
include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 4096;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    # Load modular configuration files from the /etc/nginx/conf.d directory.
    # See http://nginx.org/en/docs/ngx_core_module.html#include
    # for more information.
    include /etc/nginx/conf.d/*.conf;

    server {
        listen       80;
        listen       [::]:80;
        server_name  _;
        root         /usr/share/nginx/html;
        
      	index index.html index.htm;
	autoindex on;



        # Твой тестовый location
        location /brotli-test.txt {
            brotli on;
            brotli_comp_level 4;
            # add_header X-Brotli-Test "YES";
            # add_header Content-Encoding br;  <-- эту строку лучше УДАЛИТЬ (см. пояснение ниже)
        }


        location = /brotli-test-big.txt {
            brotli on;
            brotli_comp_level 4;
            brotli_types text/plain;
            # add_header X-Brotli-Big-Test "YES";
        }


        # Load configuration files for the default server block.
        include /etc/nginx/default.d/*.conf;

        error_page 404 /404.html;
        location = /404.html {
        }

        error_page 500 502 503 504 /50x.html;
        location = /50x.html {
        }
    }
}

[root@almalinux-9 x86_64]# 
[root@almalinux-9 x86_64]# curl -a http://localhost/repo/
<html>
<head><title>Index of /repo/</title></head>
<body>
<h1>Index of /repo/</h1><hr><pre><a href="../">../</a>
<a href="repodata/">repodata/</a>                                          29-Jul-2026 12:51                   -
<a href="nginx-1.20.1-28.el9.4.alma.1.x86_64.rpm">nginx-1.20.1-28.el9.4.alma.1.x86_64.rpm</a>            29-Jul-2026 12:51               38286
<a href="nginx-all-modules-1.20.1-28.el9.4.alma.1.noarch.rpm">nginx-all-modules-1.20.1-28.el9.4.alma.1.noarch..&gt;</a> 29-Jul-2026 12:51                9377
<a href="nginx-core-1.20.1-28.el9.4.alma.1.x86_64.rpm">nginx-core-1.20.1-28.el9.4.alma.1.x86_64.rpm</a>       29-Jul-2026 12:51             1033130
<a href="nginx-filesystem-1.20.1-28.el9.4.alma.1.noarch.rpm">nginx-filesystem-1.20.1-28.el9.4.alma.1.noarch.rpm</a> 29-Jul-2026 12:51               10977
<a href="nginx-mod-devel-1.20.1-28.el9.4.alma.1.x86_64.rpm">nginx-mod-devel-1.20.1-28.el9.4.alma.1.x86_64.rpm</a>  29-Jul-2026 12:51              763092
<a href="nginx-mod-http-image-filter-1.20.1-28.el9.4.alma.1.x86_64.rpm">nginx-mod-http-image-filter-1.20.1-28.el9.4.alm..&gt;</a> 29-Jul-2026 12:51               21363
<a href="nginx-mod-http-perl-1.20.1-28.el9.4.alma.1.x86_64.rpm">nginx-mod-http-perl-1.20.1-28.el9.4.alma.1.x86_..&gt;</a> 29-Jul-2026 12:51               32894
<a href="nginx-mod-http-xslt-filter-1.20.1-28.el9.4.alma.1.x86_64.rpm">nginx-mod-http-xslt-filter-1.20.1-28.el9.4.alma..&gt;</a> 29-Jul-2026 12:51               20169
<a href="nginx-mod-mail-1.20.1-28.el9.4.alma.1.x86_64.rpm">nginx-mod-mail-1.20.1-28.el9.4.alma.1.x86_64.rpm</a>   29-Jul-2026 12:51               55773
<a href="nginx-mod-stream-1.20.1-28.el9.4.alma.1.x86_64.rpm">nginx-mod-stream-1.20.1-28.el9.4.alma.1.x86_64.rpm</a> 29-Jul-2026 12:51               82360
</pre><hr></body>
</html>
[root@almalinux-9 x86_64]# ss -tlnp
State    Recv-Q   Send-Q     Local Address:Port     Peer Address:Port  Process                                                                              
LISTEN   0        511              0.0.0.0:80            0.0.0.0:*      users:(("nginx",pid=36873,fd=6),("nginx",pid=36872,fd=6),("nginx",pid=36774,fd=6))  
LISTEN   0        128              0.0.0.0:22            0.0.0.0:*      users:(("sshd",pid=921,fd=7))                                                       
LISTEN   0        4096           127.0.0.1:631           0.0.0.0:*      users:(("cupsd",pid=920,fd=8))                                                      
LISTEN   0        4096               [::1]:631              [::]:*      users:(("cupsd",pid=920,fd=7))                                                      
LISTEN   0        511                 [::]:80               [::]:*      users:(("nginx",pid=36873,fd=7),("nginx",pid=36872,fd=7),("nginx",pid=36774,fd=7))  
LISTEN   0        128                 [::]:22               [::]:*      users:(("sshd",pid=921,fd=8))                                                       
[root@almalinux-9 x86_64]# 
[root@almalinux-9 x86_64]#
[root@almalinux-9 x86_64]# ll /usr/share/nginx/html
итого 124
-rw-r--r--. 1 root root   3806 июл  8 00:33 404.html
-rw-r--r--. 1 root root   3849 июл  8 00:33 50x.html
-rw-r--r--. 1 root root 104000 июл 29 15:45 brotli-test-big.txt
-rw-r--r--. 1 root root     24 июл 29 15:32 brotli-test.txt
drwxr-xr-x. 2 root root     27 июл 29 15:27 icons
lrwxrwxrwx. 1 root root     25 июл 29 15:20 index.html -> ../../testpage/index.html
-rw-r--r--. 1 root root    368 июл  8 00:33 nginx-logo.png
lrwxrwxrwx. 1 root root     14 июл 29 15:20 poweredby.png -> nginx-logo.png
drwxr-xr-x. 3 root root   4096 июл 29 15:51 repo
lrwxrwxrwx. 1 root root     37 июл 29 15:20 system_noindex_logo.png -> ../../pixmaps/system-noindex-logo.png
[root@almalinux-9 x86_64]# 
[root@almalinux-9 x86_64]# 
[root@almalinux-9 x86_64]# ifconfig
enp1s0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 192.168.122.178  netmask 255.255.255.0  broadcast 192.168.122.255
        inet6 fe80::5054:ff:fedb:f5e8  prefixlen 64  scopeid 0x20<link>
        ether 52:54:00:db:f5:e8  txqueuelen 1000  (Ethernet)
        RX packets 127062  bytes 146768617 (139.9 MiB)
        RX errors 0  dropped 5136  overruns 0  frame 0
        TX packets 82552  bytes 7289013 (6.9 MiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
        inet 127.0.0.1  netmask 255.0.0.0
        inet6 ::1  prefixlen 128  scopeid 0x10<host>
        loop  txqueuelen 1000  (Local Loopback)
        RX packets 97  bytes 116294 (113.5 KiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 97  bytes 116294 (113.5 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

[root@almalinux-9 x86_64]# 
[root@almalinux-9 x86_64]# 

 
[root@almalinux-9 x86_64]# firewall-cmd --state
running
[root@almalinux-9 x86_64]# 
[root@almalinux-9 x86_64]# firewall-cmd --list-all
public (active)
  target: default
  icmp-block-inversion: no
  interfaces: enp1s0
  sources: 
  services: cockpit dhcpv6-client ssh
  ports: 
  protocols: 
  forward: yes
  masquerade: no
  forward-ports: 
  source-ports: 
  icmp-blocks: 
  rich rules: 
[root@almalinux-9 x86_64]# firewall-cmd --add-service=http --permanent
success
[root@almalinux-9 x86_64]# firewall-cmd --reload
success
[root@almalinux-9 x86_64]# 
[root@almalinux-9 x86_64]# firewall-cmd --list-all
public (active)
  target: default
  icmp-block-inversion: no
  interfaces: enp1s0
  sources: 
  services: cockpit dhcpv6-client http ssh
  ports: 
  protocols: 
  forward: yes
  masquerade: no
  forward-ports: 
  source-ports: 
  icmp-blocks: 
  rich rules: 
[root@almalinux-9 x86_64]#
[root@almalinux-9 x86_64]# cat /etc/nginx/nginx.conf
# For more information on configuration, see:
#   * Official English Documentation: http://nginx.org/en/docs/
#   * Official Russian Documentation: http://nginx.org/ru/docs/

user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

# Load dynamic modules. See /usr/share/doc/nginx/README.dynamic.
include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    # Включаем Brotli глобально
    brotli on;
    brotli_comp_level 6;  # 6 — хороший баланс скорость/сжатие (4 был для теста)
    
    # Явно указываем типы, которые хотим сжимать
    brotli_types
        text/plain
        text/css
        text/javascript
        application/javascript
        application/json
        application/xml
        font/ttf font/woff font/woff2;


    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 4096;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    # Load modular configuration files from the /etc/nginx/conf.d directory.
    # See http://nginx.org/en/docs/ngx_core_module.html#include
    # for more information.
    include /etc/nginx/conf.d/*.conf;

    server {
        listen       80;
        listen       [::]:80;
        server_name  _;
        root         /usr/share/nginx/html;
        
      	index index.html index.htm;
	    autoindex on;



        # Load configuration files for the default server block.
        include /etc/nginx/default.d/*.conf;

        error_page 404 /404.html;
        location = /404.html {
        }

        error_page 500 502 503 504 /50x.html;
        location = /50x.html {
        }
    }
}
```

После этого на клиентской машине в броузере видно содержимое созданного репозитория:

<img width="953" height="502" alt="изображение" src="https://github.com/user-attachments/assets/49b09801-7375-4fcb-ab46-ec9026b9c37c" />

```
[root@mv334 vm]# curl -a http://192.168.122.178/repo/
<html>
<head><title>Index of /repo/</title></head>
<body>
<h1>Index of /repo/</h1><hr><pre><a href="../">../</a>
<a href="repodata/">repodata/</a>                                          29-Jul-2026 12:51                   -
<a href="nginx-1.20.1-28.el9.4.alma.1.x86_64.rpm">nginx-1.20.1-28.el9.4.alma.1.x86_64.rpm</a>            29-Jul-2026 12:51               38286
<a href="nginx-all-modules-1.20.1-28.el9.4.alma.1.noarch.rpm">nginx-all-modules-1.20.1-28.el9.4.alma.1.noarch..&gt;</a> 29-Jul-2026 12:51                9377
<a href="nginx-core-1.20.1-28.el9.4.alma.1.x86_64.rpm">nginx-core-1.20.1-28.el9.4.alma.1.x86_64.rpm</a>       29-Jul-2026 12:51             1033130
<a href="nginx-filesystem-1.20.1-28.el9.4.alma.1.noarch.rpm">nginx-filesystem-1.20.1-28.el9.4.alma.1.noarch.rpm</a> 29-Jul-2026 12:51               10977
<a href="nginx-mod-devel-1.20.1-28.el9.4.alma.1.x86_64.rpm">nginx-mod-devel-1.20.1-28.el9.4.alma.1.x86_64.rpm</a>  29-Jul-2026 12:51              763092
<a href="nginx-mod-http-image-filter-1.20.1-28.el9.4.alma.1.x86_64.rpm">nginx-mod-http-image-filter-1.20.1-28.el9.4.alm..&gt;</a> 29-Jul-2026 12:51               21363
<a href="nginx-mod-http-perl-1.20.1-28.el9.4.alma.1.x86_64.rpm">nginx-mod-http-perl-1.20.1-28.el9.4.alma.1.x86_..&gt;</a> 29-Jul-2026 12:51               32894
<a href="nginx-mod-http-xslt-filter-1.20.1-28.el9.4.alma.1.x86_64.rpm">nginx-mod-http-xslt-filter-1.20.1-28.el9.4.alma..&gt;</a> 29-Jul-2026 12:51               20169
<a href="nginx-mod-mail-1.20.1-28.el9.4.alma.1.x86_64.rpm">nginx-mod-mail-1.20.1-28.el9.4.alma.1.x86_64.rpm</a>   29-Jul-2026 12:51               55773
<a href="nginx-mod-stream-1.20.1-28.el9.4.alma.1.x86_64.rpm">nginx-mod-stream-1.20.1-28.el9.4.alma.1.x86_64.rpm</a> 29-Jul-2026 12:51               82360
</pre><hr></body>
</html>
[root@mv334 vm]#
```

6. На клиентской машине (та же самая машина, на которой расположен репозиторий) подключаем репозиторий двумя способами: по http://
с использованием сконфигурированного сервера nginx и как локальный репозиторий через file:// - пакет nginx после этого виден
в обоих подключенных репозиториях. Для простоты пакеты в репозитории не подписывались, поэтому оба репозитория подключены с опцией gpgcheck=0


```
[root@almalinux-9 x86_64]# dnf repolist
идентификатор репозитория                                                      имя репозитория
appstream                                                                      AlmaLinux 9 - AppStream
baseos                                                                         AlmaLinux 9 - BaseOS
extras                                                                         AlmaLinux 9 - Extras
[root@almalinux-9 x86_64]# 
[root@almalinux-9 x86_64]# sudo tee /etc/yum.repos.d/my-repo.repo > /dev/null <<EOF
[my-repo]
name=My Custom Repo
baseurl=http://localhost/repo/
enabled=1
gpgcheck=0
EOF
[root@almalinux-9 x86_64]# 
[root@almalinux-9 x86_64]# dnf repolist
идентификатор репозитория                                                      имя репозитория
appstream                                                                      AlmaLinux 9 - AppStream
baseos                                                                         AlmaLinux 9 - BaseOS
extras                                                                         AlmaLinux 9 - Extras
my-repo                                                                        My Custom Repo
[root@almalinux-9 x86_64]# 
[root@almalinux-9 x86_64]# pwd
/root/rpmbuild/RPMS/x86_64
[root@almalinux-9 x86_64]# ll
итого 2044
-rw-r--r--. 1 root root   38286 июл 29 15:20 nginx-1.20.1-28.el9.4.alma.1.x86_64.rpm
-rw-r--r--. 1 root root    9377 июл 29 15:23 nginx-all-modules-1.20.1-28.el9.4.alma.1.noarch.rpm
-rw-r--r--. 1 root root 1033130 июл 29 15:20 nginx-core-1.20.1-28.el9.4.alma.1.x86_64.rpm
-rw-r--r--. 1 root root   10977 июл 29 15:23 nginx-filesystem-1.20.1-28.el9.4.alma.1.noarch.rpm
-rw-r--r--. 1 root root  763092 июл 29 15:20 nginx-mod-devel-1.20.1-28.el9.4.alma.1.x86_64.rpm
-rw-r--r--. 1 root root   21363 июл 29 15:20 nginx-mod-http-image-filter-1.20.1-28.el9.4.alma.1.x86_64.rpm
-rw-r--r--. 1 root root   32894 июл 29 15:20 nginx-mod-http-perl-1.20.1-28.el9.4.alma.1.x86_64.rpm
-rw-r--r--. 1 root root   20169 июл 29 15:20 nginx-mod-http-xslt-filter-1.20.1-28.el9.4.alma.1.x86_64.rpm
-rw-r--r--. 1 root root   55773 июл 29 15:20 nginx-mod-mail-1.20.1-28.el9.4.alma.1.x86_64.rpm
-rw-r--r--. 1 root root   82360 июл 29 15:20 nginx-mod-stream-1.20.1-28.el9.4.alma.1.x86_64.rpm
[root@almalinux-9 x86_64]#
[root@almalinux-9 x86_64]# dnf list --showduplicates | grep -i nginx
nginx.x86_64                                         2:1.20.1-28.el9.4.alma.1              @@commandline
nginx-all-modules.noarch                             2:1.20.1-28.el9.4.alma.1              @@commandline
nginx-core.x86_64                                    2:1.20.1-28.el9.4.alma.1              @@commandline
nginx-filesystem.noarch                              2:1.20.1-28.el9.4.alma.1              @@commandline
nginx-mod-devel.x86_64                               2:1.20.1-28.el9.4.alma.1              @@commandline
nginx-mod-http-image-filter.x86_64                   2:1.20.1-28.el9.4.alma.1              @@commandline
nginx-mod-http-perl.x86_64                           2:1.20.1-28.el9.4.alma.1              @@commandline
nginx-mod-http-xslt-filter.x86_64                    2:1.20.1-28.el9.4.alma.1              @@commandline
nginx-mod-mail.x86_64                                2:1.20.1-28.el9.4.alma.1              @@commandline
nginx-mod-stream.x86_64                              2:1.20.1-28.el9.4.alma.1              @@commandline
nginx.x86_64                                         2:1.20.1-28.el9.4.alma.1              my-repo      
nginx.x86_64                                         2:1.20.1-28.el9_8.2.alma.1            appstream    
nginx.x86_64                                         2:1.20.1-28.el9_8.3.alma.1            appstream    
nginx.x86_64                                         2:1.20.1-28.el9_8.4.alma.1            appstream    
nginx-all-modules.noarch                             2:1.20.1-28.el9.4.alma.1              my-repo      
nginx-all-modules.noarch                             2:1.20.1-28.el9_8.2.alma.1            appstream    
nginx-all-modules.noarch                             2:1.20.1-28.el9_8.3.alma.1            appstream    
nginx-all-modules.noarch                             2:1.20.1-28.el9_8.4.alma.1            appstream    
nginx-core.x86_64                                    2:1.20.1-28.el9.4.alma.1              my-repo      
nginx-core.x86_64                                    2:1.20.1-28.el9_8.2.alma.1            appstream    
nginx-core.x86_64                                    2:1.20.1-28.el9_8.3.alma.1            appstream    
nginx-core.x86_64                                    2:1.20.1-28.el9_8.4.alma.1            appstream    
nginx-filesystem.noarch                              2:1.20.1-28.el9.4.alma.1              my-repo      
nginx-filesystem.noarch                              2:1.20.1-28.el9_8.2.alma.1            appstream    
nginx-filesystem.noarch                              2:1.20.1-28.el9_8.3.alma.1            appstream    
nginx-filesystem.noarch                              2:1.20.1-28.el9_8.4.alma.1            appstream    
nginx-mod-devel.x86_64                               2:1.20.1-28.el9.4.alma.1              my-repo      
nginx-mod-http-image-filter.x86_64                   2:1.20.1-28.el9.4.alma.1              my-repo      
nginx-mod-http-image-filter.x86_64                   2:1.20.1-28.el9_8.2.alma.1            appstream    
nginx-mod-http-image-filter.x86_64                   2:1.20.1-28.el9_8.3.alma.1            appstream    
nginx-mod-http-image-filter.x86_64                   2:1.20.1-28.el9_8.4.alma.1            appstream    
nginx-mod-http-perl.x86_64                           2:1.20.1-28.el9.4.alma.1              my-repo      
nginx-mod-http-perl.x86_64                           2:1.20.1-28.el9_8.2.alma.1            appstream    
nginx-mod-http-perl.x86_64                           2:1.20.1-28.el9_8.3.alma.1            appstream    
nginx-mod-http-perl.x86_64                           2:1.20.1-28.el9_8.4.alma.1            appstream    
nginx-mod-http-xslt-filter.x86_64                    2:1.20.1-28.el9.4.alma.1              my-repo      
nginx-mod-http-xslt-filter.x86_64                    2:1.20.1-28.el9_8.2.alma.1            appstream    
nginx-mod-http-xslt-filter.x86_64                    2:1.20.1-28.el9_8.3.alma.1            appstream    
nginx-mod-http-xslt-filter.x86_64                    2:1.20.1-28.el9_8.4.alma.1            appstream    
nginx-mod-mail.x86_64                                2:1.20.1-28.el9.4.alma.1              my-repo      
nginx-mod-mail.x86_64                                2:1.20.1-28.el9_8.2.alma.1            appstream    
nginx-mod-mail.x86_64                                2:1.20.1-28.el9_8.3.alma.1            appstream    
nginx-mod-mail.x86_64                                2:1.20.1-28.el9_8.4.alma.1            appstream    
nginx-mod-stream.x86_64                              2:1.20.1-28.el9.4.alma.1              my-repo      
nginx-mod-stream.x86_64                              2:1.20.1-28.el9_8.2.alma.1            appstream    
nginx-mod-stream.x86_64                              2:1.20.1-28.el9_8.3.alma.1            appstream    
nginx-mod-stream.x86_64                              2:1.20.1-28.el9_8.4.alma.1            appstream    
pcp-pmda-nginx.x86_64                                6.3.7-8.el9_8                         appstream    
[root@almalinux-9 x86_64]# 
[root@almalinux-9 x86_64]# 
[root@almalinux-9 x86_64]# dnf list --showduplicates | grep -i nginx | grep -i my-repo
nginx.x86_64                                         2:1.20.1-28.el9.4.alma.1              my-repo      
nginx-all-modules.noarch                             2:1.20.1-28.el9.4.alma.1              my-repo      
nginx-core.x86_64                                    2:1.20.1-28.el9.4.alma.1              my-repo      
nginx-filesystem.noarch                              2:1.20.1-28.el9.4.alma.1              my-repo      
nginx-mod-devel.x86_64                               2:1.20.1-28.el9.4.alma.1              my-repo      
nginx-mod-http-image-filter.x86_64                   2:1.20.1-28.el9.4.alma.1              my-repo      
nginx-mod-http-perl.x86_64                           2:1.20.1-28.el9.4.alma.1              my-repo      
nginx-mod-http-xslt-filter.x86_64                    2:1.20.1-28.el9.4.alma.1              my-repo      
nginx-mod-mail.x86_64                                2:1.20.1-28.el9.4.alma.1              my-repo      
nginx-mod-stream.x86_64                              2:1.20.1-28.el9.4.alma.1              my-repo      
[root@almalinux-9 x86_64]# 

[root@almalinux-9 x86_64]# sudo tee /etc/yum.repos.d/my-local-repo.repo > /dev/null <<EOF
[my-repo-local]
name=My Local Custom Repo
baseurl=file:///usr/share/nginx/html/repo/
enabled=1
gpgcheck=0
EOF       
[root@almalinux-9 x86_64]# dnf repolist
идентификатор репозитория                                                      имя репозитория
appstream                                                                      AlmaLinux 9 - AppStream
baseos                                                                         AlmaLinux 9 - BaseOS
extras                                                                         AlmaLinux 9 - Extras
my-repo                                                                        My Custom Repo
my-repo-local                                                                  My Local Custom Repo
[root@almalinux-9 x86_64]# dnf list --showduplicates | grep -i nginx
nginx.x86_64                                         2:1.20.1-28.el9.4.alma.1              @@commandline
nginx-all-modules.noarch                             2:1.20.1-28.el9.4.alma.1              @@commandline
nginx-core.x86_64                                    2:1.20.1-28.el9.4.alma.1              @@commandline
nginx-filesystem.noarch                              2:1.20.1-28.el9.4.alma.1              @@commandline
nginx-mod-devel.x86_64                               2:1.20.1-28.el9.4.alma.1              @@commandline
nginx-mod-http-image-filter.x86_64                   2:1.20.1-28.el9.4.alma.1              @@commandline
nginx-mod-http-perl.x86_64                           2:1.20.1-28.el9.4.alma.1              @@commandline
nginx-mod-http-xslt-filter.x86_64                    2:1.20.1-28.el9.4.alma.1              @@commandline
nginx-mod-mail.x86_64                                2:1.20.1-28.el9.4.alma.1              @@commandline
nginx-mod-stream.x86_64                              2:1.20.1-28.el9.4.alma.1              @@commandline
nginx.x86_64                                         2:1.20.1-28.el9.4.alma.1              my-repo-local
nginx.x86_64                                         2:1.20.1-28.el9.4.alma.1              my-repo      
nginx.x86_64                                         2:1.20.1-28.el9_8.2.alma.1            appstream    
nginx.x86_64                                         2:1.20.1-28.el9_8.3.alma.1            appstream    
nginx.x86_64                                         2:1.20.1-28.el9_8.4.alma.1            appstream    
nginx-all-modules.noarch                             2:1.20.1-28.el9.4.alma.1              my-repo-local
nginx-all-modules.noarch                             2:1.20.1-28.el9.4.alma.1              my-repo      
nginx-all-modules.noarch                             2:1.20.1-28.el9_8.2.alma.1            appstream    
nginx-all-modules.noarch                             2:1.20.1-28.el9_8.3.alma.1            appstream    
nginx-all-modules.noarch                             2:1.20.1-28.el9_8.4.alma.1            appstream    
nginx-core.x86_64                                    2:1.20.1-28.el9.4.alma.1              my-repo-local
nginx-core.x86_64                                    2:1.20.1-28.el9.4.alma.1              my-repo      
nginx-core.x86_64                                    2:1.20.1-28.el9_8.2.alma.1            appstream    
nginx-core.x86_64                                    2:1.20.1-28.el9_8.3.alma.1            appstream    
nginx-core.x86_64                                    2:1.20.1-28.el9_8.4.alma.1            appstream    
nginx-filesystem.noarch                              2:1.20.1-28.el9.4.alma.1              my-repo-local
nginx-filesystem.noarch                              2:1.20.1-28.el9.4.alma.1              my-repo      
nginx-filesystem.noarch                              2:1.20.1-28.el9_8.2.alma.1            appstream    
nginx-filesystem.noarch                              2:1.20.1-28.el9_8.3.alma.1            appstream    
nginx-filesystem.noarch                              2:1.20.1-28.el9_8.4.alma.1            appstream    
nginx-mod-devel.x86_64                               2:1.20.1-28.el9.4.alma.1              my-repo-local
nginx-mod-devel.x86_64                               2:1.20.1-28.el9.4.alma.1              my-repo      
nginx-mod-http-image-filter.x86_64                   2:1.20.1-28.el9.4.alma.1              my-repo-local
nginx-mod-http-image-filter.x86_64                   2:1.20.1-28.el9.4.alma.1              my-repo      
nginx-mod-http-image-filter.x86_64                   2:1.20.1-28.el9_8.2.alma.1            appstream    
nginx-mod-http-image-filter.x86_64                   2:1.20.1-28.el9_8.3.alma.1            appstream    
nginx-mod-http-image-filter.x86_64                   2:1.20.1-28.el9_8.4.alma.1            appstream    
nginx-mod-http-perl.x86_64                           2:1.20.1-28.el9.4.alma.1              my-repo-local
nginx-mod-http-perl.x86_64                           2:1.20.1-28.el9.4.alma.1              my-repo      
nginx-mod-http-perl.x86_64                           2:1.20.1-28.el9_8.2.alma.1            appstream    
nginx-mod-http-perl.x86_64                           2:1.20.1-28.el9_8.3.alma.1            appstream    
nginx-mod-http-perl.x86_64                           2:1.20.1-28.el9_8.4.alma.1            appstream    
nginx-mod-http-xslt-filter.x86_64                    2:1.20.1-28.el9.4.alma.1              my-repo-local
nginx-mod-http-xslt-filter.x86_64                    2:1.20.1-28.el9.4.alma.1              my-repo      
nginx-mod-http-xslt-filter.x86_64                    2:1.20.1-28.el9_8.2.alma.1            appstream    
nginx-mod-http-xslt-filter.x86_64                    2:1.20.1-28.el9_8.3.alma.1            appstream    
nginx-mod-http-xslt-filter.x86_64                    2:1.20.1-28.el9_8.4.alma.1            appstream    
nginx-mod-mail.x86_64                                2:1.20.1-28.el9.4.alma.1              my-repo-local
nginx-mod-mail.x86_64                                2:1.20.1-28.el9.4.alma.1              my-repo      
nginx-mod-mail.x86_64                                2:1.20.1-28.el9_8.2.alma.1            appstream    
nginx-mod-mail.x86_64                                2:1.20.1-28.el9_8.3.alma.1            appstream    
nginx-mod-mail.x86_64                                2:1.20.1-28.el9_8.4.alma.1            appstream    
nginx-mod-stream.x86_64                              2:1.20.1-28.el9.4.alma.1              my-repo-local
nginx-mod-stream.x86_64                              2:1.20.1-28.el9.4.alma.1              my-repo      
nginx-mod-stream.x86_64                              2:1.20.1-28.el9_8.2.alma.1            appstream    
nginx-mod-stream.x86_64                              2:1.20.1-28.el9_8.3.alma.1            appstream    
nginx-mod-stream.x86_64                              2:1.20.1-28.el9_8.4.alma.1            appstream    
pcp-pmda-nginx.x86_64                                6.3.7-8.el9_8                         appstream    
[root@almalinux-9 x86_64]# 
[root@almalinux-9 x86_64]# 
[root@almalinux-9 x86_64]# dnf list --showduplicates | grep -i nginx | grep -i my-repo-local
nginx.x86_64                                         2:1.20.1-28.el9.4.alma.1              my-repo-local
nginx-all-modules.noarch                             2:1.20.1-28.el9.4.alma.1              my-repo-local
nginx-core.x86_64                                    2:1.20.1-28.el9.4.alma.1              my-repo-local
nginx-filesystem.noarch                              2:1.20.1-28.el9.4.alma.1              my-repo-local
nginx-mod-devel.x86_64                               2:1.20.1-28.el9.4.alma.1              my-repo-local
nginx-mod-http-image-filter.x86_64                   2:1.20.1-28.el9.4.alma.1              my-repo-local
nginx-mod-http-perl.x86_64                           2:1.20.1-28.el9.4.alma.1              my-repo-local
nginx-mod-http-xslt-filter.x86_64                    2:1.20.1-28.el9.4.alma.1              my-repo-local
nginx-mod-mail.x86_64                                2:1.20.1-28.el9.4.alma.1              my-repo-local
nginx-mod-stream.x86_64                              2:1.20.1-28.el9.4.alma.1              my-repo-local
[root@almalinux-9 x86_64]# 
```



# 2. Работа с пакетом DEB и с репозиторием пакетов APT/DEB в  ОС Ubuntu 24.04 (APT/DPKG-based): 

Данный пункт выполнялся путём проб и ошибок с использованием поиска в Интернет и рекомендаций Яндекс ИИ, цель была собрать рабочий пакет
и проверить его работу. 


### Примечание:
Сборка DEB-пакета в данном варианте была осложнена внесёнными в пакет изменениями при добавлении модуля Brontli, с помощью стандартной утилиты debuild DEB-пакет собрать не удалось. DEB-пакет с ограниченными возможностями (например, не создающий настройки systemctl при установке) удалось создать с помощью утилиты fpm (которая собирает DEB-пакет из директорий установленного пакета).
Стандартный полноценный DEB-пакет с помощью стандартной утилиты debuild удалось создать из исходников сервера nginx без дополнительных модулей и изменений в следующем пункте 2.1.


### При компиляции и сборке пакета DEB использовалась следующая информация:

В качестве исходников для компиляции и сборки пакета DEB используется пакет source для ngnix.
При его скачивании на компьютер скачиваются три файла:

| Файл      | Что содержит      | Для чего нужен       | 
|:---------------------------------------|:---------------|:-------------------------|
| nginx_1.24.0.orig.tar.gz              | Чистый код от nginx от разработчиков пакета        | Исходная база для сборки          |
| nginx_<версия>-<ревизия>.debian.tar.xz               | Директория debian/ (control, rules, патчи и т.д.)        | Упаковка под Ubuntu/Debian          |
| nginx_<версия>-<ревизия>.dsc               | Метаданные и контрольные суммы        | Проверка целостности и подпись         |


Вся информация по компиляции, сборке и установке пакета содержится в директории debian/ архива *.tar.xz ,
Для правильной компиляции и сборки необходимо обязательно правильно сформировать файлы debian/control , debian/rules , debian/changelog 
(например, в файл debian/rules необходимо добавить информацию о добавлении дополнительного модуля).
Директорию debian/ необходимо обязательно создать и заполнить правильными файлами перед началом компиляции и сборки пакета DEB.
Создать директорию debian/ можно создать либо утилитой dh_make (но тогда затем её нужно полностью самостоятельно заполнять необходимыми
файлами с правильным содержимым), либо вытащить уже готовую директорию debian/ из какого-либо уже собранного пакета DEB и затем использовать её в качестве
образца для правок.

Допустим, ты хочешь собрать nginx с теми же флагами, что и раньше, но на базе официального пакета Ubuntu. Ты делаешь так:

- Скачиваешь исходники через apt source nginx.

- Распаковываешь debian.tar.xz внутрь папки с upstream‑кодом.

- Правишь только debian/rules:

```
    override_dh_auto_configure:
     ./configure --prefix=/usr \
       --sbin-path=/usr/sbin/nginx \
       --conf-path=/etc/nginx/nginx.conf \
       --error-log-path=/var/log/nginx/error.log \
       --http-log-path=/var/log/nginx/access.log \
       --with-http_ssl_module \
       --with-pcre
```

Меняешь (если нужно) debian/changelog, чтобы не конфликтовать с версией Ubuntu (можно добавить свой суффикс, например 1.24.0-2ubuntu7.15+custom1).

Запускаешь debuild -us -uc -b из папки nginx-<версия>.

И всё: зависимости, пути, systemd, совместимость — уже сделаны мейнтейнерами Ubuntu, а ты контролируешь только сборку и флаги.

Также для успешной компиляции и сборки требуется заполнение файлов debian/compat , debian/install 


### При создании репозитория Debian использовалась следующая информация:

1) Структура репозиториев Debian (APT/DPKG-based) и работа с ними хорошо описана в статье

"Добавление репозитория в Debian, примеры sources.list" по ссылке  https://serveradmin.ru/nastrojka-repozitoriev-v-debian/ 


2) Создание репозиториев Debian (APT/DPKG-based) с помощью различных утилит, в зависимости от выполняемых задач, хорошо описано в статье

"Creating a Local APT Repository on Linux" по ссылке  https://www.baeldung.com/linux/apt-set-up-make-local-repository 



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
```

2. Получение пакетов исходников для сервера nginx и модуля Brontli

```
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
```

3. Установка зависимостей и окружения для компиляции и сборки nginx

```
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
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$
```

4. Настройка файлов, флагов и компиляция/сборка пакета nginx

```
kosogor@vm1-server:~/nginx-brotli-build/nginx-1.24.0$ vi debian/rules
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

5. Сборка DEB-пакета в данном варианте была осложнена внесёнными в пакет изменениями при добавлении модулю, с помощью стандартной утилиты debuild DEB-пакет собрать не удалось. DEB-пакет с ограниченными возможностями (например, не создающего настройки systemctl при установке) удалось создать с помощью утилиты fpm (которая собирает DEB-пакет из директорий установленного пакета):

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

6. Затем вручную было создана конфигурация systemctl для запуска сервиса nginx, сервис был запущен, сконфигурирован его автозапуск при загрузке ОС, а также отключена перезапись этого пакета при обновлениях:

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

7. После запуска установленного сервера nginx с модулем brotli была проверена его работа и сжатие тестового файла brotli-test-big.txt при передаче:

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
    }
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

8. Затем на этом же ВМ был организован репозиторий для DEB-пакетов, в него был добавлен DEB-пакет nginx-brotli с помощью утилиты dpkg-scanpackages:

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

9. Затем созданный репозиторий был подключен на клиентской машине (в данном случае, клиентской машиной являлся тот же компьютер) двумя способами:
как локальный репозиторий через file:// и через http:// с использованием сконфигурированного сервера nginx с модулем brontli - оба репозитория видны
после подключения при 'apt update ' и пакет nginx-brotli виден в обоих репозиториях. Для простоты пакеты в репозитории не подписывались, поэтому
оба репозитория подключены для тестирования с опцией [trusted=yes]  :

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

# 2.1. Повторная сборка пакета DEB в помощью утилиты debuild и работа с репозиторием пакетов APT/DEB в ОС Ubuntu 24.04 (APT/DPKG-based): 

В данном пункте выполнялась компиляция и сборка пакета DEB без добавления дополнительного модуля для упрощения процесса.
Данный пункт выполнялся путём проб и ошибок с использованием поиска в Интернет и рекомендаций Яндекс ИИ, цель была собрать стандартный пакет DEB для репозитория стандартной утилитой debuild.

### При компиляции и сборке пакета DEB использовалась следующая информация:

В качестве исходников для компиляции и сборки пакета DEB используется пакет source для ngnix.
При его скачивании на компьютер скачиваются три файла:

| Файл      | Что содержит      | Для чего нужен       | 
|:---------------------------------------|:---------------|:-------------------------|
| nginx_1.24.0.orig.tar.gz              | Чистый код от nginx от разработчиков пакета        | Исходная база для сборки          |
| nginx_<версия>-<ревизия>.debian.tar.xz               | Директория debian/ (control, rules, патчи и т.д.)        | Упаковка под Ubuntu/Debian          |
| nginx_<версия>-<ревизия>.dsc               | Метаданные и контрольные суммы        | Проверка целостности и подпись         |


Вся информация по компиляции, сборке и установке пакета содержится в директории debian/ архива *.tar.xz ,
Для правильной компиляции и сборки необходимо обязательно правильно сформировать файлы debian/control , debian/rules , debian/changelog 
(например, в файл debian/rules необходимо добавить информацию о добавлении дополнительного модуля).
Директорию debian/ необходимо обязательно создать и заполнить правильными файлами перед началом компиляции и сборки пакета DEB.
Создать директорию debian/ можно создать либо утилитой dh_make (но тогда затем её нужно полностью самостоятельно заполнять необходимыми
файлами с правильным содержимым), либо вытащить уже готовую директорию debian/ из какого-либо уже собранного пакета DEB и затем использовать её в качестве
образца для правок.


Допустим, ты хочешь собрать nginx с теми же флагами, что и раньше, но на базе официального пакета Ubuntu. Ты делаешь так:

- Скачиваешь исходники через apt source nginx.

- Распаковываешь debian.tar.xz внутрь папки с upstream‑кодом.

- Правишь только debian/rules:

```
    override_dh_auto_configure:
     ./configure --prefix=/usr \
       --sbin-path=/usr/sbin/nginx \
       --conf-path=/etc/nginx/nginx.conf \
       --error-log-path=/var/log/nginx/error.log \
       --http-log-path=/var/log/nginx/access.log \
       --with-http_ssl_module \
       --with-pcre
```

Меняешь (если нужно) debian/changelog, чтобы не конфликтовать с версией Ubuntu (можно добавить свой суффикс, например 1.24.0-2ubuntu7.15+custom1).

Запускаешь debuild -us -uc -b из папки nginx-<версия>.

И всё: зависимости, пути, systemd, совместимость — уже сделаны мейнтейнерами Ubuntu, а ты контролируешь только сборку и флаги.
Также для успешной компиляции и сборки требуется заполнение файлов debian/compat , debian/install 



### При создании репозитория Debian использовалась следующая информация:

1) Структура репозиториев Debian (APT/DPKG-based) и работа с ними хорошо описана в статье

"Добавление репозитория в Debian, примеры sources.list" по ссылке  https://serveradmin.ru/nastrojka-repozitoriev-v-debian/ 


2) Создание репозиториев Debian (APT/DPKG-based) с помощью различных утилит, в зависимости от выполняемых задач, хорошо описано в статье

"Creating a Local APT Repository on Linux" по ссылке  https://www.baeldung.com/linux/apt-set-up-make-local-repository 


## 0. Чистая ВМ с ОС Ubuntu 24.04

```
kosogor@kosogor:~$ uname -a
Linux kosogor 6.8.0-100-generic #100-Ubuntu SMP PREEMPT_DYNAMIC Tue Jan 13 16:40:06 UTC 2026 x86_64 x86_64 x86_64 GNU/Linux
kosogor@kosogor:~$ cat /etc/os-release | grep PRETTY_NAME
PRETTY_NAME="Ubuntu 24.04.4 LTS"
kosogor@kosogor:~$
```

1. Установка необходимых для сборки пакетов:

```
kosogor@kosogor:~$ sudo apt update
[sudo] password for kosogor: 
Пол:1 http://security.ubuntu.com/ubuntu noble-security InRelease [126 kB]
Сущ:2 http://us.archive.ubuntu.com/ubuntu noble InRelease
<...>
Чтение информации о состоянии… Готово         
Может быть обновлено 179 пакетов. Запустите «apt list --upgradable» для их показа.
kosogor@kosogor:~$
kosogor@kosogor:~$ sudo apt install devscripts build-essential fakeroot dh-make quilt
Чтение списков пакетов… Готово
Построение дерева зависимостей… Готово
Чтение информации о состоянии… Готово         
Будут установлены следующие дополнительные пакеты:
<...>

No VM guests are running outdated hypervisor (qemu) binaries on this host.
kosogor@kosogor:~$
```

2. Скачиваем исходники пакета nginx:

```
kosogor@kosogor:~$ wget https://nginx.org/download/nginx-1.24.0.tar.gz
--2026-07-30 03:23:57--  https://nginx.org/download/nginx-1.24.0.tar.gz
Resolving nginx.org (nginx.org)... 3.125.197.172, 2a05:d014:5c0:2600::6, 2a05:d014:5c0:2601::6
Connecting to nginx.org (nginx.org)|3.125.197.172|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 1112471 (1,1M) [application/octet-stream]
Saving to: ‘nginx-1.24.0.tar.gz’

nginx-1.24.0.tar.gz                    100%[============================================================================>]   1,06M  1,53MB/s    in 0,7s    

2026-07-30 03:23:58 (1,53 MB/s) - ‘nginx-1.24.0.tar.gz’ saved [1112471/1112471]

kosogor@kosogor:~$
kosogor@kosogor:~$ tar xzf nginx-1.24.0.tar.gz
kosogor@kosogor:~$ ll
total 1128
drwxr-x--- 5 kosogor kosogor    4096 июл 30 03:24 ./
drwxr-xr-x 3 root    root       4096 июн 25 06:37 ../
-rw------- 1 kosogor kosogor    1830 июн 25 09:14 .bash_history
-rw-r--r-- 1 kosogor kosogor     220 мар 31  2024 .bash_logout
-rw-r--r-- 1 kosogor kosogor    3771 мар 31  2024 .bashrc
drwx------ 2 kosogor kosogor    4096 июн 25 06:42 .cache/
drwxr-xr-x 8 kosogor kosogor    4096 апр 11  2023 nginx-1.24.0/
-rw-rw-r-- 1 kosogor kosogor 1112471 апр 11  2023 nginx-1.24.0.tar.gz
-rw-r--r-- 1 kosogor kosogor     807 мар 31  2024 .profile
drwx------ 2 kosogor kosogor    4096 июн 25 06:42 .ssh/
-rw-r--r-- 1 kosogor kosogor       0 июн 25 06:43 .sudo_as_admin_successful
-rw-rw-r-- 1 kosogor kosogor     164 июл 30 03:23 .wget-hsts
kosogor@kosogor:~$ cd nginx-1.24.0
kosogor@kosogor:~/nginx-1.24.0$ ll
total 844
drwxr-xr-x 8 kosogor kosogor   4096 апр 11  2023 ./
drwxr-x--- 5 kosogor kosogor   4096 июл 30 03:24 ../
drwxr-xr-x 6 kosogor kosogor   4096 июл 30 03:24 auto/
-rw-r--r-- 1 kosogor kosogor 323312 апр 11  2023 CHANGES
-rw-r--r-- 1 kosogor kosogor 494234 апр 11  2023 CHANGES.ru
drwxr-xr-x 2 kosogor kosogor   4096 июл 30 03:24 conf/
-rwxr-xr-x 1 kosogor kosogor   2611 апр 11  2023 configure*
drwxr-xr-x 4 kosogor kosogor   4096 июл 30 03:24 contrib/
drwxr-xr-x 2 kosogor kosogor   4096 июл 30 03:24 html/
-rw-r--r-- 1 kosogor kosogor   1397 апр 11  2023 LICENSE
drwxr-xr-x 2 kosogor kosogor   4096 июл 30 03:24 man/
-rw-r--r-- 1 kosogor kosogor     49 апр 11  2023 README
drwxr-xr-x 9 kosogor kosogor   4096 июл 30 03:24 src/
kosogor@kosogor:~/nginx-1.24.0$ 
```

3. Создаём необходимую структуру директорий, заполняем необходимые для компиляции и сборки файлы debian/control , debian/rules , debian/changelog :

```
kosogor@kosogor:~/nginx-1.24.0$ dh_make -s -y
Maintainer Name     : Eugene Kosogorov
Email-Address       : kosogor@unknown
Date                : Thu, 30 Jul 2026 03:25:13 +0000
Package Name        : nginx
Version             : 1.24.0
License             : blank
Package Type        : single

Could not find nginx_1.24.0.orig.tar.xz
Either specify an alternate file to use with -f,
or add --createorig to create one.
kosogor@kosogor:~/nginx-1.24.0$
kosogor@kosogor:~/nginx-1.24.0$ cd ..
kosogor@kosogor:~$
kosogor@kosogor:~$ tar --owner=0 --group=0 --numeric-owner -cJf nginx_1.24.0.orig.tar.xz nginx-1.24.0
kosogor@kosogor:~$ 
kosogor@kosogor:~$ cd nginx-1.24.0
kosogor@kosogor:~/nginx-1.24.0$ dh_make -s -y
Maintainer Name     : Eugene Kosogorov
Email-Address       : kosogor@unknown
Date                : Thu, 30 Jul 2026 03:30:01 +0000
Package Name        : nginx
Version             : 1.24.0
License             : blank
Package Type        : single
Skipping creating ../nginx_1.24.0.orig.tar.xz because it already exists
Done. Please edit the files in the debian/ subdirectory now.

kosogor@kosogor:~/nginx-1.24.0$ ll
total 848
drwxr-xr-x 9 kosogor kosogor   4096 июл 30 03:30 ./
drwxr-x--- 5 kosogor kosogor   4096 июл 30 03:29 ../
drwxr-xr-x 6 kosogor kosogor   4096 июл 30 03:24 auto/
-rw-r--r-- 1 kosogor kosogor 323312 апр 11  2023 CHANGES
-rw-r--r-- 1 kosogor kosogor 494234 апр 11  2023 CHANGES.ru
drwxr-xr-x 2 kosogor kosogor   4096 июл 30 03:24 conf/
-rwxr-xr-x 1 kosogor kosogor   2611 апр 11  2023 configure*
drwxr-xr-x 4 kosogor kosogor   4096 июл 30 03:24 contrib/
drwxr-xr-x 4 kosogor kosogor   4096 июл 30 03:30 debian/
drwxr-xr-x 2 kosogor kosogor   4096 июл 30 03:24 html/
-rw-r--r-- 1 kosogor kosogor   1397 апр 11  2023 LICENSE
drwxr-xr-x 2 kosogor kosogor   4096 июл 30 03:24 man/
-rw-r--r-- 1 kosogor kosogor     49 апр 11  2023 README
drwxr-xr-x 9 kosogor kosogor   4096 июл 30 03:24 src/
kosogor@kosogor:~/nginx-1.24.0$
kosogor@kosogor:~/nginx-1.24.0$ vi debian/control
kosogor@kosogor:~/nginx-1.24.0$ cat debian/control
Source: nginx
Section: web
Priority: optional
Maintainer: Your Name <your@email.com>
Build-Depends: debhelper (>= 13), build-essential, libpcre3-dev, zlib1g-dev, openssl, dh-autoreconf
Standards-Version: 4.5.1

Package: nginx
Architecture: any
Depends: ${shlibs:Depends}, ${misc:Depends}
Description: nginx web server
 A high performance reverse proxy and web server.
kosogor@kosogor:~/nginx-1.24.0$
kosogor@kosogor:~/nginx-1.24.0$ vi debian/rules
kosogor@kosogor:~/nginx-1.24.0$ cat debian/rules
#!/usr/bin/make -f
%:
	dh $@
override_dh_auto_configure:
	./configure --prefix=/usr \
		--sbin-path=/usr/sbin/nginx \
		--conf-path=/etc/nginx/nginx.conf \
		--error-log-path=/var/log/nginx/error.log \
		--http-log-path=/var/log/nginx/access.log \
		--with-http_ssl_module \
		--with-pcre \
		--with-zlib
override_dh_auto_build:
	make
override_dh_auto_test:
	# тесты пропускаем для простоты
override_dh_auto_install:
	make install DESTDIR=$(CURDIR)/debian/tmp

kosogor@kosogor:~/nginx-1.24.0$
kosogor@kosogor:~/nginx-1.24.0$ chmod +x debian/rules
kosogor@kosogor:~/nginx-1.24.0$
kosogor@kosogor:~/nginx-1.24.0$ echo "usr/sbin/nginx usr/sbin/" > debian/install
echo "etc/nginx etc/" >> debian/install
kosogor@kosogor:~/nginx-1.24.0$ 
kosogor@kosogor:~/nginx-1.24.0$ cat debian/install 
usr/sbin/nginx usr/sbin/
etc/nginx etc/
kosogor@kosogor:~/nginx-1.24.0$
kosogor@kosogor:~/nginx-1.24.0$ cat debian/changelog
nginx (1.24.0-1) UNRELEASED; urgency=medium

  * Initial release. (Closes: #nnnn)  <nnnn is the bug number of your ITP>

 -- Eugene Kosogorov <kosogor@unknown>  Thu, 30 Jul 2026 03:30:01 +0000
kosogor@kosogor:~/nginx-1.24.0$
```

4. Запускаем компиляцию, по возникающим сообщениям доустанавливаем недостающие пакеты, правим файлы debian/compat и debian/control:

```
kosogor@kosogor:~/nginx-1.24.0$ debuild -us -uc
 dpkg-buildpackage -us -uc -ui
dpkg-buildpackage: info: source package nginx
dpkg-buildpackage: info: source version 1.24.0-1
dpkg-buildpackage: info: source distribution UNRELEASED
dpkg-buildpackage: info: source changed by Eugene Kosogorov <kosogor@unknown>
 dpkg-source --before-build .
dpkg-buildpackage: info: host architecture amd64
dpkg-checkbuilddeps: error: Unmet build dependencies: libpcre3-dev zlib1g-dev
dpkg-buildpackage: warning: build dependencies/conflicts unsatisfied; aborting
dpkg-buildpackage: warning: (Use -d flag to override.)
debuild: fatal error at line 1184:
dpkg-buildpackage -us -uc -ui failed
kosogor@kosogor:~/nginx-1.24.0$
kosogor@kosogor:~/nginx-1.24.0$ sudo apt install libpcre3-dev zlib1g-dev
Чтение списков пакетов… Готово
Построение дерева зависимостей… Готово
Чтение информации о состоянии… Готово         
Будут установлены следующие дополнительные пакеты:
  libpcre16-3 libpcre3 libpcre32-3 libpcrecpp0v5
Следующие НОВЫЕ пакеты будут установлены:
  libpcre16-3 libpcre3 libpcre3-dev libpcre32-3 libpcrecpp0v5 zlib1g-dev
<...>
No VM guests are running outdated hypervisor (qemu) binaries on this host.
kosogor@kosogor:~/nginx-1.24.0$
kosogor@kosogor:~/nginx-1.24.0$ debuild -us -uc
 dpkg-buildpackage -us -uc -ui
dpkg-buildpackage: info: source package nginx
dpkg-buildpackage: info: source version 1.24.0-1
dpkg-buildpackage: info: source distribution UNRELEASED
dpkg-buildpackage: info: source changed by Eugene Kosogorov <kosogor@unknown>
 dpkg-source --before-build .
dpkg-buildpackage: info: host architecture amd64
dpkg-checkbuilddeps: error: Unmet build dependencies: debhelper (= 13)
dpkg-buildpackage: warning: build dependencies/conflicts unsatisfied; aborting
dpkg-buildpackage: warning: (Use -d flag to override.)
debuild: fatal error at line 1184:
dpkg-buildpackage -us -uc -ui failed
kosogor@kosogor:~/nginx-1.24.0$
kosogor@kosogor:~/nginx-1.24.0$ echo "13" > debian/compat
kosogor@kosogor:~/nginx-1.24.0$ 
kosogor@kosogor:~/nginx-1.24.0$ cat debian/compat
13
kosogor@kosogor:~/nginx-1.24.0$
kosogor@kosogor:~/nginx-1.24.0$ debuild -us -uc
 dpkg-buildpackage -us -uc -ui
dpkg-buildpackage: info: source package nginx
dpkg-buildpackage: info: source version 1.24.0-1
dpkg-buildpackage: info: source distribution UNRELEASED
dpkg-buildpackage: info: source changed by Eugene Kosogorov <kosogor@unknown>
 dpkg-source --before-build .
dpkg-buildpackage: info: host architecture amd64
 fakeroot debian/rules clean
dh clean
   dh_clean
 dpkg-source -b .
dpkg-source: info: using source format '3.0 (quilt)'
dpkg-source: info: building nginx using existing ./nginx_1.24.0.orig.tar.xz
dpkg-source: info: building nginx in nginx_1.24.0-1.debian.tar.xz
dpkg-source: info: building nginx in nginx_1.24.0-1.dsc
 debian/rules build
dh build
   dh_update_autotools_config
   dh_autoreconf
   debian/rules override_dh_auto_configure
make[1]: Entering directory '/home/kosogor/nginx-1.24.0'
./configure --prefix=/usr \
	--sbin-path=/usr/sbin/nginx \
	--conf-path=/etc/nginx/nginx.conf \
	--error-log-path=/var/log/nginx/error.log \
	--http-log-path=/var/log/nginx/access.log \
	--with-http_ssl_module \
	--with-pcre \
	--with-zlib
./configure: error: invalid option "--with-zlib"
make[1]: *** [debian/rules:5: override_dh_auto_configure] Error 1
make[1]: Leaving directory '/home/kosogor/nginx-1.24.0'
make: *** [debian/rules:3: build] Error 2
dpkg-buildpackage: error: debian/rules build subprocess returned exit status 2
debuild: fatal error at line 1184:
dpkg-buildpackage -us -uc -ui failed
kosogor@kosogor:~/nginx-1.24.0$
kosogor@kosogor:~/nginx-1.24.0$ vi debian/rules
kosogor@kosogor:~/nginx-1.24.0$ 
kosogor@kosogor:~/nginx-1.24.0$ cat debian/rules
#!/usr/bin/make -f
%:
	dh $@
override_dh_auto_configure:
	./configure --prefix=/usr \
		--sbin-path=/usr/sbin/nginx \
		--conf-path=/etc/nginx/nginx.conf \
		--error-log-path=/var/log/nginx/error.log \
		--http-log-path=/var/log/nginx/access.log \
		--with-http_ssl_module \
		--with-pcre
override_dh_auto_build:
	make
override_dh_auto_test:
	# тесты пропускаем для простоты
override_dh_auto_install:
	make install DESTDIR=$(CURDIR)/debian/tmp

kosogor@kosogor:~/nginx-1.24.0$
kosogor@kosogor:~/nginx-1.24.0$ debuild -us -uc
 dpkg-buildpackage -us -uc -ui
dpkg-buildpackage: info: source package nginx
dpkg-buildpackage: info: source version 1.24.0-1
dpkg-buildpackage: info: source distribution UNRELEASED
dpkg-buildpackage: info: source changed by Eugene Kosogorov <kosogor@unknown>
 dpkg-source --before-build .
dpkg-buildpackage: info: host architecture amd64
 fakeroot debian/rules clean
dh clean
   dh_clean
 dpkg-source -b .
dpkg-source: info: using source format '3.0 (quilt)'
dpkg-source: info: building nginx using existing ./nginx_1.24.0.orig.tar.xz
dpkg-source: info: building nginx in nginx_1.24.0-1.debian.tar.xz
dpkg-source: info: building nginx in nginx_1.24.0-1.dsc
 debian/rules build
dh build
   dh_update_autotools_config
   dh_autoreconf
   debian/rules override_dh_auto_configure
make[1]: Entering directory '/home/kosogor/nginx-1.24.0'
./configure --prefix=/usr \
	--sbin-path=/usr/sbin/nginx \
	--conf-path=/etc/nginx/nginx.conf \
	--error-log-path=/var/log/nginx/error.log \
	--http-log-path=/var/log/nginx/access.log \
	--with-http_ssl_module \
	--with-pcre
checking for OS
 + Linux 6.8.0-100-generic x86_64
checking for C compiler ... found
 + using GNU C compiler
checking for -Wl,-E switch ... found
checking for gcc builtin atomic operations ... found
<...>
./configure: error: SSL modules require the OpenSSL library.
You can either do not enable the modules, or install the OpenSSL library
into the system, or build the OpenSSL library statically from the source
with nginx by using --with-openssl=<path> option.

make[1]: *** [debian/rules:5: override_dh_auto_configure] Error 1
make[1]: Leaving directory '/home/kosogor/nginx-1.24.0'
make: *** [debian/rules:3: build] Error 2
dpkg-buildpackage: error: debian/rules build subprocess returned exit status 2
debuild: fatal error at line 1184:
dpkg-buildpackage -us -uc -ui failed
kosogor@kosogor:~/nginx-1.24.0$
kosogor@kosogor:~/nginx-1.24.0$ sudo apt install libssl-dev
тение списков пакетов… Готово
Построение дерева зависимостей… Готово
Чтение информации о состоянии… Готово         
Будут установлены следующие дополнительные пакеты:
  libssl3t64 openssl
<...>
No VM guests are running outdated hypervisor (qemu) binaries on this host.
kosogor@kosogor:~/nginx-1.24.0$
kosogor@kosogor:~/nginx-1.24.0$ debuild -us -uc
 dpkg-buildpackage -us -uc -ui
dpkg-buildpackage: info: source package nginx
dpkg-buildpackage: info: source version 1.24.0-1
dpkg-buildpackage: info: source distribution UNRELEASED
dpkg-buildpackage: info: source changed by Eugene Kosogorov <kosogor@unknown>
 dpkg-source --before-build .
dpkg-buildpackage: info: host architecture amd64
 fakeroot debian/rules clean
dh clean
   dh_auto_clean
	make -j3 clean
make[1]: Entering directory '/home/kosogor/nginx-1.24.0'
rm -rf Makefile objs
make[1]: Leaving directory '/home/kosogor/nginx-1.24.0'
   dh_clean
 dpkg-source -b .
dpkg-source: info: using source format '3.0 (quilt)'
dpkg-source: info: building nginx using existing ./nginx_1.24.0.orig.tar.xz
dpkg-source: info: building nginx in nginx_1.24.0-1.debian.tar.xz
dpkg-source: info: building nginx in nginx_1.24.0-1.dsc
 debian/rules build
dh build
   dh_update_autotools_config
   dh_autoreconf
   debian/rules override_dh_auto_configure
make[1]: Entering directory '/home/kosogor/nginx-1.24.0'
./configure --prefix=/usr \
	--sbin-path=/usr/sbin/nginx \
	--conf-path=/etc/nginx/nginx.conf \
	--error-log-path=/var/log/nginx/error.log \
	--http-log-path=/var/log/nginx/access.log \
	--with-http_ssl_module \
	--with-pcre
checking for OS
 + Linux 6.8.0-100-generic x86_64
<...>
dh_missing: warning: usr/html/50x.html exists in debian/tmp but is not installed to anywhere 
dh_missing: warning: usr/html/index.html exists in debian/tmp but is not installed to anywhere 
dh_missing: error: missing files, aborting
	The following debhelper tools have reported what they installed (with files per package)
	 * dh_install: nginx (2)
	 * dh_installdocs: nginx (0)
	If the missing files are installed by another tool, please file a bug against it.
	When filing the report, if the tool is not part of debhelper itself, please reference the
	"Logging helpers and dh_missing" section from the "PROGRAMMING" guide for debhelper (10.6.3+).
	  (in the debhelper package: /usr/share/doc/debhelper/PROGRAMMING.md.gz)
	Be sure to test with dpkg-buildpackage -A/-B as the results may vary when only a subset is built
	If the omission is intentional or no other helper can take care of this consider adding the
	paths to debian/not-installed.
make: *** [debian/rules:3: binary] Error 255
dpkg-buildpackage: error: fakeroot debian/rules binary subprocess returned exit status 2
debuild: fatal error at line 1184:
dpkg-buildpackage -us -uc -ui failed
kosogor@kosogor:~/nginx-1.24.0$
kosogor@kosogor:~/nginx-1.24.0$ echo "usr/html /usr/share/nginx" > debian/install
echo "usr/sbin/nginx usr/sbin/" >> debian/install
echo "etc/nginx etc/" >> debian/install
kosogor@kosogor:~/nginx-1.24.0$ 
kosogor@kosogor:~/nginx-1.24.0$ cat debian/install
usr/html /usr/share/nginx
usr/sbin/nginx usr/sbin/
etc/nginx etc/
kosogor@kosogor:~/nginx-1.24.0$ 
kosogor@kosogor:~/nginx-1.24.0$ debuild -us -uc
 dpkg-buildpackage -us -uc -ui
dpkg-buildpackage: info: source package nginx
dpkg-buildpackage: info: source version 1.24.0-1
dpkg-buildpackage: info: source distribution UNRELEASED
dpkg-buildpackage: info: source changed by Eugene Kosogorov <kosogor@unknown>
 dpkg-source --before-build .
dpkg-buildpackage: info: host architecture amd64
 fakeroot debian/rules clean
dh clean
   dh_auto_clean
	make -j3 clean
make[1]: Entering directory '/home/kosogor/nginx-1.24.0'
rm -rf Makefile objs
make[1]: Leaving directory '/home/kosogor/nginx-1.24.0'
   dh_clean
 dpkg-source -b .
dpkg-source: info: using source format '3.0 (quilt)'
dpkg-source: info: building nginx using existing ./nginx_1.24.0.orig.tar.xz
dpkg-source: info: building nginx in nginx_1.24.0-1.debian.tar.xz
dpkg-source: info: building nginx in nginx_1.24.0-1.dsc
 debian/rules build
dh build
   dh_update_autotools_config
   dh_autoreconf
   debian/rules override_dh_auto_configure
make[1]: Entering directory '/home/kosogor/nginx-1.24.0'
./configure --prefix=/usr \
	--sbin-path=/usr/sbin/nginx \
	--conf-path=/etc/nginx/nginx.conf \
	--error-log-path=/var/log/nginx/error.log \
	--http-log-path=/var/log/nginx/access.log \
	--with-http_ssl_module \
	--with-pcre
checking for OS
 + Linux 6.8.0-100-generic x86_64
<...>
W: nginx: readme-debian-contains-invalid-email-address kosogor@unknown [usr/share/doc/nginx/README.Debian]
W: nginx source: space-in-std-shortname-in-dep5-copyright <special license> [debian/copyright:11]
W: nginx source: useless-autoreconf-build-depends (does not need to satisfy dh-autoreconf:any)
W: nginx: wrong-bug-number-in-closes #nnnn [usr/share/doc/nginx/changelog.Debian.gz:3]
Finished running lintian.
kosogor@kosogor:~/nginx-1.24.0$
kosogor@kosogor:~$ dpkg -I nginx_1.24.0-1_amd64.deb
 новый пакет Debian, версия 2.0.
 размер 390198 байт(а): управляющий архив длиной 707 байт(а).
     387 bytes,    15 lines      conffiles
     328 bytes,    10 lines      control
     450 bytes,     7 lines      md5sums
 Package: nginx
 Version: 1.24.0-1
 Architecture: amd64
 Maintainer: Your Name <your@email.com>
 Installed-Size: 1018
 Depends: libc6 (>= 2.34), libcrypt1 (>= 1:4.1.0), libpcre3, libssl3t64 (>= 3.0.0), zlib1g (>= 1:1.1.4)
 Section: web
 Priority: optional
 Description: nginx web server
  A high performance reverse proxy and web server.
kosogor@kosogor:~$ 
kosogor@kosogor:~$ dpkg -c nginx_1.24.0-1_amd64.deb | head -n 40
drwxr-xr-x root/root         0 2026-07-30 03:30 ./
drwxr-xr-x root/root         0 2026-07-30 03:30 ./etc/
drwxr-xr-x root/root         0 2026-07-30 03:30 ./etc/nginx/
-rw-r--r-- root/root      1077 2026-07-30 03:30 ./etc/nginx/fastcgi.conf
-rw-r--r-- root/root      1077 2026-07-30 03:30 ./etc/nginx/fastcgi.conf.default
-rw-r--r-- root/root      1007 2026-07-30 03:30 ./etc/nginx/fastcgi_params
-rw-r--r-- root/root      1007 2026-07-30 03:30 ./etc/nginx/fastcgi_params.default
-rw-r--r-- root/root      2837 2026-07-30 03:30 ./etc/nginx/koi-utf
-rw-r--r-- root/root      2223 2026-07-30 03:30 ./etc/nginx/koi-win
-rw-r--r-- root/root      5349 2026-07-30 03:30 ./etc/nginx/mime.types
-rw-r--r-- root/root      5349 2026-07-30 03:30 ./etc/nginx/mime.types.default
-rw-r--r-- root/root      2656 2026-07-30 03:30 ./etc/nginx/nginx.conf
-rw-r--r-- root/root      2656 2026-07-30 03:30 ./etc/nginx/nginx.conf.default
-rw-r--r-- root/root       636 2026-07-30 03:30 ./etc/nginx/scgi_params
-rw-r--r-- root/root       636 2026-07-30 03:30 ./etc/nginx/scgi_params.default
-rw-r--r-- root/root       664 2026-07-30 03:30 ./etc/nginx/uwsgi_params
-rw-r--r-- root/root       664 2026-07-30 03:30 ./etc/nginx/uwsgi_params.default
-rw-r--r-- root/root      3610 2026-07-30 03:30 ./etc/nginx/win-utf
drwxr-xr-x root/root         0 2026-07-30 03:30 ./usr/
drwxr-xr-x root/root         0 2026-07-30 03:30 ./usr/sbin/
-rwxr-xr-x root/root    982432 2026-07-30 03:30 ./usr/sbin/nginx
drwxr-xr-x root/root         0 2026-07-30 03:30 ./usr/share/
drwxr-xr-x root/root         0 2026-07-30 03:30 ./usr/share/doc/
drwxr-xr-x root/root         0 2026-07-30 03:30 ./usr/share/doc/nginx/
-rw-r--r-- root/root       176 2026-07-30 03:30 ./usr/share/doc/nginx/README.Debian
-rw-r--r-- root/root       182 2026-07-30 03:30 ./usr/share/doc/nginx/changelog.Debian.gz
-rw-r--r-- root/root      1908 2026-07-30 03:30 ./usr/share/doc/nginx/copyright
drwxr-xr-x root/root         0 2026-07-30 03:30 ./usr/share/doc-base/
-rw-r--r-- root/root       493 2026-07-30 03:30 ./usr/share/doc-base/nginx.nginx
drwxr-xr-x root/root         0 2026-07-30 03:30 ./usr/share/nginx/
drwxr-xr-x root/root         0 2026-07-30 03:30 ./usr/share/nginx/html/
-rw-r--r-- root/root       497 2026-07-30 03:30 ./usr/share/nginx/html/50x.html
-rw-r--r-- root/root       615 2026-07-30 03:30 ./usr/share/nginx/html/index.html
kosogor@kosogor:~$ 
```

# 2.2 Повторная компиляция и сборка пакета DEB на ОС Ubuntu 24.04 (APT/DPKG-based), сборка в Docker: 

Данный пункт выполнялся путём проб и ошибок с использованием поиска в Интернет и рекомендаций Яндекс ИИ, цель была собрать стандартный пакет DEB для репозитория стандартной утилитой debuild, сборка производилась в Docker.

1. Подключаем репозиторий Docker, устанавливаем ключи репозитория Docker, устанавливаем Docker:

```
kosogor@kosogor:~$ sudo apt install -y ca-certificates curl gnupg lsb-release
Чтение списков пакетов… Готово
Построение дерева зависимостей… Готово
Чтение информации о состоянии… Готово         
Уже установлен пакет gnupg самой новой версии (2.4.4-2ubuntu17.4).
gnupg помечен как установленный вручную.
Уже установлен пакет lsb-release самой новой версии (12.0-2).
lsb-release помечен как установленный вручную.
Следующие пакеты будут обновлены:
  ca-certificates curl libcurl3t64-gnutls libcurl4t64
<...>

No VM guests are running outdated hypervisor (qemu) binaries on this host.
kosogor@kosogor:~$ 
kosogor@kosogor:~$ 
kosogor@kosogor:~$ sudo install -m 0755 -d /etc/apt/keyrings
kosogor@kosogor:~$ curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
kosogor@kosogor:~$ sudo chmod a+r /etc/apt/keyrings/docker.gpg
kosogor@kosogor:~$ 
kosogor@kosogor:~$ uname -a
Linux kosogor 6.8.0-100-generic #100-Ubuntu SMP PREEMPT_DYNAMIC Tue Jan 13 16:40:06 UTC 2026 x86_64 x86_64 x86_64 GNU/Linux
kosogor@kosogor:~$ uname -r
6.8.0-100-generic
kosogor@kosogor:~$ cat /etc/os-release
PRETTY_NAME="Ubuntu 24.04.4 LTS"
NAME="Ubuntu"
VERSION_ID="24.04"
VERSION="24.04.4 LTS (Noble Numbat)"
VERSION_CODENAME=noble
ID=ubuntu
ID_LIKE=debian
HOME_URL="https://www.ubuntu.com/"
SUPPORT_URL="https://help.ubuntu.com/"
BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
UBUNTU_CODENAME=noble
LOGO=ubuntu-logo
kosogor@kosogor:~$ echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu noble stable" | sudo tee /etc/apt/sources.list.d/docker.list
deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu noble stable
kosogor@kosogor:~$ 
kosogor@kosogor:~$ sudo apt update
Сущ:1 http://security.ubuntu.com/ubuntu noble-security InRelease
Пол:2 https://download.docker.com/linux/ubuntu noble InRelease [48,5 kB]                             
Сущ:3 http://us.archive.ubuntu.com/ubuntu noble InRelease                         
Сущ:4 http://us.archive.ubuntu.com/ubuntu noble-updates InRelease           
Пол:5 https://download.docker.com/linux/ubuntu noble/stable amd64 Packages [61,8 kB]
Сущ:6 http://us.archive.ubuntu.com/ubuntu noble-backports InRelease               
Сущ:7 http://us.archive.ubuntu.com/ubuntu noble-proposed InRelease
Получено 110 kB за 1с (84,1 kB/s)         
Чтение списков пакетов… Готово
Построение дерева зависимостей… Готово
Чтение информации о состоянии… Готово         
Может быть обновлено 165 пакетов. Запустите «apt list --upgradable» для их показа.
kosogor@kosogor:~$ 
kosogor@kosogor:~$ 
kosogor@kosogor:~$ sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
Чтение списков пакетов… Готово
Построение дерева зависимостей… Готово
Чтение информации о состоянии… Готово         
Будут установлены следующие дополнительные пакеты:
  docker-ce-rootless-extras pigz
<...>
No VM guests are running outdated hypervisor (qemu) binaries on this host.
kosogor@kosogor:~$
kosogor@kosogor:~$ sudo docker run hello-world
Unable to find image 'hello-world:latest' locally
latest: Pulling from library/hello-world
4f55086f7dd0: Pull complete 
d5e71e642bf5: Download complete 
Digest: sha256:c3cbe1cc1aa588a64951ac6286e0df7b27fe2e6324b1001c619bb358770c0178
Status: Downloaded newer image for hello-world:latest

Hello from Docker!
This message shows that your installation appears to be working correctly.
<...>
kosogor@kosogor:~$ 
kosogor@kosogor:~$ sudo usermod -aG docker $USER
kosogor@kosogor:~$
```

2. Формируем Dockerfile для сборки nginx в Docker и выполняем сборку (данный итоговый файл для успешной сборки пакета nginx получен путём отладки и множественных повторений,
а также на основе результатов предыдущего раздела "Сборка DEB-пакета в ВМ"):

```
kosogor@kosogor:~$ cat > Dockerfile
FROM ubuntu:24.04

RUN apt-get update && apt-get install -y \
    wget \
    devscripts \
    build-essential \
    fakeroot \
    dh-make \
    quilt \
    libpcre3-dev \
    zlib1g-dev \
    libssl-dev \
    openssl \
    dh-autoreconf \
    debhelper \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# 1. Скачиваем и проверяем
RUN wget -O nginx-1.24.0.tar.gz https://nginx.org/download/nginx-1.24.0.tar.gz && \
    [ -s nginx-1.24.0.tar.gz ] || (echo "ERROR: nginx-1.24.0.tar.gz is empty!" && exit 1)

# 2. Распаковываем и проверяем папку
RUN tar xzf nginx-1.24.0.tar.gz && \
    rm nginx-1.24.0.tar.gz && \
    [ -d nginx-1.24.0 ] || (echo "ERROR: directory nginx-1.24.0 not found!" && exit 1)

# 3. Создаём orig-архив с префиксом
RUN tar --transform 's,^,nginx-1.24.0/,' -cf nginx_1.24.0.orig.tar.xz nginx-1.24.0

# 4. Диагностика архива
RUN ls -lh nginx_1.24.0.orig.tar.xz && \
    file nginx_1.24.0.orig.tar.xz && \
    tar -tf nginx_1.24.0.orig.tar.xz | head -n 10

# Создаём пользователя
RUN useradd -m -s /bin/bash kosogor

# Переходим в папку исходников
WORKDIR /build/nginx-1.24.0

USER kosogor
ENV HOME=/home/kosogor

# dh_make (создаст debian/control, debian/rules и т.д.)
RUN env USER="kosogor" LOGNAME="kosogor" dh_make -s -y -e "kosogor@example.com"

# Возвращаемся на root
USER root

# --- Заменяем файлы, которые создал dh_make ---

# control
RUN cat > debian/control <<EOF
Source: nginx
Section: web
Priority: optional
Maintainer: Eugene Kosogorov <kosogor@example.com>
Build-Depends: debhelper (>= 13), build-essential, libpcre3-dev, zlib1g-dev, libssl-dev, openssl, dh-autoreconf
Standards-Version: 4.5.1

Package: nginx
Architecture: any
Depends: \${shlibs:Depends}, \${misc:Depends}
Description: nginx web server (minimal build)
 A high performance reverse proxy and web server.
EOF

# rules
RUN cat > debian/rules <<'EOF'
#!/usr/bin/make -f
%:
	dh $@
override_dh_auto_configure:
	./configure --prefix=/usr \
		--sbin-path=/usr/sbin/nginx \
		--conf-path=/etc/nginx/nginx.conf \
		--error-log-path=/var/log/nginx/error.log \
		--http-log-path=/var/log/nginx/access.log \
		--with-http_ssl_module \
		--with-pcre
override_dh_auto_build:
	make
override_dh_auto_test:
override_dh_auto_install:
	make install DESTDIR=$(CURDIR)/debian/tmp
EOF
RUN chmod +x debian/rules

# compat
RUN echo "13" > debian/compat

# install
RUN cat > debian/install <<EOF
usr/html /usr/share/nginx
usr/sbin/nginx usr/sbin/
etc/nginx etc/
EOF

# ВАЖНО: создаём changelog (без него debuild не запустится)
RUN cat > debian/changelog <<EOF
nginx (1.24.0-1) UNRELEASED; urgency=medium

  * Minimal build for NFS test environment
  * Custom rules for configure/build/install

 -- Eugene Kosogorov <kosogor@example.com>  $(date -R)
EOF

# ДИАГНОСТИКА ПЕРЕД СБОРКОЙ
RUN pwd
RUN ls -l debian/
RUN head -n 5 debian/changelog

# Сборка: запускаем из /build/nginx-1.24.0 (где лежит debian/)
RUN debuild -us -uc -b

# Копируем пакеты из родительской директории
WORKDIR /build
RUN cp ../nginx_*.deb . 2>/dev/null || true
kosogor@kosogor:~$ 
kosogor@kosogor:~$ 
kosogor@kosogor:~$ docker rmi nginx-debuild-demo
Error response from daemon: No such image: nginx-debuild-demo:latest
kosogor@kosogor:~$ 
kosogor@kosogor:~$ docker build --no-cache -t nginx-debuild-demo .
[+] Building 426.7s (26/26) FINISHED                                                                                                         docker:default
 => [internal] load build definition from Dockerfile                                                                                                   0.0s
 => => transferring dockerfile: 3.35kB                                                                                                                 0.0s
 => [internal] load metadata for docker.io/library/ubuntu:24.04                                                                                        1.4s
 => [internal] load .dockerignore                                                                                                                      0.0s
 => => transferring context: 2B                                                                                                                        0.0s
 => CACHED [ 1/22] FROM docker.io/library/ubuntu:24.04@sha256:4fbb8e6a8395de5a7550b33509421a2bafbc0aab6c06ba2cef9ebffbc7092d90                         0.0s
 => => resolve docker.io/library/ubuntu:24.04@sha256:4fbb8e6a8395de5a7550b33509421a2bafbc0aab6c06ba2cef9ebffbc7092d90                                  0.0s
 => [ 2/22] RUN apt-get update && apt-get install -y     wget     devscripts     build-essential     fakeroot     dh-make     quilt     libpcre3-de  263.1s
 => [ 3/22] WORKDIR /build                                                                                                                             0.3s 
 => [ 4/22] RUN wget -O nginx-1.24.0.tar.gz https://nginx.org/download/nginx-1.24.0.tar.gz &&     [ -s nginx-1.24.0.tar.gz ] || (echo "ERROR: nginx-1  1.6s 
 => [ 5/22] RUN tar xzf nginx-1.24.0.tar.gz &&     rm nginx-1.24.0.tar.gz &&     [ -d nginx-1.24.0 ] || (echo "ERROR: directory nginx-1.24.0 not foun  0.4s 
 => [ 6/22] RUN tar --transform 's,^,nginx-1.24.0/,' -cf nginx_1.24.0.orig.tar.xz nginx-1.24.0                                                         0.3s 
 => [ 7/22] RUN ls -lh nginx_1.24.0.orig.tar.xz &&     file nginx_1.24.0.orig.tar.xz &&     tar -tf nginx_1.24.0.orig.tar.xz | head -n 10              0.3s 
 => [ 8/22] RUN useradd -m -s /bin/bash kosogor                                                                                                        0.3s 
 => [ 9/22] WORKDIR /build/nginx-1.24.0                                                                                                                0.1s 
 => [10/22] RUN env USER="kosogor" LOGNAME="kosogor" dh_make -s -y -e "kosogor@example.com"                                                            0.3s 
 => [11/22] RUN cat > debian/control <<EOF                                                                                                             0.3s
 => [12/22] RUN cat > debian/rules <<'EOF'                                                                                                             0.3s 
 => [13/22] RUN chmod +x debian/rules                                                                                                                  0.3s 
 => [14/22] RUN echo "13" > debian/compat                                                                                                              0.3s 
 => [15/22] RUN cat > debian/install <<EOF                                                                                                             0.3s 
 => [16/22] RUN cat > debian/changelog <<EOF                                                                                                           0.3s 
 => [17/22] RUN pwd                                                                                                                                    0.3s
 => [18/22] RUN ls -l debian/                                                                                                                          0.3s
 => [19/22] RUN head -n 5 debian/changelog                                                                                                             0.3s
 => [20/22] RUN debuild -us -uc -b                                                                                                                    99.4s 
 => [21/22] WORKDIR /build                                                                                                                             0.1s 
 => [22/22] RUN cp ../nginx_*.deb . 2>/dev/null || true                                                                                                0.2s 
 => exporting to image                                                                                                                                56.1s 
 => => exporting layers                                                                                                                               42.3s 
 => => exporting manifest sha256:c13551175f5655b4780aaf2f598687eca77ccda5f102a2ace51417986e1ac1c5                                                      0.0s 
 => => exporting config sha256:049861846ab12370b874bc78617e1dfa94ac1f91295d91f89f152202e8e91b69                                                        0.0s 
 => => exporting attestation manifest sha256:ece04151c288a27c60b912f1e956907deaa2a2d36e2ee0390dcd0335342a6026                                          0.0s
 => => exporting manifest list sha256:99020059456c2b3e9395b179ebb920613a6cf13b577c3477487921c27ac030e8                                                 0.0s
 => => naming to docker.io/library/nginx-debuild-demo:latest                                                                                           0.0s
 => => unpacking to docker.io/library/nginx-debuild-demo:latest                                                                                       13.6s
kosogor@kosogor:~$ 
```

3. После успешной сборки DEB-пакета извлекаем готовые пакеты из контейнера:

```
kosogor@kosogor:~$ docker run -d --name nginx-build-container nginx-debuild-demo tail -f /dev/null
13dfa161b61a95f3ee25ee970fd87e526e17f048b32b88805bfa2221ca7e1788
kosogor@kosogor:~$
kosogor@kosogor:~$ mkdir docker_compiled_debs
kosogor@kosogor:~$
kosogor@kosogor:~$ docker exec nginx-build-container ls -lh /build/
total 8.2M
drwxr-xr-x 1 kosogor kosogor  4.0K Jul 30 06:27 nginx-1.24.0
-rw-r--r-- 1 root    root    1001K Jul 30 06:29 nginx-dbgsym_1.24.0-1_amd64.ddeb
-rw-r--r-- 1 root    root      72K Jul 30 06:29 nginx_1.24.0-1_amd64.build
-rw-r--r-- 1 root    root     6.3K Jul 30 06:29 nginx_1.24.0-1_amd64.buildinfo
-rw-r--r-- 1 root    root     1.3K Jul 30 06:29 nginx_1.24.0-1_amd64.changes
-rw-r--r-- 1 root    root     382K Jul 30 06:29 nginx_1.24.0-1_amd64.deb
-rw-r--r-- 1 root    root     6.8M Jul 30 06:27 nginx_1.24.0.orig.tar.xz
kosogor@kosogor:~$
kosogor@kosogor:~$ docker cp nginx-build-container:/build/ ./docker_compiled_debs/
Successfully copied 50.6MB to /home/kosogor/docker_compiled_debs/
kosogor@kosogor:~$ ll ./docker_compiled_debs/
total 396
drwxrwxr-x 3 kosogor kosogor   4096 июл 30 06:42 ./
drwxr-x--- 8 kosogor kosogor   4096 июл 30 06:36 ../
drwxr-xr-x 3 kosogor kosogor   4096 июл 30 06:29 build/
-rw-r--r-- 1 kosogor kosogor 390294 июл 30 06:29 nginx_1.24.0-1_amd64.deb
kosogor@kosogor:~$ ll ./docker_compiled_debs/build/
total 8364
drwxr-xr-x  3 kosogor kosogor    4096 июл 30 06:29 ./
drwxrwxr-x  3 kosogor kosogor    4096 июл 30 06:42 ../
drwxr-xr-x 10 kosogor kosogor    4096 июл 30 06:27 nginx-1.24.0/
-rw-r--r--  1 kosogor kosogor   72785 июл 30 06:29 nginx_1.24.0-1_amd64.build
-rw-r--r--  1 kosogor kosogor    6442 июл 30 06:29 nginx_1.24.0-1_amd64.buildinfo
-rw-r--r--  1 kosogor kosogor    1328 июл 30 06:29 nginx_1.24.0-1_amd64.changes
-rw-r--r--  1 kosogor kosogor  390294 июл 30 06:29 nginx_1.24.0-1_amd64.deb
-rw-r--r--  1 kosogor kosogor 7045120 июл 30 06:27 nginx_1.24.0.orig.tar.xz
-rw-r--r--  1 kosogor kosogor 1024840 июл 30 06:29 nginx-dbgsym_1.24.0-1_amd64.ddeb
kosogor@kosogor:~$
kosogor@kosogor:~$ ll -h ./docker_compiled_debs/build/
total 8,2M
drwxr-xr-x  3 kosogor kosogor  4,0K июл 30 06:29 ./
drwxrwxr-x  3 kosogor kosogor  4,0K июл 30 06:42 ../
drwxr-xr-x 10 kosogor kosogor  4,0K июл 30 06:27 nginx-1.24.0/
-rw-r--r--  1 kosogor kosogor   72K июл 30 06:29 nginx_1.24.0-1_amd64.build
-rw-r--r--  1 kosogor kosogor  6,3K июл 30 06:29 nginx_1.24.0-1_amd64.buildinfo
-rw-r--r--  1 kosogor kosogor  1,3K июл 30 06:29 nginx_1.24.0-1_amd64.changes
-rw-r--r--  1 kosogor kosogor  382K июл 30 06:29 nginx_1.24.0-1_amd64.deb
-rw-r--r--  1 kosogor kosogor  6,8M июл 30 06:27 nginx_1.24.0.orig.tar.xz
-rw-r--r--  1 kosogor kosogor 1001K июл 30 06:29 nginx-dbgsym_1.24.0-1_amd64.ddeb
kosogor@kosogor:~$
```

## Примечание: 
для облегчения разработки Dockerfile ИИ рекомендовано разделить его на два но это не проверялось.
В этом случае Dockerfile получается максимально простой и читается как «подготовил среду → запустил скрипт».

Dockerfile
```
FROM ubuntu:24.04

RUN apt-get update && apt-get install -y \
    wget \
    devscripts \
    build-essential \
    fakeroot \
    dh-make \
    quilt \
    libpcre3-dev \
    zlib1g-dev \
    libssl-dev \
    openssl \
    dh-autoreconf \
    debhelper \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

COPY build.sh /build/build.sh
RUN chmod +x /build/build.sh

# Вся сборка — одной командой
RUN /build/build.sh
```

А ниже приведён готовый build.sh, который выносит всю «ручную» логику из Dockerfile. Внутри него — ровно те команды, которые ты делал бы в терминале на чистой ВМ, плюс диагностика.

build.sh
```
#!/usr/bin/env bash
set -euo pipefail

WORKDIR="/build"
SRC_DIR="nginx-1.24.0"
ORIG_ARCHIVE="nginx_1.24.0.orig.tar.xz"
DEB_PKG="nginx_1.24.0-1_amd64.deb"
DBGSYM_PKG="nginx-dbgsym_1.24.0-1_amd64.ddeb"

cd "$WORKDIR"

echo "=== 1. Скачивание исходников ==="
wget -O "${SRC_DIR}.tar.gz" "https://nginx.org/download/${SRC_DIR}.tar.gz"
[ -s "${SRC_DIR}.tar.gz" ] || { echo "ERROR: архив пуст"; exit 1; }

echo "=== 2. Распаковка и проверка ==="
tar xzf "${SRC_DIR}.tar.gz"
rm "${SRC_DIR}.tar.gz"
[ -d "$SRC_DIR" ] || { echo "ERROR: папка $SRC_DIR не найдена"; exit 1; }

echo "=== 3. Создание orig-архива ==="
tar --transform 's,^,nginx-1.24.0/,' -cf "$ORIG_ARCHIVE" "$SRC_DIR"

# Диагностика архива
ls -lh "$ORIG_ARCHIVE"
file "$ORIG_ARCHIVE"
tar -tf "$ORIG_ARCHIVE" | head -n 10

echo "=== 4. Создание пользователя для debuild ==="
# debuild не любит root, поэтому нужен обычный пользователь
if ! id -u kosogor >/dev/null 2>&1; then
    useradd -m -s /bin/bash kosogor
fi

echo "=== 5. Запуск dh_make от имени kosogor ==="
export USER="kosogor"
export LOGNAME="kosogor"
HOME="/home/kosogor"

cd "$WORKDIR/$SRC_DIR"
su - kosogor -c "dh_make -s -y -e kosogor@example.com"

echo "=== 6. Перезапись файлов debian/ ==="
cd "$WORKDIR/$SRC_DIR"

cat > debian/control <<EOF
Source: nginx
Section: web
Priority: optional
Maintainer: Eugene Kosogorov <kosogor@example.com>
Build-Depends: debhelper (>= 13), build-essential, libpcre3-dev, zlib1g-dev, libssl-dev, openssl, dh-autoreconf
Standards-Version: 4.5.1

Package: nginx
Architecture: any
Depends: \${shlibs:Depends}, \${misc:Depends}
Description: nginx web server (minimal build)
 A high performance reverse proxy and web server.
EOF

cat > debian/rules <<'EOF'
#!/usr/bin/make -f
%:
	dh $@
override_dh_auto_configure:
	./configure --prefix=/usr \
		--sbin-path=/usr/sbin/nginx \
		--conf-path=/etc/nginx/nginx.conf \
		--error-log-path=/var/log/nginx/error.log \
		--http-log-path=/var/log/nginx/access.log \
		--with-http_ssl_module \
		--with-pcre
override_dh_auto_build:
	make
override_dh_auto_test:
override_dh_auto_install:
	make install DESTDIR=$(CURDIR)/debian/tmp
EOF
chmod +x debian/rules

echo "13" > debian/compat

cat > debian/install <<EOF
usr/html /usr/share/nginx
usr/sbin/nginx usr/sbin/
etc/nginx etc/
EOF

# changelog обязателен для debuild
cat > debian/changelog <<EOF
nginx (1.24.0-1) UNRELEASED; urgency=medium

  * Minimal build for NFS test environment
  * Custom rules for configure/build/install

 -- Eugene Kosogorov <kosogor@example.com>  $(date -R)
EOF

echo "=== 7. Диагностика перед сборкой ==="
pwd
ls -l debian/
head -n 5 debian/changelog

echo "=== 8. Сборка пакета ==="
# Запускаем debuild из папки с debian/ (то есть из /build/nginx-1.24.0)
cd "$WORKDIR/$SRC_DIR"
debuild -us -uc -b

echo "=== 9. Копирование результатов в WORKDIR ==="
cd "$WORKDIR"
cp "../$SRC_DIR/$DEB_PKG" . 2>/dev/null || true
cp "../$SRC_DIR/$DBGSYM_PKG" . 2>/dev/null || true

echo "=== Готово ==="
ls -lh *.deb *.ddeb 2>/dev/null || echo "Пакеты не найдены"
```
