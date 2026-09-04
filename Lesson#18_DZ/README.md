# Занятие 31.08.2026 "Vagrant"

Расширенная настройка дисков и сетей

### Цель:

научиться добавлять диски и настраивать сетевые соединения;

## 🎯Задание

### 1. Подготовка окружения:

Убедитесь, что установлены VirtualBox и Vagrant.
    
Создайте директорию для проекта.

Создать базовую виртуальную машину:
    
- Использовать можно любой образ.
    
- Настроите память ВМ: 1024 МБ.
        
Добавление дисков:

- Добавьте пару виртуальных диска размером 1 ГБ каждый.
        
Настройка сети:

- Настройте проброс 80 порта с гостевой системы на порт 8080 хостовой системы.
  
### 2. Провижининг:

Напишите провижининг, который:

- Форматирует добавленные диски в файловую систему ext4.

- Создает точки монтирования /mnt/disk1 и /mnt/disk2.

- Монтирует диски в указанные директории.

- Добавляет записи в /etc/fstab для автоматического монтирования при загрузке.

Вы можете использовать пример, продемонстрированный на занятии

### 🗂 Формат сдачи

Ссылка на git репозиторий с проектом

Репозиторий должен содержать Vagrantfile

Скриншот вывода команды df -h с запущенной ВМ

Скриншот с хостовой машины вывода команды netstat -tulpn | grep 8080 с запущенной ВМ

# Решение



В Host OS REDOS 7.3 более нативным является гипервизор KVM (основан на libvirt, содержащемся в ядре Linux), поэтому также проверяем вариант установки и работы KVM + Vagrant .
Для работы Vagrant с KVM требуется установка и сборка плагина vagrant-libvirt


Сравнительные критерии KVM (libvirt) vs VirtualBox :

| Критерий	 |  KVM (libvirt)	| VirtualBox   |
|:-----------------|:-------------------|:-------------------------|
| Производительность  | Выше (нативный гипервизор Type‑1)	| Ниже   |
| «Нативность» для RED OS	| Полная, пакеты в репозитории	| Есть, но как стороннее ПО |
| Управление из CLI	 | virsh, отлично ложится на Bash/Ansible	| VBoxManage, слабее  |
| Vagrant‑плагин	 | vagrant-libvirt	  | Встроенный провайдер, без плагина  |

Также в связи с недоступностью портала https://portal.cloud.hashicorp.com/ для проверки и работы заранее локально скачаны несколько Vagrant box для различных версий Linux:

```
[admin_insta11@mv334 lab-almalinux9]$ ls -l /distrib/vagrant_boxes/
итого 8408428
-rwxrwxrwx 1 admin_insta11 admin_insta11  546709438 авг 31 21:50  almalinux-9-9.8.20260810-amd64-libvirt.box
-rwxrwxrwx 1 admin_insta11 admin_insta11  698021674 авг 31 22:18  almalinux-9-9.8.20260810-amd64-virtualbox.box
-rwxrwxrwx 1 admin_insta11 admin_insta11  838235264 сен  1 06:22  bento-ubuntu-22.04-202510.26.0-amd64-virtualbox.box
-rwxrwxrwx 1 admin_insta11 admin_insta11 3216132560 авг 31 23:48  bento-ubuntu-26.04-202606.01.0-amd64-libvirt.box
-rwxrwxrwx 1 admin_insta11 admin_insta11 3311076684 сен  1 06:00  bento-ubuntu-26.04-202606.01.0-amd64-virtualbox.box
[admin_insta11@mv334 lab-almalinux9]$
```

## 1. Устанавливаем и проверяем вариант KVM + Vagrant

1.1 Устанавливаем и проверяем KVM + Vagrant：

1.1.1 Устанавливаем KVM：

```
# 1. Пакеты виртуализации
sudo dnf install qemu-kvm libvirt virt-install virt-manager bridge-utils -y

# 2. Запуск и автозапуск демона
sudo systemctl enable libvirtd --now

# 3. Проверка загрузки модулей ядра
lsmod | grep kvm        # должны быть kvm_intel / kvm_amd

# 4. Добавь пользователя в группу (чтобы не ходить через sudo)
sudo usermod -aG libvirt $USER
# перелогинься, чтобы изменения применились
```

1.1.2 Установка Vagrant

Так как сайт hashicorp.com недоступен, то скачиваем дистрибутив RPM Vagrant с российского зеркала https://hashicorp-releases.yandexcloud.net и затем устанавливаем из локально скачанного дистрибутива:

```
[admin_insta11@mv334 ~]$ wget https://hashicorp-releases.yandexcloud.net/vagrant/2.4.7/vagrant-2.4.7-1.x86_64.rpm
--2026-09-02 19:45:23--  https://hashicorp-releases.yandexcloud.net/vagrant/2.4.7/vagrant-2.4.7-1.x86_64.rpm
Распознаётся hashicorp-releases.yandexcloud.net (hashicorp-releases.yandexcloud.net)… 51.250.76.140, 2a0d:d6c1:0:1a::2db
Подключение к hashicorp-releases.yandexcloud.net (hashicorp-releases.yandexcloud.net)|51.250.76.140|:443... соединение установлено.
HTTP-запрос отправлен. Ожидание ответа… 302 Found
Адрес: https://storage.yandexcloud.net/hc-releases/vagrant/2.4.7/vagrant-2.4.7-1.x86_64.rpm?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=YCAJEMDf6v-2QzhEWzeRT4aQM%2F20260902%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20260902T164523Z&X-Amz-Expires=900&X-Amz-SignedHeaders=host&X-Amz-Signature=857628f55bbf2cec6c44975c11fa6f02e9116f358c751ac18c8d215503639a80 [переход]
--2026-09-02 19:45:24--  https://storage.yandexcloud.net/hc-releases/vagrant/2.4.7/vagrant-2.4.7-1.x86_64.rpm?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=YCAJEMDf6v-2QzhEWzeRT4aQM%2F20260902%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20260902T164523Z&X-Amz-Expires=900&X-Amz-SignedHeaders=host&X-Amz-Signature=857628f55bbf2cec6c44975c11fa6f02e9116f358c751ac18c8d215503639a80
Распознаётся storage.yandexcloud.net (storage.yandexcloud.net)… 213.180.193.243, 2a02:6b8::1d9
Подключение к storage.yandexcloud.net (storage.yandexcloud.net)|213.180.193.243|:443... соединение установлено.
HTTP-запрос отправлен. Ожидание ответа… 200 OK
Длина: 90145306 (86M) [application/octet-stream]
Сохранение в: «vagrant-2.4.7-1.x86_64.rpm»

vagrant-2.4.7-1.x86_64.rpm                      100%[=====================================================================================================>]  85,97M  3,49MB/s    за 57s     

2026-09-02 19:46:21 (1,50 MB/s) - «vagrant-2.4.7-1.x86_64.rpm» сохранён [90145306/90145306]
[admin_insta11@mv334 ~]$
[admin_insta11@mv334 ~]$ sudo dnf install vagrant-2.4.7-1.x86_64.rpm
[sudo] пароль для admin_insta11: 
Последняя проверка окончания срока действия метаданных: 0:11:35 назад, Ср 02 сен 2026 19:35:45.
Зависимости разрешены.
==============================================================================================================================================================================================
 Пакет                                       Архитектура                                Версия                                         Репозиторий                                      Размер
==============================================================================================================================================================================================
Установка:
 vagrant                                     x86_64                                     2.4.7-1                                        @commandline                                      86 M

Результат транзакции
==============================================================================================================================================================================================
Установка  1 Пакет

Общий размер: 86 M
Объем изменений: 180 M
Продолжить? [д/Н]: y
Загрузка пакетов:
Проверка транзакции
Проверка транзакции успешно завершена.
Идет проверка транзакции
Тест транзакции проведен успешно.
Выполнение транзакции
  Подготовка       :                                                                                                                                                                      1/1 
  Установка        : vagrant-2.4.7-1.x86_64                                                                                                                                               1/1 
  Запуск скриптлета: vagrant-2.4.7-1.x86_64                                                                                                                                               1/1 
  Проверка         : vagrant-2.4.7-1.x86_64                                                                                                                                               1/1 

Установлен:
  vagrant-2.4.7-1.x86_64                                                                                                                                                                      

Выполнено!
[admin_insta11@mv334 ~]$ vagrant --version
Vagrant 2.4.7
[admin_insta11@mv334 ~]$
```

1.1.3 Устанавливаем зависимости для сборки плагина vagrant-libvirt

```
# зависимости для сборки плагина:
[admin_insta11@mv334 ~]$ sudo dnf install gcc ruby-devel libvirt-devel -y
```

