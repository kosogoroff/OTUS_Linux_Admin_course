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

1.2.2 Создаём директорию для нового проекта и создаём в ней Vagrantfile

Исходный рабочий Vagrantfile из примера, продемонстрированного на занятии, по ссылке https://github.com/pcade/vagrant-examples/tree/main/network-storage-provisioning следующего содержания:

```
Vagrant.configure("2") do |config|
  # Ubuntu Jammy
  config.vm.define "ubuntu-jammy" do |srv|
    srv.vm.box = "ubuntu/jammy64"
    srv.vm.provider "virtualbox" do |vb|
      vb.memory = 2048
      vb.cpus = 2
      vb.name = "ubuntu-jammy-vm"
      vb.customize ['modifyvm', :id, '--audio', 'none']
    end

    # Синхронизация папок
    srv.vm.synced_folder "./", "/vagrant"

    # Подключение диска
    srv.vm.disk :disk, size: "1GB", name: "disk1"

    # Проброс порта для HTTP (будет доступен по localhost:8080)
    srv.vm.network(:forwarded_port,
                    guest: 80,
                    host: 8080,
                    host_ip: "127.0.0.1")

    # Приватная сеть в той же подсети, что и virbr0 на хосте (192.168.122.0/24)
    srv.vm.network(:private_network,
                   ip: "192.168.56.11",
                   libvirt__network_name: "default",  # Это для Libvirt, но для VirtualBox просто укажите IP
                   auto_config: true)

    # Provisioning - установка Apache
    srv.vm.provision "shell", inline: <<-SHELL
      # Обновление пакетов
      sudo apt-get update
      
      # Установка Apache
      sudo apt-get install -y apache2
      
      # Отключаем стандартную папку /var/www/html
      sudo a2dissite 000-default.conf
      
      # Создаем конфигурацию для нашего сайта
      echo "<VirtualHost *:80>
          DocumentRoot /vagrant
          <Directory /vagrant>
              Options Indexes FollowSymLinks
              AllowOverride All
              Require all granted
          </Directory>
      </VirtualHost>" | sudo tee /etc/apache2/sites-available/vagrant.conf
      
      # Включаем наш сайт
      sudo a2ensite vagrant.conf
      
      # Включение mod_rewrite
      sudo a2enmod rewrite
      
      # Перезапуск Apache
      sudo systemctl restart apache2
    SHELL
  end
end
```

Но данный файл создан для работы с virtualbox, поэтому для использования с KVM в нём нужно сделать несколько изменений:
Нужно поменять три вещи: провайдер, сеть и источник бокса.

Также в связи с недоступностью портала https://portal.cloud.hashicorp.com/ для проверки и работы заранее локально скачаны несколько Vagrant box для различных версий Linux, для создания ВМ будем использовать локально скачаные и установленные боксы. 

Модифицированный Vagrantfile приведён ниже (с учётом возможности запуска под libvirt/kvm и virtualbox, а также с учётом выполнение лабораточного задания):

```
# Имя бокса можно переопределить через переменную окружения:
#   VAGRANT_BOX=almalinux9-stand vagrant up --provider=libvirt
BOX_NAME = ENV['VAGRANT_BOX'] || 'ubuntu-jammy'

Vagrant.configure("2") do |config|
  # Ubuntu Jammy
  config.vm.define "ubuntu-jammy" do |srv|
    srv.vm.box = BOX_NAME

    srv.vm.provider "virtualbox" do |vb|
      vb.memory = 2048
      vb.cpus = 2
      vb.name = "ubuntu-vm"
      vb.customize ['modifyvm', :id, '--audio', 'none']
    end

    srv.vm.provider "libvirt" do |vb|
      vb.memory = 2048
      vb.cpus = 2
      vb.name = "ubuntu-vm"
      vb.customize ['modifyvm', :id, '--audio', 'none']
    end

    # Синхронизация папок
    srv.vm.synced_folder "./", "/vagrant"

    # Подключение диска
    srv.vm.disk :disk, size: "1GB", name: "disk1"
    srv.vm.disk :disk, size: "1GB", name: "disk2"

    # Проброс порта для HTTP (будет доступен по localhost:8080)
    srv.vm.network(:forwarded_port,
                    guest: 80,
                    host: 8080,
                    host_ip: "127.0.0.1")

    # Приватная сеть в той же подсети, что и virbr0 на хосте (192.168.122.0/24)
    srv.vm.network(:private_network,
                   ip: "192.168.56.11",
                   virtualbox__intnet: "dns",
                   libvirt__network_name: "dns",
                   libvirt__host_ip: "192.168.56.1",
                   libvirt__netmask: "255.255.255.0",
                   auto_config: true)

    # Provisioning - установка Apache
    srv.vm.provision "shell", inline: <<-SHELL

      # монтирование двух созданных дисков по 1Gb
      sudo parted -s /dev/sdb mklabel gpt mkpart primary 1MiB 100%
      sudo mkfs.ext4 -F /dev/sdb1
      sudo mkdir -p /mnt/disk1
      UUID=$(sudo blkid -s UUID -o value /dev/sdb1)
      sudo umount /mnt/disk1
      sudo mount UUID=$UUID /mnt/disk1
      sudo chmod -R 0777 /mnt/disk1
      sudo sed -i "/\/mnt\/disk1/d" /etc/fstab
      sudo echo "UUID=$UUID  \/mnt\/disk1  ext4  defaults,noatime,nodiratime  0  2" >> /etc/fstab

      sudo parted -s /dev/sdc mklabel gpt mkpart primary 1MiB 100%
      sudo mkfs.ext4 -F /dev/sdc1
      sudo mkdir -p /mnt/disk2
      UUID=$(sudo blkid -s UUID -o value /dev/sdc1)
      sudo umount /mnt/disk2
      sudo mount UUID=$UUID /mnt/disk2
      sudo chmod -R 0777 /mnt/disk2
      sudo sed -i "/\/mnt\/disk2/d" /etc/fstab
      sudo echo "UUID=$UUID  \/mnt\/disk2  ext4  defaults,noatime,nodiratime  0  2" >> /etc/fstab

      # Обновление пакетов
      sudo apt-get update
      
      # Установка Apache
      sudo apt-get install -y apache2
      
      # Отключаем стандартную папку /var/www/html
      sudo a2dissite 000-default.conf
      
      # Создаем конфигурацию для нашего сайта
      echo "<VirtualHost *:80>
          DocumentRoot /vagrant
          <Directory /vagrant>
              Options Indexes FollowSymLinks
              AllowOverride All
              Require all granted
          </Directory>
      </VirtualHost>" | sudo tee /etc/apache2/sites-available/vagrant.conf
      
      # Включаем наш сайт
      sudo a2ensite vagrant.conf
      
      # Включение mod_rewrite
      sudo a2enmod rewrite
      
      # Перезапуск Apache
      sudo systemctl restart apache2
    SHELL
  end
end
```

Данный модифицированный Vagrantfile допускает следующее использование:

1) Для создания ВМ в гипервизоре virtualbox с использованием бокса ubuntu-jammy на vagrantcloud нужно запустить командой

```
vagrant up
```

Если боксы установлены на компьютере локально, например:

```
[admin_insta11@mv334 network-storage-provisioning]$ vagrant box list
almalinux9-stand        (libvirt, 0)
almalinux9-stand-vb     (virtualbox, 0)
ubuntu-22.04-virtualbox (virtualbox, 0)
[admin_insta11@mv334 network-storage-provisioning]$ 
```

2) Для создания ВМ в гипервизоре libvirt/kvm с использованием локально установленного бокса almalinux/9 нужно запустить командой (в данной лабораторной нам вариант с Almalinux не нужен, приведён справочно)

```
VAGRANT_BOX=almalinux9-stand vagrant up --provider=libvirt
```

3) Для создания ВМ в гипервизоре virtualbox с использованием локально установленного бокса ubuntu-22.04-virtualbox нужно запустить командой

```
VAGRANT_BOX=ubuntu-22.04-virtualbox vagrant up --provider=virtualbox
```

или

```
VAGRANT_BOX=ubuntu-22.04-virtualbox vagrant up
```

Создаём виртуальную машину и производим её конфигурирование и провизионинг средствами vagrant:

- Выбран образ Ubuntu 22.04 для virtualbox.
- Память ВМ: 2048 МБ.

Добавление дисков:

- Добавлены два виртуальных диска размером 1 ГБ каждый.

Настройка сети:

- Настроен проброс 80 порта с гостевой системы на порт 8080 хостовой системы.

Провижининг:

Написан провижининг средствами Vagrant, который:

- Форматирует добавленные диски в файловую систему ext4.
  
- Создает точки монтирования /mnt/disk1 и /mnt/disk2.
  
- Монтирует диски в указанные директории.

- Добавляет записи в /etc/fstab для автоматического монтирования при загрузке.


По ссылке ниже размещён лабораторный стенд с выполненным домашним заданием:

https://github.com/kosogoroff/vagrant-provisioning-net-disks.git

Запускаем и создаём ВМ с использованием созданного Vagrantfile из локально установленного бокса, при первом запуске
производится его первый провизионинг. В дальнейшем можно запускать просто командой 'vagrant up':

