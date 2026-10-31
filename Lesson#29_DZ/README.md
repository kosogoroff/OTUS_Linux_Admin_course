# Занятие 14.10.2026 "29. DHCP, PXE"


Настройка PXE сервера для автоматической установки

## Цель:

Отработать навыки установки и настройки DHCP, TFTP, PXE загрузчика и автоматической загрузки

## Описание/Пошаговая инструкция выполнения домашнего задания:

Для выполнения домашнего задания используйте методичку


## Что нужно сделать?

    Настроить загрузку по сети дистрибутива Ubuntu 24
    Установка должна проходить из HTTP-репозитория.
    Настроить автоматическую установку c помощью файла user-data
    Задания со звёздочкой*
    Настроить автоматическую загрузку по сети дистрибутива Ubuntu 24 c использованием UEFI

Задания со звёздочкой выполняются по желанию.

Формат сдачи ДЗ - vagrant + ansible

# Решение

Ниже приведено описание выполнения домашнего задания.

## 1.1 Создание ВМ и первоначальное конфигурирование доступа средствами vagrant

В связи с недоступностью портала https://portal.cloud.hashicorp.com/  и vagrantcloud для проверки и работы заранее локально скачаны несколько Vagrant box для различных версий Linux:

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

Ниже приведён Vagrant для создания двух ВМ - pxeserver и pxeclient:

```
[admin_insta11@mv334 pxe_lab]$ cat Vagrantfile
BOX_NAME = ENV['VAGRANT_BOX'] || 'bento/ubuntu-22.04'

Vagrant.configure("2") do |config|

  config.vm.define "pxeserver" do |server|
    server.vm.box = BOX_NAME
    server.vm.host_name = 'pxeserver'
    server.vm.network "forwarded_port", guest: 80, host: 8080
    server.vm.network :private_network,
      ip: "10.0.0.20",
      virtualbox__intnet: 'pxenet'
    server.vm.network :private_network, ip: "192.168.50.10", adapter: 3
    server.vm.provider "virtualbox" do |vb|
      vb.memory = "1024"
      vb.customize ["modifyvm", :id,
                    "--natdnshostresolver1", "on"]
      end
    
 #   server.vm.provision "ansible" do |ansible|
 #     ansible.playbook = "ansible/provision.yml"
 #     ansible.inventory_path = "ansible/hosts"
 #     ansible.host_key_checking = "false"
 #     ansible.limit = "all"
 #     end
    end

  config.vm.define "pxeclient" do |pxeclient|
    pxeclient.vm.box = BOX_NAME
    #pxeclient.vm.box = 'seskion/ubuntu-20.04-efi'
    pxeclient.vm.host_name = 'pxeclient'
    pxeclient.vm.network :private_network, ip: "10.0.0.21"
    pxeclient.vm.provider :virtualbox do |vb|
      vb.memory = "6144"
      vb.customize ["modifyvm", :id,
                    "--natdnshostresolver1", "on"]
      vb.customize [
        'modifyvm', :id,
        '--nic1', 'intnet',
        '--intnet1', 'pxenet',
        '--nic2', 'nat',
        '--boot1', 'net',
        '--boot2', 'none',
        '--boot3', 'none',
        '--boot4', 'none'
        ]
      vb.customize ["modifyvm", :id,
                    "--natdnshostresolver1", "on"]
      end
    end
  end
```

Данный Vagrantfile допускает следующее использование:

1) Для создания ВМ в гипервизоре virtualbox с использованием бокса generic/ubuntu2204 на vagrantcloud нужно запустить командой

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

2) Для создания ВМ в гипервизоре virtualbox с использованием локально установленного бокса almalinux/9 нужно запустить командой

```
VAGRANT_BOX=almalinux9-stand-vb vagrant up
```

**ПРИМЕЧАНИЕ:**  гипервизор virtualbox по умолчанию разрешает использование только определённого диапазона подсетей 192.168.56.0/21 для создания внутренних сетей виртаульных машин.
Так как в задании используются другие IP-адреса, то их необходимо явно разрешить, задав список в файле /etc/vbox/networks.conf , и затем перезагрузить гипервизор:

