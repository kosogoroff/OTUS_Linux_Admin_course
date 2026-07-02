# Занятие 29.06.2026 "С чего начинается Linux"
## Домашнее задание :
Обновление ядра системы
### Цель:
научиться обновлять ядро в ОС Linux
### Задание

1. Запустите ВМ c Ubuntu.

2. Обновите ядро ОС на новейшую стабильную версию из mainline-репозитория.
   
4. Оформите отчет в README-файле в GitHub-репозитории.

### Задание со звездочкой

Собрать ядро самостоятельно из исходных кодов.

## Решение

Исходная конфигурация:

Host OS - REDOS 7.3.4 , KVM версии :
```
virsh -V
Утилита командной строки virsh для libvirt 10.8.0
```
### 1. Установка и запуск рекомендованной в методичке Ubuntu 24.04 LTS  в созданную KVM ВМ  (создание самой ВМ не привожу)

Для установки скачан рекомендованный дистрибутив ubuntu-24.04.4-live-server-amd64.iso  с сайта https://releases.ubuntu.com/24.04/

*Суть ошибки:* после установки чистой ОС с образа в ней не работает обновление:
команда 'sudo apt update' , а также другие команды установки пакетов возвращают ошибку:

```
Некорректная запись в строке 1 файла "sources /etc/apt/sources.list.d/ubuntu.sources (URI)  <...>
```
Решение проблемы заняло почти день (!) - это ещё ИИ помогал при поиске в Google и Yandex.

*Суть проблемы:* Эта ошибка возникает из-за того, что начиная с версии Ubuntu 24.04 LTS (именно с этой !), формат хранения репозиториев по умолчанию изменился со старого одномерного текстового (sources.list) на новый многострочный формат DEB822.

В старом методе репозитории хранились в файле /etc/apt/sources.list , но в версии Ubuntu 24.04 LTS в данном файле
остаётся только один комментарий:

```
# cat /etc/apt/sources.list
# Ubuntu sources have moved to /etc/apt/sources.list.d/ubuntu.sources
```

А в файле /etc/apt/sources.list.d/ubuntu.sources есть ошибка - отсутствует URI в описании основного репозитория :

```
# cat /etc/apt/sources.list.d/ubuntu.sources
Types: deb
URIs:
Suites: noble noble-updates noble-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: http://security.ubuntu.com/ubuntu/
Suites: noble-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
#
```

После исправления ошибки (добавления ссылки на репозиторий) :

```
$ cat /etc/apt/sources.list.d/ubuntu.sources
Types: deb
URIs: http://archive.ubuntu.com/ubuntu/ 
Suites: noble noble-updates noble-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: http://security.ubuntu.com/ubuntu/
Suites: noble-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
$ 
```

apt начинает работать и обновлять и устанавливать пакеты.

Даже при наличии правильных репозиториев в старом однострочном формате в файле */etc/apt/sources.list*
apt всё равно не работает и выдаёт первоначальную ошибку из-за ошибки в файле */etc/apt/sources.list.d/ubuntu.sources*

*Примечание:* везде рекомендуется обязательно использовать описание репозиториев либо старым, либо новым методом,
не смешивая их и тем более не дублируя репозитории в обоих файлах, чтобы избежать конфликта версий пакетов.


### Вывод: 
По-моему, разработчики Ubuntu Linux попутали берега: чтобы в самой новой рекомендованной к установке версии 24.04 LTS
из коробки была ошибка, ломающая все обновления - это немного слишком  ))

### 2. Обновление ядра ОС на новейшую стабильную версию из mainline-репозитория

Первоначальная конфигурация:

```
$ uname -r
6.8.0-100-generic
$ uname -p
x86_64
$ cat /etc/os-release
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
$
/kernel$ ls -al /boot
total 96812
drwxr-xr-x  4 root root     4096 июн 25 06:31 .
drwxr-xr-x 23 root root     4096 июн 25 06:31 ..
-rw-r--r--  1 root root   287599 янв 13 13:56 config-6.8.0-100-generic
drwxr-xr-x  5 root root     4096 июн 25 06:31 grub
lrwxrwxrwx  1 root root       28 июн 25 06:31 initrd.img -> initrd.img-6.8.0-100-generic
-rw-r--r--  1 root root 74658580 июн 25 06:31 initrd.img-6.8.0-100-generic
lrwxrwxrwx  1 root root       28 июн 25 06:31 initrd.img.old -> initrd.img-6.8.0-100-generic
drwx------  2 root root    16384 июн 25 06:29 lost+found
-rw-------  1 root root  9120274 янв 13 13:56 System.map-6.8.0-100-generic
lrwxrwxrwx  1 root root       25 июн 25 06:31 vmlinuz -> vmlinuz-6.8.0-100-generic
-rw-------  1 root root 15030664 янв 13 14:42 vmlinuz-6.8.0-100-generic
lrwxrwxrwx  1 root root       25 июн 25 06:31 vmlinuz.old -> vmlinuz-6.8.0-100-generic
/kernel$

```