```
[admin_insta11@mv334 vagrant-provisioning-net-disksg]$ VAGRANT_BOX=ubuntu-22.04-virtualbox vagrant up
Bringing machine 'ubuntu-jammy' up with 'virtualbox' provider...
==> ubuntu-jammy: Importing base box 'ubuntu-22.04-virtualbox'...
==> ubuntu-jammy: Matching MAC address for NAT networking...
==> ubuntu-jammy: Setting the name of the VM: ubuntu-vm
==> ubuntu-jammy: Clearing any previously set network interfaces...
==> ubuntu-jammy: Preparing network interfaces based on configuration...
    ubuntu-jammy: Adapter 1: nat
    ubuntu-jammy: Adapter 2: intnet
==> ubuntu-jammy: Forwarding ports...
    ubuntu-jammy: 80 (guest) => 8080 (host) (adapter 1)
    ubuntu-jammy: 22 (guest) => 2222 (host) (adapter 1)
==> ubuntu-jammy: Configuring storage mediums...
    ubuntu-jammy: Disk 'disk1' not found in guest. Creating and attaching disk to guest...
    ubuntu-jammy: Disk 'disk2' not found in guest. Creating and attaching disk to guest...
==> ubuntu-jammy: Running 'pre-boot' VM customizations...
==> ubuntu-jammy: Booting VM...
==> ubuntu-jammy: Waiting for machine to boot. This may take a few minutes...
    ubuntu-jammy: SSH address: 127.0.0.1:2222
    ubuntu-jammy: SSH username: vagrant
    ubuntu-jammy: SSH auth method: private key
    ubuntu-jammy: 
    ubuntu-jammy: Vagrant insecure key detected. Vagrant will automatically replace
    ubuntu-jammy: this with a newly generated keypair for better security.
    ubuntu-jammy: 
    ubuntu-jammy: Inserting generated public key within guest...
    ubuntu-jammy: Removing insecure key from the guest if it's present...
    ubuntu-jammy: Key inserted! Disconnecting and reconnecting using new SSH key...
==> ubuntu-jammy: Machine booted and ready!
==> ubuntu-jammy: Checking for guest additions in VM...
    ubuntu-jammy: The guest additions on this VM do not match the installed version of
    ubuntu-jammy: VirtualBox! In most cases this is fine, but in rare cases it can
    ubuntu-jammy: prevent things such as shared folders from working properly. If you see
    ubuntu-jammy: shared folder errors, please make sure the guest additions within the
    ubuntu-jammy: virtual machine match the version of VirtualBox you have installed on
    ubuntu-jammy: your host and reload your VM.
    ubuntu-jammy: 
    ubuntu-jammy: Guest Additions Version: 7.2.4
    ubuntu-jammy: VirtualBox Version: 7.1
==> ubuntu-jammy: Configuring and enabling network interfaces...
==> ubuntu-jammy: Mounting shared folders...
    ubuntu-jammy: /home/admin_insta11/network-storage-provisioning => /vagrant
==> ubuntu-jammy: Running provisioner: shell...
    ubuntu-jammy: Running: inline script
    ubuntu-jammy: mke2fs 1.46.5 (30-Dec-2021)
    ubuntu-jammy: Creating filesystem with 261632 4k blocks and 65408 inodes
    ubuntu-jammy: Filesystem UUID: 04642414-fdd4-4b23-adc4-043c97c984c2
    ubuntu-jammy: Superblock backups stored on blocks:
    ubuntu-jammy: 	32768, 98304, 163840, 229376
    ubuntu-jammy: 
    ubuntu-jammy: Allocating group tables: done
    ubuntu-jammy: Writing inode tables: done
    ubuntu-jammy: Creating journal (4096 blocks): done
    ubuntu-jammy: Writing superblocks and filesystem accounting information: done
    ubuntu-jammy: 
    ubuntu-jammy: umount: /mnt/disk1: not mounted.
    ubuntu-jammy: sed: -e expression #1, char 3: unknown command: `m'
    ubuntu-jammy: mke2fs 1.46.5 (30-Dec-2021)
    ubuntu-jammy: Creating filesystem with 261632 4k blocks and 65408 inodes
    ubuntu-jammy: Filesystem UUID: 8ac5aa8d-6c28-470f-b6d3-b8c56fb6bbf3
    ubuntu-jammy: Superblock backups stored on blocks:
    ubuntu-jammy: 	32768, 98304, 163840, 229376
    ubuntu-jammy: 
    ubuntu-jammy: Allocating group tables: done
    ubuntu-jammy: Writing inode tables: done
    ubuntu-jammy: Creating journal (4096 blocks): done
    ubuntu-jammy: Writing superblocks and filesystem accounting information: done
    ubuntu-jammy: 
    ubuntu-jammy: umount: /mnt/disk2: not mounted.
    ubuntu-jammy: sed: -e expression #1, char 3: unknown command: `m'
    ubuntu-jammy: Hit:1 http://us.archive.ubuntu.com/ubuntu jammy InRelease
    ubuntu-jammy: Get:2 http://security.ubuntu.com/ubuntu jammy-security InRelease [129 kB]
    ubuntu-jammy: Get:3 http://us.archive.ubuntu.com/ubuntu jammy-updates InRelease [128 kB]
    ubuntu-jammy: Get:4 http://us.archive.ubuntu.com/ubuntu jammy-backports InRelease [127 kB]
    ubuntu-jammy: Get:5 http://security.ubuntu.com/ubuntu jammy-security/main amd64 Packages [3,526 kB]
    ubuntu-jammy: Get:6 http://us.archive.ubuntu.com/ubuntu jammy-updates/main amd64 Packages [3,795 kB]
    ubuntu-jammy: Get:7 http://us.archive.ubuntu.com/ubuntu jammy-updates/main Translation-en [563 kB]
    ubuntu-jammy: Get:8 http://security.ubuntu.com/ubuntu jammy-security/main Translation-en [495 kB]
    ubuntu-jammy: Get:9 http://us.archive.ubuntu.com/ubuntu jammy-updates/restricted amd64 Packages [6,542 kB]
    ubuntu-jammy: Get:10 http://security.ubuntu.com/ubuntu jammy-security/restricted amd64 Packages [6,306 kB]
    ubuntu-jammy: Get:11 http://us.archive.ubuntu.com/ubuntu jammy-updates/restricted Translation-en [1,256 kB]
    ubuntu-jammy: Get:12 http://us.archive.ubuntu.com/ubuntu jammy-updates/universe amd64 Packages [1,282 kB]
    ubuntu-jammy: Get:13 http://security.ubuntu.com/ubuntu jammy-security/restricted Translation-en [1,211 kB]
    ubuntu-jammy: Get:14 http://us.archive.ubuntu.com/ubuntu jammy-updates/universe Translation-en [323 kB]
    ubuntu-jammy: Get:15 http://us.archive.ubuntu.com/ubuntu jammy-updates/multiverse amd64 Packages [76.8 kB]
    ubuntu-jammy: Get:16 http://us.archive.ubuntu.com/ubuntu jammy-updates/multiverse Translation-en [15.9 kB]
    ubuntu-jammy: Get:17 http://us.archive.ubuntu.com/ubuntu jammy-backports/main amd64 Packages [70.2 kB]
    ubuntu-jammy: Get:18 http://us.archive.ubuntu.com/ubuntu jammy-backports/main Translation-en [11.4 kB]
    ubuntu-jammy: Get:19 http://us.archive.ubuntu.com/ubuntu jammy-backports/universe amd64 Packages [30.8 kB]
    ubuntu-jammy: Get:20 http://us.archive.ubuntu.com/ubuntu jammy-backports/universe Translation-en [16.9 kB]
    ubuntu-jammy: Get:21 http://security.ubuntu.com/ubuntu jammy-security/universe amd64 Packages [1,048 kB]
    ubuntu-jammy: Get:22 http://security.ubuntu.com/ubuntu jammy-security/universe Translation-en [235 kB]
    ubuntu-jammy: Get:23 http://security.ubuntu.com/ubuntu jammy-security/multiverse amd64 Packages [69.4 kB]
    ubuntu-jammy: Get:24 http://security.ubuntu.com/ubuntu jammy-security/multiverse Translation-en [12.9 kB]
    ubuntu-jammy: Fetched 27.3 MB in 7s (3,732 kB/s)
    ubuntu-jammy: Reading package lists...
    ubuntu-jammy: Reading package lists...
    ubuntu-jammy: Building dependency tree...
    ubuntu-jammy: Reading state information...
    ubuntu-jammy: The following additional packages will be installed:
    ubuntu-jammy:   apache2-bin apache2-data apache2-utils libapr1 libaprutil1
    ubuntu-jammy:   libaprutil1-dbd-sqlite3 libaprutil1-ldap liblua5.3-0 mailcap mime-support
    ubuntu-jammy:   ssl-cert
    ubuntu-jammy: Suggested packages:
    ubuntu-jammy:   apache2-doc apache2-suexec-pristine | apache2-suexec-custom www-browser
    ubuntu-jammy: The following NEW packages will be installed:
    ubuntu-jammy:   apache2 apache2-bin apache2-data apache2-utils libapr1 libaprutil1
    ubuntu-jammy:   libaprutil1-dbd-sqlite3 libaprutil1-ldap liblua5.3-0 mailcap mime-support
    ubuntu-jammy:   ssl-cert
    ubuntu-jammy: 0 upgraded, 12 newly installed, 0 to remove and 179 not upgraded.
    ubuntu-jammy: Need to get 2,122 kB of archives.
    ubuntu-jammy: After this operation, 8,450 kB of additional disk space will be used.
    ubuntu-jammy: Get:1 http://us.archive.ubuntu.com/ubuntu jammy-updates/main amd64 libapr1 amd64 1.7.0-8ubuntu0.22.04.2 [108 kB]
    ubuntu-jammy: Get:2 http://us.archive.ubuntu.com/ubuntu jammy-updates/main amd64 libaprutil1 amd64 1.6.1-5ubuntu4.22.04.3 [93.4 kB]
    ubuntu-jammy: Get:3 http://us.archive.ubuntu.com/ubuntu jammy-updates/main amd64 libaprutil1-dbd-sqlite3 amd64 1.6.1-5ubuntu4.22.04.3 [11.4 kB]
    ubuntu-jammy: Get:4 http://us.archive.ubuntu.com/ubuntu jammy-updates/main amd64 libaprutil1-ldap amd64 1.6.1-5ubuntu4.22.04.3 [9,164 B]
    ubuntu-jammy: Get:5 http://us.archive.ubuntu.com/ubuntu jammy/main amd64 liblua5.3-0 amd64 5.3.6-1build1 [140 kB]
    ubuntu-jammy: Get:6 http://us.archive.ubuntu.com/ubuntu jammy-updates/main amd64 apache2-bin amd64 2.4.52-1ubuntu4.23 [1,362 kB]
    ubuntu-jammy: Get:7 http://us.archive.ubuntu.com/ubuntu jammy-updates/main amd64 apache2-data all 2.4.52-1ubuntu4.23 [165 kB]
    ubuntu-jammy: Get:8 http://us.archive.ubuntu.com/ubuntu jammy-updates/main amd64 apache2-utils amd64 2.4.52-1ubuntu4.23 [90.1 kB]
    ubuntu-jammy: Get:9 http://us.archive.ubuntu.com/ubuntu jammy-updates/main amd64 mailcap all 3.70+nmu1ubuntu1.22.04.1 [23.9 kB]
    ubuntu-jammy: Get:10 http://us.archive.ubuntu.com/ubuntu jammy/main amd64 mime-support all 3.66 [3,696 B]
    ubuntu-jammy: Get:11 http://us.archive.ubuntu.com/ubuntu jammy-updates/main amd64 apache2 amd64 2.4.52-1ubuntu4.23 [97.9 kB]
    ubuntu-jammy: Get:12 http://us.archive.ubuntu.com/ubuntu jammy/main amd64 ssl-cert all 1.1.2 [17.4 kB]
    ubuntu-jammy: dpkg-preconfigure: unable to re-open stdin: No such file or directory
    ubuntu-jammy: Fetched 2,122 kB in 2s (1,044 kB/s)
    ubuntu-jammy: Selecting previously unselected package libapr1:amd64.