```
[admin_insta11@mv334 network_lab]$ cat /etc/vbox/networks.conf
* 192.168.56.0/21
* 10.0.0.0/24
[admin_insta11@mv334 network_lab]$ 
[admin_insta11@mv334 network_lab]$ sudo systemctl restart vboxdrv
```

После запуска создаются ВМ:

```
[admin_insta11@mv334 pxe_lab]$ VAGRANT_BOX=ubuntu-22.04-virtualbox vagrant up
Bringing machine 'pxeserver' up with 'virtualbox' provider...
Bringing machine 'pxeclient' up with 'virtualbox' provider...
==> pxeserver: Importing base box 'ubuntu-22.04-virtualbox'...
==> pxeserver: Matching MAC address for NAT networking...
==> pxeserver: Setting the name of the VM: pxe_lab_pxeserver_1793405114985_81327
==> pxeserver: Clearing any previously set network interfaces...
==> pxeserver: Preparing network interfaces based on configuration...
    pxeserver: Adapter 1: nat
    pxeserver: Adapter 2: intnet
    pxeserver: Adapter 3: hostonly
==> pxeserver: Forwarding ports...
    pxeserver: 80 (guest) => 8080 (host) (adapter 1)
    pxeserver: 22 (guest) => 2222 (host) (adapter 1)
==> pxeserver: Running 'pre-boot' VM customizations...
==> pxeserver: Booting VM...
==> pxeserver: Waiting for machine to boot. This may take a few minutes...
    pxeserver: SSH address: 127.0.0.1:2222
    pxeserver: SSH username: vagrant
    pxeserver: SSH auth method: private key
    pxeserver: Warning: Connection reset. Retrying...
    pxeserver: 
    pxeserver: Vagrant insecure key detected. Vagrant will automatically replace
    pxeserver: this with a newly generated keypair for better security.
    pxeserver: 
    pxeserver: Inserting generated public key within guest...
    pxeserver: Removing insecure key from the guest if it's present...
    pxeserver: Key inserted! Disconnecting and reconnecting using new SSH key...
==> pxeserver: Machine booted and ready!
==> pxeserver: Checking for guest additions in VM...
    pxeserver: The guest additions on this VM do not match the installed version of
    pxeserver: VirtualBox! In most cases this is fine, but in rare cases it can
    pxeserver: prevent things such as shared folders from working properly. If you see
    pxeserver: shared folder errors, please make sure the guest additions within the
    pxeserver: virtual machine match the version of VirtualBox you have installed on
    pxeserver: your host and reload your VM.
    pxeserver: 
    pxeserver: Guest Additions Version: 7.2.4
    pxeserver: VirtualBox Version: 7.1
==> pxeserver: Setting hostname...
==> pxeserver: Configuring and enabling network interfaces...
==> pxeserver: Mounting shared folders...
    pxeserver: /home/admin_insta11/pxe_lab => /vagrant
==> pxeclient: Importing base box 'ubuntu-22.04-virtualbox'...
==> pxeclient: Matching MAC address for NAT networking...
==> pxeclient: Setting the name of the VM: pxe_lab_pxeclient_1793405223206_91982
==> pxeclient: Fixed port collision for 22 => 2222. Now on port 2200.
==> pxeclient: Clearing any previously set network interfaces...
==> pxeserver: flag to force provisioning. Provisioners marked to run always will still run.
==> pxeclient: Fixed port collision for 22 => 2222. Now on port 2200.
==> pxeclient: Clearing any previously set network interfaces...
==> pxeclient: Preparing network interfaces based on configuration...
    pxeclient: Adapter 1: nat
    pxeclient: Adapter 2: hostonly
==> pxeclient: Forwarding ports...
    pxeclient: 22 (guest) => 2200 (host) (adapter 1)
==> pxeclient: Running 'pre-boot' VM customizations...
==> pxeclient: Booting VM...
==> pxeclient: Waiting for machine to boot. This may take a few minutes...
    pxeclient: SSH address: 127.0.0.1:22
    pxeclient: SSH username: vagrant
    pxeclient: SSH auth method: private key
    pxeclient: Warning: Authentication failure. Retrying...
    pxeclient: Warning: Authentication failure. Retrying...
    pxeclient: Warning: Authentication failure. Retrying...
    pxeclient: Warning: Authentication failure. Retrying...
    pxeclient: Warning: Authentication failure. Retrying...
    pxeclient: Warning: Authentication failure. Retrying...
    pxeclient: Warning: Authentication failure. Retrying...
    pxeclient: Warning: Authentication failure. Retrying...
    pxeclient: Warning: Authentication failure. Retrying...
    pxeclient: Warning: Authentication failure. Retrying...
    pxeclient: Warning: Authentication failure. Retrying...
^C==> pxeclient: Waiting for cleanup before exiting...
Vagrant exited after cleanup due to external interrupt.
[admin_insta11@mv334 pxe_lab]$
[admin_insta11@mv334 pxe_lab]$ vagrant status
Current machine states:

pxeserver                 running (virtualbox)
pxeclient                 running (virtualbox)

This environment represents multiple VMs. The VMs are all listed
above with their current state. For more information about a specific
VM, run `vagrant status NAME`.
[admin_insta11@mv334 pxe_lab]$ 
```

