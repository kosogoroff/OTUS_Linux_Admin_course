# Занятие 29.06.2026 "С чего начинается Linux"
## Домашнее задание :
Обновление ядра системы
### Цель:
научиться обновлять ядро в ОС Linux
### Задание

1. Запустите ВМ c Ubuntu.

2. Обновите ядро ОС на новейшую стабильную версию из mainline-репозитория.
   
3. Оформите отчет в README-файле в GitHub-репозитории.

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

<img width="1319" height="929" alt="изображение" src="https://github.com/user-attachments/assets/6236ba36-e0a0-46fb-ae03-3d3840e7d3ae" />



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
В результате пакет устанавливается криво/не полностью - и переключения на него не происходит:

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

В результате после перезагрузки на новое установленное ядро система не переключается, новое ядро
в списке GRUB не появляется.

Удалил/зачистил установленные пакеты 6.19.14 , скачал и установил пакеты версии 6.18.37 - результат аналогичный:
один из четырёх пакетов, пакет linux-image-unsigned-6.18.37-061837-generic_6.18.37-061837.202606271054_amd64.deb устанавливается с ошибкой криво,
В результате после перезагрузки на новое установленное ядро система не переключается, новое ядро 6.18.37
в списке GRUB не появляется:

```
kosogor@kosogor:~/kernel$ sudo dpkg -i *.deb
Выбор ранее не выбранного пакета linux-headers-6.18.37-061837.
(Чтение базы данных … на данный момент установлено 106103 файла и каталога.)
Подготовка к распаковке linux-headers-6.18.37-061837_6.18.37-061837.202606271054_all.deb …
Распаковывается linux-headers-6.18.37-061837 (6.18.37-061837.202606271054) …
Выбор ранее не выбранного пакета linux-headers-6.18.37-061837-generic.
Подготовка к распаковке linux-headers-6.18.37-061837-generic_6.18.37-061837.202606271054_amd64.deb …
Распаковывается linux-headers-6.18.37-061837-generic (6.18.37-061837.202606271054) …
Выбор ранее не выбранного пакета linux-image-unsigned-6.18.37-061837-generic.
Подготовка к распаковке linux-image-unsigned-6.18.37-061837-generic_6.18.37-061837.202606271054_amd64.deb …
run-parts: missing operand
Try `run-parts --help' for more information.
dpkg: ошибка при обработке архива linux-image-unsigned-6.18.37-061837-generic_6.18.37-061837.202606271054_amd64.deb (--install):
 подпроцесс из пакета linux-image-unsigned-6.18.37-061837-generic новый сценарий pre-installation возвратил код ошибки 1
run-parts: missing operand
Try `run-parts --help' for more information.
dpkg: ошибка при очистке:
 подпроцесс из пакета linux-image-unsigned-6.18.37-061837-generic новый сценарий post-removal возвратил код ошибки 1
Выбор ранее не выбранного пакета linux-modules-6.18.37-061837-generic.
Подготовка к распаковке linux-modules-6.18.37-061837-generic_6.18.37-061837.202606271054_amd64.deb …
Распаковывается linux-modules-6.18.37-061837-generic (6.18.37-061837.202606271054) …
Настраивается пакет linux-headers-6.18.37-061837 (6.18.37-061837.202606271054) …
Настраивается пакет linux-headers-6.18.37-061837-generic (6.18.37-061837.202606271054) …
Настраивается пакет linux-modules-6.18.37-061837-generic (6.18.37-061837.202606271054) …
При обработке следующих пакетов произошли ошибки:
 linux-image-unsigned-6.18.37-061837-generic_6.18.37-061837.202606271054_amd64.deb
kosogor@kosogor:~/kernel$
```

Вычистил все пакеты 6.18.37 и 6.19.14 (листинг удалений длинный - приведён частично) :

```
kosogor@kosogor:~/kernel$ sudo dpkg -P linux-headers-6.18.37-061837-generic
(Чтение базы данных … на данный момент установлено 116817 файлов и каталогов.)
Удаляется linux-headers-6.18.37-061837-generic (6.18.37-061837.202606271054) …
dpkg: предупреждение: при удалении linux-headers-6.18.37-061837-generic каталог «/usr/lib/modules» не пуст, поэтому не удалён
kosogor@kosogor:~/kernel$ sudo dpkg -P linux-headers-6.18.37-061837
(Чтение базы данных … на данный момент установлен 105951 файл и каталог.)
Удаляется linux-headers-6.18.37-061837 (6.18.37-061837.202606271054) …
kosogor@kosogor:~/kernel$
kosogor@kosogor:~/kernel$ sudo dpkg --force-all -P linux-modules-6.19.14-061914-generic
dpkg: предупреждение: игнорируется запрос на удаление неустановленного пакета linux-modules-6.19.14-061914-generic
kosogor@kosogor:~/kernel$
kosogor@kosogor:~/kernel$ sudo dpkg -l | grep 6.19
pHR linux-image-unsigned-6.19.14-061914-generic 6.19.14-061914.202604221411             amd64        (описание недоступно)
ii  lshw                                        02.19.git.2021.06.19.996aaad9c7-2build3 amd64        information about hardware configuration
kosogor@kosogor:~/kernel$ sudo dpkg --force-all -P linux-image-unsigned-6.19.14-061914-generic
dpkg: предупреждение: проблема игнорируется, поскольку задан параметр --force:
dpkg: предупреждение: пакет абсолютно неработоспособен; перед попыткой удаления
 его следует переустановить
(Чтение базы данных … на данный момент установлено 124943 файла и каталога.)
Удаляется linux-image-unsigned-6.19.14-061914-generic (6.19.14-061914.202604221411) …
kosogor@kosogor:~/kernel$ 
kosogor@kosogor:~/kernel$ 
kosogor@kosogor:~/kernel$ sudo dpkg -l | grep 6.19
ii  lshw                                        02.19.git.2021.06.19.996aaad9c7-2build3 amd64        information about hardware configuration
kosogor@kosogor:~/kernel$
kosogor@kosogor:~/kernel$ ll /usr/lib/modules/
total 20
drwxr-xr-x  5 root root 4096 июл  2 08:01 ./
drwxr-xr-x 78 root root 4096 июн 25 07:25 ../
drwxr-xr-x  2 root root 4096 июл  2 09:00 6.18.37-061837-generic/
drwxr-xr-x  2 root root 4096 июл  2 07:51 6.19.14-061914-generic/
drwxr-xr-x  5 root root 4096 июн 25 06:31 6.8.0-100-generic/

kosogor@kosogor:~/kernel$ sudo rm -rf /usr/lib/modules/6.18.37-061837-generic/
kosogor@kosogor:~/kernel$ sudo rm -rf /usr/lib/modules/6.19.14-061914-generic/
kosogor@kosogor:~/kernel$ 
```