(Reading database ... 45823 files and directories currently installed.)
    ubuntu-jammy: Preparing to unpack .../00-libapr1_1.7.0-8ubuntu0.22.04.2_amd64.deb ...
    ubuntu-jammy: Unpacking libapr1:amd64 (1.7.0-8ubuntu0.22.04.2) ...
    ubuntu-jammy: Selecting previously unselected package libaprutil1:amd64.
    ubuntu-jammy: Preparing to unpack .../01-libaprutil1_1.6.1-5ubuntu4.22.04.3_amd64.deb ...
    ubuntu-jammy: Unpacking libaprutil1:amd64 (1.6.1-5ubuntu4.22.04.3) ...
    ubuntu-jammy: Selecting previously unselected package libaprutil1-dbd-sqlite3:amd64.
    ubuntu-jammy: Preparing to unpack .../02-libaprutil1-dbd-sqlite3_1.6.1-5ubuntu4.22.04.3_amd64.deb ...
    ubuntu-jammy: Unpacking libaprutil1-dbd-sqlite3:amd64 (1.6.1-5ubuntu4.22.04.3) ...
    ubuntu-jammy: Selecting previously unselected package libaprutil1-ldap:amd64.
    ubuntu-jammy: Preparing to unpack .../03-libaprutil1-ldap_1.6.1-5ubuntu4.22.04.3_amd64.deb ...
    ubuntu-jammy: Unpacking libaprutil1-ldap:amd64 (1.6.1-5ubuntu4.22.04.3) ...
    ubuntu-jammy: Selecting previously unselected package liblua5.3-0:amd64.
    ubuntu-jammy: Preparing to unpack .../04-liblua5.3-0_5.3.6-1build1_amd64.deb ...
    ubuntu-jammy: Unpacking liblua5.3-0:amd64 (5.3.6-1build1) ...
    ubuntu-jammy: Selecting previously unselected package apache2-bin.
    ubuntu-jammy: Preparing to unpack .../05-apache2-bin_2.4.52-1ubuntu4.23_amd64.deb ...
    ubuntu-jammy: Unpacking apache2-bin (2.4.52-1ubuntu4.23) ...
    ubuntu-jammy: Selecting previously unselected package apache2-data.
    ubuntu-jammy: Preparing to unpack .../06-apache2-data_2.4.52-1ubuntu4.23_all.deb ...
    ubuntu-jammy: Unpacking apache2-data (2.4.52-1ubuntu4.23) ...
    ubuntu-jammy: Selecting previously unselected package apache2-utils.
    ubuntu-jammy: Preparing to unpack .../07-apache2-utils_2.4.52-1ubuntu4.23_amd64.deb ...
    ubuntu-jammy: Unpacking apache2-utils (2.4.52-1ubuntu4.23) ...
    ubuntu-jammy: Selecting previously unselected package mailcap.
    ubuntu-jammy: Preparing to unpack .../08-mailcap_3.70+nmu1ubuntu1.22.04.1_all.deb ...
    ubuntu-jammy: Unpacking mailcap (3.70+nmu1ubuntu1.22.04.1) ...
    ubuntu-jammy: Selecting previously unselected package mime-support.
    ubuntu-jammy: Preparing to unpack .../09-mime-support_3.66_all.deb ...
    ubuntu-jammy: Unpacking mime-support (3.66) ...
    ubuntu-jammy: Selecting previously unselected package apache2.
    ubuntu-jammy: Preparing to unpack .../10-apache2_2.4.52-1ubuntu4.23_amd64.deb ...
    ubuntu-jammy: Unpacking apache2 (2.4.52-1ubuntu4.23) ...
    ubuntu-jammy: Selecting previously unselected package ssl-cert.
    ubuntu-jammy: Preparing to unpack .../11-ssl-cert_1.1.2_all.deb ...
    ubuntu-jammy: Unpacking ssl-cert (1.1.2) ...
    ubuntu-jammy: Setting up libapr1:amd64 (1.7.0-8ubuntu0.22.04.2) ...
    ubuntu-jammy: Setting up ssl-cert (1.1.2) ...
    ubuntu-jammy: Setting up liblua5.3-0:amd64 (5.3.6-1build1) ...
    ubuntu-jammy: Setting up apache2-data (2.4.52-1ubuntu4.23) ...
    ubuntu-jammy: Setting up mailcap (3.70+nmu1ubuntu1.22.04.1) ...
    ubuntu-jammy: Setting up libaprutil1:amd64 (1.6.1-5ubuntu4.22.04.3) ...
    ubuntu-jammy: Setting up mime-support (3.66) ...
    ubuntu-jammy: Setting up libaprutil1-ldap:amd64 (1.6.1-5ubuntu4.22.04.3) ...
    ubuntu-jammy: Setting up libaprutil1-dbd-sqlite3:amd64 (1.6.1-5ubuntu4.22.04.3) ...
    ubuntu-jammy: Setting up apache2-utils (2.4.52-1ubuntu4.23) ...
    ubuntu-jammy: Setting up apache2-bin (2.4.52-1ubuntu4.23) ...
    ubuntu-jammy: Setting up apache2 (2.4.52-1ubuntu4.23) ...
    ubuntu-jammy: Enabling module mpm_event.
    ubuntu-jammy: Enabling module authz_core.
    ubuntu-jammy: Enabling module authz_host.
    ubuntu-jammy: Enabling module authn_core.
    ubuntu-jammy: Enabling module auth_basic.
    ubuntu-jammy: Enabling module access_compat.
    ubuntu-jammy: Enabling module authn_file.
    ubuntu-jammy: Enabling module authz_user.
    ubuntu-jammy: Enabling module alias.
    ubuntu-jammy: Enabling module dir.
    ubuntu-jammy: Enabling module autoindex.
    ubuntu-jammy: Enabling module env.
    ubuntu-jammy: Enabling module mime.
    ubuntu-jammy: Enabling module negotiation.
    ubuntu-jammy: Enabling module setenvif.
    ubuntu-jammy: Enabling module filter.
    ubuntu-jammy: Enabling module deflate.
    ubuntu-jammy: Enabling module status.
    ubuntu-jammy: Enabling module reqtimeout.
    ubuntu-jammy: Enabling conf charset.
    ubuntu-jammy: Enabling conf localized-error-pages.
    ubuntu-jammy: Enabling conf other-vhosts-access-log.
    ubuntu-jammy: Enabling conf security.
    ubuntu-jammy: Enabling conf serve-cgi-bin.
    ubuntu-jammy: Enabling site 000-default.
    ubuntu-jammy: Created symlink /etc/systemd/system/multi-user.target.wants/apache2.service → /lib/systemd/system/apache2.service.
    ubuntu-jammy: Created symlink /etc/systemd/system/multi-user.target.wants/apache-htcacheclean.service → /lib/systemd/system/apache-htcacheclean.service.
    ubuntu-jammy: Processing triggers for ufw (0.36.1-4ubuntu0.1) ...
    ubuntu-jammy: Processing triggers for man-db (2.10.2-1) ...
    ubuntu-jammy: Processing triggers for libc-bin (2.35-0ubuntu3.11) ...
    ubuntu-jammy: 
    ubuntu-jammy: Running kernel seems to be up-to-date.
    ubuntu-jammy: 
    ubuntu-jammy: No services need to be restarted.
    ubuntu-jammy: 
    ubuntu-jammy: No containers need to be restarted.
    ubuntu-jammy: 
    ubuntu-jammy: No user sessions are running outdated binaries.
    ubuntu-jammy: 
    ubuntu-jammy: No VM guests are running outdated hypervisor (qemu) binaries on this host.
    ubuntu-jammy: Site 000-default disabled.
    ubuntu-jammy: To activate the new configuration, you need to run:
    ubuntu-jammy:   systemctl reload apache2
    ubuntu-jammy: <VirtualHost *:80>
    ubuntu-jammy:           DocumentRoot /vagrant
    ubuntu-jammy:           <Directory /vagrant>
    ubuntu-jammy:               Options Indexes FollowSymLinks
    ubuntu-jammy:               AllowOverride All
    ubuntu-jammy:               Require all granted
    ubuntu-jammy:           </Directory>
    ubuntu-jammy:       </VirtualHost>
    ubuntu-jammy: Enabling site vagrant.
    ubuntu-jammy: To activate the new configuration, you need to run:
    ubuntu-jammy:   systemctl reload apache2
    ubuntu-jammy: Enabling module rewrite.
    ubuntu-jammy: To activate the new configuration, you need to run:
    ubuntu-jammy:   systemctl restart apache2