## 1.2 Конфигурирование сервера для загрузки с использованием PXE

Файлы начальной загрузки будут для клиента загрузки клиента с использованием PXE будут находиться преимущественно на сервере TFTP.
Файл установочного имиджа ОС Linux будет находиться на HTTP-сервере.

#### 1.2.1 Отключаем ufw файервол

```
[admin_insta11@mv334 pxe_lab]$ vagrant ssh pxeserver
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-160-generic x86_64)

Use of this system is acceptance of the OS vendor EULA and License Agreements.
vagrant@pxeserver:~$ 
vagrant@pxeserver:~$ sudo -i
root@pxeserver:~# 
root@pxeserver:~# systemctl status ufw
● ufw.service - Uncomplicated firewall
     Loaded: loaded (/lib/systemd/system/ufw.service; enabled; vendor preset: enabled)
     Active: active (exited) since Sat 2026-10-31 00:05:40 UTC; 6min ago
       Docs: man:ufw(8)
   Main PID: 592 (code=exited, status=0/SUCCESS)
        CPU: 2ms

Oct 31 00:05:40 vagrant systemd[1]: Starting Uncomplicated firewall...
Oct 31 00:05:40 vagrant systemd[1]: Finished Uncomplicated firewall.
root@pxeserver:~# 
root@pxeserver:~# systemctl stop ufw
root@pxeserver:~# 
root@pxeserver:~# systemctl disable ufw
Synchronizing state of ufw.service with SysV service script with /lib/systemd/systemd-sysv-install.
Executing: /lib/systemd/systemd-sysv-install disable ufw
Removed /etc/systemd/system/multi-user.target.wants/ufw.service.
root@pxeserver:~# 
root@pxeserver:~# systemctl status ufw
○ ufw.service - Uncomplicated firewall
     Loaded: loaded (/lib/systemd/system/ufw.service; disabled; vendor preset: enabled)
     Active: inactive (dead)
       Docs: man:ufw(8)

Oct 31 00:05:40 vagrant systemd[1]: Starting Uncomplicated firewall...
Oct 31 00:05:40 vagrant systemd[1]: Finished Uncomplicated firewall.
Oct 31 00:12:22 pxeserver systemd[1]: Stopping Uncomplicated firewall...
Oct 31 00:12:22 pxeserver ufw-init[1646]: Skip stopping firewall: ufw (not enabled)
Oct 31 00:12:22 pxeserver systemd[1]: ufw.service: Deactivated successfully.
Oct 31 00:12:22 pxeserver systemd[1]: Stopped Uncomplicated firewall.
root@pxeserver:~# 
```



#### 1.2.2 Установка и конфигурирование DHCP и TFTP-сервера dnsmasq и файлов для загрузки PXE

##### 1.2.2.1 Устанавливаем и конфигурируем DHCP и TFTP сервер на основе dnsmasq:

```
root@pxeserver:~# apt update
<...>
root@pxeserver:~# apt install dnsmasq
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
The following additional packages will be installed:
  dns-root-data dnsmasq-base
Suggested packages:
  resolvconf
The following NEW packages will be installed:
  dns-root-data dnsmasq dnsmasq-base
0 upgraded, 3 newly installed, 0 to remove and 193 not upgraded.
Need to get 405 kB of archives.
After this operation, 1,040 kB of additional disk space will be used.
Do you want to continue? [Y/n] y
Get:1 http://us.archive.ubuntu.com/ubuntu jammy-updates/main amd64 dns-root-data all 2024071801~ubuntu0.22.04.1 [6,132 B]
Get:2 http://us.archive.ubuntu.com/ubuntu jammy-updates/main amd64 dnsmasq-base amd64 2.91-0ubuntu0.22.04.2 [379 kB]
Get:3 http://us.archive.ubuntu.com/ubuntu jammy-updates/universe amd64 dnsmasq all 2.91-0ubuntu0.22.04.2 [20.5 kB]
Fetched 405 kB in 1s (308 kB/s)
Selecting previously unselected package dns-root-data.
(Reading database ... 45823 files and directories currently installed.)
Preparing to unpack .../dns-root-data_2024071801~ubuntu0.22.04.1_all.deb ...
Unpacking dns-root-data (2024071801~ubuntu0.22.04.1) ...
Selecting previously unselected package dnsmasq-base.
Preparing to unpack .../dnsmasq-base_2.91-0ubuntu0.22.04.2_amd64.deb ...
Unpacking dnsmasq-base (2.91-0ubuntu0.22.04.2) ...
Selecting previously unselected package dnsmasq.
Preparing to unpack .../dnsmasq_2.91-0ubuntu0.22.04.2_all.deb ...
Unpacking dnsmasq (2.91-0ubuntu0.22.04.2) ...
Setting up dnsmasq-base (2.91-0ubuntu0.22.04.2) ...
Setting up dns-root-data (2024071801~ubuntu0.22.04.1) ...
Setting up dnsmasq (2.91-0ubuntu0.22.04.2) ...
Created symlink /etc/systemd/system/multi-user.target.wants/dnsmasq.service → /lib/systemd/system/dnsmasq.service.
Job for dnsmasq.service failed because the control process exited with error code.
See "systemctl status dnsmasq.service" and "journalctl -xeu dnsmasq.service" for details.
invoke-rc.d: initscript dnsmasq, action "start" failed.
× dnsmasq.service - dnsmasq - A lightweight DHCP and caching DNS server
     Loaded: loaded (/lib/systemd/system/dnsmasq.service; enabled; vendor preset: enabled)
     Active: failed (Result: exit-code) since Sat 2026-10-31 00:14:13 UTC; 32ms ago
    Process: 2254 ExecStartPre=/etc/init.d/dnsmasq checkconfig (code=exited, status=0/SUCCESS)
    Process: 2262 ExecStart=/etc/init.d/dnsmasq systemd-exec (code=exited, status=2)
        CPU: 54ms

Oct 31 00:14:13 pxeserver systemd[1]: Starting dnsmasq - A lightweight DHCP and caching DNS server...
Oct 31 00:14:13 pxeserver dnsmasq[2262]: dnsmasq: failed to create listening socket for port 53: Address already in use
Oct 31 00:14:13 pxeserver systemd[1]: dnsmasq.service: Control process exited, code=exited, status=2/INVALIDARGUMENT
Oct 31 00:14:13 pxeserver dnsmasq[2262]: failed to create listening socket for port 53: Address already in use
Oct 31 00:14:13 pxeserver systemd[1]: dnsmasq.service: Failed with result 'exit-code'.
Oct 31 00:14:13 pxeserver dnsmasq[2262]: FAILED to start up
Oct 31 00:14:13 pxeserver systemd[1]: Failed to start dnsmasq - A lightweight DHCP and caching DNS server.
Processing triggers for man-db (2.10.2-1) ...
Processing triggers for dbus (1.12.20-2ubuntu4.1) ...
Scanning processes...                                                                                                                                                                         
Scanning linux images...                                                                                                                                                                      

Running kernel seems to be up-to-date.

No services need to be restarted.

No containers need to be restarted.

No user sessions are running outdated binaries.

No VM guests are running outdated hypervisor (qemu) binaries on this host.
root@pxeserver:~# 
```

