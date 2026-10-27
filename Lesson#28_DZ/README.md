# Занятие 12.10.2026 "28. Архитектура сетей"

Разворачиваем сетевую лабораторию

## Цель:

Научиться менять базовые сетевые настройки в Linux-based системах;

## Описание/Пошаговая инструкция выполнения домашнего задания:

Для выполнения домашнего задания используйте методичку


#### Дано

https://github.com/erlong15/otus-linux/tree/network    (ветка network)

Vagrantfile с начальным построением сети

    inetRouter
    centralRouter
    centralServer

тестировалось на virtualbox


#### Планируемая архитектура

построить следующую архитектуру

Сеть office1

    192.168.2.0/26 - dev
    192.168.2.64/26 - test servers
    192.168.2.128/26 - managers
    192.168.2.192/26 - office hardware

Сеть office2

    192.168.1.0/25 - dev
    192.168.1.128/26 - test servers
    192.168.1.192/26 - office hardware

Сеть central

    192.168.0.0/28 - directors
    192.168.0.32/28 - office hardware
    192.168.0.64/26 - wifi


Итого должны получиться следующие сервера

    inetRouter
    centralRouter
    office1Router
    office2Router
    centralServer
    office1Server
    office2Server


#### Практическая часть

    Соединить офисы в сеть согласно схеме и настроить роутинг
    Все сервера и роутеры должны ходить в инет черз inetRouter
    Все сервера должны видеть друг друга
    у всех новых серверов отключить дефолт на нат (eth0), который вагрант поднимает для связи
    при нехватке сетевых интерфейсов добавить по несколько адресов на интерфейс

Формат сдачи ДЗ - vagrant + ansible

# Решение


Схема создаваемой лабораторной сети из методички:

<img width="571" height="729" alt="изображение" src="https://github.com/user-attachments/assets/0793a5a2-c247-4c88-a174-5d4be5fddc11" />

Таблица IP-адресации интерфейсов хостов из методички:

<img width="538" height="442" alt="изображение" src="https://github.com/user-attachments/assets/8cdbbefb-8935-4d84-9873-edcabfa2458b" />