[admin_insta11@mv334 vagrant-provisioning-net-disks]$
```

Подключаемся к созданной ВМ, проверяем, что созданные диски видны и примонтированы, пробуем записать на них
файлы:

```
[admin_insta11@mv334 vagrant-provisioning-net-disks]$vagrant ssh
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-160-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

 System information as of Tue Sep 15 03:12:04 AM UTC 2026

  System load:           0.69
  Usage of /:            16.0% of 30.34GB
  Memory usage:          13%
  Swap usage:            0%
  Processes:             178
  Users logged in:       0
  IPv4 address for eth0: 10.0.2.15
  IPv6 address for eth0: fd17:625c:f037:2:a00:27ff:fe16:ddef


This system is built by the Bento project by Chef Software
More information can be found at https://github.com/chef/bento

Use of this system is acceptance of the OS vendor EULA and License Agreements.
vagrant@vagrant:~$ 
vagrant@vagrant:~$ df -h
Filesystem                         Size  Used Avail Use% Mounted on
tmpfs                              197M  1.1M  196M   1% /run
/dev/mapper/ubuntu--vg-ubuntu--lv   31G  4.9G   24G  17% /
tmpfs                              982M     0  982M   0% /dev/shm
tmpfs                              5.0M     0  5.0M   0% /run/lock
/dev/sda2                          2.0G  131M  1.7G   8% /boot
vagrant                            156G   73G   83G  47% /vagrant
/dev/sdb1                          988M   24K  921M   1% /mnt/disk1
/dev/sdc1                          988M   24K  921M   1% /mnt/disk2
tmpfs                              197M  8.0K  197M   1% /run/user/1000
vagrant@vagrant:~$ 
vagrant@vagrant:~$ cat /etc/fstab
# /etc/fstab: static file system information.
#
# Use 'blkid' to print the universally unique identifier for a
# device; this may be used with UUID= as a more robust way to name devices
# that works even if disks are added and removed. See fstab(5).
#
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
# / was on /dev/ubuntu-vg/ubuntu-lv during curtin installation
/dev/disk/by-id/dm-uuid-LVM-hdIJZMcW0IiMN1hQHlkwKD0xgeiosdmVgJCojKJgdu3kkOKNQrAupoLdBCNFiEq3 / ext4 defaults 0 1
# /boot was on /dev/sda2 during curtin installation
/dev/disk/by-uuid/178463a5-df75-4611-b948-da0107e9a453 /boot ext4 defaults 0 1
/swap.img	none	swap	sw	0	0
#VAGRANT-BEGIN
# The contents below are automatically generated by Vagrant. Do not modify.
vagrant /vagrant vboxsf uid=1000,gid=1000,_netdev 0 0
#VAGRANT-END
UUID=04642414-fdd4-4b23-adc4-043c97c984c2  /mnt/disk1  ext4  defaults,noatime,nodiratime  0  2
UUID=8ac5aa8d-6c28-470f-b6d3-b8c56fb6bbf3  /mnt/disk2  ext4  defaults,noatime,nodiratime  0  2
vagrant@vagrant:~$ 
vagrant@vagrant:~$ lsblk -f
NAME                      FSTYPE      FSVER    LABEL UUID                                   FSAVAIL FSUSE% MOUNTPOINTS
loop0                     squashfs    4.0                                                         0   100% /snap/snapd/21759
loop1                     squashfs    4.0                                                         0   100% /snap/core20/2318
loop2                     squashfs    4.0                                                         0   100% /snap/lxd/29351
sda                                                                                                        
├─sda1                                                                                                     
├─sda2                    ext4        1.0            178463a5-df75-4611-b948-da0107e9a453      1.7G     7% /boot
└─sda3                    LVM2_member LVM2 001       KoqZIv-vJYX-UvDz-fqWI-m0Yh-3WFS-NVAXYa                
  └─ubuntu--vg-ubuntu--lv ext4        1.0            40082512-a418-449c-8972-691f1ae551cb     23.9G    16% /
sdb                                                                                                        
└─sdb1                    ext4        1.0            04642414-fdd4-4b23-adc4-043c97c984c2    920.3M     0% /mnt/disk1
sdc                                                                                                        
└─sdc1                    ext4        1.0            8ac5aa8d-6c28-470f-b6d3-b8c56fb6bbf3    920.3M     0% /mnt/disk2
vagrant@vagrant:~$ 
vagrant@vagrant:~$ 
vagrant@vagrant:~$ cat > /mnt/disk1/test1.txt
This is a test file on disk #1
vagrant@vagrant:~$ 
vagrant@vagrant:~$ cat > /mnt/disk2/test2.txt
This is a test file on disk #2
vagrant@vagrant:~$ 
vagrant@vagrant:~$ cat /mnt/disk1/test1.txt
This is a test file on disk #1
vagrant@vagrant:~$ cat /mnt/disk2/test2.txt
This is a test file on disk #2
vagrant@vagrant:~$ 
vagrant@vagrant:~$ 
vagrant@vagrant:~$ exit
logout
[admin_insta11@mv334 vagrant-provisioning-net-disks]$
```

Также работает проброс порта и синхронизация с внешней директорией, на хосте открывается страница сконфигурированного в ВМ WEB-сервера:

<img width="1073" height="1047" alt="изображение" src="https://github.com/user-attachments/assets/f20eb3ad-19b2-4842-92fc-de81c62dd676" />

При изменении  на хосте файла index.html в директории /home/admin_insta11/vagrant-provisioning-net-disks страница в WEB-броузере также меняется.

Для проверки перезагружаем ВМ, после перезагрузки диски по-прежнему примонтированы, записанные на них файлы сохранились:

```
[admin_insta11@mv334 vagrant-provisioning-net-disks]$ vagrant halt
==> ubuntu-jammy: Attempting graceful shutdown of VM...
[admin_insta11@mv334 vagrant-provisioning-net-disks]$ 
[admin_insta11@mv334 vagrant-provisioning-net-disks]$ 
[admin_insta11@mv334 vagrant-provisioning-net-disks]$ vagrant up
Bringing machine 'ubuntu-jammy' up with 'virtualbox' provider...
==> ubuntu-jammy: Clearing any previously set forwarded ports...
==> ubuntu-jammy: Clearing any previously set network interfaces...
==> ubuntu-jammy: Preparing network interfaces based on configuration...
    ubuntu-jammy: Adapter 1: nat
    ubuntu-jammy: Adapter 2: intnet
==> ubuntu-jammy: Forwarding ports...
    ubuntu-jammy: 80 (guest) => 8080 (host) (adapter 1)
    ubuntu-jammy: 22 (guest) => 2222 (host) (adapter 1)
==> ubuntu-jammy: Configuring storage mediums...
==> ubuntu-jammy: Running 'pre-boot' VM customizations...
==> ubuntu-jammy: Booting VM...
==> ubuntu-jammy: Waiting for machine to boot. This may take a few minutes...
    ubuntu-jammy: SSH address: 127.0.0.1:2222
    ubuntu-jammy: SSH username: vagrant
    ubuntu-jammy: SSH auth method: private key
    ubuntu-jammy: Warning: Connection reset. Retrying...
    ubuntu-jammy: Warning: Remote connection disconnect. Retrying...
    ubuntu-jammy: Warning: Connection reset. Retrying...
==> ubuntu-jammy: Machine booted and ready!
==> ubuntu-jammy: Checking for guest additions in VM...
    ubuntu-jammy: The guest additions on this VM do not match the installed version of
    ubuntu-jammy: VirtualBox! In most cases this is fine, but in rare cases it can
    ubuntu-jammy: prevent things such as shared folders from working properly. If you see
    ubuntu-jammy: shared folder errors, please make sure the guest additions within the
    ubuntu-jammy: virtual machine match the version of VirtualBox you have installed on
    ubuntu-jammy: your host and reload your VM.
    ubuntu-jammy: 
    ubuntu-jammy: Guest Additions Version: 7.2.4
    ubuntu-jammy: VirtualBox Version: 7.1
==> ubuntu-jammy: Configuring and enabling network interfaces...
==> ubuntu-jammy: Mounting shared folders...
    ubuntu-jammy: /home/admin_insta11/network-storage-provisioning => /vagrant
==> ubuntu-jammy: Machine already provisioned. Run `vagrant provision` or use the `--provision`
==> ubuntu-jammy: flag to force provisioning. Provisioners marked to run always will still run.
[admin_insta11@mv334 network-storage-provisioning]$ vagrant ssh
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-160-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

 System information as of Tue Sep 15 03:47:07 AM UTC 2026

  System load:           0.02
  Usage of /:            16.7% of 30.34GB
  Memory usage:          12%
  Swap usage:            0%
  Processes:             163
  Users logged in:       0
  IPv4 address for eth0: 10.0.2.15
  IPv6 address for eth0: fd17:625c:f037:2:a00:27ff:fe16:ddef


This system is built by the Bento project by Chef Software
More information can be found at https://github.com/chef/bento