##### 1.2.2.2 Конфигурируем DHCP и TFTP сервер dnsmasq, скачиваем, создаём и размещаем на TFTP-сервере необходимые файлы:

Создаём файл конфигурации:

- выдачу IP-адресов по DHCP;
- название загрузочного имиджа pxelinux.0 для загрузки PXE:

```
root@pxeserver:~# vi /etc/dnsmasq.d/pxe.conf
root@pxeserver:~# 
root@pxeserver:~# cat /etc/dnsmasq.d/pxe.conf
#Указываем интерфейс в на котором будет работать DHCP/TFTP
interface=eth1
bind-interfaces
#Также указываем интерфейс и range адресов которые будут выдаваться по DHCP
dhcp-range=eth1,10.0.0.100,10.0.0.120
#Имя файла, с которого надо начинать загрузку для Legacy boot (этот пример рассматривается в методичке)
dhcp-boot=pxelinux.0
#dhcp-boot=pxe_fix.ipxe
#Имена файлов, для UEFI-загрузки (не обязательно добавлять)
dhcp-match=set:efi-x86_64,option:client-arch,7
dhcp-boot=tag:efi-x86_64,bootx64.efi
#Включаем TFTP-сервер
enable-tftp
#Указываем каталог для TFTP-сервера
tftp-root=/srv/tftp/amd64
root@pxeserver:~# 
```

В директорию TFTP-сервера помещаем необходимые файлы:

1. Пакет для сетевой загрузки Ubuntu 24.04:

```
root@pxeserver:~# wget https://cdimage.ubuntu.com/ubuntu-server/noble/daily-live/current/noble-netboot-amd64.tar.gz
--2026-10-31 00:24:15--  https://cdimage.ubuntu.com/ubuntu-server/noble/daily-live/current/noble-netboot-amd64.tar.gz
Resolving cdimage.ubuntu.com (cdimage.ubuntu.com)... 91.189.91.124, 185.125.190.37, 185.125.190.40, ...
Connecting to cdimage.ubuntu.com (cdimage.ubuntu.com)|91.189.91.124|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 102997006 (98M) [application/x-gzip]
Saving to: ‘noble-netboot-amd64.tar.gz’

noble-netboot-amd64.tar.gz                      100%[=====================================================================================================>]  98.23M  4.44MB/s    in 23s     

2026-10-31 00:24:38 (4.32 MB/s) - ‘noble-netboot-amd64.tar.gz’ saved [102997006/102997006]

root@pxeserver:~# 
root@pxeserver:~# tar -xzvf noble-netboot-amd64.tar.gz -C /srv/tftp
./
./amd64/
./amd64/ldlinux.c32
./amd64/pxelinux.cfg/
./amd64/pxelinux.cfg/default
./amd64/pxelinux.0
./amd64/linux
./amd64/initrd
./amd64/grub/
./amd64/grub/grub.cfg
./amd64/grubx64.efi
./amd64/bootx64.efi
root@pxeserver:~#
```


2. Файл загрузочной конфигурации ОС Linux для сетевой загрузки Ubuntu 24.04 с указанием загрузочного имиджа ОС и файла автоматической установки Kickstart,
которые будут располагаться на HTTP-сервере. HTTP-сервер используется в связи с тем, что обечпечивает более высокой скоростью загрузки, по сравнению с TFTP-сервером).
Также в строке параметров загрузки Linux указывается необходимый размер временного диска для скачивания имиджа и его временного размещения в памяти ОЗУ клиента.
Этот диск должен иметь достаточный максимальный размер для размещения имиджа (в данном случае размер загружаемого установочного имиджа равен 3,8Гб - поэтому мексамальный размер
диска указан с небольшим запасом 4,5Гб):

```
root@pxeserver:~# vi /srv/tftp/amd64/pxelinux.cfg/default
root@pxeserver:~#
root@pxeserver:~# cat /srv/tftp/amd64/pxelinux.cfg/default
DEFAULT install
LABEL install
  KERNEL linux
  INITRD initrd
  APPEND root=/dev/ram0 ramdisk_size=4500000 ip=dhcp iso-url=http://10.0.0.20/srv/images/noble-live-server-amd64.iso autoinstall ds=nocloud-net;s=http://10.0.0.20/srv/ks/

root@pxeserver:~# 
```