1.1.4 Устанавливаем плагин vagrant-libvirt

Репозиторий https://gems.hashicorp.com/ недоступен, поэтому стандартная команда установки завершается с ошибкой:

```
[admin_insta11@mv334 ~]$ vagrant plugin install vagrant-libvirt
Installing the 'vagrant-libvirt' plugin. This can take a few minutes...
Vagrant failed to load a configured plugin source. This can be caused
by a variety of issues including: transient connectivity issues, proxy
filtering rejecting access to a configured plugin source, or a configured
plugin source not responding correctly. Please review the error message
below to help resolve the issue:

  bad response Not Found 404 (https://gems.hashicorp.com/specs.4.8.gz)

Source: https://gems.hashicorp.com/
[admin_insta11@mv334 ~]$
```

Поэтому скачиваем и устанавливаем плагин и его зависимости из репозитория https://rubygems.org/  

(в команде ниже ключ --plugin-clean-sources сначала очищает список источников, чтобы удалить недоступный https://gems.hashicorp.com/ ,
в затем ключ --plugin-source добавляет источник https://rubygems.org/ ) :

```
[admin_insta11@mv334 ~]$ wget https://rubygems.org/downloads/vagrant-libvirt-0.11.2.gem
--2026-09-02 19:52:47--  https://rubygems.org/downloads/vagrant-libvirt-0.11.2.gem
Распознаётся rubygems.org (rubygems.org)… 151.101.1.227, 151.101.129.227, 151.101.65.227, ...
Подключение к rubygems.org (rubygems.org)|151.101.1.227|:443... соединение установлено.
HTTP-запрос отправлен. Ожидание ответа… 200 OK
Длина: 130048 (127K) [application/octet-stream]
Сохранение в: «vagrant-libvirt-0.11.2.gem»

vagrant-libvirt-0.11.2.gem                      100%[=====================================================================================================>] 127,00K   564KB/s    за 0,2s    

2026-09-02 19:52:48 (564 KB/s) - «vagrant-libvirt-0.11.2.gem» сохранён [130048/130048]

[admin_insta11@mv334 ~]$
[admin_insta11@mv334 ~]$ export CONFIGURE_ARGS="with-libvirt-include=/usr/include/libvirt with-libvirt-lib=/usr/lib64"
vagrant plugin install --plugin-clean-sources --plugin-source https://rubygems.org/ ./vagrant-libvirt-0.11.2.gem
Installing the './vagrant-libvirt-0.11.2.gem' plugin. This can take a few minutes...
Fetching racc-1.8.1.gem
Building native extensions. This could take a while...
Building native extensions. This could take a while...
Fetching fog-core-2.6.0.gem
Fetching ruby-libvirt-0.8.4.gem
Building native extensions. This could take a while...
Installed the plugin 'vagrant-libvirt (0.11.2)'!
[admin_insta11@mv334 ~]$ 
[admin_insta11@mv334 ~]$ vagrant plugin list
vagrant-libvirt (0.11.2, global)
  - Version Constraint: 0.11.2
[admin_insta11@mv334 ~]$
```

Можно также сделать libvirt провайдером по умолчанию для Vagrant:

```
# сделать libvirt провайдером по умолчанию
export VAGRANT_DEFAULT_PROVIDER=libvirt
```

1.1.5  Устанавливаем ansible на Host OS:

```
admin_insta11@mv334 lab-almalinux9]$ sudo dnf install ansible
[sudo] пароль для admin_insta11: 
Последняя проверка окончания срока действия метаданных: 0:42:41 назад, Ср 02 сен 2026 19:35:45.
Зависимости разрешены.
==============================================================================================================================================================================================
 Пакет                                                Архитектура                             Версия                                          Репозиторий                               Размер
==============================================================================================================================================================================================
Установка:
 ansible                                              noarch                                  6.7.0-2.el7                                     updates                                    36 M
Установка зависимостей:
 ansible-core                                         noarch                                  2.13.13-3.el7                                   updates                                   3.0 M
 ansible-packaging                                    noarch                                  1-16.1.el7                                      updates                                    12 k
 ansible-srpm-macros                                  noarch                                  1-16.1.el7                                      updates                                    19 k
 python3-packaging                                    noarch                                  24.1-1.el7                                      RedOSdvd                                   95 k
 python3-resolvelib                                   noarch                                  0.5.5-3.el7                                     base                                       31 k

Результат транзакции
==============================================================================================================================================================================================
Установка  6 Пакетов

Общий размер: 40 M
Объем загрузки: 39 M
Объем изменений: 296 M
Продолжить? [д/Н]: y
Загрузка пакетов:
(1/5): python3-resolvelib-0.5.5-3.el7.noarch.rpm                                                                                                               45 kB/s |  31 kB     00:00    
(2/5): ansible-packaging-1-16.1.el7.noarch.rpm                                                                                                                 29 kB/s |  12 kB     00:00    
(3/5): ansible-srpm-macros-1-16.1.el7.noarch.rpm                                                                                                              138 kB/s |  19 kB     00:00    
(4/5): ansible-core-2.13.13-3.el7.noarch.rpm                                                                                                                  1.8 MB/s | 3.0 MB     00:01    
(5/5): ansible-6.7.0-2.el7.noarch.rpm                                                                                                                         2.6 MB/s |  36 MB     00:14    
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Общий размер                                                                                                                                                  2.8 MB/s |  39 MB     00:14     
Проверка транзакции
Проверка транзакции успешно завершена.
Идет проверка транзакции
Тест транзакции проведен успешно.
Выполнение транзакции
  Подготовка       :                                                                                                                                                                      1/1 
  Установка        : ansible-srpm-macros-1-16.1.el7.noarch                                                                                                                                1/6 
  Установка        : python3-resolvelib-0.5.5-3.el7.noarch                                                                                                                                2/6 
  Установка        : python3-packaging-24.1-1.el7.noarch                                                                                                                                  3/6 
  Установка        : ansible-6.7.0-2.el7.noarch                                                                                                                                           4/6 
  Установка        : ansible-packaging-1-16.1.el7.noarch                                                                                                                                  5/6 
  Установка        : ansible-core-2.13.13-3.el7.noarch                                                                                                                                    6/6 
  Запуск скриптлета: ansible-core-2.13.13-3.el7.noarch                                                                                                                                    6/6 
  Проверка         : python3-packaging-24.1-1.el7.noarch                                                                                                                                  1/6 
  Проверка         : python3-resolvelib-0.5.5-3.el7.noarch                                                                                                                                2/6 
  Проверка         : ansible-6.7.0-2.el7.noarch                                                                                                                                           3/6 
  Проверка         : ansible-core-2.13.13-3.el7.noarch                                                                                                                                    4/6 
  Проверка         : ansible-packaging-1-16.1.el7.noarch                                                                                                                                  5/6 
  Проверка         : ansible-srpm-macros-1-16.1.el7.noarch                                                                                                                                6/6 

Установлен:
  ansible-6.7.0-2.el7.noarch             ansible-core-2.13.13-3.el7.noarch  ansible-packaging-1-16.1.el7.noarch  ansible-srpm-macros-1-16.1.el7.noarch  python3-packaging-24.1-1.el7.noarch 
  python3-resolvelib-0.5.5-3.el7.noarch 

Выполнено!
[admin_insta11@mv334 lab-almalinux9]$
```

1.2 Проверяем работоспособность установленного окружения KVM + Vagrant

1.2.1 Регистрируем в Vagrant локально скачанный box для Almalinux 9 для libvirt :

```
[admin_insta11@mv334 ~]$ ll /distrib/vagrant_boxes/
итого 8408428
-rwxrwxrwx 1 admin_insta11 admin_insta11  546709438 авг 31 21:50  almalinux-9-9.8.20260810-amd64-libvirt.box
-rwxrwxrwx 1 admin_insta11 admin_insta11  698021674 авг 31 22:18  almalinux-9-9.8.20260810-amd64-virtualbox.box
-rwxrwxrwx 1 admin_insta11 admin_insta11  838235264 сен  1 06:22  bento-ubuntu-22.04-202510.26.0-amd64-virtualbox.box
-rwxrwxrwx 1 admin_insta11 admin_insta11 3216132560 авг 31 23:48  bento-ubuntu-26.04-202606.01.0-amd64-libvirt.box
-rwxrwxrwx 1 admin_insta11 admin_insta11 3311076684 сен  1 06:00  bento-ubuntu-26.04-202606.01.0-amd64-virtualbox.box
-rwxrwxrwx 1 admin_insta11 admin_insta11       2020 сен  1 18:12 'Vagrant boxes.txt'
[admin_insta11@mv334 ~]$
[admin_insta11@mv334 ~]$ vagrant box list
There are no installed boxes! Use `vagrant box add` to add some.
[admin_insta11@mv334 ~]$
[admin_insta11@mv334 ~]$ export BOX_FILE="/distrib/vagrant_boxes/almalinux-9-9.8.20260810-amd64-libvirt.box"
[admin_insta11@mv334 ~]$ export BOX_NAME="almalinux9-stand"
[admin_insta11@mv334 ~]$ vagrant box add --name "$BOX_NAME" "$BOX_FILE"
==> box: Box file was not detected as metadata. Adding it directly...
==> box: Adding box 'almalinux9-stand' (v0) for provider: 
    box: Unpacking necessary files from: file:///distrib/vagrant_boxes/almalinux-9-9.8.20260810-amd64-libvirt.box
==> box: Successfully added box 'almalinux9-stand' (v0) for ''!
[admin_insta11@mv334 ~]$ 
[admin_insta11@mv334 ~]$ vagrant box list
almalinux9-stand (libvirt, 0)
[admin_insta11@mv334 ~]$
```

1.2.2 Создаём директорию для нового проекта и создаём в ней Vagrantfile

Для проверки используем рабочий Vagrantfile из Задания 13 "SELinux" по ссылке https://github.com/Nickmob/vagrant_selinux следующего содержания:

```
MACHINES = {
  :"selinux" => {
              :box_name => "almalinux/9",
              :box_version => "9.4.20240805",
              :cpus => 2,
              :memory => 2048
            }
}

Vagrant.configure("2") do |config|
  MACHINES.each do |boxname, boxconfig|
    config.vm.synced_folder ".", "/vagrant", disabled: true
    config.vm.define boxname do |box|
      box.vm.box = boxconfig[:box_name]
      box.vm.box_version = boxconfig[:box_version]
      box.vm.host_name = boxname.to_s
      box.vm.network "forwarded_port", guest: 4881, host: 4881
      box.vm.provider "virtualbox" do |v|
        v.memory = boxconfig[:memory]
        v.cpus = boxconfig[:cpus]
      end
      box.vm.provision "shell", inline: <<-SHELL
      yum install -y epel-release
      yum install -y nginx
      yum install -y setroubleshoot-server selinux-policy-mls setools-console policycoreutils-python-utils policycoreutils-newrole
      sed -ie 's/:80/:4881/g' /etc/nginx/nginx.conf
      sed -i 's/listen       80;/listen       4881;/' /etc/nginx/nginx.conf
      systemctl start nginx
      systemctl status nginx
      ss -tlpn | grep 4881
SHELL
    end
  end
end
```

Но данный файл создан для работы с virtualbox, поэтому для использования с KVM в нём нужно сделать несколько изменений:
Нужно поменять три вещи: провайдер, сеть и источник бокса.

| В исходнике	| Проблема	| Решение |
|:---------------------|:--------------------------|:-----------------------------|
| box.vm.provider  "virtualbox"	 | У меня libvirt	| Меняем на "libvirt" |
| almalinux/9, версия 9.4.20240805	| Бокс с облака недоступен	| Используем локальный almalinux9-stand |
| forwarded_port	| libvirt не умеет проброс портов как VirtualBox	| Ставим VM на private network с фиксированным IP |


Примечание по поводу 'А почему пишут ( и правда ли это) , что virtualbox поддерживает пробров портов внутрь виртуальной машины, а KVM - нет ?':
```
Да, это правда, но с важной технической оговоркой. VirtualBox поддерживает проброс портов «из коробки» через графический интерфейс (GUI),
а KVM (через Libvirt/Virsh) требует ручной настройки сети.
Разница кроется в архитектуре и целях создания этих систем.В чем разница между VirtualBox и KVM?

VirtualBox — это настольный гипервизор. Он создан для обычных пользователей. VirtualBox по умолчанию использует сеть типа NAT.
В этом режиме гипервизор сам работает как встроенный роутер, поэтому разработчики добавили простую кнопку «Проброс портов» прямо в настройки программы.

KVM — это гипервизор корпоративного уровня. Это часть ядра Linux. Сам по себе KVM вообще не занимается сетью — он только виртуализирует процессор и память.
Сетью управляет демон libvirt, который создает стандартный сетевой мост Linux (virbr0). libvirt не знает, какие порты вам нужны, и оставляет управление
трафиком стандартным системным утилитам Linux (вроде iptables или nftables).

Почему говорят, что KVM «не поддерживает» проброс?
Когда люди так говорят, они имеют в виду, что в KVM нет одной простой команды или кнопки вроде virsh forward-port --host 80 --guest 80.
В KVM/Libvirt сетевая подсистема изолирована от управления самой машиной:
Виртуальная машина получает полноценный IP-адрес в виртуальной сети хоста.
Для хост-системы эта машина выглядит как отдельный физический компьютер в локальной сети.
Чтобы перенаправить трафик, нужно настраивать сетевой экран самого хоста (Linux), а не настройки виртуализации.

Альтернатива: как сделать аналог VirtualBox в KVM?Если вы хотите, чтобы KVM вел себя как VirtualBox и не требовал настройки iptables,
можно использовать сетевой режим "Пользователь" (User-mode networking / SLIRP).При создании машины или в ее XML-конфигурации можно указать
такой тип сети:

xml<interface type='user'>
  <mac address='52:54:00:12:34:56'/>
  <model type='virtio'/>
</interface>

В этом режиме сеть работает полностью внутри пространства пользователя (как в VirtualBox), и в QEMU есть встроенный механизм проброса портов
через аргументы командной строки (например, -net user,hostfwd=tcp::8022-:22). Однако этот режим работает медленнее и редко используется в production,
поэтому в virsh для него нет удобных стандартных команд.
```

Адаптированный для KVM Vagrantfile:

```
MACHINES = {
  :"selinux" => {
              :box_name => "almalinux9-stand",
              :cpus => 2,
              :memory => 2048
            }
}

Vagrant.configure("2") do |config|
  MACHINES.each do |boxname, boxconfig|
    config.vm.synced_folder ".", "/vagrant", disabled: true
    config.vm.define boxname do |box|
      box.vm.box = boxconfig[:box_name]
      box.vm.host_name = boxname.to_s

      # libvirt не поддерживает forwarded_port как VirtualBox,
      # поэтому даём VM фиксированный IP в приватной сети
      box.vm.network "private_network", ip: "192.168.56.10"

      box.vm.provider "libvirt" do |v|
        v.memory = boxconfig[:memory]
        v.cpus = boxconfig[:cpus]
        # Папка хранения образов (опционально)
        # v.storage_pool_name = "default"
      end

      box.vm.provision "shell", inline: <<-SHELL
        dnf install -y epel-release
        dnf install -y nginx
        dnf install -y setroubleshoot-server selinux-policy-mls setools-console policycoreutils-python-utils policycoreutils-newrole
        sed -ie 's/:80/:4881/g' /etc/nginx/nginx.conf
        sed -i 's/listen       80;/listen       4881;/' /etc/nginx/nginx.conf
        systemctl start nginx
        systemctl status nginx
        ss -tlpn | grep 4881
      SHELL
    end
  end
end
```

Создаём директорию для нового проекта и создаём в ней вышеупомянутый Vagrantfile для libvirt/KVM (вместо команды 'vagrant init ...') :

```
[admin_insta11@mv334 ~]$ mkdir -p ~/lab-almalinux9 && cd ~/lab-almalinux9
[admin_insta11@mv334 lab-almalinux9]$
[admin_insta11@mv334 lab-almalinux9]$ cat > Vagrantfile
MACHINES = {
  :"selinux" => {
              :box_name => "almalinux9-stand",
              :cpus => 2,
              :memory => 2048
            }
}

Vagrant.configure("2") do |config|
  MACHINES.each do |boxname, boxconfig|
    config.vm.synced_folder ".", "/vagrant", disabled: true
    config.vm.define boxname do |box|
      box.vm.box = boxconfig[:box_name]
      box.vm.host_name = boxname.to_s

      # libvirt не поддерживает forwarded_port как VirtualBox,
      # поэтому даём VM фиксированный IP в приватной сети
      box.vm.network "private_network", ip: "192.168.56.10"

      box.vm.provider "libvirt" do |v|
        v.memory = boxconfig[:memory]
        v.cpus = boxconfig[:cpus]
        # Папка хранения образов (опционально)
        # v.storage_pool_name = "default"
      end

      box.vm.provision "shell", inline: <<-SHELL
        dnf install -y epel-release
        dnf install -y nginx
        dnf install -y setroubleshoot-server selinux-policy-mls setools-console policycoreutils-python-utils policycoreutils-newrole
        sed -ie 's/:80/:4881/g' /etc/nginx/nginx.conf
        sed -i 's/listen       80;/listen       4881;/' /etc/nginx/nginx.conf
        systemctl start nginx
        systemctl status nginx
        ss -tlpn | grep 4881
      SHELL
    end
  end
end
[admin_insta11@mv334 lab-almalinux9]$
```

1.2.3 После этого запускаем ВМ в Vagrant (при первом запуске происходит её provisioning) и подключаемся к ней по SSH:

```
[admin_insta11@mv334 lab-almalinux9]$ vagrant box list | grep almalinux9-stand
almalinux9-stand (libvirt, 0)
[admin_insta11@mv334 lab-almalinux9]$ vagrant up --provider=libvirt
Bringing machine 'selinux' up with 'libvirt' provider...
==> selinux: No version detected for almalinux9-stand, using timestamp to watch for modifications. Consider
==> selinux: generating a local metadata for the box with a version to allow better handling.
==> selinux: See https://www.vagrantup.com/docs/boxes/format#box-metadata for further details.
==> selinux: Uploading base box image as volume into Libvirt storage...
==> selinux: Creating image (snapshot of base box volume).
==> selinux: Creating domain with the following settings...
==> selinux:  -- Name:              lab-almalinux9_selinux
==> selinux:  -- Description:       Source: /home/admin_insta11/lab-almalinux9/Vagrantfile
==> selinux:  -- Domain type:       kvm
==> selinux:  -- Cpus:              2
==> selinux:  -- Feature:           acpi
==> selinux:  -- Feature:           apic
==> selinux:  -- Feature:           pae
==> selinux:  -- Clock offset:      utc
==> selinux:  -- Memory:            2048M
==> selinux:  -- Base box:          almalinux9-stand
==> selinux:  -- Storage pool:      default
==> selinux:  -- Image(vda):        /var/lib/libvirt/images/lab-almalinux9_selinux.img, virtio, 20G
==> selinux:  -- Disk driver opts:  cache='default'
==> selinux:  -- Graphics Type:     vnc
==> selinux:  -- Video Type:        cirrus
==> selinux:  -- Video VRAM:        16384
==> selinux:  -- Video 3D accel:    false
==> selinux:  -- Keymap:            en-us
==> selinux:  -- TPM Backend:       passthrough
==> selinux:  -- INPUT:             type=mouse, bus=ps2
==> selinux: Creating shared folders metadata...
==> selinux: Starting domain.
==> selinux: Domain launching with graphics connection settings...
==> selinux:  -- Graphics Port:      5901
==> selinux:  -- Graphics IP:        127.0.0.1
==> selinux:  -- Graphics Password:  Not defined
==> selinux:  -- Graphics Websocket: 5700
==> selinux: Waiting for domain to get an IP address...
==> selinux: Waiting for machine to boot. This may take a few minutes...
    selinux: SSH address: 192.168.121.206:22
    selinux: SSH username: vagrant
    selinux: SSH auth method: private key
    selinux: 
    selinux: Vagrant insecure key detected. Vagrant will automatically replace
    selinux: this with a newly generated keypair for better security.
    selinux: 
    selinux: Inserting generated public key within guest...
    selinux: Removing insecure key from the guest if it's present...
    selinux: Key inserted! Disconnecting and reconnecting using new SSH key...
==> selinux: Machine booted and ready!
==> selinux: Setting hostname...
==> selinux: Configuring and enabling network interfaces...
==> selinux: Running provisioner: shell...
    selinux: Running: inline script
    selinux: AlmaLinux 9 - AppStream                         4.3 MB/s |  23 MB     00:05
    selinux: AlmaLinux 9 - BaseOS                            6.5 MB/s |  31 MB     00:04
    selinux: AlmaLinux 9 - Extras                             31 kB/s |  22 kB     00:00
    selinux: Dependencies resolved.
    selinux: ================================================================================
    selinux:  Package               Architecture    Version            Repository       Size
    selinux: ================================================================================
    selinux: Installing:
    selinux:  epel-release          noarch          9-9.el9            extras           18 k
    selinux: 
    selinux: Transaction Summary
    selinux: ================================================================================
    selinux: Install  1 Package
    selinux: 
    selinux: Total download size: 18 k
    selinux: Installed size: 26 k
    selinux: Downloading Packages:
    selinux: epel-release-9-9.el9.noarch.rpm                 173 kB/s |  18 kB     00:00
    selinux: --------------------------------------------------------------------------------
    selinux: Total                                            26 kB/s |  18 kB     00:00
    selinux: Running transaction check
    selinux: Transaction check succeeded.
    selinux: Running transaction test
    selinux: Transaction test succeeded.
    selinux: Running transaction
    selinux:   Preparing        :                                                        1/1
    selinux:   Installing       : epel-release-9-9.el9.noarch                            1/1
    selinux:   Running scriptlet: epel-release-9-9.el9.noarch                            1/1
    selinux: Many EPEL packages require the CodeReady Builder (CRB) repository.
    selinux: It is recommended that you run /usr/bin/crb enable to enable the CRB repository.
    selinux: 
    selinux:   Verifying        : epel-release-9-9.el9.noarch                            1/1
    selinux: 
    selinux: Installed:
    selinux:   epel-release-9-9.el9.noarch
    selinux: 
    selinux: Complete!
    selinux: Extra Packages for Enterprise Linux 9 - x86_64  1.9 MB/s |  20 MB     00:10
    selinux: Extra Packages for Enterprise Linux 9 openh264  1.4 kB/s | 2.5 kB     00:01
    selinux: Dependencies resolved.
    selinux: ================================================================================
    selinux:  Package                Arch    Version                        Repository  Size
    selinux: ================================================================================
    selinux: Installing:
    selinux:  nginx                  x86_64  2:1.20.1-28.el9_8.5.alma.1     appstream   38 k
    selinux: Installing dependencies:
    selinux:  almalinux-logos-httpd  noarch  90.7-1.el9                     appstream   18 k
    selinux:  nginx-core             x86_64  2:1.20.1-28.el9_8.5.alma.1     appstream  569 k
    selinux:  nginx-filesystem       noarch  2:1.20.1-28.el9_8.5.alma.1     appstream   11 k
    selinux: 
    selinux: Transaction Summary
    selinux: ================================================================================
    selinux: Install  4 Packages
    selinux: 
    selinux: Total download size: 635 k
    selinux: Installed size: 1.8 M
    selinux: Downloading Packages:
    selinux: (1/4): almalinux-logos-httpd-90.7-1.el9.noarch. 184 kB/s |  18 kB     00:00
    selinux: (2/4): nginx-1.20.1-28.el9_8.5.alma.1.x86_64.rp 376 kB/s |  38 kB     00:00
    selinux: (3/4): nginx-filesystem-1.20.1-28.el9_8.5.alma. 368 kB/s |  11 kB     00:00
    selinux: (4/4): nginx-core-1.20.1-28.el9_8.5.alma.1.x86_ 2.2 MB/s | 569 kB     00:00
    selinux: --------------------------------------------------------------------------------
    selinux: Total                                           670 kB/s | 635 kB     00:00
    selinux: Running transaction check
    selinux: Transaction check succeeded.
    selinux: Running transaction test
    selinux: Transaction test succeeded.
    selinux: Running transaction
    selinux:   Preparing        :                                                        1/1
    selinux:   Running scriptlet: nginx-filesystem-2:1.20.1-28.el9_8.5.alma.1.noarch     1/4
    selinux:   Installing       : nginx-filesystem-2:1.20.1-28.el9_8.5.alma.1.noarch     1/4
    selinux:   Installing       : nginx-core-2:1.20.1-28.el9_8.5.alma.1.x86_64           2/4
    selinux:   Installing       : almalinux-logos-httpd-90.7-1.el9.noarch                3/4
    selinux:   Installing       : nginx-2:1.20.1-28.el9_8.5.alma.1.x86_64                4/4
    selinux:   Running scriptlet: nginx-2:1.20.1-28.el9_8.5.alma.1.x86_64                4/4
    selinux:   Verifying        : almalinux-logos-httpd-90.7-1.el9.noarch                1/4
    selinux:   Verifying        : nginx-2:1.20.1-28.el9_8.5.alma.1.x86_64                2/4
    selinux:   Verifying        : nginx-core-2:1.20.1-28.el9_8.5.alma.1.x86_64           3/4
    selinux:   Verifying        : nginx-filesystem-2:1.20.1-28.el9_8.5.alma.1.noarch     4/4
    selinux: 
    selinux: Installed:
    selinux:   almalinux-logos-httpd-90.7-1.el9.noarch
    selinux:   nginx-2:1.20.1-28.el9_8.5.alma.1.x86_64
    selinux:   nginx-core-2:1.20.1-28.el9_8.5.alma.1.x86_64
    selinux:   nginx-filesystem-2:1.20.1-28.el9_8.5.alma.1.noarch
    selinux: 
    selinux: Complete!
    selinux: Last metadata expiration check: 0:00:06 ago on Wed 02 Sep 2026 05:36:13 PM UTC.
    selinux: Dependencies resolved.
    selinux: ================================================================================
    selinux:  Package                        Arch     Version              Repository   Size
    selinux: ================================================================================
    selinux: Installing:
    selinux:  policycoreutils-newrole        x86_64   3.6-5.el9            baseos       23 k
    selinux:  policycoreutils-python-utils   noarch   3.6-5.el9            appstream    69 k
    selinux:  selinux-policy-mls             noarch   38.1.75-2.el9_8      baseos      4.3 M
    selinux:  setools-console                x86_64   4.4.4-1.el9          baseos       46 k
    selinux:  setroubleshoot-server          x86_64   3.3.35-2.el9         appstream   326 k
    selinux: Installing dependencies:
    selinux:  initscripts-service            noarch   10.11.8-4.el9        baseos       11 k
    selinux:  mcstrans                       x86_64   3.6-1.el9            baseos      141 k
    selinux:  python3-dasbus                 noarch   1.7-1.el9            appstream    88 k
    selinux:  python3-libxml2                x86_64   2.9.13-14.el9_8.2    baseos      225 k
    selinux:  setroubleshoot-plugins         noarch   3.3.14-4.el9         appstream   324 k
    selinux: 
    selinux: Transaction Summary
    selinux: ================================================================================
    selinux: Install  10 Packages
    selinux: 
    selinux: Total download size: 5.5 M
    selinux: Installed size: 16 M
    selinux: Downloading Packages:
    selinux: (1/10): policycoreutils-python-utils-3.6-5.el9. 568 kB/s |  69 kB     00:00
    selinux: (2/10): python3-dasbus-1.7-1.el9.noarch.rpm     673 kB/s |  88 kB     00:00
    selinux: (3/10): initscripts-service-10.11.8-4.el9.noarc 277 kB/s |  11 kB     00:00
    selinux: (4/10): setroubleshoot-plugins-3.3.14-4.el9.noa 1.7 MB/s | 324 kB     00:00
    selinux: (5/10): policycoreutils-newrole-3.6-5.el9.x86_6 548 kB/s |  23 kB     00:00
    selinux: (6/10): mcstrans-3.6-1.el9.x86_64.rpm           2.1 MB/s | 141 kB     00:00
    selinux: (7/10): python3-libxml2-2.9.13-14.el9_8.2.x86_6 2.2 MB/s | 225 kB     00:00
    selinux: (8/10): setools-console-4.4.4-1.el9.x86_64.rpm  1.0 MB/s |  46 kB     00:00
    selinux: (9/10): setroubleshoot-server-3.3.35-2.el9.x86_ 1.2 MB/s | 326 kB     00:00
    selinux: (10/10): selinux-policy-mls-38.1.75-2.el9_8.noa 2.9 MB/s | 4.3 MB     00:01
    selinux: --------------------------------------------------------------------------------
    selinux: Total                                           1.3 MB/s | 5.5 MB     00:04
    selinux: Running transaction check
    selinux: Transaction check succeeded.
    selinux: Running transaction test
    selinux: Transaction test succeeded.
    selinux: Running transaction
    selinux:   Running scriptlet: selinux-policy-mls-38.1.75-2.el9_8.noarch              1/1
    selinux:   Preparing        :                                                        1/1
    selinux:   Installing       : python3-libxml2-2.9.13-14.el9_8.2.x86_64              1/10
    selinux:   Installing       : policycoreutils-newrole-3.6-5.el9.x86_64              2/10
    selinux:   Installing       : mcstrans-3.6-1.el9.x86_64                             3/10
    selinux:   Running scriptlet: mcstrans-3.6-1.el9.x86_64                             3/10
    selinux:   Installing       : initscripts-service-10.11.8-4.el9.noarch              4/10
    selinux:   Installing       : python3-dasbus-1.7-1.el9.noarch                       5/10
    selinux:   Installing       : policycoreutils-python-utils-3.6-5.el9.noarch         6/10
    selinux:   Installing       : setroubleshoot-plugins-3.3.14-4.el9.noarch            7/10
    selinux:   Running scriptlet: setroubleshoot-server-3.3.35-2.el9.x86_64             8/10
    selinux:   Installing       : setroubleshoot-server-3.3.35-2.el9.x86_64             8/10
    selinux:   Running scriptlet: setroubleshoot-server-3.3.35-2.el9.x86_64             8/10
    selinux:   Running scriptlet: selinux-policy-mls-38.1.75-2.el9_8.noarch             9/10
    selinux:   Installing       : selinux-policy-mls-38.1.75-2.el9_8.noarch             9/10
    selinux:   Running scriptlet: selinux-policy-mls-38.1.75-2.el9_8.noarch             9/10
    selinux:   Installing       : setools-console-4.4.4-1.el9.x86_64                   10/10
    selinux:   Running scriptlet: selinux-policy-mls-38.1.75-2.el9_8.noarch            10/10
    selinux:   Running scriptlet: setools-console-4.4.4-1.el9.x86_64                   10/10
    selinux:   Verifying        : policycoreutils-python-utils-3.6-5.el9.noarch         1/10
    selinux:   Verifying        : python3-dasbus-1.7-1.el9.noarch                       2/10
    selinux:   Verifying        : setroubleshoot-plugins-3.3.14-4.el9.noarch            3/10
    selinux:   Verifying        : setroubleshoot-server-3.3.35-2.el9.x86_64             4/10
    selinux:   Verifying        : initscripts-service-10.11.8-4.el9.noarch              5/10
    selinux:   Verifying        : mcstrans-3.6-1.el9.x86_64                             6/10
    selinux:   Verifying        : policycoreutils-newrole-3.6-5.el9.x86_64              7/10
    selinux:   Verifying        : python3-libxml2-2.9.13-14.el9_8.2.x86_64              8/10
    selinux:   Verifying        : selinux-policy-mls-38.1.75-2.el9_8.noarch             9/10
    selinux:   Verifying        : setools-console-4.4.4-1.el9.x86_64                   10/10
    selinux: 
    selinux: Installed:
    selinux:   initscripts-service-10.11.8-4.el9.noarch
    selinux:   mcstrans-3.6-1.el9.x86_64
    selinux:   policycoreutils-newrole-3.6-5.el9.x86_64
    selinux:   policycoreutils-python-utils-3.6-5.el9.noarch
    selinux:   python3-dasbus-1.7-1.el9.noarch
    selinux:   python3-libxml2-2.9.13-14.el9_8.2.x86_64
    selinux:   selinux-policy-mls-38.1.75-2.el9_8.noarch
    selinux:   setools-console-4.4.4-1.el9.x86_64
    selinux:   setroubleshoot-plugins-3.3.14-4.el9.noarch
    selinux:   setroubleshoot-server-3.3.35-2.el9.x86_64
    selinux: 
    selinux: Complete!
    selinux: Job for nginx.service failed because the control process exited with error code.
    selinux: See "systemctl status nginx.service" and "journalctl -xeu nginx.service" for details.
    selinux: × nginx.service - The nginx HTTP and reverse proxy server
    selinux:      Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; preset: disabled)
    selinux:      Active: failed (Result: exit-code) since Wed 2026-09-02 17:36:36 UTC; 17ms ago
    selinux:     Process: 6298 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
    selinux:     Process: 6299 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=1/FAILURE)
    selinux:         CPU: 19ms
    selinux: 
    selinux: Sep 02 17:36:36 selinux systemd[1]: Starting The nginx HTTP and reverse proxy server...
    selinux: Sep 02 17:36:36 selinux nginx[6299]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
    selinux: Sep 02 17:36:36 selinux nginx[6299]: nginx: [emerg] bind() to 0.0.0.0:4881 failed (13: Permission denied)
    selinux: Sep 02 17:36:36 selinux nginx[6299]: nginx: configuration file /etc/nginx/nginx.conf test failed
    selinux: Sep 02 17:36:36 selinux systemd[1]: nginx.service: Control process exited, code=exited, status=1/FAILURE
    selinux: Sep 02 17:36:36 selinux systemd[1]: nginx.service: Failed with result 'exit-code'.
    selinux: Sep 02 17:36:36 selinux systemd[1]: Failed to start The nginx HTTP and reverse proxy server.
The SSH command responded with a non-zero exit status. Vagrant
assumes that this means the command failed. The output for this command
should be in the log above. Please read the output to determine what
went wrong.
[admin_insta11@mv334 lab-almalinux9]$ vagrant ssh -c "systemctl status nginx"
× nginx.service - The nginx HTTP and reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; preset: disabled)
     Active: failed (Result: exit-code) since Wed 2026-09-02 17:36:36 UTC; 53s ago
    Process: 6298 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
    Process: 6299 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=1/FAILURE)
        CPU: 19ms
[admin_insta11@mv334 lab-almalinux9]$ 
[admin_insta11@mv334 lab-almalinux9]$ 
[admin_insta11@mv334 lab-almalinux9]$ vagrant status
Current machine states:

selinux                   running (libvirt)

The Libvirt domain is running. To stop this machine, you can run
`vagrant halt`. To destroy the machine, you can run `vagrant destroy`.
[admin_insta11@mv334 lab-almalinux9]$ vagrant ssh 
Last login: Wed Sep  2 17:37:30 2026 from 192.168.121.1
[vagrant@selinux ~]$ ifconfig
-bash: ifconfig: command not found
[vagrant@selinux ~]$ ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 52:54:00:f9:cb:e9 brd ff:ff:ff:ff:ff:ff
    altname enp0s5
    altname ens5
    inet 192.168.121.206/24 brd 192.168.121.255 scope global dynamic noprefixroute eth0
       valid_lft 3033sec preferred_lft 3033sec
    inet6 fe80::7811:f61:fbe:ea84/64 scope link noprefixroute 
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 52:54:00:ab:db:11 brd ff:ff:ff:ff:ff:ff
    altname enp0s6
    altname ens6
    inet 192.168.56.10/24 brd 192.168.56.255 scope global noprefixroute eth1
       valid_lft forever preferred_lft forever
    inet6 fe80::5054:ff:feab:db11/64 scope link 
       valid_lft forever preferred_lft forever
[vagrant@selinux ~]$ exit
logout
[admin_insta11@mv334 lab-almalinux9]$ 
```

ВМ успешно создалась, сконфигурировалась и запустилась (ошибка при запуске сервиса nginx ожидаема и соответствует заданию по SELinux), 
подключение командой 'vargant ssh' к ней успешно.

Также созданная и запущенная ВМ видна в менеджере виртуальных машин KVM virt-manager:

<img width="555" height="547" alt="изображение" src="https://github.com/user-attachments/assets/d6da551e-dba4-4283-b43b-27d65deb21f7" />


Примечание: если в проекте есть несколько виртуальных машин, то для подключения к ним в команде 'vagrant ssh ...' необходимо указывать
название конкретной виртуальной машины (список виртуальных машин и их имён виден в команде 'vagrant status'). Если виртуальная машина в проекте только одна,
то имя её в команде 'vagrantssh' можно не указывать.


## 2. Также проверяем вариант установки и работы Vagrant + Virtualbox

2.1 Устанавливаем Virtualbox, на всякий случай перегружаем хост, после перезагрузки проверяем работу драйвера virtualbox:

```
[admin_insta11@mv334 ~]$ sudo dnf install VirtualBox VirtualBox-guest-additions VirtualBox-kmod_$(uname -r)
[sudo] пароль для admin_insta11: 
Последняя проверка окончания срока действия метаданных: 0:21:31 назад, Пт 04 сен 2026 18:58:19.
Зависимости разрешены.
=================================================================================================================================================
 Пакет                                                  Архитектура            Версия                             Репозиторий              Размер
=================================================================================================================================================
Установка:
 VirtualBox                                             x86_64                 7.1.16-1.el7                       updates                   26 M
 VirtualBox-kmod_6.1.175-1.el7.3.x86_64                 x86_64                 7.1.16-7.el7                       kernels6                 331 k
 kernel-lt                                              x86_64                 6.1.180-1.el7.3                    kernels6                  80 M
 virtualbox-guest-additions                             x86_64                 7.1.16-1.el7                       updates                  721 k
Установка зависимостей:
 VirtualBox-kmod                                        x86_64                 7.1.16-9.el7                       kernels6                 7.7 k
 VirtualBox-kmod_6.1.180-1.el7.3.x86_64                 x86_64                 7.1.16-9.el7                       kernels6                 330 k
 VirtualBox-server                                      x86_64                 7.1.16-1.el7                       updates                   22 M
 qt6-qtscxml                                            x86_64                 6.6.3-1.el7                        updates                  539 k
 qt6-qttools-common                                     noarch                 6.6.3-1.el7                        updates                  9.6 k
 qt6-qttools-libs-help                                  x86_64                 6.6.3-1.el7                        updates                  191 k

Результат транзакции
=================================================================================================================================================
Установка  10 Пакетов

Объем загрузки: 130 M
Объем изменений: 511 M
Продолжить? [д/Н]: y
Загрузка пакетов:
(1/10): qt6-qtscxml-6.6.3-1.el7.x86_64.rpm                                                                       465 kB/s | 539 kB     00:01    
(2/10): qt6-qttools-common-6.6.3-1.el7.noarch.rpm                                                                 34 kB/s | 9.6 kB     00:00    
(3/10): qt6-qttools-libs-help-6.6.3-1.el7.x86_64.rpm                                                             238 kB/s | 191 kB     00:00    
(4/10): virtualbox-guest-additions-7.1.16-1.el7.x86_64.rpm                                                       283 kB/s | 721 kB     00:02    
(5/10): VirtualBox-kmod-7.1.16-9.el7.x86_64.rpm                                                                   45 kB/s | 7.7 kB     00:00    
(6/10): VirtualBox-kmod_6.1.175-1.el7.3.x86_64-7.1.16-7.el7.x86_64.rpm                                           388 kB/s | 331 kB     00:00    
(7/10): VirtualBox-kmod_6.1.180-1.el7.3.x86_64-7.1.16-9.el7.x86_64.rpm                                           695 kB/s | 330 kB     00:00    
(8/10): VirtualBox-server-7.1.16-1.el7.x86_64.rpm                                                                913 kB/s |  22 MB     00:24    
(9/10): VirtualBox-7.1.16-1.el7.x86_64.rpm                                                                       746 kB/s |  26 MB     00:35    
(10/10): kernel-lt-6.1.180-1.el7.3.x86_64.rpm                                                                    2.1 MB/s |  80 MB     00:37    
-------------------------------------------------------------------------------------------------------------------------------------------------
Общий размер                                                                                                     2.9 MB/s | 130 MB     00:44     
Проверка транзакции
Проверка транзакции успешно завершена.
Идет проверка транзакции
Тест транзакции проведен успешно.
Выполнение транзакции
  Подготовка       :                                                                                                                         1/1 
  Запуск скриптлета: kernel-lt-6.1.180-1.el7.3.x86_64                                                                                       1/10 
  Установка        : kernel-lt-6.1.180-1.el7.3.x86_64                                                                                       1/10 
  Установка        : VirtualBox-kmod_6.1.180-1.el7.3.x86_64-7.1.16-9.el7.x86_64                                                             2/10 
  Установка        : VirtualBox-kmod-7.1.16-9.el7.x86_64                                                                                    3/10 
  Установка        : VirtualBox-server-7.1.16-1.el7.x86_64                                                                                  4/10 
  Запуск скриптлета: VirtualBox-server-7.1.16-1.el7.x86_64                                                                                  4/10 
Created symlink /etc/systemd/system/multi-user.target.wants/vboxdrv.service → /usr/lib/systemd/system/vboxdrv.service.

  Установка        : qt6-qttools-common-6.6.3-1.el7.noarch                                                                                  5/10 
  Установка        : qt6-qttools-libs-help-6.6.3-1.el7.x86_64                                                                               6/10 
  Установка        : qt6-qtscxml-6.6.3-1.el7.x86_64                                                                                         7/10 
  Установка        : VirtualBox-7.1.16-1.el7.x86_64                                                                                         8/10 
  Установка        : virtualbox-guest-additions-7.1.16-1.el7.x86_64                                                                         9/10 
  Запуск скриптлета: virtualbox-guest-additions-7.1.16-1.el7.x86_64                                                                         9/10 
  Установка        : VirtualBox-kmod_6.1.175-1.el7.3.x86_64-7.1.16-7.el7.x86_64                                                            10/10 
  Запуск скриптлета: kernel-lt-6.1.180-1.el7.3.x86_64                                                                                      10/10 
  Запуск скриптлета: VirtualBox-kmod_6.1.180-1.el7.3.x86_64-7.1.16-9.el7.x86_64                                                            10/10 
  Запуск скриптлета: VirtualBox-kmod_6.1.175-1.el7.3.x86_64-7.1.16-7.el7.x86_64                                                            10/10 
Creating group vboxsf with gid 969.
Creating group vboxusers with gid 968.
Creating user vboxadd (n/a) with uid 967 and gid 1.

  Проверка         : VirtualBox-7.1.16-1.el7.x86_64                                                                                         1/10 
  Проверка         : VirtualBox-server-7.1.16-1.el7.x86_64                                                                                  2/10 
  Проверка         : qt6-qtscxml-6.6.3-1.el7.x86_64                                                                                         3/10 
  Проверка         : qt6-qttools-common-6.6.3-1.el7.noarch                                                                                  4/10 
  Проверка         : qt6-qttools-libs-help-6.6.3-1.el7.x86_64                                                                               5/10 
  Проверка         : virtualbox-guest-additions-7.1.16-1.el7.x86_64                                                                         6/10 
  Проверка         : VirtualBox-kmod-7.1.16-9.el7.x86_64                                                                                    7/10 
  Проверка         : VirtualBox-kmod_6.1.175-1.el7.3.x86_64-7.1.16-7.el7.x86_64                                                             8/10 
  Проверка         : VirtualBox-kmod_6.1.180-1.el7.3.x86_64-7.1.16-9.el7.x86_64                                                             9/10 
  Проверка         : kernel-lt-6.1.180-1.el7.3.x86_64                                                                                      10/10 

Установлен:
  VirtualBox-7.1.16-1.el7.x86_64                                          VirtualBox-kmod-7.1.16-9.el7.x86_64                                    
  VirtualBox-kmod_6.1.175-1.el7.3.x86_64-7.1.16-7.el7.x86_64              VirtualBox-kmod_6.1.180-1.el7.3.x86_64-7.1.16-9.el7.x86_64             
  VirtualBox-server-7.1.16-1.el7.x86_64                                   kernel-lt-6.1.180-1.el7.3.x86_64                                       
  qt6-qtscxml-6.6.3-1.el7.x86_64                                          qt6-qttools-common-6.6.3-1.el7.noarch                                  
  qt6-qttools-libs-help-6.6.3-1.el7.x86_64                                virtualbox-guest-additions-7.1.16-1.el7.x86_64                         

Выполнено!
[admin_insta11@mv334 ~]$
[admin_insta11@mv334 ~]$ sudo reboot

<... ПЕРЕЗАГРУЗКА ...>

[admin_insta11@mv334 ~]$ systemctl status vboxdrv
● vboxdrv.service - Linux kernel module init script
     Loaded: loaded (/usr/lib/systemd/system/vboxdrv.service; enabled; vendor preset: enabled)
     Active: active (exited) since Fri 2026-09-04 19:23:37 MSK; 3min 38s ago
    Process: 705 ExecStart=/sbin/modprobe vboxdrv (code=exited, status=0/SUCCESS)
    Process: 745 ExecStart=/sbin/modprobe vboxnetflt (code=exited, status=0/SUCCESS)
    Process: 750 ExecStart=/sbin/modprobe vboxnetadp (code=exited, status=0/SUCCESS)
   Main PID: 750 (code=exited, status=0/SUCCESS)
        CPU: 27ms

сен 04 19:23:37 mv334 systemd[1]: Starting Linux kernel module init script...
сен 04 19:23:37 mv334 systemd[1]: Finished Linux kernel module init script.
[admin_insta11@mv334 ~]$
```

2.2 Добавляем Бокс ВМ в реестр vagrant:

```
[admin_insta11@mv334 ~]$ ll /distrib/vagrant_boxes/
итого 8408428
-rwxrwxrwx 1 admin_insta11 admin_insta11  546709438 авг 31 21:50  almalinux-9-9.8.20260810-amd64-libvirt.box
-rwxrwxrwx 1 admin_insta11 admin_insta11  698021674 авг 31 22:18  almalinux-9-9.8.20260810-amd64-virtualbox.box
-rwxrwxrwx 1 admin_insta11 admin_insta11  838235264 сен  1 06:22  bento-ubuntu-22.04-202510.26.0-amd64-virtualbox.box
-rwxrwxrwx 1 admin_insta11 admin_insta11 3216132560 авг 31 23:48  bento-ubuntu-26.04-202606.01.0-amd64-libvirt.box
-rwxrwxrwx 1 admin_insta11 admin_insta11 3311076684 сен  1 06:00  bento-ubuntu-26.04-202606.01.0-amd64-virtualbox.box
-rwxrwxrwx 1 admin_insta11 admin_insta11       2020 сен  1 18:12 'Vagrant boxes.txt'
[admin_insta11@mv334 ~]$ export BOX_FILE="almalinux-9-9.8.20260810-amd64-virtualbox.box"
[admin_insta11@mv334 ~]$ export BOX_FILE="/distrib/vagrant_boxes/almalinux-9-9.8.20260810-amd64-virtualbox.box"
[admin_insta11@mv334 ~]$ vagrant box add --name "$BOX_NAME" "$BOX_FILE"
==> box: Box file was not detected as metadata. Adding it directly...
==> box: Adding box 'almalinux9-stand-vb' (v0) for provider: 
    box: Unpacking necessary files from: file:///distrib/vagrant_boxes/almalinux-9-9.8.20260810-amd64-virtualbox.box
==> box: Successfully added box 'almalinux9-stand-vb' (v0) for ''!
[admin_insta11@mv334 ~]$ 
[admin_insta11@mv334 ~]$ 
[admin_insta11@mv334 ~]$ vagrant box list
almalinux9-stand    (libvirt, 0)
almalinux9-stand-vb (virtualbox, 0)
[admin_insta11@mv334 ~]$
```

2.3 Создаём проект и Vagrantfile для новой ВМ. При этом делаем в исходном Vagrantfile для virtualbox изменения для использования локально установленного бокса ВМ (вместо скачивания его из облака):
- строку ':box_name => "almalinux/9"' заменяем на строку ':box_name => "almalinux9-stand-vb"' с именем локально установленного бокса из команды 'vagrant box add';
- убираем точную версию и ссылку на неё, так как локально установленная точная версия немного отличается.

Исправленный Vagrantfile для virtualbox приведён ниже:
```
[admin_insta11@mv334 ~]$ mkdir -p ~/lab-almalinux9-virtualbox && cd ~/lab-almalinux9-virtualbox
[admin_insta11@mv334 ~]$
[admin_insta11@mv334 lab-almalinux9-virtualbox]$ cat > Vagrantfile
MACHINES = {
  :"selinux" => {
#              :box_name => "almalinux/9",       # <-- меняем на имя локально установленного бокса из vagrant box add
#              :box_version => "9.4.20240805",   # <-- убираем точную версию, так как локальная отличается
              :box_name => "almalinux9-stand-vb",
              :cpus => 2,
              :memory => 2048
            }
}

Vagrant.configure("2") do |config|
  MACHINES.each do |boxname, boxconfig|
    config.vm.synced_folder ".", "/vagrant", disabled: true
    config.vm.define boxname do |box|
      box.vm.box = boxconfig[:box_name]
#      box.vm.box_version = boxconfig[:box_version]   # <--  убираем ссылку на точную версию в хэше MACHINES
      box.vm.host_name = boxname.to_s
      box.vm.network "forwarded_port", guest: 4881, host: 4881
      box.vm.provider "virtualbox" do |v|
        v.memory = boxconfig[:memory]
        v.cpus = boxconfig[:cpus]
      end
      box.vm.provision "shell", inline: <<-SHELL
      yum install -y epel-release
      yum install -y nginx
      yum install -y setroubleshoot-server selinux-policy-mls setools-console policycoreutils-python-utils policycoreutils-newrole
      sed -ie 's/:80/:4881/g' /etc/nginx/nginx.conf
      sed -i 's/listen       80;/listen       4881;/' /etc/nginx/nginx.conf
      systemctl start nginx
      systemctl status nginx
      ss -tlpn | grep 4881
SHELL
    end
  end
end

```

2.4 Создаём и запускаем ВМ для virtualbox. Для запуска virtualbox необходимо выгрузить драйверы ядра для libvirt/kvm - два гипервизора
не могут быть одновременно запущены на одном хосте, при запуске ВМ для virtualbox выдаётся ошибка:

```
[admin_insta11@mv334 lab-almalinux9-virtualbox]$ vagrant up
Bringing machine 'selinux' up with 'virtualbox' provider...
==> selinux: Importing base box 'almalinux9-stand-vb'...
==> selinux: Matching MAC address for NAT networking...
==> selinux: Setting the name of the VM: lab-almalinux9-virtualbox_selinux_1788544356267_45854
==> selinux: Clearing any previously set network interfaces...
==> selinux: Preparing network interfaces based on configuration...
    selinux: Adapter 1: nat
==> selinux: Forwarding ports...
    selinux: 4881 (guest) => 4881 (host) (adapter 1)
    selinux: 22 (guest) => 2222 (host) (adapter 1)
==> selinux: Running 'pre-boot' VM customizations...
==> selinux: Booting VM...
There was an error while executing `VBoxManage`, a CLI used by Vagrant
for controlling VirtualBox. The command and stderr is shown below.

Command: ["startvm", "4141b4ad-07d8-4f90-8be7-d215c6d2db39", "--type", "headless"]

Stderr: VBoxManage: error: VT-x is being used by another hypervisor (VERR_VMX_IN_VMX_ROOT_MODE).
VBoxManage: error: VirtualBox can't operate in VMX root mode. Please disable the KVM kernel extension, recompile your kernel and reboot (VERR_VMX_IN_VMX_ROOT_MODE)
VBoxManage: error: Details: code NS_ERROR_FAILURE (0x80004005), component ConsoleWrap, interface IConsole

[admin_insta11@mv334 lab-almalinux9-virtualbox]$
```

Поэтому перед запуском ВМ для virtualbox сначала ВРЕМЕННО останавливаем виртуальные машины, запущенные в KVM, сам гипервизор KVM и его драйвера ядра:

```
[admin_insta11@mv334 lab-almalinux9-kvm]$ vagrant halt
==> selinux: Attempting graceful shutdown of VM...
[admin_insta11@mv334 lab-almalinux9-kvm]$ 
[admin_insta11@mv334 lab-almalinux9-kvm]$ 
[admin_insta11@mv334 lab-almalinux9-kvm]$ sudo virsh list
[sudo] пароль для admin_insta11: 
 ID   Имя   Состояние
-----------------------

[admin_insta11@mv334 lab-almalinux9-kvm]$ sudo systemctl stop libvirtd.socket libvirtd-ro.socket libvirtd-admin.socket libvirtd.service
[admin_insta11@mv334 lab-almalinux9-kvm]$
[admin_insta11@mv334 lab-almalinux9-kvm]$ lsmod | grep kvm
kvm_intel             389120  0
kvm                  1118208  1 kvm_intel
irqbypass              16384  1 kvm
[admin_insta11@mv334 lab-almalinux9-kvm]$
[admin_insta11@mv334 lab-almalinux9-kvm]$ sudo modprobe -r kvm_intel
[admin_insta11@mv334 lab-almalinux9-kvm]$
[admin_insta11@mv334 lab-almalinux9-kvm]$ lsmod | grep kvm
[admin_insta11@mv334 lab-almalinux9-kvm]$ 
```

А затем запускаем ВМ для virtualbox:

```
[admin_insta11@mv334 lab-almalinux9-kvm]$ cd ..
[admin_insta11@mv334 ~]$ cd lab-almalinux9-virtualbox/
[admin_insta11@mv334 lab-almalinux9-virtualbox]$ vagrant up
Bringing machine 'selinux' up with 'virtualbox' provider...
==> selinux: Clearing any previously set forwarded ports...
==> selinux: Clearing any previously set network interfaces...
==> selinux: Preparing network interfaces based on configuration...
    selinux: Adapter 1: nat
==> selinux: Forwarding ports...
    selinux: 4881 (guest) => 4881 (host) (adapter 1)
    selinux: 22 (guest) => 2222 (host) (adapter 1)
==> selinux: Running 'pre-boot' VM customizations...
==> selinux: Booting VM...
==> selinux: Waiting for machine to boot. This may take a few minutes...
    selinux: SSH address: 127.0.0.1:2222
    selinux: SSH username: vagrant
    selinux: SSH auth method: private key
==> selinux: Machine booted and ready!
==> selinux: Checking for guest additions in VM...
    selinux: The guest additions on this VM do not match the installed version of
    selinux: VirtualBox! In most cases this is fine, but in rare cases it can
    selinux: prevent things such as shared folders from working properly. If you see
    selinux: shared folder errors, please make sure the guest additions within the
    selinux: virtual machine match the version of VirtualBox you have installed on
    selinux: your host and reload your VM.
    selinux: 
    selinux: Guest Additions Version: 7.2.16
    selinux: VirtualBox Version: 7.1
==> selinux: Setting hostname...
==> selinux: Machine already provisioned. Run `vagrant provision` or use the `--provision`
==> selinux: flag to force provisioning. Provisioners marked to run always will still run.
[admin_insta11@mv334 lab-almalinux9-virtualbox]$ 
[admin_insta11@mv334 lab-almalinux9-virtualbox]$ vagrant ssh
Last login: Fri Sep  4 18:08:48 2026 from 10.0.2.2
[vagrant@selinux ~]$
```

При этом в менеджере VirtualBox видна созданная и запущенная виртуальная машина:

<img width="967" height="574" alt="изображение" src="https://github.com/user-attachments/assets/79e8d67e-e201-4f5a-a56c-3103ede6a21f" />


2.5 После эксперимента с запуском ВМ для virtualbox для переключения обратно на libvrt/kvm останавливаем все ВМ для virtualbox (драйвер
virtualbox выгружать не нужно), загружаем драйвера ядра для libvrt/kvm, запускаем сервис libvirt, и после этого запускаем ВМ в KVM:

```
[admin_insta11@mv334 lab-almalinux9-virtualbox]$ vagrant ssh
Last login: Fri Sep  4 18:08:48 2026 from 10.0.2.2
[vagrant@selinux ~]$ exit
logout
[admin_insta11@mv334 lab-almalinux9-virtualbox]$ vagrant halt
==> selinux: Attempting graceful shutdown of VM...
[admin_insta11@mv334 lab-almalinux9-virtualbox]$ 
[admin_insta11@mv334 lab-almalinux9-virtualbox]$ cd ..
[admin_insta11@mv334 ~]$ cd lab-almalinux9-kvm
[admin_insta11@mv334 lab-almalinux9-kvm]$ 
[admin_insta11@mv334 lab-almalinux9-kvm]$ sudo modprobe kvm_intel
[admin_insta11@mv334 lab-almalinux9-kvm]$ 
[admin_insta11@mv334 lab-almalinux9-kvm]$ lsmod | grep kvm
kvm_intel             389120  0
kvm                  1118208  1 kvm_intel
irqbypass              16384  1 kvm
[admin_insta11@mv334 lab-almalinux9-kvm]$ 
[admin_insta11@mv334 lab-almalinux9-kvm]$ sudo systemctl start libvirtd
[admin_insta11@mv334 lab-almalinux9-kvm]$ 
[admin_insta11@mv334 lab-almalinux9-kvm]$ vagrant up
Bringing machine 'selinux' up with 'libvirt' provider...
==> selinux: Creating shared folders metadata...
==> selinux: Starting domain.
==> selinux: Domain launching with graphics connection settings...
==> selinux:  -- Graphics Port:      5900
==> selinux:  -- Graphics IP:        127.0.0.1
==> selinux:  -- Graphics Password:  Not defined
==> selinux:  -- Graphics Websocket: 5700
==> selinux: Waiting for domain to get an IP address...
==> selinux: Waiting for machine to boot. This may take a few minutes...
    selinux: SSH address: 192.168.121.206:22
    selinux: SSH username: vagrant
    selinux: SSH auth method: private key
    selinux: Warning: Host unreachable. Retrying...
    selinux: Warning: Connection refused. Retrying...
==> selinux: Machine booted and ready!
==> selinux: Machine already provisioned. Run `vagrant provision` or use the `--provision`
==> selinux: flag to force provisioning. Provisioners marked to run always will still run.
[admin_insta11@mv334 lab-almalinux9-kvm]$ 
[admin_insta11@mv334 lab-almalinux9-kvm]$ vagrant ssh
Last login: Fri Sep  4 19:39:34 2026 from 192.168.121.1
[vagrant@selinux ~]$ 
[vagrant@selinux ~]$ exit
logout
[admin_insta11@mv334 lab-almalinux9-kvm]$ vagrant halt
==> selinux: Attempting graceful shutdown of VM...
[admin_insta11@mv334 lab-almalinux9-kvm]$ 
```