Use of this system is acceptance of the OS vendor EULA and License Agreements.
Last login: Tue Sep 15 03:12:04 2026 from 10.0.2.2
vagrant@vagrant:~$ df -h
Filesystem                         Size  Used Avail Use% Mounted on
tmpfs                              197M  1.1M  196M   1% /run
/dev/mapper/ubuntu--vg-ubuntu--lv   31G  5.1G   24G  18% /
tmpfs                              982M     0  982M   0% /dev/shm
tmpfs                              5.0M     0  5.0M   0% /run/lock
/dev/sda2                          2.0G  131M  1.7G   8% /boot
/dev/sdc1                          988M   28K  921M   1% /mnt/disk2
/dev/sdb1                          988M   28K  921M   1% /mnt/disk1
vagrant                            156G   74G   83G  47% /vagrant
tmpfs                              197M  8.0K  197M   1% /run/user/1000
vagrant@vagrant:~$ 
vagrant@vagrant:~$ cat /mnt/disk1/test1.txt
This is a test file on disk #1
vagrant@vagrant:~$ cat /mnt/disk2/test2.txt
This is a test file on disk #2
vagrant@vagrant:~$ 
vagrant@vagrant:~$ 
vagrant@vagrant:~$ 
vagrant@vagrant:~$ exit
logout
[admin_insta11@mv334 vagrant-provisioning-net-disks]$ vagrant halt
==> ubuntu-jammy: Attempting graceful shutdown of VM...
[admin_insta11@mv334 vagrant-provisioning-net-disks]$
```


# КОНЕЦ

### Далее приведены общие подходы и полученные результаты по работе с гипервизорами libvirt/kvm и virtualbox , в том числе при совместной работе с vagrant. Приведённый ниже материал не относится непосредственно к данной лабораторной работе, хотя все результаты были получены в процессе выполнения данной лабораторной работы. Изучено различие построения сетей гипервизоров libvirt/kvm и virtualbox.

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
трафиком стандартным системным утилитам Linux хоста (вроде iptables или nftables).

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
то имя её в команде 'vagrant ssh' можно не указывать.


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

## 3. Организация сети и сетевой связности для при использовании libvirt/kvm и virtuallbox

Понимание организации сети и сетевой связности между виртуальными машинами, хостовой машиной и внешним интернетом важно для дальнейшего обучения - пришлось разобраться с использованием интернета и ИИ.

Главное отличие, которое нужно запомнить: 

- KVM/libvirt строит сеть из стандартных компонентов Linux, использует стандартный сетевой стек (мосты, TAP-интерфейсы, dnsmasq) — всё видновсё можно настроить и автоматизировать через ip, bridge, iptables, Ansible.

- VirtualBox прячет всё внутрь своих модулей ядра (свои модули, свои адреса 10.0.2.x внутри сети виртуальных машин) — снаружи видно только проброшенные порты и (иногда) интерфейс vboxnet0.

Различия в построении сетей libvirt/kvm и virtualbox:

| Параметр	| libvirt (private_network) | VirtualBox (Port Forwarding) |
|:---------------------|:---------------------------|:-------------------------------------|
| Доступ к nginx в ВМ	| http://192.168.56.10:4881 (фиксированный IP VM) | http://localhost:4881 |
| Кто держит порт	| Nginx внутри VM | Процесс VirtualBox на хосте |
| Видимость для других ПК | Да (если сеть хоста разрешает, сделаны настройки в firewall/iptables/nftables хоста) | Нет (только localhost) |
| Тип сети	| Изолированная сеть с фиксированным IP | NAT + проброс портов |

| Команда на хосте	| KVM/libvirt	| VirtualBox |
|:---------------------|:---------------------------|:-------------------------------------|
| bridge link show	   | виден vnet0 на virbr0 |	пусто |
| ip -br addr	       | виден virbr0, vnet0	| только vboxnet0 (в режиме host-only) |
| ss -tlpn  grep 4881  | пусто (nginx внутри ВМ)	| процесс VirtualBox на 127.0.0.1:4881 |
| ps aux  grep dnsmasq |	виден dnsmasq от libvirt	| пусто (DHCP внутри VB) |

В libvirt хост ходит по IP на ВМ — потому что там обычный Linux‑мост (virbr0) и TAP‑интерфейсы, всё прозрачно видно через ip addr и bridge link. Используются интерфейсы: virbr0 на хосте, vnet0 (или vnet1) как порт этого моста, и в ВМ — интерфейс с IP из той же подсети. Это и есть «физическая» связь в KVM: TAP‑устройство в ядре + мост.

В VirtualBox хост не видит IP гостевой машины и приходится делать проброс портов — потому что там сеть «спрятана» внутри движка virtualbox.

Более подробно ниже.

### 3.1 Организация сети и сетевой связности для при использовании libvirt/kvm


Сетевая связность между ВМ на основе libvirt и хостом осуществляется по двум созданным сетевым мостам:

eth0 (порт в ВМ) ↔ vnet1 (TAP интерфейс на хосте) ↔ virbr1 (мост на хосте)
eth1 (порт в ВМ) ↔ vnet2 (TAP интерфейс на хосте) ↔ virbr2 (мост на хосте)

В ВМ это выглядит как две сетевые карты, на хосте - как два моста virbr1 и virbr2 и два TAP интерфейса vnet1 и vnet2:

| Инт в ВМ | IP	в ВМ  | Инт на хосте  |	IP	на хосте | Откуда конфигурация | Назначение |
|:----------|:-----------------------|:--------------|:------------------------|:--------------------|:--------------------|
| eth0 | 192.168.121.226 (DHCP)	| virbr1, vnet1 | 192.168.121.1/24 (virbr1) | vagrant-libvirt | SSH, управление vagrant |
| eth1 | 192.168.56.10 (статика) | virbr2, vnet2 | 192.168.56.1/24 (virbr2) | Vagrantfile private_network | Лаба, сервисы |


<ins>**Мост 1:**</ins> virbr1 (192.168.121.0/24) — сеть управления Vagrant

Её создал плагин vagrant-libvirt автоматически, без специальной конфигурации. Она нужна для:

- SSH-доступа: vagrant ssh подключается именно по этому IP (192.168.121.226).

- Провижининга: когда Vagrant загружает box и запускает shell-скрипты из Vagrantfile, он ходит через эту сеть.

- Проверки готовности: Vagrant ждёт, пока ВМ получит IP от DHCP на этом мосту, и только потом считает её «booted and ready».

В virsh net-list --all она называется vagrant-libvirt. Это служебная сеть — она существует, пока работает плагин vagrant-libvirt.


<ins>**Мост 2:**</ins> virbr2 (192.168.56.0/24) — сеть private_network

Эту сеть создал Vagrant из строки конфигурации в Vagrantfile:

box.vm.network "private_network", ip: "192.168.56.10"

Это целевая сеть для внешней связи ВМ с хостом. Хост может ходить в nginx на ВМ напрямую командой: 

curl http://192.168.56.10:4881.

В virsh net-list --all она называется lab-almalinux90.


Сети видны в конфигурации kvm:

```
[admin_insta11@mv334 lab-almalinux9-kvm]$ sudo virsh net-list --all
 Имя                   Состояние   Автозапуск   Постоянный
------------------------------------------------------------
 default               активен     yes          yes
 lab-almalinux9-kvm0   активен     no           yes
 vagrant-libvirt       активен     no           yes
```


| Компонент	| Где живёт	| Кто видит |
|:----------------------|:----------------------------------|:-------------|
| virtio-net (eth0, eth1) | Внутри ВМ (PCI-устройство) | Гостевое ядро |
| TAP (vnet1, vnet2)	| На хосте (интерфейс ядра Linux)	| Хост, QEMU |
| Мост (virbr1, virbr2)	| На хосте (интерфейс ядра Linux)	| Хост       |
| «Кабель» между ними	| Внутри процесса QEMU (память)	| Реализация внутри QEMU (см. ниже) |


Настройки QEMU в командной строке запуска:

```
[admin_insta11@mv334 lab-almalinux9-kvm]$ cat /proc/$(pgrep -f qemu-system | head -1)/cmdline | tr '\0' '\n' | grep -A1 'netdev'
-netdev
{"type":"tap","fd":"41","vhost":true,"vhostfd":"43","id":"hostua-net-0"}
--
{"driver":"virtio-net-pci","iommu_platform":false,"netdev":"hostua-net-0","id":"ua-net-0","mac":"52:54:00:59:2e:0c","bus":"pci.0","addr":"0x5"}
-netdev
{"type":"tap","fd":"44","vhost":true,"vhostfd":"45","id":"hostua-net-1"}
--
{"driver":"virtio-net-pci","iommu_platform":false,"netdev":"hostua-net-1","id":"ua-net-1","mac":"52:54:00:92:11:47","bus":"pci.0","addr":"0x6"}
-chardev
[admin_insta11@mv334 lab-almalinux9-kvm]$
```

Сетевая карта eth0 в ВМ (управление, SSH)

```
QEMU: -netdev {"type":"tap","fd":"41","id":"hostua-net-0"}
      ↓
      fd 41 → /dev/net/tun → vnet1 (TAP, MAC: fe:54:00:59:2e:0c)
      ↓
      мост virbr1 (192.168.121.1)

QEMU: -device virtio-net-pci, mac="52:54:00:59:2e:0c", addr="0x5"
      ↓
      В ВМ: eth0, PCI 00:05.0, IP 192.168.121.226 (DHCP)
```
	  
Сетевая карта eth1 в ВМ  (лаба, private_network)

```
QEMU: -netdev {"type":"tap","fd":"44","id":"hostua-net-1"}
      ↓
      fd 44 → /dev/net/tun → vnet2 (TAP, MAC: fe:54:00:92:11:47)
      ↓
      мост virbr2 (192.168.56.1)

QEMU: -device virtio-net-pci, mac="52:54:00:92:11:47", addr="0x6"
      ↓
      В ВМ: eth1, PCI 00:06.0, IP 192.168.56.10 (статика из Vagrantfile)