**ПРИМЕЧАНИЕ:** ещё большее значение для загрузки имиджа имеет размер памяти ОЗУ на клиентской машине pxeclient - путём экспериментов выяснено, что выбраный установочный диск ISO
Ubuntu 24.04 размером 3,8Гб не мог загрузиться на клиентскую машину до конца при размере ОЗУ в ВМ pxeclient меньше 5500Мб (при размере ОЗУ 5400Мб ужее не загружался).
Кроме того, при дальнейшей инсталляции уже загруженного имиджа инсталлятор subiquity также завершался с указанием на нехватку памяти - пришлось увеличить размер ОЗУ ещё
на 0,5Гб - после этого автоматическая установка ОС Ubuntu 24.04 успешно продолжилась.
Поэтому, с учётом полученных результатов, размер ОЗУ в Vagrantfile при создании ВМ pxeclient указан 6144Мб.

Перезапускаем dnsmasq для применения настроек:

```
root@pxeserver:~# systemctl restart dnsmasq
root@pxeserver:~# 
root@pxeserver:~# systemctl status dnsmasq
● dnsmasq.service - dnsmasq - A lightweight DHCP and caching DNS server
     Loaded: loaded (/lib/systemd/system/dnsmasq.service; enabled; vendor preset: enabled)
     Active: active (running) since Sat 2026-10-31 00:27:01 UTC; 13s ago
    Process: 2535 ExecStartPre=/etc/init.d/dnsmasq checkconfig (code=exited, status=0/SUCCESS)
    Process: 2543 ExecStart=/etc/init.d/dnsmasq systemd-exec (code=exited, status=0/SUCCESS)
    Process: 2552 ExecStartPost=/etc/init.d/dnsmasq systemd-start-resolvconf (code=exited, status=0/SUCCESS)
   Main PID: 2551 (dnsmasq)
      Tasks: 1 (limit: 1011)
     Memory: 1.3M
        CPU: 73ms
     CGroup: /system.slice/dnsmasq.service
             └─2551 /usr/sbin/dnsmasq -x /run/dnsmasq/dnsmasq.pid -u dnsmasq -7 /etc/dnsmasq.d,.dpkg-dist,.dpkg-old,.dpkg-new --local-service --trust-anchor=.,20326,8,2,E06D44B80B8F1D39A95C>

Oct 31 00:27:00 pxeserver systemd[1]: Starting dnsmasq - A lightweight DHCP and caching DNS server...
Oct 31 00:27:01 pxeserver dnsmasq[2551]: started, version 2.91 cachesize 150
Oct 31 00:27:01 pxeserver dnsmasq[2551]: compile time options: IPv6 GNU-getopt DBus no-UBus i18n IDN2 DHCP DHCPv6 no-Lua TFTP conntrack ipset no-nftset auth DNSSEC loop-detect inotify dumpf>
Oct 31 00:27:01 pxeserver dnsmasq-dhcp[2551]: DHCP, IP range 10.0.0.100 -- 10.0.0.120, lease time 1h
Oct 31 00:27:01 pxeserver dnsmasq-dhcp[2551]: DHCP, sockets bound exclusively to interface eth1
Oct 31 00:27:01 pxeserver dnsmasq-tftp[2551]: TFTP root is /srv/tftp/amd64
Oct 31 00:27:01 pxeserver dnsmasq[2551]: reading /etc/resolv.conf
Oct 31 00:27:01 pxeserver dnsmasq[2551]: using nameserver 127.0.0.53#53
Oct 31 00:27:01 pxeserver dnsmasq[2551]: read /etc/hosts - 10 names
Oct 31 00:27:01 pxeserver systemd[1]: Started dnsmasq - A lightweight DHCP and caching DNS server.
root@pxeserver:~#
```


##### 1.2.2.3 Устанавливаем и конфигурируем HTTP сервер apache, скачиваем и размещаем на HTTP-сервере файл загрузочного имиджа:



```
root@pxeserver:~# apt install apache2
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
The following additional packages will be installed:
  apache2-bin apache2-data apache2-utils libapr1 libaprutil1 libaprutil1-dbd-sqlite3 libaprutil1-ldap liblua5.3-0 mailcap mime-support ssl-cert
Suggested packages:
  apache2-doc apache2-suexec-pristine | apache2-suexec-custom www-browser
The following NEW packages will be installed:
  apache2 apache2-bin apache2-data apache2-utils libapr1 libaprutil1 libaprutil1-dbd-sqlite3 libaprutil1-ldap liblua5.3-0 mailcap mime-support ssl-cert
0 upgraded, 12 newly installed, 0 to remove and 193 not upgraded.
Need to get 2,123 kB of archives.
After this operation, 8,445 kB of additional disk space will be used.
Do you want to continue? [Y/n] y
<...>
No VM guests are running outdated hypervisor (qemu) binaries on this host.
root@pxeserver:~#
root@pxeserver:~# mkdir /srv/images
root@pxeserver:~# cd /srv/images
root@pxeserver:/srv/images#
root@pxeserver:/srv/images# wget https://cdimage.ubuntu.com/ubuntu-server/noble/daily-live/current/noble-live-server-amd64.iso
--2026-10-31 00:30:52--  https://cdimage.ubuntu.com/ubuntu-server/noble/daily-live/current/noble-live-server-amd64.iso
Resolving cdimage.ubuntu.com (cdimage.ubuntu.com)... 185.125.190.37, 185.125.190.40, 91.189.91.124, ...
Connecting to cdimage.ubuntu.com (cdimage.ubuntu.com)|185.125.190.37|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 4080486400 (3.8G) [application/x-iso9660-image]
Saving to: ‘noble-live-server-amd64.iso’

noble-live-server-amd64.iso                     100%[=====================================================================================================>]   3.80G  5.25MB/s    in 12m 18s 

2026-10-31 00:43:10 (5.27 MB/s) - ‘noble-live-server-amd64.iso’ saved [4080486400/4080486400]

root@pxeserver:/srv/images#
```

Создаём файл конфигурации HTTP-сервера:

```
root@pxeserver:/srv/images# vim /etc/apache2/sites-available/ks-server.conf
root@pxeserver:/srv/images#
root@pxeserver:~# cat /etc/apache2/sites-available/ks-server.conf
#Указываем IP-адрес хоста и порт на котором будет работать Web-сервер
<VirtualHost 10.0.0.20:80>
DocumentRoot /
# Указываем директорию /srv/images из которой будет загружаться iso-образ
<Directory /srv/images>
Options Indexes MultiViews
AllowOverride All
Require all granted
</Directory>
# Файлы Kickstart для автоматической установки
<Directory /srv/ks>
Options Indexes MultiViews
AllowOverride All
Require all granted
</Directory>
</VirtualHost>
root@pxeserver:~#
```

Создаём на HTTP-сервере файлы, необходимые для автоматической установки ОС и настройки пакетов с помощью subiquity:

- файл user-data с необходимыми настройками установки;
- минимальный файл meta-data

```
root@pxeserver:~# cat /srv/ks/user-data
#cloud-config
autoinstall:
  apt:
    disable_components: []
    geoip: true
    preserve_sources_list: false
    primary:
      - arches:
          - amd64
          - i386
        uri: http://us.archive.ubuntu.com/ubuntu
      - arches:
          - default
        uri: http://ports.ubuntu.com/ubuntu-ports
  drivers:
    install: false
  identity:
    hostname: linux
    password: $6$sJgo6Hg5zXBwkkI8$btrEoWAb5FxKhajagWR49XM4EAOfO/Dr5bMrLOkGe3KkMYdsh7T3MU5mYwY2TIMJpVKckAwnZFs2ltUJ1abOZ.
    realname: otus
    username: otus
  kernel:
    package: linux-generic
  keyboard:
    layout: us
    toggle: null
    variant: ''
  locale: en_US.UTF-8
  network:
    ethernets:
      enp0s3:
        dhcp4: true
      enp0s8:
        dhcp4: true
    version: 2
  ssh:
    allow-pw: true
    authorized-keys: []
  updates: security
  version: 1
root@pxeserver:~# 
root@pxeserver:~# cat /srv/ks/meta-data
instance-id: i-pxe-test
local-hostname: linux
root@pxeserver:~# 

```