Далее скачал и установил пакеты версии 6.13.2 рекомендованные в методичке - данные пакеты установились без ошибок:

```
kosogor@kosogor:~/kernel$ wget https://kernel.ubuntu.com/mainline/v6.13.2/amd64/linux-headers-6.13.2-061302-generic_6.13.2-061302.202502081010_amd64.deb
--2026-07-02 09:13:53--  https://kernel.ubuntu.com/mainline/v6.13.2/amd64/linux-headers-6.13.2-061302-generic_6.13.2-061302.202502081010_amd64.deb
Resolving kernel.ubuntu.com (kernel.ubuntu.com)... 185.125.189.75, 185.125.189.76, 185.125.189.74
Connecting to kernel.ubuntu.com (kernel.ubuntu.com)|185.125.189.75|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 3694072 (3,5M) [application/x-debian-package]
Saving to: ‘linux-headers-6.13.2-061302-generic_6.13.2-061302.202502081010_amd64.deb’

linux-headers-6.13.2-061302-generic_6.13 100%[================================================================================>]   3,52M  1,93MB/s    in 1,8s    

2026-07-02 09:13:56 (1,93 MB/s) - ‘linux-headers-6.13.2-061302-generic_6.13.2-061302.202502081010_amd64.deb’ saved [3694072/3694072]

kosogor@kosogor:~/kernel$ wget https://kernel.ubuntu.com/mainline/v6.13.2/amd64/linux-headers-6.13.2-061302_6.13.2-061302.201302.202502081010_amd64.deb
--2026-07-02 09:14:38--  https://kernel.ubuntu.com/mainline/v6.13.2/amd64/linux-headers-6.13.2-061302_6.13.2-061302.201302.202502081010_amd64.deb
Resolving kernel.ubuntu.com (kernel.ubuntu.com)... 185.125.189.76, 185.125.189.75, 185.125.189.74
Connecting to kernel.ubuntu.com (kernel.ubuntu.com)|185.125.189.76|:443... connected.
HTTP request sent, awaiting response... 404 Not Found
2026-07-02 09:14:38 ERROR 404: Not Found.

kosogor@kosogor:~/kernel$ wget https://kernel.ubuntu.com/mainline/v6.13.2/amd64/linux-headers-6.13.2-061302_6.13.2-061302.202502081010_all.deb
--2026-07-02 09:21:36--  https://kernel.ubuntu.com/mainline/v6.13.2/amd64/linux-headers-6.13.2-061302_6.13.2-061302.202502081010_all.deb
Resolving kernel.ubuntu.com (kernel.ubuntu.com)... 185.125.189.76, 185.125.189.75, 185.125.189.74
Connecting to kernel.ubuntu.com (kernel.ubuntu.com)|185.125.189.76|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 13875326 (13M) [application/x-debian-package]
Saving to: ‘linux-headers-6.13.2-061302_6.13.2-061302.202502081010_all.deb’

linux-headers-6.13.2-061302_6.13.2-06130 100%[================================================================================>]  13,23M  4,50MB/s    in 2,9s    

2026-07-02 09:21:40 (4,50 MB/s) - ‘linux-headers-6.13.2-061302_6.13.2-061302.202502081010_all.deb’ saved [13875326/13875326]

kosogor@kosogor:~/kernel$ wget https://kernel.ubuntu.com/mainline/v6.13.2/amd64/linux-image-unsigned-6.13.2-061302-generic_6.13.2-061302.202502081010_amd64.deb
--2026-07-02 09:21:59--  https://kernel.ubuntu.com/mainline/v6.13.2/amd64/linux-image-unsigned-6.13.2-061302-generic_6.13.2-061302.202502081010_amd64.deb
Resolving kernel.ubuntu.com (kernel.ubuntu.com)... 185.125.189.75, 185.125.189.74, 185.125.189.76
Connecting to kernel.ubuntu.com (kernel.ubuntu.com)|185.125.189.75|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 15677632 (15M) [application/x-debian-package]
Saving to: ‘linux-image-unsigned-6.13.2-061302-generic_6.13.2-061302.202502081010_amd64.deb’

linux-image-unsigned-6.13.2-061302-gener 100%[================================================================================>]  14,95M  4,59MB/s    in 3,3s    

2026-07-02 09:22:03 (4,59 MB/s) - ‘linux-image-unsigned-6.13.2-061302-generic_6.13.2-061302.202502081010_amd64.deb’ saved [15677632/15677632]

kosogor@kosogor:~/kernel$ wget https://kernel.ubuntu.com/mainline/v6.13.2/amd64/linux-modules-6.13.2-061302-generic_6.13.2-061302.202502081010_amd64.deb
--2026-07-02 09:22:17--  https://kernel.ubuntu.com/mainline/v6.13.2/amd64/linux-modules-6.13.2-061302-generic_6.13.2-061302.202502081010_amd64.deb
Resolving kernel.ubuntu.com (kernel.ubuntu.com)... 185.125.189.74, 185.125.189.76, 185.125.189.75
Connecting to kernel.ubuntu.com (kernel.ubuntu.com)|185.125.189.74|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 184576192 (176M) [application/x-debian-package]
Saving to: ‘linux-modules-6.13.2-061302-generic_6.13.2-061302.202502081010_amd64.deb’

linux-modules-6.13.2-061302-generic_6.13 100%[================================================================================>] 176,03M  5,44MB/s    in 33s     

2026-07-02 09:22:51 (5,38 MB/s) - ‘linux-modules-6.13.2-061302-generic_6.13.2-061302.202502081010_amd64.deb’ saved [184576192/184576192]

kosogor@kosogor:~/kernel$ ll
total 212732
drwxrwxr-x 2 kosogor kosogor      4096 июл  2 09:22 ./
drwxr-x--- 5 kosogor kosogor      4096 июл  2 07:25 ../
-rw-rw-r-- 1 kosogor kosogor  13875326 фев 15  2025 linux-headers-6.13.2-061302_6.13.2-061302.202502081010_all.deb
-rw-rw-r-- 1 kosogor kosogor   3694072 фев 15  2025 linux-headers-6.13.2-061302-generic_6.13.2-061302.202502081010_amd64.deb
-rw-rw-r-- 1 kosogor kosogor  15677632 фев 15  2025 linux-image-unsigned-6.13.2-061302-generic_6.13.2-061302.202502081010_amd64.deb
-rw-rw-r-- 1 kosogor kosogor 184576192 фев 15  2025 linux-modules-6.13.2-061302-generic_6.13.2-061302.202502081010_amd64.deb
kosogor@kosogor:~/kernel$ sudo dpkg -i *.deb
Выбор ранее не выбранного пакета linux-headers-6.13.2-061302.
(Чтение базы данных … на данный момент установлено 84633 файла и каталога.)
Подготовка к распаковке linux-headers-6.13.2-061302_6.13.2-061302.202502081010_all.deb …
Распаковывается linux-headers-6.13.2-061302 (6.13.2-061302.202502081010) …
Выбор ранее не выбранного пакета linux-headers-6.13.2-061302-generic.
Подготовка к распаковке linux-headers-6.13.2-061302-generic_6.13.2-061302.202502081010_amd64.deb …
Распаковывается linux-headers-6.13.2-061302-generic (6.13.2-061302.202502081010) …
Выбор ранее не выбранного пакета linux-image-unsigned-6.13.2-061302-generic.
Подготовка к распаковке linux-image-unsigned-6.13.2-061302-generic_6.13.2-061302.202502081010_amd64.deb …
Распаковывается linux-image-unsigned-6.13.2-061302-generic (6.13.2-061302.202502081010) …
Выбор ранее не выбранного пакета linux-modules-6.13.2-061302-generic.
Подготовка к распаковке linux-modules-6.13.2-061302-generic_6.13.2-061302.202502081010_amd64.deb …
Распаковывается linux-modules-6.13.2-061302-generic (6.13.2-061302.202502081010) …
Настраивается пакет linux-headers-6.13.2-061302 (6.13.2-061302.202502081010) …
Настраивается пакет linux-headers-6.13.2-061302-generic (6.13.2-061302.202502081010) …
Настраивается пакет linux-modules-6.13.2-061302-generic (6.13.2-061302.202502081010) …
Настраивается пакет linux-image-unsigned-6.13.2-061302-generic (6.13.2-061302.202502081010) …
I: /boot/vmlinuz is now a symlink to vmlinuz-6.13.2-061302-generic
I: /boot/initrd.img is now a symlink to initrd.img-6.13.2-061302-generic
Обрабатываются триггеры для linux-image-unsigned-6.13.2-061302-generic (6.13.2-061302.202502081010) …
/etc/kernel/postinst.d/initramfs-tools:
update-initramfs: Generating /boot/initrd.img-6.13.2-061302-generic
/etc/kernel/postinst.d/zz-update-grub:
Sourcing file `/etc/default/grub'
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-6.13.2-061302-generic
Found initrd image: /boot/initrd.img-6.13.2-061302-generic
Found linux image: /boot/vmlinuz-6.8.0-100-generic
Found initrd image: /boot/initrd.img-6.8.0-100-generic
Warning: os-prober will not be executed to detect other bootable partitions.
Systems on them will not be added to the GRUB boot configuration.
Check GRUB_DISABLE_OS_PROBER documentation entry.
Adding boot menu entry for UEFI Firmware Settings ...
done
kosogor@kosogor:~/kernel$ ll /boot
total 203500
drwxr-xr-x  4 root root     4096 июл  2 09:23 ./
drwxr-xr-x 23 root root     4096 июн 25 06:31 ../
-rw-r--r--  1 root root   294303 фев  8  2025 config-6.13.2-061302-generic
-rw-r--r--  1 root root   287599 янв 13 13:56 config-6.8.0-100-generic
drwxr-xr-x  5 root root     4096 июл  2 09:23 grub/
lrwxrwxrwx  1 root root       32 июл  2 09:23 initrd.img -> initrd.img-6.13.2-061302-generic
-rw-r--r--  1 root root 83362512 июл  2 09:23 initrd.img-6.13.2-061302-generic
-rw-r--r--  1 root root 74658580 июн 25 06:31 initrd.img-6.8.0-100-generic
lrwxrwxrwx  1 root root       28 июн 25 06:31 initrd.img.old -> initrd.img-6.8.0-100-generic
drwx------  2 root root    16384 июн 25 06:29 lost+found/
-rw-------  1 root root  9934398 фев  8  2025 System.map-6.13.2-061302-generic
-rw-------  1 root root  9120274 янв 13 13:56 System.map-6.8.0-100-generic
lrwxrwxrwx  1 root root       29 июл  2 09:23 vmlinuz -> vmlinuz-6.13.2-061302-generic
-rw-------  1 root root 15647232 фев  8  2025 vmlinuz-6.13.2-061302-generic
-rw-------  1 root root 15030664 янв 13 14:42 vmlinuz-6.8.0-100-generic
lrwxrwxrwx  1 root root       25 июн 25 06:31 vmlinuz.old -> vmlinuz-6.8.0-100-generic
kosogor@kosogor:~/kernel$ 
kosogor@kosogor:~/kernel$ 
kosogor@kosogor:~/kernel$ sudo update-grub
Sourcing file `/etc/default/grub'
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-6.13.2-061302-generic
Found initrd image: /boot/initrd.img-6.13.2-061302-generic
Found linux image: /boot/vmlinuz-6.8.0-100-generic
Found initrd image: /boot/initrd.img-6.8.0-100-generic
Warning: os-prober will not be executed to detect other bootable partitions.
Systems on them will not be added to the GRUB boot configuration.
Check GRUB_DISABLE_OS_PROBER documentation entry.
Adding boot menu entry for UEFI Firmware Settings ...
done
kosogor@kosogor:~/kernel$ 
kosogor@kosogor:~/kernel$ 
kosogor@kosogor:~/kernel$ sudo grub-set-default 0
kosogor@kosogor:~/kernel$ 
kosogor@kosogor:~/kernel$ sudo reboot
```