Для обновления скачал последнюю имеющуюся версию 6.19.14:

```
kosogor@kosogor:~$ mkdir kernel && cd kernel
kosogor@kosogor:~/kernel$ 
kosogor@kosogor:~/kernel$ wget https://kernel.ubuntu.com/mainline/v6.19.14/amd64/linux-headers-6.19.14-061914-generic_6.19.14-061914.202604221411_amd64.deb
--2026-07-02 07:26:20--  https://kernel.ubuntu.com/mainline/v6.19.14/amd64/linux-headers-6.19.14-061914-generic_6.19.14-061914.202604221411_amd64.deb
Resolving kernel.ubuntu.com (kernel.ubuntu.com)... 185.125.189.75, 185.125.189.74, 185.125.189.76
Connecting to kernel.ubuntu.com (kernel.ubuntu.com)|185.125.189.75|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 4030966 (3,8M) [application/x-debian-package]
Saving to: ‘linux-headers-6.19.14-061914-generic_6.19.14-061914.202604221411_amd64.deb’

linux-headers-6.19.14-061914-g 100%[=================================================>]   3,84M  3,12MB/s    in 1,2s    

2026-07-02 07:26:23 (3,12 MB/s) - ‘linux-headers-6.19.14-061914-generic_6.19.14-061914.202604221411_amd64.deb’ saved [4030966/4030966]

kosogor@kosogor:~/kernel$ wget https://kernel.ubuntu.com/mainline/v6.19.14/amd64/linux-headers-6.19.14-061914_6.19.14-061914.202604221411_all.deb
--2026-07-02 07:26:44--  https://kernel.ubuntu.com/mainline/v6.19.14/amd64/linux-headers-6.19.14-061914_6.19.14-061914.202604221411_all.deb
Resolving kernel.ubuntu.com (kernel.ubuntu.com)... 185.125.189.75, 185.125.189.74, 185.125.189.76
Connecting to kernel.ubuntu.com (kernel.ubuntu.com)|185.125.189.75|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 14628194 (14M) [application/x-debian-package]
Saving to: ‘linux-headers-6.19.14-061914_6.19.14-061914.202604221411_all.deb’

linux-headers-6.19.14-061914_6 100%[=================================================>]  13,95M  4,59MB/s    in 3,0s    

2026-07-02 07:26:48 (4,59 MB/s) - ‘linux-headers-6.19.14-061914_6.19.14-061914.202604221411_all.deb’ saved [14628194/14628194]

kosogor@kosogor:~/kernel$ wget https://kernel.ubuntu.com/mainline/v6.19.14/amd64/linux-image-unsigned-6.19.14-061914-generic_6.19.14-061914.202604221411_amd64.deb
--2026-07-02 07:27:09--  https://kernel.ubuntu.com/mainline/v6.19.14/amd64/linux-image-unsigned-6.19.14-061914-generic_6.19.14-061914.202604221411_amd64.deb
Resolving kernel.ubuntu.com (kernel.ubuntu.com)... 185.125.189.76, 185.125.189.74, 185.125.189.75
Connecting to kernel.ubuntu.com (kernel.ubuntu.com)|185.125.189.76|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 17019072 (16M) [application/x-debian-package]
Saving to: ‘linux-image-unsigned-6.19.14-061914-generic_6.19.14-061914.202604221411_amd64.deb’

linux-image-unsigned-6.19.14-0 100%[=================================================>]  16,23M  4,36MB/s    in 4,3s    

2026-07-02 07:27:14 (3,80 MB/s) - ‘linux-image-unsigned-6.19.14-061914-generic_6.19.14-061914.202604221411_amd64.deb’ saved [17019072/17019072]

kosogor@kosogor:~/kernel$ wget https://kernel.ubuntu.com/mainline/v6.19.14/amd64/linux-modules-6.19.14-061914-generic_6.19.14-061914.202604221411_amd64.deb
--2026-07-02 07:27:35--  https://kernel.ubuntu.com/mainline/v6.19.14/amd64/linux-modules-6.19.14-061914-generic_6.19.14-061914.202604221411_amd64.deb
Resolving kernel.ubuntu.com (kernel.ubuntu.com)... 185.125.189.76, 185.125.189.74, 185.125.189.75
Connecting to kernel.ubuntu.com (kernel.ubuntu.com)|185.125.189.76|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 167188672 (159M) [application/x-debian-package]
Saving to: ‘linux-modules-6.19.14-061914-generic_6.19.14-061914.202604221411_amd64.deb’

linux-modules-6.19.14-061914-g 100%[=================================================>] 159,44M  5,74MB/s    in 31s     

2026-07-02 07:28:07 (5,20 MB/s) - ‘linux-modules-6.19.14-061914-generic_6.19.14-061914.202604221411_amd64.deb’ saved [167188672/167188672]

kosogor@kosogor:~/kernel$
```