```  
	  
Здесь видно, что:

- fd:"41" и fd:"44" — это те самые файловые дескрипторы интерфейсов TAP, которые видны через ls -la /proc/.../fd/ | grep tun.

- "vhost":true и vhostfd — это отдельная оптимизация: помимо TAP, QEMU открывает vhost-дескриптор (43 и 45), который позволяет ядру напрямую пересылать пакеты в virtio-net ВМ, минуя пользовательский процесс QEMU. Это даёт высокую пропускную способность — почти как нативная сетевая карта.

- MAC-адреса 52:54:00:59:2e:0c и 52:54:00:92:11:47 — те, которые видны внутри ВМ через ip link.

- addr":"0x5" и addr":"0x6" — это PCI-слоты. В ВМ они видны как 00:05.0 и 00:06.0 через lspci.


Из Host-машины доступ к nginx по порту 4881 осуществляется по IP-адресу ВМ в private_network:

curl http://192.168.56.10:4881

При запущенной Vagrant сконфигурированной ВМ с использованием  libvirt/kvm видны следующие сетевые интерфейсы и конфигурации:

- в гостевой ВМ интерфейсы и конфигурации видны следующие:

```
[admin_insta11@mv334 lab-almalinux9-kvm]$ vagrant ssh
Last login: Sat Sep  5 17:04:16 2026 from 192.168.121.1
[vagrant@selinux ~]$ ip -br addr show
lo               UNKNOWN        127.0.0.1/8 ::1/128 
eth0             UP             192.168.121.226/24 fe80::d4b4:6edc:311:9c69/64 
eth1             UP             192.168.56.10/24 fe80::5054:ff:fe92:1147/64 
[vagrant@selinux ~]$ ip -br link show
lo               UNKNOWN        00:00:00:00:00:00 <LOOPBACK,UP,LOWER_UP> 
eth0             UP             52:54:00:59:2e:0c <BROADCAST,MULTICAST,UP,LOWER_UP> 
eth1             UP             52:54:00:92:11:47 <BROADCAST,MULTICAST,UP,LOWER_UP> 
[vagrant@selinux ~]$
[vagrant@selinux ~]$ ip link
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP mode DEFAULT group default qlen 1000
    link/ether 52:54:00:59:2e:0c brd ff:ff:ff:ff:ff:ff
    altname enp0s5
    altname ens5
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP mode DEFAULT group default qlen 1000
    link/ether 52:54:00:92:11:47 brd ff:ff:ff:ff:ff:ff
    altname enp0s6
    altname ens6
[vagrant@selinux ~]$ ip addr
<...>
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 52:54:00:59:2e:0c brd ff:ff:ff:ff:ff:ff
    altname enp0s5
    altname ens5
    inet 192.168.121.226/24 brd 192.168.121.255 scope global dynamic noprefixroute eth0
       valid_lft 3091sec preferred_lft 3091sec
    inet6 fe80::d4b4:6edc:311:9c69/64 scope link noprefixroute 
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 52:54:00:92:11:47 brd ff:ff:ff:ff:ff:ff
    altname enp0s6
    altname ens6
    inet 192.168.56.10/24 brd 192.168.56.255 scope global noprefixroute eth1
       valid_lft forever preferred_lft forever
    inet6 fe80::5054:ff:fe92:1147/64 scope link 
       valid_lft forever preferred_lft forever