После перезагрузки ОС переключилась на обновлённое ядро 6.13.2 :

```
kosogor@kosogor:~$ uname -r
6.13.2-061302-generic
kosogor@kosogor:~$
```

В меню загрузки GRUB ядро 6.13.2 также появилось.

## Разборки с 6.19.14 (задача со звёздочкой :) )

Далее попытался разобраться, почему не устанавливаются последние ядра.
Применил следующие рекомендации из Интернета (поиск причин в том числе с применением ИИ от Google ) :

### 1. Причина ошибки: скрипты обслуживания пакета ядра (preinst/postrm) вызывают run-parts с указанием каталога, но если его нет, run-parts получает пустую строку, что приводит к ошибке «missing operand».

*Решение:* создать каталоги, в которых будут выполняться скрипты обслуживания ядра:

/etc/kernel/preinst.d , /etc/kernel/postinst.d , /etc/kernel/prerm.d , /etc/kernel/postrm.d . 

Для этого нужно выполнить команду:

sudo mkdir -p /etc/kernel/preinst.d /etc/kernel/postinst.d /etc/kernel/prerm.d /etc/kernel/postrm.d

*Результат:*

В перечне директорий не хватало одной после выполнения команды одна директория добавилась: 
```
kosogor@kosogor:~/kernel$ ll /etc/kernel/
total 24
drwxr-xr-x   6 root root 4096 июн 25 06:30 ./
drwxr-xr-x 108 root root 4096 июн 25 07:26 ../
drwxr-xr-x   2 root root 4096 ноя 25  2025 install.d/
drwxr-xr-x   2 root root 4096 июн 25 06:30 postinst.d/
drwxr-xr-x   2 root root 4096 июн 25 06:30 postrm.d/
drwxr-xr-x   2 root root 4096 июн 25 06:30 preinst.d/
kosogor@kosogor:~/
sudo mkdir -p /etc/kernel/preinst.d /etc/kernel/postinst.d /etc/kernel/prerm.d /etc/kernel/postrm.d
kosogor@kosogor:~/kernel$ ll /etc/kernel/
total 28
drwxr-xr-x   7 root root 4096 июл  2 08:41 ./
drwxr-xr-x 108 root root 4096 июн 25 07:26 ../
drwxr-xr-x   2 root root 4096 ноя 25  2025 install.d/
drwxr-xr-x   2 root root 4096 июн 25 06:30 postinst.d/
drwxr-xr-x   2 root root 4096 июн 25 06:30 postrm.d/
drwxr-xr-x   2 root root 4096 июн 25 06:30 preinst.d/
drwxr-xr-x   2 root root 4096 июл  2 08:41 prerm.d/
kosogor@kosogor:~/kernel$
```