Репозиторий со стендом домашнего задания выложен по ссылке [https://github.com/kosogoroff/backups_lab.git](https://github.com/kosogoroff/network_lab.git)

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

Модифицированный Vagrantfile (используется в лабораторном проекте) приведён ниже:

```
[admin_insta11@mv334 network_lab]$ cat Vagrantfile
BOX_NAME = ENV['VAGRANT_BOX'] || 'bento/ubuntu-22.04'

MACHINES = {
  :inetRouter => {
        :box_name => BOX_NAME,
        :vm_name => "inetRouter",
        #:public => {:ip => "10.10.10.1", :adapter => 1},
        :net => [   
                    #ip, adpter, netmask, virtualbox__intnet
                    ["192.168.255.1", 2, "255.255.255.252",  "router-net"], 
                    ["192.168.50.10", 8, "255.255.255.0"],
                ]
  },

  :centralRouter => {
        :box_name => BOX_NAME,
        :vm_name => "centralRouter",
        :net => [
                   ["192.168.255.2",  2, "255.255.255.252",  "router-net"],
                   ["192.168.0.1",    3, "255.255.255.240",  "dir-net"],
                   ["192.168.0.33",   4, "255.255.255.240",  "hw-net"],
                   ["192.168.0.65",   5, "255.255.255.192",  "mgt-net"],
                   ["192.168.255.9",  6, "255.255.255.252",  "office1-central"],
                   ["192.168.255.5",  7, "255.255.255.252",  "office2-central"],
                   ["192.168.50.11",  8, "255.255.255.0"],
                ]
  },

  :centralServer => {
        :box_name => BOX_NAME,
        :vm_name => "centralServer",
        :net => [
                   ["192.168.0.2",    2, "255.255.255.240",  "dir-net"],
                   ["192.168.50.12",  8, "255.255.255.0"],
                ]
  },

  :office1Router => {
        :box_name => BOX_NAME,
        :vm_name => "office1Router",
        :net => [
                   ["192.168.255.10",  2,  "255.255.255.252",  "office1-central"],
                   ["192.168.2.1",     3,  "255.255.255.192",  "dev1-net"],
                   ["192.168.2.65",    4,  "255.255.255.192",  "test1-net"],
                   ["192.168.2.129",   5,  "255.255.255.192",  "managers-net"],
                   ["192.168.2.193",   6,  "255.255.255.192",  "office1-net"],
                   ["192.168.50.20",   8,  "255.255.255.0"],
                ]
  },

  :office1Server => {
        :box_name => BOX_NAME,
        :vm_name => "office1Server",
        :net => [
                   ["192.168.2.130",  2,  "255.255.255.192",  "managers-net"],
                   ["192.168.50.21",  8,  "255.255.255.0"],
                ]
  },

  :office2Router => {
       :box_name => BOX_NAME,
       :vm_name => "office2Router",
       :net => [
                   ["192.168.255.6",  2,  "255.255.255.252",  "office2-central"],
                   ["192.168.1.1",    3,  "255.255.255.128",  "dev2-net"],
                   ["192.168.1.129",  4,  "255.255.255.192",  "test2-net"],
                   ["192.168.1.193",  5,  "255.255.255.192",  "office2-net"],
                   ["192.168.50.30",  8,  "255.255.255.0"],
               ]
  },

  :office2Server => {
       :box_name => BOX_NAME,
       :vm_name => "office2Server",
       :net => [
                  ["192.168.1.2",    2,  "255.255.255.128",  "dev2-net"],
                  ["192.168.50.31",  8,  "255.255.255.0"],
               ]
  }
}

Vagrant.configure("2") do |config|
  MACHINES.each do |boxname, boxconfig|
    config.vm.define boxname do |box|
      box.vm.box = boxconfig[:box_name]
      box.vm.host_name = boxconfig[:vm_name]
      
      box.vm.provider "virtualbox" do |v|
        v.memory = 768
        v.cpus = 1
       end

      boxconfig[:net].each do |ipconf|
        box.vm.network("private_network", ip: ipconf[0], adapter: ipconf[1], netmask: ipconf[2], virtualbox__intnet: ipconf[3])
      end

      if boxconfig.key?(:public)
        box.vm.network "public_network", boxconfig[:public]
      end

      box.vm.provision "shell", inline: <<-SHELL
        mkdir -p ~root/.ssh
        cp ~vagrant/.ssh/auth* ~root/.ssh
      SHELL
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
VAGRANT_BOX=almalinux9-stand-vb vagrant up --provider=virtualbox
```

или просто

```
VAGRANT_BOX=almalinux9-stand-vb vagrant up
```

Также исходный и модифицированный Vagrantfile рассчитаны на создание нескольких ВМ - каждую ВМ можно индивидуально описывать в массиве MACHINES.

**ПРИМЕЧАНИЕ:**  гипервизор virtualbox по умолчанию разрешает использование только определённого диапазона подсетей для создания внутренних сетей виртаульных машин.
Так как в задании используются другие IP-адреса, то их необходимо явно разрешить, задав список в файле /etc/vbox/networks.conf , и затем перезагрузить гипервизор:

```
[admin_insta11@mv334 network_lab]$ cat /etc/vbox/networks.conf
* 192.168.56.0/21
* 192.168.0.0/21
* 192.168.50.0/24
* 192.168.255.0/24
[admin_insta11@mv334 network_lab]$ 
[admin_insta11@mv334 network_lab]$ sudo systemctl restart vboxdrv
```


После запуска с вышеприведённым Vagrantfile ВМ создаются:

```
admin_insta11@mv334 network_lab]$ VAGRANT_BOX=ubuntu-22.04-virtualbox vagrant up
Bringing machine 'inetRouter' up with 'virtualbox' provider...
Bringing machine 'centralRouter' up with 'virtualbox' provider...
Bringing machine 'centralServer' up with 'virtualbox' provider...
Bringing machine 'office1Router' up with 'virtualbox' provider...
Bringing machine 'office1Server' up with 'virtualbox' provider...
Bringing machine 'office2Router' up with 'virtualbox' provider...
Bringing machine 'office2Server' up with 'virtualbox' provider...
==> inetRouter: You assigned a static IP ending in ".1" or ":1" to this machine.
==> inetRouter: This is very often used by the router and can cause the
==> inetRouter: network to not work properly. If the network doesn't work
==> inetRouter: properly, try changing this IP.
==> inetRouter: You assigned a static IP ending in ".1" or ":1" to this machine.
==> inetRouter: This is very often used by the router and can cause the
==> inetRouter: network to not work properly. If the network doesn't work
==> inetRouter: properly, try changing this IP.
==> inetRouter: Clearing any previously set network interfaces...
==> inetRouter: Preparing network interfaces based on configuration...
    inetRouter: Adapter 1: nat
    inetRouter: Adapter 2: intnet
    inetRouter: Adapter 8: hostonly
==> inetRouter: Forwarding ports...
    inetRouter: 22 (guest) => 2222 (host) (adapter 1)
==> inetRouter: Running 'pre-boot' VM customizations...
==> inetRouter: Booting VM...
==> inetRouter: Waiting for machine to boot. This may take a few minutes...
    inetRouter: SSH address: 127.0.0.1:2222
    inetRouter: SSH username: vagrant
    inetRouter: SSH auth method: private key
    inetRouter: Warning: Connection reset. Retrying...
    inetRouter: Warning: Remote connection disconnect. Retrying...
    inetRouter: 
    inetRouter: Vagrant insecure key detected. Vagrant will automatically replace
    inetRouter: this with a newly generated keypair for better security.
    inetRouter: 
    inetRouter: Inserting generated public key within guest...
    inetRouter: Removing insecure key from the guest if it's present...
    inetRouter: Key inserted! Disconnecting and reconnecting using new SSH key...
==> inetRouter: Machine booted and ready!
==> inetRouter: Checking for guest additions in VM...
    inetRouter: The guest additions on this VM do not match the installed version of
    inetRouter: VirtualBox! In most cases this is fine, but in rare cases it can
    inetRouter: prevent things such as shared folders from working properly. If you see
    inetRouter: shared folder errors, please make sure the guest additions within the
    inetRouter: virtual machine match the version of VirtualBox you have installed on
    inetRouter: your host and reload your VM.
    inetRouter: 
    inetRouter: Guest Additions Version: 7.2.4
    inetRouter: VirtualBox Version: 7.1
==> inetRouter: Setting hostname...
==> inetRouter: Configuring and enabling network interfaces...
==> inetRouter: Mounting shared folders...
    inetRouter: /home/admin_insta11/network_lab => /vagrant
==> inetRouter: Running provisioner: shell...
    inetRouter: Running: inline script
==> centralRouter: You assigned a static IP ending in ".1" or ":1" to this machine.
==> centralRouter: This is very often used by the router and can cause the
==> centralRouter: network to not work properly. If the network doesn't work
==> centralRouter: properly, try changing this IP.
==> centralRouter: Importing base box 'ubuntu-22.04-virtualbox'...
==> centralRouter: Matching MAC address for NAT networking...
==> centralRouter: You assigned a static IP ending in ".1" or ":1" to this machine.
==> centralRouter: This is very often used by the router and can cause the
==> centralRouter: network to not work properly. If the network doesn't work
==> centralRouter: properly, try changing this IP.
==> centralRouter: Setting the name of the VM: network_lab_centralRouter_1792939017250_26780
==> centralRouter: Fixed port collision for 22 => 2222. Now on port 2200.
==> centralRouter: Clearing any previously set network interfaces...
==> centralRouter: Preparing network interfaces based on configuration...
    centralRouter: Adapter 1: nat
    centralRouter: Adapter 2: intnet
    centralRouter: Adapter 3: intnet
    centralRouter: Adapter 4: intnet
    centralRouter: Adapter 5: intnet
    centralRouter: Adapter 6: intnet
    centralRouter: Adapter 7: intnet
    centralRouter: Adapter 8: hostonly
==> centralRouter: Forwarding ports...
    centralRouter: 22 (guest) => 2200 (host) (adapter 1)
==> centralRouter: Running 'pre-boot' VM customizations...
==> centralRouter: Booting VM...
==> centralRouter: Waiting for machine to boot. This may take a few minutes...
    centralRouter: SSH address: 127.0.0.1:2200
    centralRouter: SSH username: vagrant
    centralRouter: SSH auth method: private key
    centralRouter: Warning: Connection reset. Retrying...
    centralRouter: Warning: Remote connection disconnect. Retrying...
    centralRouter: 
    centralRouter: Vagrant insecure key detected. Vagrant will automatically replace
    centralRouter: this with a newly generated keypair for better security.
    centralRouter: 
    centralRouter: Inserting generated public key within guest...
    centralRouter: Removing insecure key from the guest if it's present...
    centralRouter: Key inserted! Disconnecting and reconnecting using new SSH key...
==> centralRouter: Machine booted and ready!
==> centralRouter: Checking for guest additions in VM...
    centralRouter: The guest additions on this VM do not match the installed version of
    centralRouter: VirtualBox! In most cases this is fine, but in rare cases it can
    centralRouter: prevent things such as shared folders from working properly. If you see
    centralRouter: shared folder errors, please make sure the guest additions within the
    centralRouter: virtual machine match the version of VirtualBox you have installed on
    centralRouter: your host and reload your VM.
    centralRouter: 
    centralRouter: Guest Additions Version: 7.2.4
    centralRouter: VirtualBox Version: 7.1
==> centralRouter: Setting hostname...
==> centralRouter: Configuring and enabling network interfaces...
==> centralRouter: Mounting shared folders...
    centralRouter: /home/admin_insta11/network_lab => /vagrant
==> centralRouter: Running provisioner: shell...
    centralRouter: Running: inline script
==> centralServer: Importing base box 'ubuntu-22.04-virtualbox'...
==> centralServer: Matching MAC address for NAT networking...
==> centralServer: Setting the name of the VM: network_lab_centralServer_1792939117994_48971
==> centralServer: Fixed port collision for 22 => 2222. Now on port 2201.
==> centralServer: Clearing any previously set network interfaces...
==> centralServer: Preparing network interfaces based on configuration...
    centralServer: Adapter 1: nat
    centralServer: Adapter 2: intnet
    centralServer: Adapter 8: hostonly
==> centralServer: Forwarding ports...
    centralServer: 22 (guest) => 2201 (host) (adapter 1)
==> centralServer: Running 'pre-boot' VM customizations...
==> centralServer: Booting VM...
==> centralServer: Waiting for machine to boot. This may take a few minutes...
    centralServer: SSH address: 127.0.0.1:2201
    centralServer: SSH username: vagrant
    centralServer: SSH auth method: private key
    centralServer: Warning: Connection reset. Retrying...
    centralServer: Warning: Remote connection disconnect. Retrying...
    centralServer: 
    centralServer: Vagrant insecure key detected. Vagrant will automatically replace
    centralServer: this with a newly generated keypair for better security.
    centralServer: 
    centralServer: Inserting generated public key within guest...
    centralServer: Removing insecure key from the guest if it's present...
    centralServer: Key inserted! Disconnecting and reconnecting using new SSH key...
==> centralServer: Machine booted and ready!
==> centralServer: Checking for guest additions in VM...
    centralServer: The guest additions on this VM do not match the installed version of
    centralServer: VirtualBox! In most cases this is fine, but in rare cases it can
    centralServer: prevent things such as shared folders from working properly. If you see
    centralServer: shared folder errors, please make sure the guest additions within the
    centralServer: virtual machine match the version of VirtualBox you have installed on
    centralServer: your host and reload your VM.
    centralServer: 
    centralServer: Guest Additions Version: 7.2.4
    centralServer: VirtualBox Version: 7.1
==> centralServer: Setting hostname...
==> centralServer: Configuring and enabling network interfaces...
==> centralServer: Mounting shared folders...
    centralServer: /home/admin_insta11/network_lab => /vagrant
==> centralServer: Running provisioner: shell...
    centralServer: Running: inline script
==> office1Router: You assigned a static IP ending in ".1" or ":1" to this machine.
==> office1Router: This is very often used by the router and can cause the
==> office1Router: network to not work properly. If the network doesn't work
==> office1Router: properly, try changing this IP.
==> office1Router: Importing base box 'ubuntu-22.04-virtualbox'...
==> office1Router: Matching MAC address for NAT networking...
==> office1Router: You assigned a static IP ending in ".1" or ":1" to this machine.
==> office1Router: This is very often used by the router and can cause the
==> office1Router: network to not work properly. If the network doesn't work
==> office1Router: properly, try changing this IP.
==> office1Router: Setting the name of the VM: network_lab_office1Router_1792939216631_22800
==> office1Router: Fixed port collision for 22 => 2222. Now on port 2202.
==> office1Router: Clearing any previously set network interfaces...
==> office1Router: Preparing network interfaces based on configuration...
    office1Router: Adapter 1: nat
    office1Router: Adapter 2: intnet
    office1Router: Adapter 3: intnet
    office1Router: Adapter 4: intnet
    office1Router: Adapter 5: intnet
    office1Router: Adapter 6: intnet
    office1Router: Adapter 8: hostonly
==> office1Router: Forwarding ports...
    office1Router: 22 (guest) => 2202 (host) (adapter 1)
==> office1Router: Running 'pre-boot' VM customizations...
==> office1Router: Booting VM...
==> office1Router: Waiting for machine to boot. This may take a few minutes...
    office1Router: SSH address: 127.0.0.1:2202
    office1Router: SSH username: vagrant
    office1Router: SSH auth method: private key
    office1Router: Warning: Connection reset. Retrying...
    office1Router: Warning: Remote connection disconnect. Retrying...
    office1Router: 
    office1Router: Vagrant insecure key detected. Vagrant will automatically replace
    office1Router: this with a newly generated keypair for better security.
    office1Router: 
    office1Router: Inserting generated public key within guest...
    office1Router: Removing insecure key from the guest if it's present...
    office1Router: Key inserted! Disconnecting and reconnecting using new SSH key...
==> office1Router: Machine booted and ready!
==> office1Router: Checking for guest additions in VM...
    office1Router: The guest additions on this VM do not match the installed version of
    office1Router: VirtualBox! In most cases this is fine, but in rare cases it can
    office1Router: prevent things such as shared folders from working properly. If you see
    office1Router: shared folder errors, please make sure the guest additions within the
    office1Router: virtual machine match the version of VirtualBox you have installed on
    office1Router: your host and reload your VM.
    office1Router: 
    office1Router: Guest Additions Version: 7.2.4
    office1Router: VirtualBox Version: 7.1
==> office1Router: Setting hostname...
==> office1Router: Configuring and enabling network interfaces...
==> office1Router: Mounting shared folders...
    office1Router: /home/admin_insta11/network_lab => /vagrant
==> office1Router: Running provisioner: shell...
    office1Router: Running: inline script
==> office1Server: Importing base box 'ubuntu-22.04-virtualbox'...
==> office1Server: Matching MAC address for NAT networking...
==> office1Server: Setting the name of the VM: network_lab_office1Server_1792939319784_75387
==> office1Server: Fixed port collision for 22 => 2222. Now on port 2203.
==> office1Server: Clearing any previously set network interfaces...
==> office1Server: Preparing network interfaces based on configuration...
    office1Server: Adapter 1: nat
    office1Server: Adapter 2: intnet
    office1Server: Adapter 8: hostonly
==> office1Server: Forwarding ports...
    office1Server: 22 (guest) => 2203 (host) (adapter 1)
==> office1Server: Running 'pre-boot' VM customizations...
==> office1Server: Booting VM...
==> office1Server: Waiting for machine to boot. This may take a few minutes...
    office1Server: SSH address: 127.0.0.1:2203
    office1Server: SSH username: vagrant
    office1Server: SSH auth method: private key
    office1Server: Warning: Connection reset. Retrying...
    office1Server: Warning: Remote connection disconnect. Retrying...
    office1Server: 
    office1Server: Vagrant insecure key detected. Vagrant will automatically replace
    office1Server: this with a newly generated keypair for better security.
    office1Server: 
    office1Server: Inserting generated public key within guest...
    office1Server: Removing insecure key from the guest if it's present...
    office1Server: Key inserted! Disconnecting and reconnecting using new SSH key...
==> office1Server: Machine booted and ready!
==> office1Server: Checking for guest additions in VM...
    office1Server: The guest additions on this VM do not match the installed version of
    office1Server: VirtualBox! In most cases this is fine, but in rare cases it can
    office1Server: prevent things such as shared folders from working properly. If you see
    office1Server: shared folder errors, please make sure the guest additions within the
    office1Server: virtual machine match the version of VirtualBox you have installed on
    office1Server: your host and reload your VM.
    office1Server: 
    office1Server: Guest Additions Version: 7.2.4
    office1Server: VirtualBox Version: 7.1
==> office1Server: Setting hostname...
==> office1Server: Configuring and enabling network interfaces...
==> office1Server: Mounting shared folders...
    office1Server: /home/admin_insta11/network_lab => /vagrant
==> office1Server: Running provisioner: shell...
    office1Server: Running: inline script
==> office2Router: You assigned a static IP ending in ".1" or ":1" to this machine.
==> office2Router: This is very often used by the router and can cause the
==> office2Router: network to not work properly. If the network doesn't work
==> office2Router: properly, try changing this IP.
==> office2Router: Importing base box 'ubuntu-22.04-virtualbox'...
==> office2Router: Matching MAC address for NAT networking...
==> office2Router: You assigned a static IP ending in ".1" or ":1" to this machine.
==> office2Router: This is very often used by the router and can cause the
==> office2Router: network to not work properly. If the network doesn't work
==> office2Router: properly, try changing this IP.
==> office2Router: Setting the name of the VM: network_lab_office2Router_1792939421478_81242
==> office2Router: Fixed port collision for 22 => 2222. Now on port 2204.
==> office2Router: Clearing any previously set network interfaces...
==> office2Router: Preparing network interfaces based on configuration...
    office2Router: Adapter 1: nat
    office2Router: Adapter 2: intnet
    office2Router: Adapter 3: intnet
    office2Router: Adapter 4: intnet
    office2Router: Adapter 5: intnet
    office2Router: Adapter 8: hostonly
==> office2Router: Forwarding ports...
    office2Router: 22 (guest) => 2204 (host) (adapter 1)
==> office2Router: Running 'pre-boot' VM customizations...
==> office2Router: Booting VM...
==> office2Router: Waiting for machine to boot. This may take a few minutes...
    office2Router: SSH address: 127.0.0.1:2204
    office2Router: SSH username: vagrant
    office2Router: SSH auth method: private key
    office2Router: Warning: Connection reset. Retrying...
    office2Router: Warning: Remote connection disconnect. Retrying...
    office2Router: 
    office2Router: Vagrant insecure key detected. Vagrant will automatically replace
    office2Router: this with a newly generated keypair for better security.
    office2Router: 
    office2Router: Inserting generated public key within guest...
    office2Router: Removing insecure key from the guest if it's present...
    office2Router: Key inserted! Disconnecting and reconnecting using new SSH key...
==> office2Router: Machine booted and ready!
==> office2Router: Checking for guest additions in VM...
    office2Router: The guest additions on this VM do not match the installed version of
    office2Router: VirtualBox! In most cases this is fine, but in rare cases it can
    office2Router: prevent things such as shared folders from working properly. If you see
    office2Router: shared folder errors, please make sure the guest additions within the
    office2Router: virtual machine match the version of VirtualBox you have installed on
    office2Router: your host and reload your VM.
    office2Router: 
    office2Router: Guest Additions Version: 7.2.4
    office2Router: VirtualBox Version: 7.1
==> office2Router: Setting hostname...
==> office2Router: Configuring and enabling network interfaces...
==> office2Router: Mounting shared folders...
    office2Router: /home/admin_insta11/network_lab => /vagrant
==> office2Router: Running provisioner: shell...
    office2Router: Running: inline script
==> office2Server: Importing base box 'ubuntu-22.04-virtualbox'...
==> office2Server: Matching MAC address for NAT networking...
==> office2Server: Setting the name of the VM: network_lab_office2Server_1792939523107_93675
==> office2Server: Fixed port collision for 22 => 2222. Now on port 2205.
==> office2Server: Clearing any previously set network interfaces...
==> office2Server: Preparing network interfaces based on configuration...
    office2Server: Adapter 1: nat
    office2Server: Adapter 2: intnet
    office2Server: Adapter 8: hostonly
==> office2Server: Forwarding ports...
    office2Server: 22 (guest) => 2205 (host) (adapter 1)
==> office2Server: Running 'pre-boot' VM customizations...
==> office2Server: Booting VM...
==> office2Server: Waiting for machine to boot. This may take a few minutes...
    office2Server: SSH address: 127.0.0.1:2205
    office2Server: SSH username: vagrant
    office2Server: SSH auth method: private key
    office2Server: Warning: Connection reset. Retrying...
    office2Server: Warning: Remote connection disconnect. Retrying...
    office2Server: 
    office2Server: Vagrant insecure key detected. Vagrant will automatically replace
    office2Server: this with a newly generated keypair for better security.
    office2Server: 
    office2Server: Inserting generated public key within guest...
    office2Server: Removing insecure key from the guest if it's present...
    office2Server: Key inserted! Disconnecting and reconnecting using new SSH key...
==> office2Server: Machine booted and ready!
==> office2Server: Checking for guest additions in VM...
    office2Server: The guest additions on this VM do not match the installed version of
    office2Server: VirtualBox! In most cases this is fine, but in rare cases it can
    office2Server: prevent things such as shared folders from working properly. If you see
    office2Server: shared folder errors, please make sure the guest additions within the
    office2Server: virtual machine match the version of VirtualBox you have installed on
    office2Server: your host and reload your VM.
    office2Server: 
    office2Server: Guest Additions Version: 7.2.4
    office2Server: VirtualBox Version: 7.1
==> office2Server: Setting hostname...
==> office2Server: Configuring and enabling network interfaces...
==> office2Server: Mounting shared folders...
    office2Server: /home/admin_insta11/network_lab => /vagrant
==> office2Server: Running provisioner: shell...
    office2Server: Running: inline script
[admin_insta11@mv334 network_lab]$ 
[admin_insta11@mv334 network_lab]$ vagrant status
Current machine states:

inetRouter                running (virtualbox)
centralRouter             running (virtualbox)
centralServer             running (virtualbox)
office1Router             running (virtualbox)
office1Server             running (virtualbox)
office2Router             running (virtualbox)
office2Server             running (virtualbox)

This environment represents multiple VMs. The VMs are all listed
above with their current state. For more information about a specific
VM, run `vagrant status NAME`.
[admin_insta11@mv334 network_lab]$
```

Конфигурации интерфейсов и маршрутов сразу после создания ВМ следующие:

```
[admin_insta11@mv334 network_lab]$ vagrant ssh inetRouter
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-160-generic x86_64)

Use of this system is acceptance of the OS vendor EULA and License Agreements.
vagrant@inetRouter:~$ ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:16:dd:ef brd ff:ff:ff:ff:ff:ff
    altname enp0s3
    inet 10.0.2.15/24 metric 100 brd 10.0.2.255 scope global dynamic eth0
       valid_lft 84736sec preferred_lft 84736sec
    inet6 fd17:625c:f037:2:a00:27ff:fe16:ddef/64 scope global dynamic mngtmpaddr noprefixroute 
       valid_lft 86317sec preferred_lft 14317sec
    inet6 fe80::a00:27ff:fe16:ddef/64 scope link 
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:42:99:d0 brd ff:ff:ff:ff:ff:ff
    altname enp0s8
    inet 192.168.255.1/30 brd 192.168.255.3 scope global eth1
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fe42:99d0/64 scope link 
       valid_lft forever preferred_lft forever
4: eth2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:ed:81:c9 brd ff:ff:ff:ff:ff:ff
    altname enp0s19
    inet 192.168.50.10/24 brd 192.168.50.255 scope global eth2
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:feed:81c9/64 scope link 
       valid_lft forever preferred_lft forever
vagrant@inetRouter:~$ ping 8.8.8.8
PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.
64 bytes from 8.8.8.8: icmp_seq=1 ttl=255 time=88.3 ms
64 bytes from 8.8.8.8: icmp_seq=2 ttl=255 time=89.7 ms
64 bytes from 8.8.8.8: icmp_seq=3 ttl=255 time=88.4 ms
^C
--- 8.8.8.8 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2002ms
rtt min/avg/max/mdev = 88.299/88.810/89.745/0.662 ms
vagrant@inetRouter:~$ ping ya.ru
PING ya.ru (77.88.55.242) 56(84) bytes of data.
64 bytes from ya.ru (77.88.55.242): icmp_seq=1 ttl=255 time=81.1 ms
64 bytes from ya.ru (77.88.55.242): icmp_seq=2 ttl=255 time=80.9 ms
64 bytes from ya.ru (77.88.55.242): icmp_seq=3 ttl=255 time=81.0 ms
64 bytes from ya.ru (77.88.55.242): icmp_seq=4 ttl=255 time=81.1 ms
^C
--- ya.ru ping statistics ---
5 packets transmitted, 4 received, 20% packet loss, time 4004ms
rtt min/avg/max/mdev = 80.918/81.037/81.148/0.081 ms
vagrant@inetRouter:~$ 
vagrant@inetRouter:~$ ip r
default via 10.0.2.2 dev eth0 proto dhcp src 10.0.2.15 metric 100 
10.0.2.0/24 dev eth0 proto kernel scope link src 10.0.2.15 metric 100 
10.0.2.2 dev eth0 proto dhcp scope link src 10.0.2.15 metric 100 
10.0.2.3 dev eth0 proto dhcp scope link src 10.0.2.15 metric 100 
192.168.50.0/24 dev eth2 proto kernel scope link src 192.168.50.10 
192.168.255.0/30 dev eth1 proto kernel scope link src 192.168.255.1 
vagrant@inetRouter:~$ ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:16:dd:ef brd ff:ff:ff:ff:ff:ff
    altname enp0s3
    inet 10.0.2.15/24 metric 100 brd 10.0.2.255 scope global dynamic eth0
       valid_lft 84546sec preferred_lft 84546sec
    inet6 fd17:625c:f037:2:a00:27ff:fe16:ddef/64 scope global dynamic mngtmpaddr noprefixroute 
       valid_lft 86126sec preferred_lft 14126sec
    inet6 fe80::a00:27ff:fe16:ddef/64 scope link 
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:42:99:d0 brd ff:ff:ff:ff:ff:ff
    altname enp0s8
    inet 192.168.255.1/30 brd 192.168.255.3 scope global eth1
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fe42:99d0/64 scope link 
       valid_lft forever preferred_lft forever
4: eth2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:ed:81:c9 brd ff:ff:ff:ff:ff:ff
    altname enp0s19
    inet 192.168.50.10/24 brd 192.168.50.255 scope global eth2
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:feed:81c9/64 scope link 
       valid_lft forever preferred_lft forever
vagrant@inetRouter:~$ ping 192.168.255.2
PING 192.168.255.2 (192.168.255.2) 56(84) bytes of data.
64 bytes from 192.168.255.2: icmp_seq=1 ttl=64 time=1.53 ms
64 bytes from 192.168.255.2: icmp_seq=2 ttl=64 time=0.989 ms
64 bytes from 192.168.255.2: icmp_seq=3 ttl=64 time=1.01 ms
64 bytes from 192.168.255.2: icmp_seq=4 ttl=64 time=1.01 ms
64 bytes from 192.168.255.2: icmp_seq=5 ttl=64 time=1.04 ms
64 bytes from 192.168.255.2: icmp_seq=6 ttl=64 time=1.02 ms
^C
--- 192.168.255.2 ping statistics ---
6 packets transmitted, 6 received, 0% packet loss, time 5008ms
rtt min/avg/max/mdev = 0.989/1.099/1.529/0.192 ms
vagrant@inetRouter:~$ exit
logout
[admin_insta11@mv334 network_lab]$ vagrant ssh centralRouter
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-160-generic x86_64)

Use of this system is acceptance of the OS vendor EULA and License Agreements.
vagrant@centralRouter:~$ ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:16:dd:ef brd ff:ff:ff:ff:ff:ff
    altname enp0s3
    inet 10.0.2.15/24 metric 100 brd 10.0.2.255 scope global dynamic eth0
       valid_lft 84428sec preferred_lft 84428sec
    inet6 fd17:625c:f037:2:a00:27ff:fe16:ddef/64 scope global dynamic mngtmpaddr noprefixroute 
       valid_lft 86276sec preferred_lft 14276sec
    inet6 fe80::a00:27ff:fe16:ddef/64 scope link 
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:72:f1:5d brd ff:ff:ff:ff:ff:ff
    altname enp0s8
    inet 192.168.255.2/30 brd 192.168.255.3 scope global eth1
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fe72:f15d/64 scope link 
       valid_lft forever preferred_lft forever
4: eth2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:5b:00:d5 brd ff:ff:ff:ff:ff:ff
    altname enp0s9
    inet 192.168.0.1/28 brd 192.168.0.15 scope global eth2
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fe5b:d5/64 scope link 
       valid_lft forever preferred_lft forever
5: eth3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:c6:50:30 brd ff:ff:ff:ff:ff:ff
    altname enp0s10
    inet 192.168.0.33/28 brd 192.168.0.47 scope global eth3
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fec6:5030/64 scope link 
       valid_lft forever preferred_lft forever
6: eth4: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:ad:91:67 brd ff:ff:ff:ff:ff:ff
    altname enp0s16
    inet 192.168.0.65/26 brd 192.168.0.127 scope global eth4
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fead:9167/64 scope link 
       valid_lft forever preferred_lft forever
7: eth5: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:5a:36:65 brd ff:ff:ff:ff:ff:ff
    altname enp0s17
    inet 192.168.255.9/30 brd 192.168.255.11 scope global eth5
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fe5a:3665/64 scope link 
       valid_lft forever preferred_lft forever
8: eth6: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:f2:87:80 brd ff:ff:ff:ff:ff:ff
    altname enp0s18
    inet 192.168.255.5/30 brd 192.168.255.7 scope global eth6
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fef2:8780/64 scope link 
       valid_lft forever preferred_lft forever
9: eth7: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:a4:40:95 brd ff:ff:ff:ff:ff:ff
    altname enp0s19
    inet 192.168.50.11/24 brd 192.168.50.255 scope global eth7
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fea4:4095/64 scope link 
       valid_lft forever preferred_lft forever
vagrant@centralRouter:~$ 
vagrant@centralRouter:~$ ip r
default via 10.0.2.2 dev eth0 proto dhcp src 10.0.2.15 metric 100 
10.0.2.0/24 dev eth0 proto kernel scope link src 10.0.2.15 metric 100 
10.0.2.2 dev eth0 proto dhcp scope link src 10.0.2.15 metric 100 
10.0.2.3 dev eth0 proto dhcp scope link src 10.0.2.15 metric 100 
192.168.0.0/28 dev eth2 proto kernel scope link src 192.168.0.1 
192.168.0.32/28 dev eth3 proto kernel scope link src 192.168.0.33 
192.168.0.64/26 dev eth4 proto kernel scope link src 192.168.0.65 
192.168.50.0/24 dev eth7 proto kernel scope link src 192.168.50.11 
192.168.255.0/30 dev eth1 proto kernel scope link src 192.168.255.2 
192.168.255.4/30 dev eth6 proto kernel scope link src 192.168.255.5 
192.168.255.8/30 dev eth5 proto kernel scope link src 192.168.255.9 
vagrant@centralRouter:~$ 
vagrant@centralRouter:~$ ip r -n
Command "-n" is unknown, try "ip route help".
vagrant@centralRouter:~$ exit
logout
[admin_insta11@mv334 network_lab]$ vagrant ssh office1Router
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-160-generic x86_64)

Use of this system is acceptance of the OS vendor EULA and License Agreements.
vagrant@office1Router:~$ ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:16:dd:ef brd ff:ff:ff:ff:ff:ff
    altname enp0s3
    inet 10.0.2.15/24 metric 100 brd 10.0.2.255 scope global dynamic eth0
       valid_lft 84251sec preferred_lft 84251sec
    inet6 fd17:625c:f037:2:a00:27ff:fe16:ddef/64 scope global dynamic mngtmpaddr noprefixroute 
       valid_lft 86368sec preferred_lft 14368sec
    inet6 fe80::a00:27ff:fe16:ddef/64 scope link 
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:6b:fd:7c brd ff:ff:ff:ff:ff:ff
    altname enp0s8
    inet 192.168.255.10/30 brd 192.168.255.11 scope global eth1
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fe6b:fd7c/64 scope link 
       valid_lft forever preferred_lft forever
4: eth2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:e0:4d:e4 brd ff:ff:ff:ff:ff:ff
    altname enp0s9
    inet 192.168.2.1/26 brd 192.168.2.63 scope global eth2
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fee0:4de4/64 scope link 
       valid_lft forever preferred_lft forever
5: eth3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:78:c5:f6 brd ff:ff:ff:ff:ff:ff
    altname enp0s10
    inet 192.168.2.65/26 brd 192.168.2.127 scope global eth3
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fe78:c5f6/64 scope link 
       valid_lft forever preferred_lft forever
6: eth4: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:c9:2e:be brd ff:ff:ff:ff:ff:ff
    altname enp0s16
    inet 192.168.2.129/26 brd 192.168.2.191 scope global eth4
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fec9:2ebe/64 scope link 
       valid_lft forever preferred_lft forever
7: eth5: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:c9:42:79 brd ff:ff:ff:ff:ff:ff
    altname enp0s17
    inet 192.168.2.193/26 brd 192.168.2.255 scope global eth5
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fec9:4279/64 scope link 
       valid_lft forever preferred_lft forever
8: eth6: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:c1:8a:a5 brd ff:ff:ff:ff:ff:ff
    altname enp0s19
    inet 192.168.50.20/24 brd 192.168.50.255 scope global eth6
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fec1:8aa5/64 scope link 
       valid_lft forever preferred_lft forever
vagrant@office1Router:~$ 
vagrant@office1Router:~$ route
-bash: route: command not found
vagrant@office1Router:~$ ip r
default via 10.0.2.2 dev eth0 proto dhcp src 10.0.2.15 metric 100 
10.0.2.0/24 dev eth0 proto kernel scope link src 10.0.2.15 metric 100 
10.0.2.2 dev eth0 proto dhcp scope link src 10.0.2.15 metric 100 
10.0.2.3 dev eth0 proto dhcp scope link src 10.0.2.15 metric 100 
192.168.2.0/26 dev eth2 proto kernel scope link src 192.168.2.1 
192.168.2.64/26 dev eth3 proto kernel scope link src 192.168.2.65 
192.168.2.128/26 dev eth4 proto kernel scope link src 192.168.2.129 
192.168.2.192/26 dev eth5 proto kernel scope link src 192.168.2.193 
192.168.50.0/24 dev eth6 proto kernel scope link src 192.168.50.20 
192.168.255.8/30 dev eth1 proto kernel scope link src 192.168.255.10 
vagrant@office1Router:~$ 
vagrant@office1Router:~$ exit
logout
[admin_insta11@mv334 network_lab]$ vagrant ssh office1Server
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-160-generic x86_64)

Use of this system is acceptance of the OS vendor EULA and License Agreements.
vagrant@office1Server:~$ ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:16:dd:ef brd ff:ff:ff:ff:ff:ff
    altname enp0s3
    inet 10.0.2.15/24 metric 100 brd 10.0.2.255 scope global dynamic eth0
       valid_lft 84165sec preferred_lft 84165sec
    inet6 fd17:625c:f037:2:a00:27ff:fe16:ddef/64 scope global dynamic mngtmpaddr noprefixroute 
       valid_lft 86087sec preferred_lft 14087sec
    inet6 fe80::a00:27ff:fe16:ddef/64 scope link 
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:56:cd:45 brd ff:ff:ff:ff:ff:ff
    altname enp0s8
    inet 192.168.2.130/26 brd 192.168.2.191 scope global eth1
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fe56:cd45/64 scope link 
       valid_lft forever preferred_lft forever
4: eth2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:b7:36:71 brd ff:ff:ff:ff:ff:ff
    altname enp0s19
    inet 192.168.50.21/24 brd 192.168.50.255 scope global eth2
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:feb7:3671/64 scope link 
       valid_lft forever preferred_lft forever
vagrant@office1Server:~$ 
vagrant@office1Server:~$ ip r
default via 10.0.2.2 dev eth0 proto dhcp src 10.0.2.15 metric 100 
10.0.2.0/24 dev eth0 proto kernel scope link src 10.0.2.15 metric 100 
10.0.2.2 dev eth0 proto dhcp scope link src 10.0.2.15 metric 100 
10.0.2.3 dev eth0 proto dhcp scope link src 10.0.2.15 metric 100 
192.168.2.128/26 dev eth1 proto kernel scope link src 192.168.2.130 
192.168.50.0/24 dev eth2 proto kernel scope link src 192.168.50.21 
vagrant@office1Server:~$ 
vagrant@office1Server:~$ exit
logout
[admin_insta11@mv334 network_lab]$ 
[admin_insta11@mv334 network_lab]$ vagrant ssh office2Router
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-160-generic x86_64)

Use of this system is acceptance of the OS vendor EULA and License Agreements.
vagrant@office2Router:~$ 
vagrant@office2Router:~$ ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:16:dd:ef brd ff:ff:ff:ff:ff:ff
    altname enp0s3
    inet 10.0.2.15/24 metric 100 brd 10.0.2.255 scope global dynamic eth0
       valid_lft 84190sec preferred_lft 84190sec
    inet6 fd17:625c:f037:2:a00:27ff:fe16:ddef/64 scope global dynamic mngtmpaddr noprefixroute 
       valid_lft 86135sec preferred_lft 14135sec
    inet6 fe80::a00:27ff:fe16:ddef/64 scope link 
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:49:05:f3 brd ff:ff:ff:ff:ff:ff
    altname enp0s8
    inet 192.168.255.6/30 brd 192.168.255.7 scope global eth1
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fe49:5f3/64 scope link 
       valid_lft forever preferred_lft forever
4: eth2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:89:57:e9 brd ff:ff:ff:ff:ff:ff
    altname enp0s9
    inet 192.168.1.1/25 brd 192.168.1.127 scope global eth2
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fe89:57e9/64 scope link 
       valid_lft forever preferred_lft forever
5: eth3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:16:42:09 brd ff:ff:ff:ff:ff:ff
    altname enp0s10
    inet 192.168.1.129/26 brd 192.168.1.191 scope global eth3
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fe16:4209/64 scope link 
       valid_lft forever preferred_lft forever
6: eth4: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:2a:21:39 brd ff:ff:ff:ff:ff:ff
    altname enp0s16
    inet 192.168.1.193/26 brd 192.168.1.255 scope global eth4
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fe2a:2139/64 scope link 
       valid_lft forever preferred_lft forever
7: eth5: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:86:1b:45 brd ff:ff:ff:ff:ff:ff
    altname enp0s19
    inet 192.168.50.30/24 brd 192.168.50.255 scope global eth5
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fe86:1b45/64 scope link 
       valid_lft forever preferred_lft forever
vagrant@office2Router:~$ 
vagrant@office2Router:~$ ip r
default via 10.0.2.2 dev eth0 proto dhcp src 10.0.2.15 metric 100 
10.0.2.0/24 dev eth0 proto kernel scope link src 10.0.2.15 metric 100 
10.0.2.2 dev eth0 proto dhcp scope link src 10.0.2.15 metric 100 
10.0.2.3 dev eth0 proto dhcp scope link src 10.0.2.15 metric 100 
192.168.1.0/25 dev eth2 proto kernel scope link src 192.168.1.1 
192.168.1.128/26 dev eth3 proto kernel scope link src 192.168.1.129 
192.168.1.192/26 dev eth4 proto kernel scope link src 192.168.1.193 
192.168.50.0/24 dev eth5 proto kernel scope link src 192.168.50.30 
192.168.255.4/30 dev eth1 proto kernel scope link src 192.168.255.6 
vagrant@office2Router:~$ 
vagrant@office2Router:~$ exit
logout
[admin_insta11@mv334 network_lab]$ vagrant ssh office2Server
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-160-generic x86_64)

Use of this system is acceptance of the OS vendor EULA and License Agreements.
vagrant@office2Server:~$ 
vagrant@office2Server:~$ ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:16:dd:ef brd ff:ff:ff:ff:ff:ff
    altname enp0s3
    inet 10.0.2.15/24 metric 100 brd 10.0.2.255 scope global dynamic eth0
       valid_lft 84193sec preferred_lft 84193sec
    inet6 fd17:625c:f037:2:a00:27ff:fe16:ddef/64 scope global dynamic mngtmpaddr noprefixroute 
       valid_lft 86079sec preferred_lft 14079sec
    inet6 fe80::a00:27ff:fe16:ddef/64 scope link 
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:24:c7:91 brd ff:ff:ff:ff:ff:ff
    altname enp0s8
    inet 192.168.1.2/25 brd 192.168.1.127 scope global eth1
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fe24:c791/64 scope link 
       valid_lft forever preferred_lft forever
4: eth2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:62:8c:cc brd ff:ff:ff:ff:ff:ff
    altname enp0s19
    inet 192.168.50.31/24 brd 192.168.50.255 scope global eth2
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fe62:8ccc/64 scope link 
       valid_lft forever preferred_lft forever
vagrant@office2Server:~$ 
vagrant@office2Server:~$ ip r
default via 10.0.2.2 dev eth0 proto dhcp src 10.0.2.15 metric 100 
10.0.2.0/24 dev eth0 proto kernel scope link src 10.0.2.15 metric 100 
10.0.2.2 dev eth0 proto dhcp scope link src 10.0.2.15 metric 100 
10.0.2.3 dev eth0 proto dhcp scope link src 10.0.2.15 metric 100 
192.168.1.0/25 dev eth1 proto kernel scope link src 192.168.1.2 
192.168.50.0/24 dev eth2 proto kernel scope link src 192.168.50.31 
vagrant@office2Server:~$ 
vagrant@office2Server:~$ exit
logout
[admin_insta11@mv334 network_lab]$ 
[admin_insta11@mv334 network_lab]$ vagrant ssh centralServer
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-160-generic x86_64)

Use of this system is acceptance of the OS vendor EULA and License Agreements.
vagrant@centralServer:~$ 
vagrant@centralServer:~$ ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:16:dd:ef brd ff:ff:ff:ff:ff:ff
    altname enp0s3
    inet 10.0.2.15/24 metric 100 brd 10.0.2.255 scope global dynamic eth0
       valid_lft 83693sec preferred_lft 83693sec
    inet6 fd17:625c:f037:2:a00:27ff:fe16:ddef/64 scope global dynamic mngtmpaddr noprefixroute 
       valid_lft 86138sec preferred_lft 14138sec
    inet6 fe80::a00:27ff:fe16:ddef/64 scope link 
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:f2:3b:6a brd ff:ff:ff:ff:ff:ff
    altname enp0s8
    inet 192.168.0.2/28 brd 192.168.0.15 scope global eth1
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fef2:3b6a/64 scope link 
       valid_lft forever preferred_lft forever
4: eth2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:ff:ca:5d brd ff:ff:ff:ff:ff:ff
    altname enp0s19
    inet 192.168.50.12/24 brd 192.168.50.255 scope global eth2
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:feff:ca5d/64 scope link 
       valid_lft forever preferred_lft forever
vagrant@centralServer:~$ 
vagrant@centralServer:~$ ip r
default via 10.0.2.2 dev eth0 proto dhcp src 10.0.2.15 metric 100 
10.0.2.0/24 dev eth0 proto kernel scope link src 10.0.2.15 metric 100 
10.0.2.2 dev eth0 proto dhcp scope link src 10.0.2.15 metric 100 
10.0.2.3 dev eth0 proto dhcp scope link src 10.0.2.15 metric 100 
192.168.0.0/28 dev eth1 proto kernel scope link src 192.168.0.2 
192.168.50.0/24 dev eth2 proto kernel scope link src 192.168.50.12 
vagrant@centralServer:~$ 
vagrant@centralServer:~$ exit
logout
[admin_insta11@mv334 network_lab]$ 
```


## 1.2 Провизионинг ВМ средствами ansible

### 1.2.1 Доступ ansible на ВМ с использованием ключей и пользователя, созданного vagrant

При создании ВМ vagrant также создал себе в этих ВМ для доступа пользователя vagrant с необходимыми правами,
а также:

- настроил доступ по ключам для входа без пароля и для пользователя vagrant,
- настроил sudoers для выполнения пользователем vagrant всех команд через sudo с правами root без пароля. 

Настройки прав пользователя vagrant внутри ВМ:

```
admin_insta11@mv334 backups_lab]$ vagrant ssh backup
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-160-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

 System information as of Sat Oct 24 06:56:33 AM UTC 2026

  System load:           0.0
  Usage of /:            16.2% of 30.34GB
  Memory usage:          17%
  Swap usage:            0%
  Processes:             143
  Users logged in:       0
  IPv4 address for eth0: 10.0.2.15
  IPv6 address for eth0: fd17:625c:f037:2:a00:27ff:fe16:ddef


This system is built by the Bento project by Chef Software
More information can be found at https://github.com/chef/bento

Use of this system is acceptance of the OS vendor EULA and License Agreements.
Last login: Sat Oct 24 06:29:59 2026 from 192.168.56.1
vagrant@backup:~$ 
vagrant@backup:~$ sudo -i
root@backup:~# 
root@backup:~# cat /etc/passwd | grep vagrant
vagrant:x:1000:1000:vagrant:/home/vagrant:/bin/bash
root@backup:~# 
root@backup:~# cat /etc/group | grep vagrant
adm:x:4:syslog,vagrant
cdrom:x:24:vagrant
sudo:x:27:vagrant
dip:x:30:vagrant
plugdev:x:46:vagrant
lxd:x:110:vagrant
vagrant:x:1000:
root@backup:~# 
root@backup:~# cat /etc/sudoers
<...>

# User privilege specification
root	ALL=(ALL:ALL) ALL

# Members of the admin group may gain root privileges
%admin ALL=(ALL) ALL

# Allow members of group sudo to execute any command
%sudo	ALL=(ALL:ALL) ALL

# See sudoers(5) for more information on "@include" directives:

@includedir /etc/sudoers.d
root@backup:~# 
root@backup:~# ll /etc/sudoers.d
total 20
drwxr-xr-x  2 root root 4096 Oct 23  2025 ./
drwxr-xr-x 97 root root 4096 Oct 24 05:54 ../
-r--r-----  1 root root   31 Oct 23  2025 99_vagrant
-r--r-----  1 root root 1096 Aug  3  2022 README
-rw-r--r--  1 root root   31 Oct 23  2025 vagrant
root@backup:~# 
root@backup:~# cat /etc/sudoers.d/vagrant
vagrant ALL=(ALL) NOPASSWD:ALL
root@backup:~# cat /etc/sudoers.d/99_vagrant
vagrant ALL=(ALL) NOPASSWD:ALL
root@backup:~# 
```

Настройки доступа vagrant в ВМ (пример) можно получить командой:

```
[admin_insta11@mv334 backups_lab]$ vagrant ssh-config backup
Host backup
  HostName 127.0.0.1
  User vagrant
  Port 2222
  UserKnownHostsFile /dev/null
  StrictHostKeyChecking no
  PasswordAuthentication no
  IdentityFile /home/admin_insta11/backups_lab/.vagrant/machines/backup/virtualbox/private_key
  IdentitiesOnly yes
  LogLevel FATAL
  PubkeyAcceptedKeyTypes +ssh-rsa
  HostKeyAlgorithms +ssh-rsa
[admin_insta11@mv334 backups_lab]$
```

Для удобного формирования файла хостов inventory.ini для ansible используем следующий Shell script, который формирует файл inventory.ini автоматически на основе вывода команды 'vagrant ssh-config' :

```
[admin_insta11@mv334 network_lab]$ cat generate_inventory.sh 
#!/usr/bin/env bash

INVENTORY="inventory.ini"
> "$INVENTORY"

echo "[vagrant_boxes]" > "$INVENTORY"
echo "" >> "$INVENTORY"

# Объявляем ассоциативные массивы для хранения данных
declare -A HOSTS_PORT
declare -A HOSTS_NAME
declare -A HOSTS_KEY

current_host=""

# Читаем вывод vagrant ssh-config
while IFS= read -r line; do

    # Если встретили Host, запоминаем имя текущего хоста
    if [[ "$line" =~ ^Host[[:space:]]+([^[:space:]]+) ]]; then
        current_host="${BASH_REMATCH[1]}"
    fi

    # Если есть текущий хост, пытаемся собрать для него данные
    if [[ -n "$current_host" ]]; then
        # Собираем Port
        if [[ "$line" =~ ^[[:space:]]*Port[[:space:]]+([0-9]+) ]]; then
            HOSTS_PORT["$current_host"]="${BASH_REMATCH[1]}"
        fi

        # Собираем IdentityFile
        if [[ "$line" =~ ^[[:space:]]*IdentityFile[[:space:]]+\"?([^\"]+)\"? ]]; then
            HOSTS_KEY["$current_host"]="${BASH_REMATCH[1]}"
        fi

	        # Собираем HostName
        if [[ "$line" =~ ^[[:space:]]*HostName[[:space:]]+\"?([^\"]+)\"? ]]; then
            HOSTS_NAME["$current_host"]="${BASH_REMATCH[1]}"
        fi
    fi
done < <(vagrant ssh-config)

# ТЕПЕРЬ ВЫВОДИМ ВСЁ СРАЗУ
# Проходим по всем найденным хостам
for host in "${!HOSTS_PORT[@]}"; do
    port="${HOSTS_PORT[$host]}"
    key="${HOSTS_KEY[$host]}"
    name="${HOSTS_NAME[$host]}"
    
    # Проверка: есть ли и порт, и ключ
    if [[ -n "$port" && -n "$key" ]]; then
        clean_key="${key//\"/}"
        echo "$host ansible_host=$name ansible_port=$port ansible_private_key_file=$clean_key" >> "$INVENTORY"
        echo ">>> ЗАПИСАНО: $host (port=$port)"
    else
        echo "⚠️ Пропущен $host: нет полных данных (port='$port', key='$key', name='$name')"
    fi
done

# Добавляем переменные группы
echo "" >> "$INVENTORY"
echo "[vagrant_boxes:vars]" >> "$INVENTORY"
echo "ansible_user=vagrant" >> "$INVENTORY"
echo "ansible_python_interpreter=/usr/bin/python3" >> "$INVENTORY"
echo "host_key_checking=False" >> "$INVENTORY"

echo "✅ Готово! Содержимое inventory.ini:"
cat "$INVENTORY"
```

После создания ВМ с помощью 'vagrant up' запускаем однократно данный скрипт, который создаёт файл inventory.ini для использования ansible:

```
[admin_insta11@mv334 network_lab]$ ./generate_inventory.sh 
>>> ЗАПИСАНО: inetRouter (port=2222)
>>> ЗАПИСАНО: office1Router (port=2202)
>>> ЗАПИСАНО: office1Server (port=2203)
>>> ЗАПИСАНО: office2Router (port=2204)
>>> ЗАПИСАНО: office2Server (port=2205)
>>> ЗАПИСАНО: centralServer (port=2201)
>>> ЗАПИСАНО: centralRouter (port=2200)
✅ Готово! Содержимое inventory.ini:
[vagrant_boxes]

inetRouter ansible_host=127.0.0.1 ansible_port=2222 ansible_private_key_file=/home/admin_insta11/network_lab/.vagrant/machines/inetRouter/virtualbox/private_key
office1Router ansible_host=127.0.0.1 ansible_port=2202 ansible_private_key_file=/home/admin_insta11/network_lab/.vagrant/machines/office1Router/virtualbox/private_key
office1Server ansible_host=127.0.0.1 ansible_port=2203 ansible_private_key_file=/home/admin_insta11/network_lab/.vagrant/machines/office1Server/virtualbox/private_key
office2Router ansible_host=127.0.0.1 ansible_port=2204 ansible_private_key_file=/home/admin_insta11/network_lab/.vagrant/machines/office2Router/virtualbox/private_key
office2Server ansible_host=127.0.0.1 ansible_port=2205 ansible_private_key_file=/home/admin_insta11/network_lab/.vagrant/machines/office2Server/virtualbox/private_key
centralServer ansible_host=127.0.0.1 ansible_port=2201 ansible_private_key_file=/home/admin_insta11/network_lab/.vagrant/machines/centralServer/virtualbox/private_key
centralRouter ansible_host=127.0.0.1 ansible_port=2200 ansible_private_key_file=/home/admin_insta11/network_lab/.vagrant/machines/centralRouter/virtualbox/private_key

[vagrant_boxes:vars]
ansible_user=vagrant
ansible_python_interpreter=/usr/bin/python3
host_key_checking=False
[admin_insta11@mv334 network_lab]$
```

После этого в созданный для inventory.ini список хостов можно добавить дополнительные необходимые секции и параметры:

```
[admin_insta11@mv334 network_lab]$ #  Далее вручную добавляем в inventory.ini секцию со списком маршрутизаторов
[admin_insta11@mv334 network_lab]$ vi inventory.ini
[admin_insta11@mv334 network_lab]$ 
[admin_insta11@mv334 network_lab]$ cat inventory.ini
[vagrant_boxes]

inetRouter ansible_host=127.0.0.1 ansible_port=2222 ansible_private_key_file=/home/admin_insta11/network_lab/.vagrant/machines/inetRouter/virtualbox/private_key
office1Router ansible_host=127.0.0.1 ansible_port=2202 ansible_private_key_file=/home/admin_insta11/network_lab/.vagrant/machines/office1Router/virtualbox/private_key
office1Server ansible_host=127.0.0.1 ansible_port=2203 ansible_private_key_file=/home/admin_insta11/network_lab/.vagrant/machines/office1Server/virtualbox/private_key
office2Router ansible_host=127.0.0.1 ansible_port=2204 ansible_private_key_file=/home/admin_insta11/network_lab/.vagrant/machines/office2Router/virtualbox/private_key
office2Server ansible_host=127.0.0.1 ansible_port=2205 ansible_private_key_file=/home/admin_insta11/network_lab/.vagrant/machines/office2Server/virtualbox/private_key
centralServer ansible_host=127.0.0.1 ansible_port=2201 ansible_private_key_file=/home/admin_insta11/network_lab/.vagrant/machines/centralServer/virtualbox/private_key
centralRouter ansible_host=127.0.0.1 ansible_port=2200 ansible_private_key_file=/home/admin_insta11/network_lab/.vagrant/machines/centralRouter/virtualbox/private_key

[routers]
inetRouter
centralRouter
office1Router
office2Router

[vagrant_boxes:vars]
ansible_user=vagrant
ansible_python_interpreter=/usr/bin/python3
host_key_checking=False
[admin_insta11@mv334 network_lab]$
[admin_insta11@mv334 network_lab]$ cat ansible.cfg
[defaults]
inventory = ./inventory.ini
host_key_checking = False
```

После создания файла inventory.ini скриптом роверяем доступность всех созданных ВМ для управления с помощью ansible::

```
[admin_insta11@mv334 network_lab]$ ansible all -m ping
office2Router | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
office1Server | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
office1Router | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
office2Server | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
inetRouter | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
centralServer | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
centralRouter | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
[admin_insta11@mv334 network_lab]$
```

Таким образом, необходимый доступ для ansible через credentials, созданные vagrant, настроен.

### 1.2.2 Провизионинг ВМ backup средствами ansible

Общая структура проекта (vagrant + ansible) приведена ниже:

```
[admin_insta11@mv334 network_lab]$ 
[admin_insta11@mv334 network_lab]$ tree
.
├── ansible
│   ├── playbook.yml
│   └── templates
│       ├── 00-installer-config.yaml
│       ├── 50-vagrant_centralRouter.yaml
│       ├── 50-vagrant_centralServer.yaml
│       ├── 50-vagrant_inetRouter.yaml
│       ├── 50-vagrant_office1Router.yaml
│       ├── 50-vagrant_office1Server.yaml
│       ├── 50-vagrant_office2Router.yaml
│       ├── 50-vagrant_office2Server.yaml
│       └── iptables_rules.ipv4
├── ansible.cfg
├── generate_inventory.sh
├── inventory.ini
└── Vagrantfile

2 directories, 15 files
[admin_insta11@mv334 network_lab]$ 
```

Плейбук playbook.yml для выполнения всех необходимых задач приведён ниже:

```
---
- name: Task 1 - NAT on inetRouter
  hosts: vagrant_boxes
  become: true
  tasks:

    # ------------------------------------------------------------------------------------
    # ЭТАП 1: Отключаем cloud-init, чтобы он не конфликтовал с нашими сетевыми конфигами
    # ------------------------------------------------------------------------------------
    
    - name: Disable cloud-init network configuration
      copy:
        dest: /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
        content: |
          network: {config: disabled}
        owner: root
        group: root
        mode: '0644'
      tags:
        - cloud-init-disable
      register: ci_disable_result

    - name: Clean cloud-init network cache (автоматически убирает/очищает 50-cloud-init.yaml)
      command: cloud-init clean -c network
      changed_when: false
      tags:
        - cloud-init-disable
      when: ci_disable_result.changed or ci_disable_result is succeeded

    # ------------------------------------------------------------------
    #  На inetRouter настраиваем NAT и сервис systemctl для применения правил NAT на iptables
    # ------------------------------------------------------------------

    - name: Set up NAT on inetRouter
      template:
        src: "{{ item.src }}"
        dest: "{{ item.dest }}"
        owner: root
        group: root
        mode: "{{ item.mode }}"
      loop:
        - src: "iptables_rules.ipv4"
          dest: "/etc/iptables_rules.ipv4"
          mode: "0644"
      when: inventory_hostname == "inetRouter"

    # Для применения правил iptables на inetRouter при загрузке создаём отдельный сервис systemd, выполняющийся после загрузки сети  
    - name: Create systemd unit for applying NAT rules
      copy:
        content: |
          [Unit]
          Description=Apply iptables NAT rules
          After=network.target

          [Service]
          Type=oneshot
          ExecStart=/bin/sh -c "/sbin/iptables-restore < /etc/iptables_rules.ipv4"
          RemainAfterExit=yes

          [Install]
          WantedBy=multi-user.target
        dest: /etc/systemd/system/iptables-nat.service
        owner: root
        group: root
        mode: "0644"
      when: inventory_hostname == "inetRouter"

    - name: Enable and start iptables-nat service
      systemd:
        name: iptables-nat
        enabled: true
        state: started
        daemon_reload: true
      when: inventory_hostname == "inetRouter"


- name: Task 2 - IP forwarding on all routers
  hosts: vagrant_boxes
  become: true
  tasks:
    - name: set up forward packages across routers
      sysctl:
        name: net.ipv4.conf.all.forwarding
        value: '1'
        state: present
      when: "'routers' in group_names"


- name: Task 3 - Disable default route (на всех хостах кроме inetRouter)
  hosts: vagrant_boxes
  become: true
  tasks:
    - name: disable default route
      template:
        src: "00-installer-config.yaml"
        dest: "/etc/netplan/00-installer-config.yaml"
        owner: root
        group: root
        mode: "0644"
      when: inventory_hostname != "inetRouter"

    # netplan try интерактивен и будет висеть. Для автоматизации используем apply.
    - name: apply netplan config
      command: netplan apply
      when: inventory_hostname != "inetRouter"

# Для каждого из хостов по его имени применяем соответствующий ему файл /etc/netplan/50-vagrant.yaml
- name: Task 5 - Add static routes and reboot
  hosts: vagrant_boxes
  become: true
  tasks:
    - name: add default gateway and static routes for each host
      template:
        src: "50-vagrant_{{ inventory_hostname }}.yaml"
        dest: "/etc/netplan/50-vagrant.yaml"
        owner: root
        group: root
        mode: "0644"

    - name: restart all hosts
      reboot:
        reboot_timeout: 600

# После настройки сети устанавливаем пакет traceroute на все хосты
- name: Task 6 - Install traceroute
  hosts: vagrant_boxes
  become: true
  tasks:
    - name: Install traceroute
      apt:
        name: traceroute
        state: present

```


Ниже приведены файлы для копирования на хосты для конфигурации сетевых интерфейсов и статических маршрутов хостов с помощью /etc/netplan
в соответствии с планом сети и для конфигурирования правил iptables на inetRouter :

```
[admin_insta11@mv334 network_lab]$ cd ansible/templates/
[admin_insta11@mv334 templates]$ 
[admin_insta11@mv334 templates]$ cat 00-installer-config.yaml
# This is the network config written by 'subiquity'
network:
  ethernets:
    eth0:
      dhcp4: true
      dhcp4-overrides:
          use-routes: false
      dhcp6: false
  version: 2
[admin_insta11@mv334 templates]$ 
[admin_insta11@mv334 templates]$ cat 50-vagrant_inetRouter.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: true
    eth1:
      addresses:
        - 192.168.255.1/30
      routes:
        - to: 192.168.0.0/25
          via: 192.168.255.2
        - to: 192.168.1.0/24
          via: 192.168.255.2
        - to: 192.168.2.0/24
          via: 192.168.255.2
        - to: 192.168.255.4/30
          via: 192.168.255.2
        - to: 192.168.255.8/30
          via: 192.168.255.2
    eth2:
      addresses:
        - 192.168.50.10/24
[admin_insta11@mv334 templates]$ 
[admin_insta11@mv334 templates]$ cat 50-vagrant_centralRouter.yaml 
network:
  version: 2
  renderer: networkd
  ethernets:
    eth1:
      addresses:
        - 192.168.255.2/30
      routes:
        - to: 0.0.0.0/0
          via: 192.168.255.1
    eth2:
      addresses:
        - 192.168.0.1/28
    eth3:
      addresses:
        - 192.168.0.33/28
    eth4:
      addresses:
        - 192.168.0.65/26
    eth5:
      addresses:
        - 192.168.255.9/30
      routes:
        - to: 192.168.2.0/24
          via: 192.168.255.10
    eth6:
      addresses:
        - 192.168.255.5/30
      routes:
        - to: 192.168.1.0/28
          via: 192.168.255.6
    eth7:
      addresses:
        - 192.168.50.11/24
[admin_insta11@mv334 templates]$ 
[admin_insta11@mv334 templates]$ cat 50-vagrant_office1Router.yaml 
network:
  version: 2
  renderer: networkd
  ethernets:
    eth1:
      addresses:
        - 192.168.255.10/30
      routes:
        - to: 0.0.0.0/0
          via: 192.168.255.9
    eth2:
      addresses:
        - 192.168.2.1/26
    eth3:
      addresses:
        - 192.168.2.65/26
    eth4:
      addresses:
        - 192.168.2.129/26
    eth5:
      addresses:
        - 192.168.2.193/26
    eth6:
      addresses:
        - 192.168.50.20/24
[admin_insta11@mv334 templates]$ 
[admin_insta11@mv334 templates]$ cat 50-vagrant_office2Router.yaml 
network:
  version: 2
  renderer: networkd
  ethernets:
    eth1:
      addresses:
        - 192.168.255.6/30
      routes:
        - to: 0.0.0.0/0
          via: 192.168.255.5
    eth2:
      addresses:
        - 192.168.1.1/25
    eth3:
      addresses:
        - 192.168.1.129/26
    eth4:
      addresses:
        - 192.168.1.193/26
    eth5:
      addresses:
        - 192.168.50.30/24
[admin_insta11@mv334 templates]$ 
[admin_insta11@mv334 templates]$ cat 50-vagrant_centralServer.yaml 
network:
  version: 2
  renderer: networkd
  ethernets:
    eth1:
      addresses:
        - 192.168.0.2/28
      routes:
        - to: 0.0.0.0/0
          via: 192.168.0.1
[admin_insta11@mv334 templates]$ 
[admin_insta11@mv334 templates]$ cat 50-vagrant_office1Server.yaml 
network:
  version: 2
  renderer: networkd
  ethernets:
    eth1:
      addresses:
        - 192.168.2.130/26
      routes:
        - to: 0.0.0.0/0
          via: 192.168.2.129
    eth2:
      addresses:
        - 192.168.50.21/24
[admin_insta11@mv334 templates]$ 
[admin_insta11@mv334 templates]$ cat 50-vagrant_office2Server.yaml 
network:
  version: 2
  renderer: networkd
  ethernets:
    eth1:
      addresses:
        - 192.168.1.2/25
      routes:
        - to: 0.0.0.0/0
          via: 192.168.1.1
    eth2:
      addresses:
        - 192.168.50.31/24
[admin_insta11@mv334 templates]$ 
[admin_insta11@mv334 templates]$ cat iptables_rules.ipv4 
# Generated by iptables-save v1.8.7 on Sat Oct 14 16:14:36 2023
*filter
:INPUT ACCEPT [90:8713]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [54:7429]
-A INPUT -p icmp -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -p tcp -m state --state NEW -m tcp --dport 22 -j ACCEPT
COMMIT
# Completed on Sat Oct 14 16:14:36 2023
# Generated by iptables-save v1.8.7 on Sat Oct 14 16:14:36 2023
*nat
:PREROUTING ACCEPT [1:44]
:INPUT ACCEPT [1:44]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING ! -d 192.168.0.0/16 -o eth0 -j MASQUERADE
COMMIT
# Completed on Sat Oct 14 16:14:36 2023
[admin_insta11@mv334 templates]$ 
```

При выполнении плейбука все задачи выполняются для хостов сети:

```
[admin_insta11@mv334 network_lab]$ ansible-playbook -i inventory.ini ansible/playbook.yml

PLAY [Task 1 - NAT on inetRouter] ************************************************************************************************************************************************************

TASK [Gathering Facts] ***********************************************************************************************************************************************************************
ok: [office2Server]
ok: [inetRouter]
ok: [office2Router]
ok: [office1Server]
ok: [office1Router]
ok: [centralRouter]
ok: [centralServer]

TASK [Disable cloud-init network configuration] **********************************************************************************************************************************************
ok: [inetRouter]
ok: [office1Router]
ok: [office1Server]
ok: [office2Server]
ok: [office2Router]
ok: [centralRouter]
ok: [centralServer]

TASK [Clean cloud-init network cache (автоматически убирает/очищает 50-cloud-init.yaml)] *****************************************************************************************************
ok: [inetRouter]
ok: [office1Server]
ok: [office1Router]
ok: [office2Router]
ok: [office2Server]
ok: [centralServer]
ok: [centralRouter]

TASK [Set up NAT on inetRouter] **************************************************************************************************************************************************************
skipping: [office1Router] => (item={'src': 'iptables_rules.ipv4', 'dest': '/etc/iptables_rules.ipv4', 'mode': '0644'}) 
skipping: [office1Server] => (item={'src': 'iptables_rules.ipv4', 'dest': '/etc/iptables_rules.ipv4', 'mode': '0644'}) 
skipping: [office2Router] => (item={'src': 'iptables_rules.ipv4', 'dest': '/etc/iptables_rules.ipv4', 'mode': '0644'}) 
skipping: [office2Server] => (item={'src': 'iptables_rules.ipv4', 'dest': '/etc/iptables_rules.ipv4', 'mode': '0644'}) 
skipping: [centralServer] => (item={'src': 'iptables_rules.ipv4', 'dest': '/etc/iptables_rules.ipv4', 'mode': '0644'}) 
skipping: [centralRouter] => (item={'src': 'iptables_rules.ipv4', 'dest': '/etc/iptables_rules.ipv4', 'mode': '0644'}) 
ok: [inetRouter] => (item={'src': 'iptables_rules.ipv4', 'dest': '/etc/iptables_rules.ipv4', 'mode': '0644'})

TASK [Create systemd unit for applying NAT rules] ********************************************************************************************************************************************
skipping: [office1Router]
skipping: [office1Server]
skipping: [office2Router]
skipping: [office2Server]
skipping: [centralServer]
skipping: [centralRouter]
ok: [inetRouter]

TASK [Enable and start iptables-nat service] *************************************************************************************************************************************************
skipping: [office1Router]
skipping: [office1Server]
skipping: [office2Router]
skipping: [office2Server]
skipping: [centralServer]
skipping: [centralRouter]
ok: [inetRouter]

PLAY [Task 2 - IP forwarding on all routers] *************************************************************************************************************************************************

TASK [Gathering Facts] ***********************************************************************************************************************************************************************
ok: [inetRouter]
ok: [office1Server]
ok: [office2Server]
ok: [office1Router]
ok: [office2Router]
ok: [centralServer]
ok: [centralRouter]

TASK [set up forward packages across routers] ************************************************************************************************************************************************
skipping: [office1Server]
skipping: [office2Server]
skipping: [centralServer]
ok: [office2Router]
ok: [office1Router]
ok: [inetRouter]
ok: [centralRouter]

PLAY [Task 3 - Disable default route (except inetRouter)] ************************************************************************************************************************************

TASK [Gathering Facts] ***********************************************************************************************************************************************************************
ok: [inetRouter]
ok: [office1Server]
ok: [office2Server]
ok: [office1Router]
ok: [office2Router]
ok: [centralServer]
ok: [centralRouter]

TASK [disable default route] *****************************************************************************************************************************************************************
skipping: [inetRouter]
ok: [office2Router]
ok: [office1Server]
ok: [office1Router]
ok: [office2Server]
ok: [centralServer]
ok: [centralRouter]

TASK [apply netplan config] ******************************************************************************************************************************************************************
skipping: [inetRouter]
changed: [office1Server]
changed: [office1Router]
changed: [office2Server]
changed: [office2Router]
changed: [centralServer]
changed: [centralRouter]

PLAY [Task 5 - Add static routes and reboot] *************************************************************************************************************************************************

TASK [Gathering Facts] ***********************************************************************************************************************************************************************
ok: [office1Server]
ok: [inetRouter]
ok: [office2Server]
ok: [office2Router]
ok: [office1Router]
ok: [centralServer]
ok: [centralRouter]

TASK [add default gateway and static routes for each host] ***********************************************************************************************************************************
ok: [inetRouter]
ok: [office1Server]
ok: [office1Router]
ok: [office2Router]
ok: [office2Server]
ok: [centralServer]
ok: [centralRouter]

TASK [restart all hosts] *********************************************************************************************************************************************************************
changed: [office2Server]
changed: [inetRouter]
changed: [office2Router]
changed: [office1Server]
changed: [office1Router]
changed: [centralRouter]
changed: [centralServer]

PLAY [Task 6 - Install traceroute] ***********************************************************************************************************************************************************

TASK [Gathering Facts] ***********************************************************************************************************************************************************************
ok: [office1Server]
ok: [office2Router]
ok: [office1Router]
ok: [inetRouter]
ok: [centralServer]
ok: [office2Server]
ok: [centralRouter]

TASK [Install traceroute] ********************************************************************************************************************************************************************
ok: [inetRouter]
changed: [office2Router]
changed: [centralServer]
changed: [office2Server]
ok: [centralRouter]
changed: [office1Router]
changed: [office1Server]

PLAY RECAP ***********************************************************************************************************************************************************************************
centralRouter              : ok=13   changed=2    unreachable=0    failed=0    skipped=3    rescued=0    ignored=0   
centralServer              : ok=12   changed=3    unreachable=0    failed=0    skipped=4    rescued=0    ignored=0   
inetRouter                 : ok=14   changed=1    unreachable=0    failed=0    skipped=2    rescued=0    ignored=0   
office1Router              : ok=13   changed=3    unreachable=0    failed=0    skipped=3    rescued=0    ignored=0   
office1Server              : ok=12   changed=3    unreachable=0    failed=0    skipped=4    rescued=0    ignored=0   
office2Router              : ok=13   changed=3    unreachable=0    failed=0    skipped=3    rescued=0    ignored=0   
office2Server              : ok=12   changed=3    unreachable=0    failed=0    skipped=4    rescued=0    ignored=0   

[admin_insta11@mv334 network_lab]$
```

## Проверка связности сети и выхода в сеть интернет с хостов

После создания и провизионинга сети проверяем таблицы маршрутов на маршрутизаторах сети, а также связность между хостами сети и выход с хостов в Public internet с помощью утилит ping и traceroute:

```
[admin_insta11@mv334 network_lab]$ vagrant ssh centralRouter
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-160-generic x86_64)

Use of this system is acceptance of the OS vendor EULA and License Agreements.
Last login: Tue Oct 27 17:12:55 2026 from 10.0.2.2
vagrant@centralRouter:~$ 
vagrant@centralRouter:~$ ip route
default via 192.168.255.1 dev eth1 proto static 
10.0.2.0/24 dev eth0 proto kernel scope link src 10.0.2.15 metric 100 
10.0.2.3 dev eth0 proto dhcp scope link src 10.0.2.15 metric 100 
192.168.0.0/28 dev eth2 proto kernel scope link src 192.168.0.1 
192.168.0.32/28 dev eth3 proto kernel scope link src 192.168.0.33 
192.168.0.64/26 dev eth4 proto kernel scope link src 192.168.0.65 
192.168.1.0/28 via 192.168.255.6 dev eth6 proto static 
192.168.2.0/24 via 192.168.255.10 dev eth5 proto static 
192.168.50.0/24 dev eth7 proto kernel scope link src 192.168.50.11 
192.168.255.0/30 dev eth1 proto kernel scope link src 192.168.255.2 
192.168.255.4/30 dev eth6 proto kernel scope link src 192.168.255.5 
192.168.255.8/30 dev eth5 proto kernel scope link src 192.168.255.9 
vagrant@centralRouter:~$ 
vagrant@centralRouter:~$ exit
logout
[admin_insta11@mv334 network_lab]$ 
[admin_insta11@mv334 network_lab]$ vagrant ssh inetRouter
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-160-generic x86_64)

Use of this system is acceptance of the OS vendor EULA and License Agreements.
Last login: Tue Oct 27 17:12:14 2026 from 10.0.2.2
vagrant@inetRouter:~$ 
vagrant@inetRouter:~$ 
vagrant@inetRouter:~$ ip route
default via 10.0.2.2 dev eth0 proto dhcp src 10.0.2.15 metric 100 
10.0.2.0/24 dev eth0 proto kernel scope link src 10.0.2.15 metric 100 
10.0.2.2 dev eth0 proto dhcp scope link src 10.0.2.15 metric 100 
10.0.2.3 dev eth0 proto dhcp scope link src 10.0.2.15 metric 100 
192.168.0.0/25 via 192.168.255.2 dev eth1 proto static 
192.168.1.0/24 via 192.168.255.2 dev eth1 proto static 
192.168.2.0/24 via 192.168.255.2 dev eth1 proto static 
192.168.50.0/24 dev eth2 proto kernel scope link src 192.168.50.10 
192.168.255.0/30 dev eth1 proto kernel scope link src 192.168.255.1 
192.168.255.4/30 via 192.168.255.2 dev eth1 proto static 
192.168.255.8/30 via 192.168.255.2 dev eth1 proto static 
vagrant@inetRouter:~$ 
vagrant@inetRouter:~$ 
vagrant@inetRouter:~$ exit
logout
[admin_insta11@mv334 network_lab]$ 
[admin_insta11@mv334 network_lab]$ vagrant ssh office1Router
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-160-generic x86_64)

Use of this system is acceptance of the OS vendor EULA and License Agreements.
Last login: Tue Oct 27 17:12:14 2026 from 10.0.2.2
vagrant@office1Router:~$ 
vagrant@office1Router:~$ ip route
default via 192.168.255.9 dev eth1 proto static 
10.0.2.0/24 dev eth0 proto kernel scope link src 10.0.2.15 metric 100 
10.0.2.3 dev eth0 proto dhcp scope link src 10.0.2.15 metric 100 
192.168.2.0/26 dev eth2 proto kernel scope link src 192.168.2.1 
192.168.2.64/26 dev eth3 proto kernel scope link src 192.168.2.65 
192.168.2.128/26 dev eth4 proto kernel scope link src 192.168.2.129 
192.168.2.192/26 dev eth5 proto kernel scope link src 192.168.2.193 
192.168.50.0/24 dev eth6 proto kernel scope link src 192.168.50.20 
192.168.255.8/30 dev eth1 proto kernel scope link src 192.168.255.10 
vagrant@office1Router:~$ 
vagrant@office1Router:~$ exit
logout
[admin_insta11@mv334 network_lab]$ 
[admin_insta11@mv334 network_lab]$ vagrant ssh office2Router
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-160-generic x86_64)

Use of this system is acceptance of the OS vendor EULA and License Agreements.
Last login: Tue Oct 27 17:12:14 2026 from 10.0.2.2
vagrant@office2Router:~$ 
vagrant@office2Router:~$ ip route
default via 192.168.255.5 dev eth1 proto static 
10.0.2.0/24 dev eth0 proto kernel scope link src 10.0.2.15 metric 100 
10.0.2.3 dev eth0 proto dhcp scope link src 10.0.2.15 metric 100 
192.168.1.0/25 dev eth2 proto kernel scope link src 192.168.1.1 
192.168.1.128/26 dev eth3 proto kernel scope link src 192.168.1.129 
192.168.1.192/26 dev eth4 proto kernel scope link src 192.168.1.193 
192.168.50.0/24 dev eth5 proto kernel scope link src 192.168.50.30 
192.168.255.4/30 dev eth1 proto kernel scope link src 192.168.255.6 
vagrant@office2Router:~$ 
vagrant@office2Router:~$ exit
logout
[admin_insta11@mv334 network_lab]$ 



[admin_insta11@mv334 network_lab]$ vagrant ssh office1Server
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-160-generic x86_64)

Use of this system is acceptance of the OS vendor EULA and License Agreements.
Last login: Tue Oct 27 17:12:13 2026 from 10.0.2.2
vagrant@office1Server:~$ 
vagrant@office1Server:~$ 
vagrant@office1Server:~$ ping 8.8.8.8
PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.
64 bytes from 8.8.8.8: icmp_seq=1 ttl=252 time=91.5 ms
64 bytes from 8.8.8.8: icmp_seq=2 ttl=252 time=91.4 ms
64 bytes from 8.8.8.8: icmp_seq=3 ttl=252 time=91.2 ms
64 bytes from 8.8.8.8: icmp_seq=4 ttl=252 time=91.0 ms
^C
--- 8.8.8.8 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3005ms
rtt min/avg/max/mdev = 90.977/91.272/91.549/0.214 ms
vagrant@office1Server:~$ 
vagrant@office1Server:~$ ping ya.ru
PING ya.ru (77.88.55.242) 56(84) bytes of data.
64 bytes from ya.ru (77.88.55.242): icmp_seq=1 ttl=252 time=83.0 ms
64 bytes from ya.ru (77.88.55.242): icmp_seq=2 ttl=252 time=83.5 ms
64 bytes from ya.ru (77.88.55.242): icmp_seq=3 ttl=252 time=83.0 ms
64 bytes from ya.ru (77.88.55.242): icmp_seq=4 ttl=252 time=82.6 ms
64 bytes from ya.ru (77.88.55.242): icmp_seq=5 ttl=252 time=83.0 ms

--- ya.ru ping statistics ---
5 packets transmitted, 5 received, 0% packet loss, time 4006ms
rtt min/avg/max/mdev = 82.604/83.021/83.485/0.279 ms
vagrant@office1Server:~$ 
vagrant@office1Server:~$ traceroute 8.8.8.8
traceroute to 8.8.8.8 (8.8.8.8), 30 hops max, 60 byte packets
 1  _gateway (192.168.2.129)  1.075 ms  0.819 ms  0.801 ms
 2  192.168.255.9 (192.168.255.9)  1.845 ms  1.790 ms  1.674 ms
 3  192.168.255.1 (192.168.255.1)  2.539 ms  2.422 ms  2.368 ms
 4  10.0.2.2 (10.0.2.2)  2.442 ms  2.251 ms  2.183 ms
 5  172.17.15.1 (172.17.15.1)  2.872 ms  2.719 ms  2.868 ms
 6  192.168.10.14 (192.168.10.14)  2.814 ms  3.400 ms  3.362 ms
 7  192.168.200.7 (192.168.200.7)  68.757 ms  68.798 ms  68.720 ms
 8  192.168.200.6 (192.168.200.6)  68.495 ms  68.225 ms  68.149 ms
 9  192.168.1.3 (192.168.1.3)  69.205 ms  69.143 ms  69.687 ms
10  Moscow-GIN-PE11-ae4-2499.rosprint.net (195.151.21.1)  69.990 ms  69.441 ms  69.559 ms
11  Umbrella-PE01-ae1-0.rosprint.net (195.151.241.162)  71.430 ms  71.248 ms  73.023 ms
12  Moscow-GIN-IX01-ae3-0.rosprint.net (195.151.233.53)  72.570 ms  72.495 ms  74.723 ms
13  178.18.225.111.ix.dataix.eu (178.18.225.111)  97.402 ms  94.178 ms  96.805 ms
14  * 178.18.235.253 (178.18.235.253)  94.769 ms  96.813 ms
15  216.239.57.151 (216.239.57.151)  102.842 ms  96.163 ms 192.178.248.215 (192.178.248.215)  97.237 ms
16  209.85.242.83 (209.85.242.83)  97.995 ms 142.251.48.45 (142.251.48.45)  93.375 ms 172.253.72.123 (172.253.72.123)  102.188 ms
17  dns.google (8.8.8.8)  93.280 ms  171.059 ms  96.647 ms
vagrant@office1Server:~$ 
vagrant@office1Server:~$ ping 192.168.0.2
PING 192.168.0.2 (192.168.0.2) 56(84) bytes of data.
64 bytes from 192.168.0.2: icmp_seq=1 ttl=62 time=2.86 ms
64 bytes from 192.168.0.2: icmp_seq=2 ttl=62 time=2.71 ms
64 bytes from 192.168.0.2: icmp_seq=3 ttl=62 time=2.75 ms
64 bytes from 192.168.0.2: icmp_seq=4 ttl=62 time=2.80 ms
^C
--- 192.168.0.2 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3005ms
rtt min/avg/max/mdev = 2.706/2.779/2.858/0.056 ms
vagrant@office1Server:~$ traceroute 192.168.0.2
traceroute to 192.168.0.2 (192.168.0.2), 30 hops max, 60 byte packets
 1  _gateway (192.168.2.129)  0.990 ms  0.882 ms  0.818 ms
 2  192.168.255.9 (192.168.255.9)  2.181 ms  1.963 ms  1.893 ms
 3  192.168.0.2 (192.168.0.2)  2.253 ms  3.243 ms  3.186 ms
vagrant@office1Server:~$ 
vagrant@office1Server:~$ ping 192.168.1.2
PING 192.168.1.2 (192.168.1.2) 56(84) bytes of data.
64 bytes from 192.168.1.2: icmp_seq=1 ttl=61 time=4.03 ms
64 bytes from 192.168.1.2: icmp_seq=2 ttl=61 time=3.55 ms
64 bytes from 192.168.1.2: icmp_seq=3 ttl=61 time=3.83 ms
64 bytes from 192.168.1.2: icmp_seq=4 ttl=61 time=3.58 ms
64 bytes from 192.168.1.2: icmp_seq=5 ttl=61 time=3.75 ms
^C
--- 192.168.1.2 ping statistics ---
5 packets transmitted, 5 received, 0% packet loss, time 4008ms
rtt min/avg/max/mdev = 3.554/3.746/4.026/0.173 ms
vagrant@office1Server:~$ traceroute 192.168.1.2
traceroute to 192.168.1.2 (192.168.1.2), 30 hops max, 60 byte packets
 1  _gateway (192.168.2.129)  0.974 ms  0.885 ms  0.862 ms
 2  192.168.255.9 (192.168.255.9)  1.389 ms  1.330 ms  1.203 ms
 3  192.168.255.6 (192.168.255.6)  2.271 ms  2.205 ms  1.969 ms
 4  192.168.1.2 (192.168.1.2)  2.586 ms  2.769 ms  2.699 ms
vagrant@office1Server:~$ 
vagrant@office1Server:~$ exit
logout
[admin_insta11@mv334 network_lab]$ vagrant ssh centralServer
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-160-generic x86_64)

Use of this system is acceptance of the OS vendor EULA and License Agreements.
Last login: Tue Oct 27 17:12:24 2026 from 10.0.2.2
vagrant@centralServer:~$ 
vagrant@centralServer:~$ ping ya.ru
PING ya.ru (5.255.255.242) 56(84) bytes of data.
64 bytes from ya.ru (5.255.255.242): icmp_seq=1 ttl=253 time=73.8 ms
64 bytes from ya.ru (5.255.255.242): icmp_seq=2 ttl=253 time=73.5 ms
64 bytes from ya.ru (5.255.255.242): icmp_seq=3 ttl=253 time=73.8 ms
64 bytes from ya.ru (5.255.255.242): icmp_seq=4 ttl=253 time=73.7 ms
64 bytes from ya.ru (5.255.255.242): icmp_seq=5 ttl=253 time=73.8 ms
64 bytes from ya.ru (5.255.255.242): icmp_seq=6 ttl=253 time=73.2 ms
64 bytes from ya.ru (5.255.255.242): icmp_seq=7 ttl=253 time=73.6 ms
^C
--- ya.ru ping statistics ---
7 packets transmitted, 7 received, 0% packet loss, time 6008ms
rtt min/avg/max/mdev = 73.240/73.632/73.842/0.207 ms
vagrant@centralServer:~$ 
vagrant@centralServer:~$ traceroute ya.ru
traceroute to ya.ru (77.88.44.242), 30 hops max, 60 byte packets
 1  _gateway (192.168.0.1)  0.910 ms  0.822 ms  0.753 ms
 2  192.168.255.1 (192.168.255.1)  2.696 ms  2.634 ms  2.582 ms
 3  10.0.2.2 (10.0.2.2)  2.442 ms  2.232 ms  2.013 ms
 4  172.17.15.1 (172.17.15.1)  2.674 ms  2.630 ms  2.826 ms
 5  192.168.10.14 (192.168.10.14)  3.308 ms  3.264 ms  3.153 ms
 6  192.168.200.7 (192.168.200.7)  69.204 ms  69.052 ms  68.634 ms
 7  192.168.200.6 (192.168.200.6)  67.468 ms  67.800 ms  67.617 ms
 8  192.168.1.3 (192.168.1.3)  70.886 ms  70.341 ms  70.966 ms
 9  Moscow-GIN-PE11-ae4-2499.rosprint.net (195.151.21.1)  85.456 ms  70.229 ms  84.972 ms
10  Umbrella-PE01-ae1-0.rosprint.net (195.151.241.162)  71.656 ms  71.528 ms  71.462 ms
11  Moscow-GIN-IX01-ae3-0.rosprint.net (195.151.233.53)  73.677 ms  73.611 ms  71.505 ms
12  styri.yndx.net (195.208.208.116)  71.100 ms  70.994 ms  75.247 ms
13  * * *
^C
vagrant@centralServer:~$ 
vagrant@centralServer:~$ ping 192.168.2.130
PING 192.168.2.130 (192.168.2.130) 56(84) bytes of data.
64 bytes from 192.168.2.130: icmp_seq=1 ttl=62 time=3.16 ms
64 bytes from 192.168.2.130: icmp_seq=2 ttl=62 time=2.76 ms
64 bytes from 192.168.2.130: icmp_seq=3 ttl=62 time=2.83 ms
^C
--- 192.168.2.130 ping statistics ---
4 packets transmitted, 3 received, 25% packet loss, time 3004ms
rtt min/avg/max/mdev = 2.764/2.917/3.155/0.170 ms
vagrant@centralServer:~$ 
vagrant@centralServer:~$ traceroute 192.168.2.130
traceroute to 192.168.2.130 (192.168.2.130), 30 hops max, 60 byte packets
 1  _gateway (192.168.0.1)  0.792 ms  0.836 ms  0.558 ms
 2  192.168.255.10 (192.168.255.10)  1.522 ms  1.466 ms  1.348 ms
 3  192.168.2.130 (192.168.2.130)  2.320 ms  2.169 ms  1.986 ms
vagrant@centralServer:~$ 
vagrant@centralServer:~$ traceroute 192.168.1.2
traceroute to 192.168.1.2 (192.168.1.2), 30 hops max, 60 byte packets
 1  _gateway (192.168.0.1)  0.815 ms  0.713 ms  0.928 ms
 2  192.168.255.6 (192.168.255.6)  1.583 ms  1.367 ms  1.305 ms
 3  192.168.1.2 (192.168.1.2)  1.994 ms  1.931 ms  1.882 ms
vagrant@centralServer:~$ 

```

**Вывод:** лабораторная сеть создана, адресация и маршрутизация настроена, функционирование сети проверено. Связность между хостами и доступ в интернет с хостов сети работает.