Применяем конфигурации и перезапускаем apache:

```
root@pxeserver:/srv/images# 
root@pxeserver:/srv/images# a2ensite ks-server.conf
Enabling site ks-server.
To activate the new configuration, you need to run:
  systemctl reload apache2
root@pxeserver:/srv/images# 
root@pxeserver:/srv/images# systemctl restart apache2
root@pxeserver:/srv/images# 
root@pxeserver:/srv/images# systemctl status apache2
● apache2.service - The Apache HTTP Server
     Loaded: loaded (/lib/systemd/system/apache2.service; enabled; vendor preset: enabled)
     Active: active (running) since Sat 2026-10-31 00:48:35 UTC; 10s ago
       Docs: https://httpd.apache.org/docs/2.4/
    Process: 3416 ExecStart=/usr/sbin/apachectl start (code=exited, status=0/SUCCESS)
   Main PID: 3420 (apache2)
      Tasks: 55 (limit: 1011)
     Memory: 4.9M
        CPU: 37ms
     CGroup: /system.slice/apache2.service
             ├─3420 /usr/sbin/apache2 -k start
             ├─3421 /usr/sbin/apache2 -k start
             └─3422 /usr/sbin/apache2 -k start

Oct 31 00:48:35 pxeserver systemd[1]: Starting The Apache HTTP Server...
Oct 31 00:48:35 pxeserver apachectl[3419]: AH00558: apache2: Could not reliably determine the server's fully qualified domain name, using 127.0.2.1. Set the 'ServerName' directive globally >
Oct 31 00:48:35 pxeserver systemd[1]: Started The Apache HTTP Server.
root@pxeserver:/srv/images#
root@pxeserver:/srv/images# ss -tlnp
State     Recv-Q    Send-Q                          Local Address:Port         Peer Address:Port    Process                                                                                   
LISTEN    0         32                                  10.0.0.20:53                0.0.0.0:*        users:(("dnsmasq",pid=2551,fd=7))                                                        
LISTEN    0         32                                  127.0.0.1:53                0.0.0.0:*        users:(("dnsmasq",pid=2551,fd=10))                                                       
LISTEN    0         4096                            127.0.0.53%lo:53                0.0.0.0:*        users:(("systemd-resolve",pid=2384,fd=14))                                               
LISTEN    0         128                                   0.0.0.0:22                0.0.0.0:*        users:(("sshd",pid=856,fd=3))                                                            
LISTEN    0         32            [fe80::a00:27ff:feea:ed58]%eth1:53                   [::]:*        users:(("dnsmasq",pid=2551,fd=13))                                                       
LISTEN    0         511                                         *:80                      *:*        users:(("apache2",pid=3422,fd=4),("apache2",pid=3421,fd=4),("apache2",pid=3420,fd=4))    
LISTEN    0         32                                      [::1]:53                   [::]:*        users:(("dnsmasq",pid=2551,fd=16))                                                       
LISTEN    0         128                                      [::]:22                   [::]:*        users:(("sshd",pid=856,fd=4))                                                            
root@pxeserver:/srv/images#
```


Общая структура файлов, расположенных на TFTP и HTTP-серверах получилась следующая:

```
root@pxeserver:~# tree /srv
/srv
├── images
│   └── noble-live-server-amd64.iso
├── ks
│   ├── meta-data
│   └── user-data
└── tftp
    └── amd64
        ├── bootx64.efi
        ├── grub
        │   └── grub.cfg
        ├── grubx64.efi
        ├── initrd
        ├── ldlinux.c32
        ├── linux
        ├── pxe_fix.ipxe
        ├── pxelinux.0
        └── pxelinux.cfg
            └── default

6 directories, 12 files
root@pxeserver:~# 
```

В том числе вручную созданы файлы конфигураций:

- на TFTP-сервере:
  
  - /srv/tftp/pxelinux.cfg/default
    
- на HTTP-сервере:
  
  - /srv/ks/user-data
  - /srv/ks/meta-data
 