После этого изменения повторно попытался установить пакеты ядра 6.19.14 - результат тот же, ошибка.

*Вывод:* не помогло (либо помогло частично, но основную проблему не решило).

### 2. Причина ошибки: Обновление системного debianutils (Альтернатива). Необходимо обновить пакет debianutils на более новую версию 5.23. 

*Решение:* Если ваша базовая ОС — это Ubuntu 24.04/LTS или аналогичный Mint, вы можете вручную обновить саму утилиту debianutils до официальной свежей версии ( wget http://security.ubuntu.com/ubuntu/pool/main/d/debianutils/debianutils_5.23.2_amd64.deb ) . Новая версия из коробки умеет работать со скриптами новых ядер. 

Обновил:

```
kosogor@kosogor:~/kernel$ sudo dpkg -l | grep -i debianutils
ii  debianutils                           5.17build1                              amd64        Miscellaneous utilities specific to Debian
kosogor@kosogor:~/kernel$ 
kosogor@kosogor:~/kernel$ 
kosogor@kosogor:~/kernel$ sudo apt update debianutils
E: Команде update не нужны аргументы
kosogor@kosogor:~/kernel$ sudo apt install --update debianutils
Чтение списков пакетов… Готово
Построение дерева зависимостей… Готово
Чтение информации о состоянии… Готово         
Все пакеты имеют последние версии.
Чтение списков пакетов… Готово
Построение дерева зависимостей… Готово
Чтение информации о состоянии… Готово         
Уже установлен пакет debianutils самой новой версии (5.17build1).
debianutils помечен как установленный вручную.
Обновлено 0 пакетов, установлено 0 новых пакетов, для удаления отмечено 0 пакетов, и 0 пакетов не обновлено.
kosogor@kosogor:~/kernel$ 
kosogor@kosogor:~/kernel$ 
kosogor@kosogor:~/kernel$ wget http://security.ubuntu.com/ubuntu/pool/main/d/debianutils/debianutils_5.23.2_amd64.deb
--2026-07-02 09:07:13--  http://security.ubuntu.com/ubuntu/pool/main/d/debianutils/debianutils_5.23.2_amd64.deb
Resolving security.ubuntu.com (security.ubuntu.com)... 172.66.152.176, 104.20.28.246, 2606:4700:10::6814:1cf6, ...
Connecting to security.ubuntu.com (security.ubuntu.com)|172.66.152.176|:80... connected.
HTTP request sent, awaiting response... 200 OK
Length: 93156 (91K) [application/vnd.debian.binary-package]
Saving to: ‘debianutils_5.23.2_amd64.deb’

debianutils_5.23.2_amd64.deb             100%[================================================================================>]  90,97K   582KB/s    in 0,2s    

2026-07-02 09:07:13 (582 KB/s) - ‘debianutils_5.23.2_amd64.deb’ saved [93156/93156]

kosogor@kosogor:~/kernel$
kosogor@kosogor:~/kernel$ sudo dpkg -i debianutils_5.23.2_amd64.deb 
(Чтение базы данных … на данный момент установлено 84633 файла и каталога.)
Подготовка к распаковке debianutils_5.23.2_amd64.deb …
Распаковывается debianutils (5.23.2) на замену (5.17build1) …
Настраивается пакет debianutils (5.23.2) …
Обрабатываются триггеры для man-db (2.12.0-4build2) …
kosogor@kosogor:~/kernel$ 
```

После этого изменения повторно попытался установить пакеты ядра 6.19.14 - результат тот же, ошибка та же.

*Вывод:* не помогло (либо помогло частично, но основную проблему не решило).

### 3. Причина ошибки: Эта ошибка возникает из-за сбоя в пре-установочном скрипте (preinst) ядра Mainline. Скрипт вызывает утилиту run-parts без указания целевой папки, что приводит к синтаксической ошибке и прерыванию установки.

Эта проблема начала массово проявляться, начиная с релизов ядер ветки 6.14 и выше, и стала постоянной в ветках 6.18, 6.19 и новом ядре 7.0. В конце 2025 года команда разработчиков Ubuntu Mainline Kernels изменила логику автоматических сценариев внутри пакетов (скрипты preinst и postrm). В старых ядрах (до 6.13 включительно) скрипт вызывал утилиту отдельно для каждой папки. В новых ядрах (начиная с 6.14) скрипты оптимизировали, объединив вызовы в одну строку, чтобы проверять сразу несколько директорий. Где скрылась ошибка: разработчики забыли учесть, что если одна из этих папок отсутствует в системе (или переменная пути оказывается пустой), скрипт передает в run-parts пустые кавычки "" или ничего. Из-за этого утилита падает, а вместе с ней прерывается и вся установка.

Решение 1: Установка «умной» заглушки для run-parts (Этот способ как раз решил проблему) : Заменить поведение run-parts для пакетов ядра, заставив систему делить цепочку папок на одиночные вызовы. Для этого:

1. Сначала нужно вывести dpkg из ступора, чтобы исправить поврежденную базу пакетов:

```
sudo rm -f /var/lib/dpkg/info/linux-image-unsigned-6.19.14*.*
sudo dpkg --configure -a
```

2. Создать файл для скрипта-заглушки run-parts в новом файле /usr/local/bin/run-parts  (поскольку /usr/local/bin имеет более высокий приоритет в Ubuntu, чем /usr/bin, система всегда будет запускать именно этот скрипт перед выполнением системного /usr/bin/run-parts ) :

```
#!/bin/bash
# Если аргументов нет вообще, просто выходим
if [ -z "$1" ]; then
    exit 0
fi

# Если передано несколько директорий, обрабатываем каждую отдельно
for arg in "$@"; do
    if [[ "$arg" == -* ]]; then
        # Сохраняем флаги (например, --report)
        FLAGS+=("$arg")
    else
        # Выполняем оригинальный run-parts для каждой папки
        /usr/bin/run-parts "${FLAGS[@]}" "$arg"
    fi
done
```

3. Сделать данный файл исполняемым:

```
sudo chmod +x /usr/local/bin/run-parts
```

4. После успешной установки пакетов ядра удалить скрипт-заглушку для восстановления штатного поведения системы.


Данное решение ПОМОГЛО в решении основной проблемы: после создания скрипта /usr/local/bin/run-parts установка пакетов ядра версии 6.19.14
прошла успешно:

```
kosogor@kosogor:~/kernel$ sudo nano /usr/local/bin/run-parts
kosogor@kosogor:~/kernel$
kosogor@kosogor:~$ cat /usr/local/bin/run-parts
#!/bin/bash
# Если аргументов нет вообще, просто выходим
if [ -z "$1" ]; then
    exit 0
fi

# Если передано несколько директорий, обрабатываем каждую отдельно
for arg in "$@"; do
    if [[ "$arg" == -* ]]; then
        # Сохраняем флаги (например, --report)
        FLAGS+=("$arg")
    else
        # Выполняем оригинальный run-parts для каждой папки
        /usr/bin/run-parts "${FLAGS[@]}" "$arg"
    fi
done
kosogor@kosogor:~$

kosogor@kosogor:~/kernel$ wget https://kernel.ubuntu.com/mainline/v6.19.14/amd64/linux-headers-6.19.14-061914-generic_6.19.14-061914.202604221411_amd64.deb
--2026-07-02 09:36:39--  https://kernel.ubuntu.com/mainline/v6.19.14/amd64/linux-headers-6.19.14-061914-generic_6.19.14-061914.202604221411_amd64.deb
Resolving kernel.ubuntu.com (kernel.ubuntu.com)... 185.125.189.75, 185.125.189.74, 185.125.189.76
Connecting to kernel.ubuntu.com (kernel.ubuntu.com)|185.125.189.75|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 4030966 (3,8M) [application/x-debian-package]
Saving to: ‘linux-headers-6.19.14-061914-generic_6.19.14-061914.202604221411_amd64.deb’

linux-headers-6.19.14-061914-generic_6.1 100%[================================================================================>]   3,84M  2,34MB/s    in 1,6s    

2026-07-02 09:36:42 (2,34 MB/s) - ‘linux-headers-6.19.14-061914-generic_6.19.14-061914.202604221411_amd64.deb’ saved [4030966/4030966]

kosogor@kosogor:~/kernel$ wget https://kernel.ubuntu.com/mainline/v6.19.14/amd64/linux-headers-6.19.14-061914_6.19.14-061914.202604221411_all.deb
--2026-07-02 09:37:01--  https://kernel.ubuntu.com/mainline/v6.19.14/amd64/linux-headers-6.19.14-061914_6.19.14-061914.202604221411_all.deb
Resolving kernel.ubuntu.com (kernel.ubuntu.com)... 185.125.189.75, 185.125.189.76, 185.125.189.74
Connecting to kernel.ubuntu.com (kernel.ubuntu.com)|185.125.189.75|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 14628194 (14M) [application/x-debian-package]
Saving to: ‘linux-headers-6.19.14-061914_6.19.14-061914.202604221411_all.deb’

linux-headers-6.19.14-061914_6.19.14-061 100%[================================================================================>]  13,95M  4,60MB/s    in 3,0s    

2026-07-02 09:37:05 (4,60 MB/s) - ‘linux-headers-6.19.14-061914_6.19.14-061914.202604221411_all.deb’ saved [14628194/14628194]

kosogor@kosogor:~/kernel$ wget https://kernel.ubuntu.com/mainline/v6.19.14/amd64/linux-image-unsigned-6.19.14-061914-generic_6.19.14-061914.202604221411_amd64.deb
--2026-07-02 09:37:18--  https://kernel.ubuntu.com/mainline/v6.19.14/amd64/linux-image-unsigned-6.19.14-061914-generic_6.19.14-061914.202604221411_amd64.deb
Resolving kernel.ubuntu.com (kernel.ubuntu.com)... 185.125.189.75, 185.125.189.74, 185.125.189.76
Connecting to kernel.ubuntu.com (kernel.ubuntu.com)|185.125.189.75|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 17019072 (16M) [application/x-debian-package]
Saving to: ‘linux-image-unsigned-6.19.14-061914-generic_6.19.14-061914.202604221411_amd64.deb’

linux-image-unsigned-6.19.14-061914-gene 100%[================================================================================>]  16,23M  4,69MB/s    in 3,5s    

2026-07-02 09:37:22 (4,69 MB/s) - ‘linux-image-unsigned-6.19.14-061914-generic_6.19.14-061914.202604221411_amd64.deb’ saved [17019072/17019072]

kosogor@kosogor:~/kernel$ wget https://kernel.ubuntu.com/mainline/v6.19.14/amd64/linux-modules-6.19.14-061914-generic_6.19.14-061914.202604221411_amd64.deb
--2026-07-02 09:37:36--  https://kernel.ubuntu.com/mainline/v6.19.14/amd64/linux-modules-6.19.14-061914-generic_6.19.14-061914.202604221411_amd64.deb
Resolving kernel.ubuntu.com (kernel.ubuntu.com)... 185.125.189.76, 185.125.189.75, 185.125.189.74
Connecting to kernel.ubuntu.com (kernel.ubuntu.com)|185.125.189.76|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 167188672 (159M) [application/x-debian-package]
Saving to: ‘linux-modules-6.19.14-061914-generic_6.19.14-061914.202604221411_amd64.deb’

linux-modules-6.19.14-061914-generic_6.1 100%[================================================================================>] 159,44M  5,25MB/s    in 31s     

2026-07-02 09:38:08 (5,13 MB/s) - ‘linux-modules-6.19.14-061914-generic_6.19.14-061914.202604221411_amd64.deb’ saved [167188672/167188672]

kosogor@kosogor:~/kernel$ ll
total 198132
drwxrwxr-x 2 kosogor kosogor      4096 июл  2 09:37 ./
drwxr-x--- 5 kosogor kosogor      4096 июл  2 07:25 ../
-rw-rw-r-- 1 kosogor kosogor  14628194 апр 22 21:40 linux-headers-6.19.14-061914_6.19.14-061914.202604221411_all.deb
-rw-rw-r-- 1 kosogor kosogor   4030966 апр 22 21:40 linux-headers-6.19.14-061914-generic_6.19.14-061914.202604221411_amd64.deb
-rw-rw-r-- 1 kosogor kosogor  17019072 апр 22 21:39 linux-image-unsigned-6.19.14-061914-generic_6.19.14-061914.202604221411_amd64.deb
-rw-rw-r-- 1 kosogor kosogor 167188672 апр 22 21:40 linux-modules-6.19.14-061914-generic_6.19.14-061914.202604221411_amd64.deb
kosogor@kosogor:~/kernel$
kosogor@kosogor:~/kernel$ sudo dpkg -i linux-image-unsigned-6.19.14-061914-generic_6.19.14-061914.202604221411_amd64.deb
Выбор ранее не выбранного пакета linux-image-unsigned-6.19.14-061914-generic.
(Чтение базы данных … на данный момент установлено 164179 файлов и каталогов.)
Подготовка к распаковке linux-image-unsigned-6.19.14-061914-generic_6.19.14-061914.202604221411_amd64.deb …
Распаковывается linux-image-unsigned-6.19.14-061914-generic (6.19.14-061914.202604221411) …
Настраивается пакет linux-image-unsigned-6.19.14-061914-generic (6.19.14-061914.202604221411) …
I: /boot/vmlinuz.old is now a symlink to vmlinuz-6.13.2-061302-generic
I: /boot/initrd.img.old is now a symlink to initrd.img-6.13.2-061302-generic
I: /boot/vmlinuz is now a symlink to vmlinuz-6.19.14-061914-generic
I: /boot/initrd.img is now a symlink to initrd.img-6.19.14-061914-generic
Обрабатываются триггеры для linux-image-unsigned-6.19.14-061914-generic (6.19.14-061914.202604221411) …
/etc/kernel/postinst.d/initramfs-tools:
update-initramfs: Generating /boot/initrd.img-6.19.14-061914-generic
/etc/kernel/postinst.d/zz-update-grub:
Sourcing file `/etc/default/grub'
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-6.19.14-061914-generic
Found initrd image: /boot/initrd.img-6.19.14-061914-generic
Found linux image: /boot/vmlinuz-6.13.2-061302-generic
Found initrd image: /boot/initrd.img-6.13.2-061302-generic
Found linux image: /boot/vmlinuz-6.8.0-100-generic
Found initrd image: /boot/initrd.img-6.8.0-100-generic
Warning: os-prober will not be executed to detect other bootable partitions.
Systems on them will not be added to the GRUB boot configuration.
Check GRUB_DISABLE_OS_PROBER documentation entry.
Adding boot menu entry for UEFI Firmware Settings ...
done
kosogor@kosogor:~/kernel$ 
kosogor@kosogor:~/kernel$ ll /boot
total 307528
drwxr-xr-x  4 root root     4096 июл  2 09:41 ./
drwxr-xr-x 23 root root     4096 июн 25 06:31 ../
-rw-r--r--  1 root root   294303 фев  8  2025 config-6.13.2-061302-generic
-rw-r--r--  1 root root   306720 апр 22 14:11 config-6.19.14-061914-generic
-rw-r--r--  1 root root   287599 янв 13 13:56 config-6.8.0-100-generic
drwxr-xr-x  5 root root     4096 июл  2 09:41 grub/
lrwxrwxrwx  1 root root       33 июл  2 09:41 initrd.img -> initrd.img-6.19.14-061914-generic
-rw-r--r--  1 root root 83362512 июл  2 09:23 initrd.img-6.13.2-061302-generic
-rw-r--r--  1 root root 78413711 июл  2 09:41 initrd.img-6.19.14-061914-generic
-rw-r--r--  1 root root 74658580 июн 25 06:31 initrd.img-6.8.0-100-generic
lrwxrwxrwx  1 root root       32 июл  2 09:41 initrd.img.old -> initrd.img-6.13.2-061302-generic
drwx------  2 root root    16384 июн 25 06:29 lost+found/
-rw-------  1 root root  9934398 фев  8  2025 System.map-6.13.2-061302-generic
-rw-------  1 root root 10817371 апр 22 14:11 System.map-6.19.14-061914-generic
-rw-------  1 root root  9120274 янв 13 13:56 System.map-6.8.0-100-generic
lrwxrwxrwx  1 root root       30 июл  2 09:41 vmlinuz -> vmlinuz-6.19.14-061914-generic
-rw-------  1 root root 15647232 фев  8  2025 vmlinuz-6.13.2-061302-generic
-rw-------  1 root root 16982528 апр 22 14:11 vmlinuz-6.19.14-061914-generic
-rw-------  1 root root 15030664 янв 13 14:42 vmlinuz-6.8.0-100-generic
lrwxrwxrwx  1 root root       29 июл  2 09:41 vmlinuz.old -> vmlinuz-6.13.2-061302-generic
kosogor@kosogor:~/kernel$ 
kosogor@kosogor:~/kernel$ 
kosogor@kosogor:~/kernel$ sudo update-grub
Sourcing file `/etc/default/grub'
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-6.19.14-061914-generic
Found initrd image: /boot/initrd.img-6.19.14-061914-generic
Found linux image: /boot/vmlinuz-6.13.2-061302-generic
Found initrd image: /boot/initrd.img-6.13.2-061302-generic
Found linux image: /boot/vmlinuz-6.8.0-100-generic
Found initrd image: /boot/initrd.img-6.8.0-100-generic
Warning: os-prober will not be executed to detect other bootable partitions.
Systems on them will not be added to the GRUB boot configuration.
Check GRUB_DISABLE_OS_PROBER documentation entry.
Adding boot menu entry for UEFI Firmware Settings ...
done
kosogor@kosogor:~/kernel$ 
kosogor@kosogor:~/kernel$ sudo grub-set-default 0
kosogor@kosogor:~/kernel$ 
kosogor@kosogor:~/kernel$ 
kosogor@kosogor:~/kernel$ sudo reboot

После перезагрузки ОС:

kosogor@kosogor:~$ uname -r
6.19.14-061914-generic
kosogor@kosogor:~$ 
kosogor@kosogor:~$
```

Ядро 6.19.14 в меню загрузки GRUB появилось:

<img width="1315" height="927" alt="изображение" src="https://github.com/user-attachments/assets/41deaeed-e1bb-4901-a3a6-9eefa0fc9e2c" />

*Примечание:* также для устранения данной ошибки предлагался способ пересборки установочного пакета ядра, привожу справочно, не стал применять/проверять:


```
Способ 2: Распаковка и ручное исправление скрипта

Если первый способ не помог, исправьте ошибку внутри самого пакета. Для этого:

1) Распакуйте управляющие файлы пакета:

dpkg-deb -e linux-image-unsigned-6.19.14-061914-generic_6.19.14-061914.202604221411_amd64.deb deb-control

2) Найдите строку с ошибкой:Откройте файл deb-control/preinst текстовым редактором и найдите вызов run-parts. Обычно ошибка кроется в пустой переменной, например: run-parts $DIR.

3) Исправьте или закомментируйте эту строку, добавив # в начало:

# run-parts ...

4) Распакуйте содержимое самого пакета:

dpkg-deb -x linux-image-unsigned-6.19.14-061914-generic_6.19.14-061914.202604221411_amd64.deb deb-data

5) Соберите исправленный пакет обратно:

dpkg-deb -b deb-data/ deb-control/ fixed-kernel.deb

6) Установите новый пакет:

sudo dpkg -i fixed-kernel.deb

```


### Вывод: 
По-моему, разработчики ядер Linux также попутали берега : все установочные пакеты ядер версий >6.14 содержат ошибку, препятствующую их установке,
с которой просто так не разобраться (начинающему сисадмину в одиночку без применения Интернета - тем более).


## Откат на исходное ядро

По рекомендации из лекции удалил ранее установленное ядро mainline 6.13.2 и вернулся к загрузке системы с исходным ядром 6.8.0-100 , оставив ядро 6.9.14 в системе:

```
kosogor@kosogor:~$ uname -r
6.19.14-061914-generic
kosogor@kosogor:~$
kosogor@kosogor:~$ apt list --installed | grep '6.13.2'

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

linux-headers-6.13.2-061302-generic/now 6.13.2-061302.202502081010 amd64 [установлен, локальный]
linux-headers-6.13.2-061302/now 6.13.2-061302.202502081010 all [установлен, локальный]
linux-image-unsigned-6.13.2-061302-generic/now 6.13.2-061302.202502081010 amd64 [установлен, локальный]
linux-modules-6.13.2-061302-generic/now 6.13.2-061302.202502081010 amd64 [установлен, локальный]
kosogor@kosogor:~$
kosogor@kosogor:~$ sudo apt purge linux-headers-6.13.2-061302-generic linux-headers-6.13.2-061302 linux-image-unsigned-6.13.2-061302-generic linux-modules-6.13.2-061302-generic
[sudo] password for kosogor: 
Чтение списков пакетов… Готово
Построение дерева зависимостей… Готово
Чтение информации о состоянии… Готово         
Следующие пакеты будут УДАЛЕНЫ:
  linux-headers-6.13.2-061302* linux-headers-6.13.2-061302-generic* linux-image-unsigned-6.13.2-061302-generic* linux-modules-6.13.2-061302-generic*
Обновлено 0 пакетов, установлено 0 новых пакетов, для удаления отмечено 4 пакетов, и 145 пакетов не обновлено.
После данной операции объём занятого дискового пространства уменьшится на 316 MB.
Хотите продолжить? [Д/н] y
(Чтение базы данных … на данный момент установлено 164183 файла и каталога.)
Удаляется linux-headers-6.13.2-061302-generic (6.13.2-061302.202502081010) …
Удаляется linux-headers-6.13.2-061302 (6.13.2-061302.202502081010) …
Удаляется linux-image-unsigned-6.13.2-061302-generic (6.13.2-061302.202502081010) …
I: /boot/vmlinuz.old is now a symlink to vmlinuz-6.8.0-100-generic
I: /boot/initrd.img.old is now a symlink to initrd.img-6.8.0-100-generic
/etc/kernel/postrm.d/initramfs-tools:
update-initramfs: Deleting /boot/initrd.img-6.13.2-061302-generic
/etc/kernel/postrm.d/zz-update-grub:
Sourcing file `/etc/default/grub'
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-6.19.14-061914-generic
Found initrd image: /boot/initrd.img-6.19.14-061914-generic
Found linux image: /boot/vmlinuz-6.8.0-100-generic
Found initrd image: /boot/initrd.img-6.8.0-100-generic
Warning: os-prober will not be executed to detect other bootable partitions.
Systems on them will not be added to the GRUB boot configuration.
Check GRUB_DISABLE_OS_PROBER documentation entry.
Adding boot menu entry for UEFI Firmware Settings ...
done
Удаляется linux-modules-6.13.2-061302-generic (6.13.2-061302.202502081010) …
(Чтение базы данных … на данный момент установлено 125210 файлов и каталогов.)
Вычищаются файлы настройки пакета linux-image-unsigned-6.13.2-061302-generic (6.13.2-061302.202502081010) …
Вычищаются файлы настройки пакета linux-modules-6.13.2-061302-generic (6.13.2-061302.202502081010) …
kosogor@kosogor:~$

kosogor@kosogor:~$ cat /etc/default/grub
# If you change this file, run 'update-grub' afterwards to update
# /boot/grub/grub.cfg.
# For full documentation of the options in this file, see:
#   info -f grub -n 'Simple configuration'

GRUB_DEFAULT=0
GRUB_TIMEOUT_STYLE=hidden
GRUB_TIMEOUT=0
GRUB_DISTRIBUTOR=`( . /etc/os-release; echo ${NAME:-Ubuntu} ) 2>/dev/null || echo Ubuntu`
GRUB_CMDLINE_LINUX_DEFAULT=""
GRUB_CMDLINE_LINUX=""

# If your computer has multiple operating systems installed, then you
# probably want to run os-prober. However, if your computer is a host
# for guest OSes installed via LVM or raw disk devices, running
# os-prober can cause damage to those guest OSes as it mounts
# filesystems to look for things.
#GRUB_DISABLE_OS_PROBER=false

# Uncomment to enable BadRAM filtering, modify to suit your needs
# This works with Linux (no patch required) and with any kernel that obtains
# the memory map information from GRUB (GNU Mach, kernel of FreeBSD ...)
#GRUB_BADRAM="0x01234567,0xfefefefe,0x89abcdef,0xefefefef"

# Uncomment to disable graphical terminal
#GRUB_TERMINAL=console

# The resolution used on graphical terminal
# note that you can use only modes which your graphic card supports via VBE
# you can see them in real GRUB with the command `vbeinfo'
#GRUB_GFXMODE=640x480

# Uncomment if you don't want GRUB to pass "root=UUID=xxx" parameter to Linux
#GRUB_DISABLE_LINUX_UUID=true

# Uncomment to disable generation of recovery mode menu entries
#GRUB_DISABLE_RECOVERY="true"

# Uncomment to get a beep at grub start
#GRUB_INIT_TUNE="480 440 1"
kosogor@kosogor:~$ 
kosogor@kosogor:~$
kosogor@kosogor:~$ sudo nano /etc/default/grub
kosogor@kosogor:~$
kosogor@kosogor:~$ cat /etc/default/grub
# If you change this file, run 'update-grub' afterwards to update
# /boot/grub/grub.cfg.
# For full documentation of the options in this file, see:
#   info -f grub -n 'Simple configuration'

GRUB_DEFAULT="1>2"
GRUB_TIMEOUT_STYLE=hidden
GRUB_TIMEOUT=0
GRUB_DISTRIBUTOR=`( . /etc/os-release; echo ${NAME:-Ubuntu} ) 2>/dev/null || echo Ubuntu`
GRUB_CMDLINE_LINUX_DEFAULT=""
GRUB_CMDLINE_LINUX=""

# If your computer has multiple operating systems installed, then you
# probably want to run os-prober. However, if your computer is a host
# for guest OSes installed via LVM or raw disk devices, running
# os-prober can cause damage to those guest OSes as it mounts
# filesystems to look for things.
#GRUB_DISABLE_OS_PROBER=false

# Uncomment to enable BadRAM filtering, modify to suit your needs
# This works with Linux (no patch required) and with any kernel that obtains
# the memory map information from GRUB (GNU Mach, kernel of FreeBSD ...)
#GRUB_BADRAM="0x01234567,0xfefefefe,0x89abcdef,0xefefefef"

# Uncomment to disable graphical terminal
#GRUB_TERMINAL=console

# The resolution used on graphical terminal
# note that you can use only modes which your graphic card supports via VBE
# you can see them in real GRUB with the command `vbeinfo'
#GRUB_GFXMODE=640x480

# Uncomment if you don't want GRUB to pass "root=UUID=xxx" parameter to Linux
#GRUB_DISABLE_LINUX_UUID=true

# Uncomment to disable generation of recovery mode menu entries
#GRUB_DISABLE_RECOVERY="true"

# Uncomment to get a beep at grub start
#GRUB_INIT_TUNE="480 440 1"
kosogor@kosogor:~$ 
osogor@kosogor:~$ sudo update-grub
[sudo] password for kosogor: 
sudo: a password is required
kosogor@kosogor:~$ sudo reboot
osogor@kosogor:~$ Connection to 192.168.122.176 closed by remote host.
Connection to 192.168.122.176 closed.
[admin_insta11@mv334 ~]$ 
[admin_insta11@mv334 ~]$ 
[admin_insta11@mv334 ~]$ ssh kosogor@192.168.122.176
kosogor@192.168.122.176's password: 
Welcome to Ubuntu 24.04.4 LTS (GNU/Linux 6.8.0-100-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

 System information as of Чт 02 июл 2026 14:00:30 UTC

  System load:  0.0                Processes:               157
  Usage of /:   45.0% of 13.67GB   Users logged in:         0
  Memory usage: 5%                 IPv4 address for enp1s0: 192.168.122.176
  Swap usage:   0%

 * Strictly confined Kubernetes makes edge and IoT secure. Learn how MicroK8s
   just raised the bar for easy, resilient and secure K8s cluster deployment.

   https://ubuntu.com/engage/secure-kubernetes-at-the-edge

Расширенное поддержание безопасности (ESM) для Applications выключено.

153 обновления может быть применено немедленно.
123 из этих обновлений, являются стандартными обновлениями безопасности.
Чтобы просмотреть дополнительные обновления выполните: apt list --upgradable

Включите ESM Apps для получения дополнительных будущих обновлений безопасности.
Смотрите https://ubuntu.com/esm или выполните: sudo pro status


Last login: Thu Jul  2 13:58:40 2026 from 192.168.122.1
kosogor@kosogor:~$ 
kosogor@kosogor:~$ 
kosogor@kosogor:~$ sudo update-grub
[sudo] password for kosogor: 
sudo: a password is required
kosogor@kosogor:~$ uname -r
6.8.0-100-generic
kosogor@kosogor:~$
```

В загрузочном меню GRUB по умолчанию теперь выбрана загрузка ОС с ядром 6.8.0-100 :

<img width="1309" height="919" alt="изображение" src="https://github.com/user-attachments/assets/f291dc23-953a-4e8d-b2a3-157d6e6e7054" />
<img width="1307" height="923" alt="изображение" src="https://github.com/user-attachments/assets/62a684b6-ee4e-483f-aa56-3ca585afe3f3" />


# Общий вывод

Работы получилось значительно больше, чем первоначально планировалось в методичке в связи с несоответствием и неработоспособностью/ошибками
в самом Linux Ubuntu 24.04 LTS.
При этом к лекции/лектору и к самой методичке претензий нет никаких.
Все претензии в данном случае к разработчикам инсталляционного образа Linux Ubuntu 24.04 LTS и Mainline Linux kernels.

Получил бесценный опыт ))))

К сожалению на задачу со звездочкой по сборке ядра из исходников  времени уже не хватило (кроме того, были уже опасения, что в процессе сборки
граблей может оказаться ещё больше).

Надеюсь, он может быть полезен и вам.
Если вдруг в моих действиях при выполнении ДЗ или в оформлении отчёта вы обнаружите недостатки, просьба сообщить.