[vagrant@selinux ~]$ 
[vagrant@selinux ~]$ bridge link show
[vagrant@selinux ~]$
[vagrant@selinux ~]$ lspci | grep -i net
00:05.0 Ethernet controller: Red Hat, Inc. Virtio network device
00:06.0 Ethernet controller: Red Hat, Inc. Virtio network device
[vagrant@selinux ~]$ 
```

На хост-машине интерфейсы и конфигурации видны следующие:

```
[admin_insta11@mv334 lab-almalinux9-kvm]$ ifconfig
<...>
virbr1: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 192.168.121.1  netmask 255.255.255.0  broadcast 192.168.121.255
        ether 52:54:00:e1:a4:a4  txqueuelen 1000  (Ethernet)
        RX packets 36141  bytes 1754125 (1.6 MiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 62663  bytes 88736163 (84.6 MiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

virbr2: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 192.168.56.1  netmask 255.255.255.0  broadcast 192.168.56.255
        ether 52:54:00:d6:81:ea  txqueuelen 1000  (Ethernet)
        RX packets 35  bytes 3248 (3.1 KiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 20  bytes 2317 (2.2 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

vnet1: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet6 fe80::fc54:ff:fe59:2e0c  prefixlen 64  scopeid 0x20<link>
        ether fe:54:00:59:2e:0c  txqueuelen 1000  (Ethernet)
        RX packets 36141  bytes 2260099 (2.1 MiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 62780  bytes 88743555 (84.6 MiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

vnet2: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet6 fe80::fc54:ff:fe92:1147  prefixlen 64  scopeid 0x20<link>
        ether fe:54:00:92:11:47  txqueuelen 1000  (Ethernet)
        RX packets 35  bytes 3738 (3.6 KiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 137  bytes 9709 (9.4 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

[admin_insta11@mv334 lab-almalinux9-kvm]$
[admin_insta11@mv334 lab-almalinux9-kvm]$ ip link
<...>
8: virbr1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP mode DEFAULT group default qlen 1000
    link/ether 52:54:00:e1:a4:a4 brd ff:ff:ff:ff:ff:ff
9: virbr2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP mode DEFAULT group default qlen 1000
    link/ether 52:54:00:d6:81:ea brd ff:ff:ff:ff:ff:ff
10: vnet1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master virbr1 state UNKNOWN mode DEFAULT group default qlen 1000
    link/ether fe:54:00:59:2e:0c brd ff:ff:ff:ff:ff:ff
11: vnet2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master virbr2 state UNKNOWN mode DEFAULT group default qlen 1000
    link/ether fe:54:00:92:11:47 brd ff:ff:ff:ff:ff:ff
[admin_insta11@mv334 lab-almalinux9-kvm]$
[admin_insta11@mv334 lab-almalinux9-kvm]$ ip addr
<...>
8: virbr1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether 52:54:00:e1:a4:a4 brd ff:ff:ff:ff:ff:ff
    inet 192.168.121.1/24 brd 192.168.121.255 scope global virbr1
       valid_lft forever preferred_lft forever
9: virbr2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether 52:54:00:d6:81:ea brd ff:ff:ff:ff:ff:ff
    inet 192.168.56.1/24 brd 192.168.56.255 scope global virbr2
       valid_lft forever preferred_lft forever
10: vnet1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master virbr1 state UNKNOWN group default qlen 1000
    link/ether fe:54:00:59:2e:0c brd ff:ff:ff:ff:ff:ff
    inet6 fe80::fc54:ff:fe59:2e0c/64 scope link 
       valid_lft forever preferred_lft forever
11: vnet2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master virbr2 state UNKNOWN group default qlen 1000
    link/ether fe:54:00:92:11:47 brd ff:ff:ff:ff:ff:ff
    inet6 fe80::fc54:ff:fe92:1147/64 scope link 
       valid_lft forever preferred_lft forever
[admin_insta11@mv334 lab-almalinux9-kvm]$ 
[admin_insta11@mv334 lab-almalinux9-kvm]$ ip neigh show dev virbr1
192.168.121.226 lladdr 52:54:00:59:2e:0c REACHABLE 
[admin_insta11@mv334 lab-almalinux9-kvm]$ ip neigh show dev virbr2
192.168.56.10 lladdr 52:54:00:92:11:47 STALE 
[admin_insta11@mv334 lab-almalinux9-kvm]$ 
[admin_insta11@mv334 lab-almalinux9-kvm]$ brctl show
bridge name	bridge id		STP enabled	interfaces
virbr1		8000.525400e1a4a4	yes		vnet1
virbr2		8000.525400d681ea	yes		vnet2
[admin_insta11@mv334 lab-almalinux9-kvm]$
[admin_insta11@mv334 lab-almalinux9-kvm]$ for i in /sys/class/net/vnet*; do
  dev=$(basename "$i")
  echo -n "$dev -> "
  bridge link show dev "$dev" | awk '/master/ {for(j=1;j<=NF;j++) if($j=="master") print $(j+1)}'
done
vnet1 -> virbr1
vnet2 -> virbr2
[admin_insta11@mv334 lab-almalinux9-kvm]$
[admin_insta11@mv334 lab-almalinux9-kvm]$ sudo ls -la /proc/$(pgrep -f qemu-system | head -1)/fd/ 2>/dev/null | grep tun
[sudo] пароль для admin_insta11: 
lrwx------ 1 qemu qemu 64 сен  5 20:44 41 -> /dev/net/tun
lrwx------ 1 qemu qemu 64 сен  5 20:44 44 -> /dev/net/tun
[admin_insta11@mv334 lab-almalinux9-kvm]$
[admin_insta11@mv334 lab-almalinux9-kvm]$ cat /proc/$(pgrep -f qemu-system | head -1)/cmdline | tr '\0' '\n' | grep -A1 'netdev'
-netdev
{"type":"tap","fd":"41","vhost":true,"vhostfd":"43","id":"hostua-net-0"}
--
{"driver":"virtio-net-pci","iommu_platform":false,"netdev":"hostua-net-0","id":"ua-net-0","mac":"52:54:00:59:2e:0c","bus":"pci.0","addr":"0x5"}
-netdev
{"type":"tap","fd":"44","vhost":true,"vhostfd":"45","id":"hostua-net-1"}
--
{"driver":"virtio-net-pci","iommu_platform":false,"netdev":"hostua-net-1","id":"ua-net-1","mac":"52:54:00:92:11:47","bus":"pci.0","addr":"0x6"}
-chardev
[admin_insta11@mv334 lab-almalinux9-kvm]$ 
```

 **Примечание 1:**  TAP‑интерфейс — это виртуальный сетевой интерфейс в Linux, который выглядит для ядра как обычная сетевая карта, но на самом деле передаёт пакеты в пользовательское приложение (в случае KVM — в QEMU/libvirt) через файловый дескриптор. TAP — это интерфейс, у которого один конец в ядре Linux (виден как vnet1), а второй конец — в пользовательском процессе (QEMU). Не в другом интерфейсе, а в программе.

В команде 'ip addr show vnet0' и 'ip addr show vnet1' на хосте, у интерфейса TAP vnet0 и vnet1 не будет IP‑адреса. Это нормально: TAP в такой схеме — это «порт коммутатора», а IP есть у моста (virbr0), а не у порта.

QEMU — это пользовательский процесс на хосте. Он держит файловый дескриптор TAP-интерфейса vnet1 и одновременно эмулирует PCI-устройство virtio-net для ВМ. Когда ВМ «отправляет» кадр через eth0, QEMU перехватывает его (внутри себя) и пишет в TAP. Когда кадр приходит из TAP — QEMU «кладёт» его в виртуальную карту ВМ, и ядро ВМ видит его как входящий Ethernet-кадр.

Схема связности между гостевой ВМ и хостом получается следующая (на примере одного из мостов):

```
ВМ (AlmaLinux)                       Хост (RED OS)
─────────────                        ──────────────
                
 virtio-net (PCI-устройство)         Пользовательское пространство (хост)  Ядро Linux (хост)               Ядро Linux (хост)  
 ┌───────────────────────────┐       ┌─────────────────────────────┐       ┌───────────────────────┐       ┌───────────────────────┐               
 │ eth0                      │ ←───→ │ QEMU процесс                │ ←───→ │ vnet1                 │ ←───→ │ virbr1                │                
 │virtio-net (PCI-устройство)│       │ → эмулирует eth0 для ВМ     │       │(TAP-интерфейс)        │       │(мост)                 │                
 │ MAC 52:54:00:59:2e:0c     │ кадры │ → держит файловый дескриптор│ кадры │ MAC fe:54:00:59:2e:0c │ кадры │ MAC 52:54:00:e1:a4:a4 │                
 │ IP 192.168.121.226/24     │       │   порта TAP                 │       │ без IP                │       │ IP  192.168.121.1/24  │                  
 └───────────────────────────┘       │   (fd=open("/dev/net/tun")) │       └───────────────────────┘       └───────────────────────┘ 
                                     │ → передаёт кадры ←→         │       
                                     │   через память              │        
                                     └─────────────────────────────┘    
```

Для гостевой ОС это выглядит как реальная сетевая карта. Для хоста это обычный сетевой интерфейс, который можно увидеть через ip link.


Как создать TAP вручную (для понимания, Vagrant/libvirt делают это автоматически):

```
# Создать TAP-интерфейс tap0
sudo ip tuntap add dev tap0 mode tap

# Посмотреть его
ip -br link show tap0
# Обрати внимание: NO-CARRIER, UP, NO-IP

# Добавить в мост (если есть свой мост)
sudo ip link set tap0 master br0

# Удалить интерфейс
sudo ip link delete tap0
```

Полезные приёмы, для включения/отключения и прослушивания сетевого трафика ВМ на хосте:

```
# Команды на хосте

# «Послушать» кабель, покажет ровно тот трафик, который ходит между ВМ и мостом.
tcpdump -i vnet1

# Увидеть кабель, показывает, какой vnet* в какой virbr* воткнут.
bridge link show

# Выдернуть кабель программно, чтобы эмулировать сбои сети в тестах  (ВМ потеряет связь по eth0)
ip link set vnet1 down
# или удаление интерфейса vnet1 из моста

# Проверить: в bridge link show будет state disabled
bridge link show dev vnet1

# Вернуть обратно
sudo ip link set vnet1 up
# Мост сам подхватит порт, и ВМ снова получит сеть

# Изолировать кабель: можно создать свой мост и подключить туда vnet вручную
ip link add br-test type bridge
```


### 3.2 Организация сети и сетевой связности для при использовании virtualbox


Сетевая связность между ВМ на основе libvirt и хостом осуществляется


## 3.3 Различные режимы работы сети kvm/libvirt и virtualbox. Какие интерфейсы создаются в различных режимах работы сетей kvm/libvirt и virtualbox


## 3.3.1 KVM/libvirt: какие интерфейсы создаются

KVM использует стандартный Linux-сетевой стек: Linux-bridge + TAP-устройства. Всё прозрачно и видно через ip addr, brctl show, virsh.

### 3.3.1.1 Режим NAT (сеть default в libvirt)

```
┌──────────────────────────────────────────────────────────────┐
│ Хост (RED OS)                                                │
│                                                              │
│  enp3s0: 192.168.1.50 (физический)                           │
│                                                              │
│  virbr0: 192.168.122.1 ←─── Linux-bridge, созданный libvirt  │
│  ├─ dnsmasq: DHCP 192.168.122.2–254, DNS                     │
│  ├─ vnet0 (TAP) ─────────────┐                               │
│  │                           │                               │
│  ┌───────────────────────────┴────────────────────────────┐  │
│  │ Гостевая ВМ (AlmaLinux)                                │  │
│  │                                                        │  │
│  │  ens3 (или eth0): 192.168.122.50                       │  │
│  │  шлюз: 192.168.122.1 (= virbr0)                        │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

Что создаётся на хосте:

    virbr0 — Linux-bridge (мост). Это настоящий сетевой интерфейс ядра Linux, созданный libvirt. У него IP 192.168.122.1, он работает как шлюз и DNS-сервер (через dnsmasq).
    vnet0 — TAP-устройство. Каждый раз, когда запускается ВМ, libvirt создаёт TAP-интерфейс и подключает его к virbr0. Один TAP = одна ВМ.
    Видно через ip link show vnet0 и brctl show virbr0.

Что создаётся в ВМ:

    Интерфейс ens3 (virtio-net) с IP 192.168.122.50 (от DHCP libvirt).
    Шлюз 192.168.122.1 — это virbr0 на хосте.

Как связаны:

    Трафик ВМ → ens3 → vnet0 (TAP) → virbr0 (bridge) → NAT через iptables/nftables → enp3s0 → интернет.
    Хост → ВМ: напрямую по IP, без проброса портов. curl http://192.168.122.50:4881 работает «из коробки».


**Примечание:** чтобы реализовать в kvm/libvirt режим режим аналогичный режиму работы в virtualbox (доступ с хоста к nginx командой curl http://localhost:4881 ),
необходимо дополнительно использовать настройку iptables (так как libvirt сам по себе не поддерживает проброс портов). Vagrantfile для реализации такого режима
работы сети приведён ниже:

```
MACHINES = {
  :"selinux" => {
              :box_name => "almalinux9-stand",
              :cpus => 2,
              :memory => 2048
            }
}

GUEST_IP = "192.168.56.10"
HOST_PORT = 4881
GUEST_PORT = 4881

Vagrant.configure("2") do |config|
  MACHINES.each do |boxname, boxconfig|
    config.vm.synced_folder ".", "/vagrant", disabled: true
    config.vm.define boxname do |box|
      box.vm.box = boxconfig[:box_name]
      box.vm.host_name = boxname.to_s

      # Фиксированный IP в приватной сети (нужен для iptables-правил)
      box.vm.network "private_network", ip: GUEST_IP

      box.vm.provider "libvirt" do |v|
        v.memory = boxconfig[:memory]
        v.cpus = boxconfig[:cpus]
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

      # === iptables NAT: localhost:4881 → ВМ:4881 ===
      # Срабатывает после vagrant up
      config.trigger.after :up do |trigger|
        trigger.name = "iptables-nat-up"
        trigger.info = "Setting up iptables DNAT: localhost:#{HOST_PORT} → #{GUEST_IP}:#{GUEST_PORT}"
        trigger.run = { inline: <<-BASH
          # DNAT для внешнего трафика (PREROUTING)
          iptables -t nat -C PREROUTING -p tcp --dport #{HOST_PORT} -j DNAT --to-destination #{GUEST_IP}:#{GUEST_PORT} 2>/dev/null || \
          iptables -t nat -A PREROUTING -p tcp --dport #{HOST_PORT} -j DNAT --to-destination #{GUEST_IP}:#{GUEST_PORT}

          # DNAT для локального трафика (OUTPUT — для curl http://localhost:4881)
          iptables -t nat -C OUTPUT -p tcp -d 127.0.0.1 --dport #{HOST_PORT} -j DNAT --to-destination #{GUEST_IP}:#{GUEST_PORT} 2>/dev/null || \
          iptables -t nat -A OUTPUT -p tcp -d 127.0.0.1 --dport #{HOST_PORT} -j DNAT --to-destination #{GUEST_IP}:#{GUEST_PORT}

          # Разрешаем форвардинг
          iptables -C FORWARD -p tcp -d #{GUEST_IP} --dport #{GUEST_PORT} -j ACCEPT 2>/dev/null || \
          iptables -I FORWARD -p tcp -d #{GUEST_IP} --dport #{GUEST_PORT} -j ACCEPT
        BASH
        }
      end

      # Чистим правила после vagrant halt/destroy
      config.trigger.after :halt do |trigger|
        trigger.name = "iptables-nat-halt"
        trigger.run = { inline: <<-BASH
          iptables -t nat -D PREROUTING -p tcp --dport #{HOST_PORT} -j DNAT --to-destination #{GUEST_IP}:#{GUEST_PORT} 2>/dev/null
          iptables -t nat -D OUTPUT -p tcp -d 127.0.0.1 --dport #{HOST_PORT} -j DNAT --to-destination #{GUEST_IP}:#{GUEST_PORT} 2>/dev/null
          iptables -D FORWARD -p tcp -d #{GUEST_IP} --dport #{GUEST_PORT} -j ACCEPT 2>/dev/null
        BASH
        }
      end

      config.trigger.after :destroy do |trigger|
        trigger.name = "iptables-nat-destroy"
        trigger.run = { inline: <<-BASH
          iptables -t nat -D PREROUTING -p tcp --dport #{HOST_PORT} -j DNAT --to-destination #{GUEST_IP}:#{GUEST_PORT} 2>/dev/null
          iptables -t nat -D OUTPUT -p tcp -d 127.0.0.1 --dport #{HOST_PORT} -j DNAT --to-destination #{GUEST_IP}:#{GUEST_PORT} 2>/dev/null
          iptables -D FORWARD -p tcp -d #{GUEST_IP} --dport #{GUEST_PORT} -j ACCEPT 2>/dev/null
        BASH
        }
      end
    end
  end
end
```

### Что здесь происходит

Три цепочки iptables, и каждая делает свою часть: 

1. PREROUTING (nat) — для внешнего трафика

Пакет извне → eth0 хоста:4881 → DNAT → 192.168.56.10:4881

Если кто-то с другой машины в сети зайдёт на http://<ip-хоста>:4881, пакет попадёт в PREROUTING и будет перенаправлен в ВМ.

2. OUTPUT (nat) — для локального трафика

curl http://localhost:4881 → OUTPUT → DNAT → 192.168.56.10:4881

Это ключевое правило, без которого curl http://localhost:4881 не работает. PREROUTING не обрабатывает пакеты, которые генерирует сам хост — для них нужна цепочка OUTPUT в таблице nat. 

3. FORWARD (filter) — разрешить пересылку

iptables -I FORWARD -p tcp -d 192.168.56.10 --dport 4881 -j ACCEPT

По умолчанию libvirt ставит правила REJECT для FORWARD. Это правило разрешает пересылку DNAT-пакетов к ВМ.

Проверка после vagrant up

```
# По localhost (как в VirtualBox NAT)
curl -s http://localhost:4881 | head -5

# Напрямую по IP (как было раньше)
curl -s http://192.168.56.10:4881 | head -5

# Посмотреть правила
sudo iptables -t nat -L -n --line-numbers | grep 4881
```

Важный нюанс: -C перед -A

В правилах используется конструкция iptables -t nat -C ... 2>/dev/null || iptables -t nat -A ... — это проверка «есть ли уже такое правило?». Если правило уже существует (-C возвращает 0), оно не дублируется. Если нет — добавляется. Это защищает от дублей при повторном vagrant up без halt.



## 3.3.1.2 Режим Isolated / Private (private_network с фиксированным IP в Vagrant)

```
┌──────────────────────────────────────────────────────────────┐
│ Хост (RED OS)                                                │
│                                                              │
│  virbr1: 192.168.56.1 ←─── ещё один Linux-bridge             │
│  ├─ vnet1 (TAP) ─────────────┐                               │
│  │                           │                               │
│  ┌───────────────────────────┴────────────────────────────┐  │
│  │ Гостевая ВМ (AlmaLinux)                                │  │
│  │  ens4: 192.168.56.10                                   │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

То же самое, но без NAT и без выхода в интернет. Только изолированная сеть между хостом и ВМ.

### 3.3.1.3 Режим Bridged (мост к физической сети)

```
┌──────────────────────────────────────────────────────────────┐
│ Хост (RED OS)                                                │
│                                                              │
│  enp3s0: 192.168.1.50 ── добавлен в мост br0                 │
│  br0: 192.168.1.50 (IP переехал сюда)                        │
│  ├─ vnet0 (TAP) ─────────────┐                               │
│  │                           │                               │
│  ┌───────────────────────────┴────────────────────────────┐  │
│  │ Гостевая ВМ (AlmaLinux)                                │  │
│  │  ens3: 192.168.1.51 (от физического DHCP-сервера)      │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

Физический интерфейс хоста enp3s0 включается в мост br0, IP переезжает с enp3s0 на br0. ВМ через TAP подключается к тому же мосту — и получает IP из физической сети.


## 3.3.2 VirtualBox: какие интерфейсы создаются

VirtualBox использует собственный сетевой стек, который не зависит от Linux-bridge и TAP — он реализован внутри модуля ядра vboxdrv/vboxnetadp.

### 3.3.2.1 Режим NAT (по умолчанию в твоём Vagrantfile с forwarded_port)

```
┌─────────────────────────────────────────────┐
│ Хост (RED OS)                               │
│                                             │
│  lo: 127.0.0.1                              │
│  enp3s0: 192.168.1.50 (физический)          │
│                                             │
│  VirtualBox NAT-движок (внутри ядра VB)     │
│  слушает 127.0.0.1:4881 → проброс в ВМ      │
│                                             │
│  ┌────────────────────────────────────────┐ │
│  │ Гостевая ВМ (AlmaLinux)                │ │
│  │                                        │ │
│  │  eth0 (или enp0s3): 10.0.2.15          │ │
│  │  шлюз: 10.0.2.2 (NAT-шлюз VirtualBox)  │ │
│  │  DNS: 10.0.2.3                         │ │
│  └────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

Что создаётся на хосте:

    Ничего видимого. VirtualBox NAT не создаёт сетевого интерфейса на хосте (нет vboxnet*, нет моста). Трафик обрабатывается внутренним движком VB.
    Видны только слушатели проброшенных портов: ss -tlpn | grep 4881 → процесс VirtualBox на 127.0.0.1:4881.

Что создаётся в ВМ:

    Один интерфейс enp0s3 (PCI-адаптер VirtualBox) с IP 10.0.2.15.
    Шлюз 10.0.2.2 — это NAT-движок VirtualBox, не реальный маршрутизатор.
    DNS 10.0.2.3 — тоже встроенный в VirtualBox.

Как связаны:

    ВМ → интернет: трафик идёт через внутренний NAT VirtualBox, который подменяет адрес и выпускает через физический интерфейс хоста.
    Хост → ВМ: только через проброс портов (forwarded_port). Напрямую по IP 10.0.2.15 с хоста не достучаться.

### 3.3.2.2 Режим Host-Only (private_network с фиксированным IP)

```
┌─────────────────────────────────────────────┐
│ Хост (RED OS)                               │
│                                             │
│  enp3s0: 192.168.1.50 (физический)          │
│  vboxnet0: 192.168.56.1 ←─── VirtualBox     │
│        создаёт этот интерфейс на хосте      │
│                                             │
│  ┌────────────────────────────────────────┐ │
│  │ Гостевая ВМ (AlmaLinux)                │ │
│  │                                        │ │
│  │  enp0s8: 192.168.56.10                 │ │
│  └──────┬─────────────────────────────────┘ │
│         │                                   │
│  vboxnet0 ←─ виртуальный коммутатор VB      │
└─────────────────────────────────────────────┘
```

Что создаётся на хосте:

    Интерфейс vboxnet0 — это виртуальный адаптер типа «host-only», созданный VirtualBox. У него свой IP (обычно 192.168.56.1).
    Виден через ip addr show vboxnet0.

Что создаётся в ВМ:

    Второй интерфейс enp0s8 с IP 192.168.56.10 (тот, что ты указал в private_network).

Как связаны:

    vboxnet0 (хост) и enp0s8 (ВМ) — в одной виртуальной сети. Хост может пинговать ВМ напрямую по IP, ВМ может пинговать хост.
    Но интернета у ВМ в этом режиме нет (если не добавить NAT-адаптер первым).

Vagrantfile для реализации такого режима работы сети virtualbox приведён ниже:

```
MACHINES = {
  :"selinux" => {
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
      box.vm.host_name = boxname.to_s

      # Доступ по IP напрямую (как в KVM через private_network)
      box.vm.network "private_network", ip: "192.168.56.10"

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



### 3.3.2.3 Режим Bridged

```
┌─────────────────────────────────────────────┐
│ Хост (RED OS)                               │
│                                             │
│  enp3s0: 192.168.1.50 (физический)          │
│  ├─ VirtualBox Bridged = mirror enp3s0      │
│                                             │
│  ┌────────────────────────────────────────┐ │
│  │ Гостевая ВМ (AlmaLinux)                │ │
│  │  enp0s3: 192.168.1.51 (из той же сети) │ │
│  └────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

ВМ получает IP из той же сети, что и хост (от физического DHCP-сервера). VirtualBox просто «вешает» ВМ поверх физической сетевой карты через macvtap-подобный механизм. Интерфейс на хосте не создаётся — трафик идёт напрямую через физический адаптер.




### 3.3.3 Сводная таблица режимов работы сетей virtualbox и libvirt/kvm

| Параметр	| VirtualBox (NAT)	| VirtualBox (Host-Only)	| KVM/libvirt (NAT)	| KVM/libvirt (Private) |
|:------------------|:------------------------|:-------------------|:-----------------------------|:------------------------------|
| Интерфейс на хосте	|нет (внутренний движок VB)	| vboxnet0	| virbr0 (bridge) + vnet0 (TAP)| virbr1 (bridge) + vnet1 (TAP)|
| Интерфейс в ВМ	| enp0s3	| enp0s8	| ens3 (virtio)	| ens4 (virtio)|
| Технология	| Внутренний NAT VB	| Внутренний коммутатор VB	| Linux-bridge + TAP + iptables	| Linux-bridge + TAP|
| Хост → ВМ по IP	| нет (только проброс портов)	| да	|да	 |да |
| ВМ → интернет	| да (через NAT VB)	| нет	| да (через NAT libvirt)	| нет |
| nginx в ВМ доступен с хоста| curl http://localhost:4881| curl http://192.168.56.10:4881| curl http://192.168.56.10:4881|curl http://192.168.56.10:4881|
| DHCP/DNS	| встроен в VB	| встроен в VB	| dnsmasq на хосте	| dnsmasq на хосте |
| Виден через ip addr	| vboxnet* (в host-only) | vboxnet0	| virbr*, vnet*	| virbr*, vnet*|

Как увидеть всё это своими глазами

Запущена ВМ на libvirt, выполнить на хосте:

```
# Все мосты и их порты
bridge link show

# Все интерфейсы (увидишь virbr0, vnet0)
ip -br addr show

# Проверить, что dnsmasq раздаёт IP
sudo virsh net-dhcp-leases default
```

Когда запущена ВМ на VirtualBox:

```
# Host-only адаптер (если есть)
ip -br addr show | grep vboxnet

# Проброшенные порты (держит сам VirtualBox)
ss -tlpn | grep -E '4881|2222'
```

Внутри ВМ в обоих случаях:

```
ip -br addr show
ip route show
```