По время установки скачаных пакетов возникает ошибка при установке пакета linux-image-unsigned-6.19.14-061914-generic_6.19.14-061914.202604221411_amd64.deb .
В результате пакет устанавливается криво в папке /boot, и переключения на него не происходит:

```
kosogor@kosogor:~/kernel$ sudo dpkg -i *.deb
Выбор ранее не выбранного пакета linux-headers-6.19.14-061914.
(Чтение базы данных … на данный момент установлено 84633 файла и каталога.)
Подготовка к распаковке linux-headers-6.19.14-061914_6.19.14-061914.202604221411_all.deb …
Распаковывается linux-headers-6.19.14-061914 (6.19.14-061914.202604221411) …
Выбор ранее не выбранного пакета linux-headers-6.19.14-061914-generic.
Подготовка к распаковке linux-headers-6.19.14-061914-generic_6.19.14-061914.202604221411_amd64.deb …
Распаковывается linux-headers-6.19.14-061914-generic (6.19.14-061914.202604221411) …
Выбор ранее не выбранного пакета linux-image-unsigned-6.19.14-061914-generic.
Подготовка к распаковке linux-image-unsigned-6.19.14-061914-generic_6.19.14-061914.202604221411_amd64.deb …
run-parts: missing operand
Try `run-parts --help' for more information.
dpkg: ошибка при обработке архива linux-image-unsigned-6.19.14-061914-generic_6.19.14-061914.202604221411_amd64.deb (--install):
 подпроцесс из пакета linux-image-unsigned-6.19.14-061914-generic новый сценарий pre-installation возвратил код ошибки 1
run-parts: missing operand
Try `run-parts --help' for more information.
dpkg: ошибка при очистке:
 подпроцесс из пакета linux-image-unsigned-6.19.14-061914-generic новый сценарий post-removal возвратил код ошибки 1
Выбор ранее не выбранного пакета linux-modules-6.19.14-061914-generic.
Подготовка к распаковке linux-modules-6.19.14-061914-generic_6.19.14-061914.202604221411_amd64.deb …
Распаковывается linux-modules-6.19.14-061914-generic (6.19.14-061914.202604221411) …
Настраивается пакет linux-headers-6.19.14-061914 (6.19.14-061914.202604221411) …
Настраивается пакет linux-headers-6.19.14-061914-generic (6.19.14-061914.202604221411) …
Настраивается пакет linux-modules-6.19.14-061914-generic (6.19.14-061914.202604221411) …
При обработке следующих пакетов произошли ошибки:
 linux-image-unsigned-6.19.14-061914-generic_6.19.14-061914.202604221411_amd64.deb
kosogor@kosogor:~/kernel$
kosogor@kosogor:~/kernel$ ls -al /boot
total 107676
drwxr-xr-x  4 root root     4096 июл  2 07:29 .
drwxr-xr-x 23 root root     4096 июн 25 06:31 ..
-rw-r--r--  1 root root   306720 апр 22 14:11 config-6.19.14-061914-generic
-rw-r--r--  1 root root   287599 янв 13 13:56 config-6.8.0-100-generic
drwxr-xr-x  5 root root     4096 июн 25 06:31 grub
lrwxrwxrwx  1 root root       28 июн 25 06:31 initrd.img -> initrd.img-6.8.0-100-generic
-rw-r--r--  1 root root 74658580 июн 25 06:31 initrd.img-6.8.0-100-generic
lrwxrwxrwx  1 root root       28 июн 25 06:31 initrd.img.old -> initrd.img-6.8.0-100-generic
drwx------  2 root root    16384 июн 25 06:29 lost+found
-rw-------  1 root root 10817371 апр 22 14:11 System.map-6.19.14-061914-generic
-rw-------  1 root root  9120274 янв 13 13:56 System.map-6.8.0-100-generic
lrwxrwxrwx  1 root root       25 июн 25 06:31 vmlinuz -> vmlinuz-6.8.0-100-generic
-rw-------  1 root root 15030664 янв 13 14:42 vmlinuz-6.8.0-100-generic
lrwxrwxrwx  1 root root       25 июн 25 06:31 vmlinuz.old -> vmlinuz-6.8.0-100-generic
kosogor@kosogor:~/kernel$
```

Удалил/зачистил все установленные пакеты

