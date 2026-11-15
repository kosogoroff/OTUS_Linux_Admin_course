# Занятие 02.11.2026 "33. Статическая и динамическая маршрутизация, OSPF"

OSPF

## Цель:

- Создать домашнюю сетевую лабораторию;
  
- Научиться настраивать протокол OSPF в Linux-based системах.

## Описание/Пошаговая инструкция выполнения домашнего задания:

Для выполнения домашнего задания используйте методичку


## Что нужно сделать?

- Поднять три виртуалки
- Объединить их разными сетями

- поднять OSPF между машинами на базе frr ;
- изобразить ассиметричный роутинг;
- сделать один из линков "дорогим", но что бы при этом роутинг был симметричным.

Формат сдачи: Vagrantfile + ansible

# Решение

Ниже приведена схема лабораторной сети из методички:

<img width="705" height="565" alt="изображение" src="https://github.com/user-attachments/assets/ee80c10d-a6b5-4b96-8e9a-c772c0e84831" />



Таблица IP-адресации интерфейсов хостов:


| Server      | IP and netmask      | Interface       | Default route on the host    |
|:---------------------------------------|:---------------|:-------------------------|:------------------------|
| router1       | Default NAT address DHCP virtualbox    | eth0      | To 10.0.2.2 virtualbox router via eth0 |
|                | 10.0.10.1/30                          | eth1         |           |        
|                | 10.0.12.1/30                          | eth2         |           |        
|                | 192.168.10.1/24                       | eth3         |           |        
| router2       | Default NAT address DHCP virtualbox    | eth0      | Default route via OSPF |
|                | 10.0.10.2/30                          | eth1         |           |        
|                | 10.0.11.2/30                          | eth2         |           |        
|                | 192.168.20.1/24                       | eth3         |           |
| router3       | Default NAT address DHCP virtualbox    | eth0      | Default route via OSPF |
|                | 10.0.11.1/30                          | eth1         |           |        
|                | 10.0.12.2/30                          | eth2         |           |        
|                | 192.168.30.1/24                       | eth3         |           |

Vagrantfile для создания лабораторного стенда приведён ниже:

```
[admin_insta11@mv334 ospf_lab]$ cat Vagrantfile
BOX_NAME = ENV['VAGRANT_BOX'] || 'bento/ubuntu-22.04'

MACHINES = {
  :router1 => {
        :box_name => BOX_NAME,
        :vm_name => "router1",
        :net => [
                   {ip: '10.0.10.1', adapter: 2, netmask: "255.255.255.252", virtualbox__intnet: "r1-r2"},
                   {ip: '10.0.12.1', adapter: 3, netmask: "255.255.255.252", virtualbox__intnet: "r1-r3"},
                   {ip: '192.168.10.1', adapter: 4, netmask: "255.255.255.0", virtualbox__intnet: "net1"},
                   {ip: '192.168.50.10', adapter: 5},
                ]
  },

  :router2 => {
        :box_name => BOX_NAME,
        :vm_name => "router2",
        :net => [
                   {ip: '10.0.10.2', adapter: 2, netmask: "255.255.255.252", virtualbox__intnet: "r1-r2"},
                   {ip: '10.0.11.2', adapter: 3, netmask: "255.255.255.252", virtualbox__intnet: "r2-r3"},
                   {ip: '192.168.20.1', adapter: 4, netmask: "255.255.255.0", virtualbox__intnet: "net2"},
                   {ip: '192.168.50.11', adapter: 5},
                ]
  },

  :router3 => {
        :box_name => BOX_NAME,
        :vm_name => "router3",
        :net => [
                   {ip: '10.0.11.1', adapter: 2, netmask: "255.255.255.252", virtualbox__intnet: "r2-r3"},
                   {ip: '10.0.12.2', adapter: 3, netmask: "255.255.255.252", virtualbox__intnet: "r1-r3"},
                   {ip: '192.168.30.1', adapter: 4, netmask: "255.255.255.0", virtualbox__intnet: "net3"},
                   {ip: '192.168.50.12', adapter: 5},
                ]
  }

}

Vagrant.configure("2") do |config|

  MACHINES.each do |boxname, boxconfig|
    
    config.vm.define boxname do |box|
   
      box.vm.box = boxconfig[:box_name]
      box.vm.host_name = boxconfig[:vm_name]

      if boxconfig[:vm_name] == "router3"
       box.vm.provision "ansible" do |ansible|
        ansible.playbook = "ansible/playbook.yml"
        ansible.inventory_path = "ansible/hosts"
        ansible.host_key_checking = "false"
        ansible.limit = "all"
       end
      end

      boxconfig[:net].each do |ipconf|
        box.vm.network "private_network", **ipconf
      end

     end
  end
end
```

По сравнению с исходным Vagrantfile из методички в приведённом сделано несколько изменений:

1. Добавлена возможность в явном виде указывать название бокса Vagrant для создания виртуальных машин из командной строки - в том числе и из числа локально скачанных боксов Vagrant:

```
[admin_insta11@mv334 ospf_lab]$ vagrant box list
almalinux9-stand        (libvirt, 0)
almalinux9-stand-vb     (virtualbox, 0)
ubuntu-22.04-virtualbox (virtualbox, 0)
[admin_insta11@mv334 ospf_lab]$
```

2. Исправлена несовместимость синтаксиса RUBY 2 с новым синтаксисом RUBY 3, который используется в новых версиях vagrant 2.4.7.

В файле из методички было:

```
<...>
boxconfig[:net].each do |ipconf|
  box.vm.network "private_network", ipconf
end
<...>
```

Исправлено на:

```
<...>
boxconfig[:net].each do |ipconf|
  box.vm.network "private_network", **ipconf
end
<...>
```

##### Почему без ** ломалось

Без правки vagrant возникала ошибка:

```
/opt/vagrant/embedded/gems/gems/vagrant-2.4.7/plugins/kernel_v2/config/vm.rb:328:in `network': wrong number of arguments (given 2, expected 1) (ArgumentError)
```


В Ruby 3 локальную переменную с хэшем (ipconf) больше не преобразуют автоматически в keyword-аргументы, поэтому box.vm.network "private_network", ipconf воспринимается как два позиционных аргумента, а метод network ждёт один. Это классическая несовместимость старых Vagrantfile с новыми Ruby/Vagrant (у нас vagrant 2.4.7 с Ruby 3).
Раньше (Ruby 2.6 и старше) хэш, переданный последним аргументом, автоматически воспринимался как keyword-аргументы — можно было писать просто vm.network "private_network", ipconf, и это работало. Такой неявный «автоконвертер» породил кучу путаницы, поэтому в Ruby 3 его убрали: теперь хэш — это хэш, а keyword-аргументы — это keyword-аргументы, и для передачи хэша как набора именованных аргументов нужен явный **.

Исходный Vagrantfile для Ruby 2, а в составе Vagrant 2.4.7 стоит уже Ruby 3.x — отсюда и wrong number of arguments (given 2, expected 1): метод понял вызов как «два позиционных аргумента», а принимает только один плюс опции.

Двойной сплат ** разворачивает хэш в keyword-аргументы:

```
opts = { ip: "10.0.10.1", netmask: "255.255.255.252" }

# эти два вызова идентичны:
vm.network "private_network", ip: "10.0.10.1", netmask: "255.255.255.252"
vm.network "private_network", **opts
```

В документации Ruby есть официальный разбор, где расписаны все случаи «что раньше работало, а теперь нет»:  https://www.ruby-lang.org/en/news/2019/12/12/separation-of-positional-and-keyword-arguments-in-ruby-3-0/ 


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

При запуске vagrant создаются ВМ:

```
[admin_insta11@mv334 ospf_lab]$ VAGRANT_BOX=ubuntu-22.04-virtualbox vagrant up
Bringing machine 'router1' up with 'virtualbox' provider...
Bringing machine 'router2' up with 'virtualbox' provider...
Bringing machine 'router3' up with 'virtualbox' provider...
==> router1: You assigned a static IP ending in ".1" or ":1" to this machine.
==> router1: This is very often used by the router and can cause the
==> router1: network to not work properly. If the network doesn't work
==> router1: properly, try changing this IP.
==> router1: You assigned a static IP ending in ".1" or ":1" to this machine.
==> router1: This is very often used by the router and can cause the
==> router1: network to not work properly. If the network doesn't work
==> router1: properly, try changing this IP.
==> router1: You assigned a static IP ending in ".1" or ":1" to this machine.
==> router1: This is very often used by the router and can cause the
==> router1: network to not work properly. If the network doesn't work
==> router1: properly, try changing this IP.
==> router1: Importing base box 'ubuntu-22.04-virtualbox'...
==> router1: Matching MAC address for NAT networking...
==> router1: You assigned a static IP ending in ".1" or ":1" to this machine.
==> router1: This is very often used by the router and can cause the
==> router1: network to not work properly. If the network doesn't work
==> router1: properly, try changing this IP.
==> router1: You assigned a static IP ending in ".1" or ":1" to this machine.
==> router1: This is very often used by the router and can cause the
==> router1: network to not work properly. If the network doesn't work
==> router1: properly, try changing this IP.
==> router1: You assigned a static IP ending in ".1" or ":1" to this machine.
==> router1: This is very often used by the router and can cause the
==> router1: network to not work properly. If the network doesn't work
==> router1: properly, try changing this IP.
==> router1: Setting the name of the VM: ospf_lab_router1_1794661958935_82842
==> router1: Clearing any previously set network interfaces...
==> router1: Preparing network interfaces based on configuration...
    router1: Adapter 1: nat
    router1: Adapter 2: intnet
    router1: Adapter 3: intnet
    router1: Adapter 4: intnet
    router1: Adapter 5: hostonly
==> router1: Forwarding ports...
    router1: 22 (guest) => 2222 (host) (adapter 1)
==> router1: Booting VM...
==> router1: Waiting for machine to boot. This may take a few minutes...
    router1: SSH address: 127.0.0.1:2222
    router1: SSH username: vagrant
    router1: SSH auth method: private key
    router1: Warning: Connection reset. Retrying...
    router1: 
    router1: Vagrant insecure key detected. Vagrant will automatically replace
    router1: this with a newly generated keypair for better security.
    router1: 
    router1: Inserting generated public key within guest...
    router1: Removing insecure key from the guest if it's present...
    router1: Key inserted! Disconnecting and reconnecting using new SSH key...
==> router1: Machine booted and ready!
==> router1: Checking for guest additions in VM...
    router1: The guest additions on this VM do not match the installed version of
    router1: VirtualBox! In most cases this is fine, but in rare cases it can
    router1: prevent things such as shared folders from working properly. If you see
    router1: shared folder errors, please make sure the guest additions within the
    router1: virtual machine match the version of VirtualBox you have installed on
    router1: your host and reload your VM.
    router1: 
    router1: Guest Additions Version: 7.2.4
    router1: VirtualBox Version: 7.1
==> router1: Setting hostname...
==> router1: Configuring and enabling network interfaces...
==> router1: Mounting shared folders...
    router1: /home/admin_insta11/ospf_lab => /vagrant
==> router2: You assigned a static IP ending in ".1" or ":1" to this machine.
==> router2: This is very often used by the router and can cause the
==> router2: network to not work properly. If the network doesn't work
==> router2: properly, try changing this IP.
==> router2: Importing base box 'ubuntu-22.04-virtualbox'...
==> router2: Matching MAC address for NAT networking...
==> router2: You assigned a static IP ending in ".1" or ":1" to this machine.
==> router2: This is very often used by the router and can cause the
==> router2: network to not work properly. If the network doesn't work
==> router2: properly, try changing this IP.
==> router2: Setting the name of the VM: ospf_lab_router2_1794662056357_85733
==> router2: Fixed port collision for 22 => 2222. Now on port 2200.
==> router2: Clearing any previously set network interfaces...
==> router2: Preparing network interfaces based on configuration...
    router2: Adapter 1: nat
    router2: Adapter 2: intnet
    router2: Adapter 3: intnet
    router2: Adapter 4: intnet
    router2: Adapter 5: hostonly
==> router2: Forwarding ports...
    router2: 22 (guest) => 2200 (host) (adapter 1)
==> router2: Booting VM...
==> router2: Waiting for machine to boot. This may take a few minutes...
    router2: SSH address: 127.0.0.1:2200
    router2: SSH username: vagrant
    router2: SSH auth method: private key
    router2: 
    router2: Vagrant insecure key detected. Vagrant will automatically replace
    router2: this with a newly generated keypair for better security.
    router2: 
    router2: Inserting generated public key within guest...
    router2: Removing insecure key from the guest if it's present...
    router2: Key inserted! Disconnecting and reconnecting using new SSH key...
==> router2: Machine booted and ready!
==> router2: Checking for guest additions in VM...
    router2: The guest additions on this VM do not match the installed version of
    router2: VirtualBox! In most cases this is fine, but in rare cases it can
    router2: prevent things such as shared folders from working properly. If you see
    router2: shared folder errors, please make sure the guest additions within the
    router2: virtual machine match the version of VirtualBox you have installed on
    router2: your host and reload your VM.
    router2: 
    router2: Guest Additions Version: 7.2.4
    router2: VirtualBox Version: 7.1
==> router2: Setting hostname...
==> router2: Configuring and enabling network interfaces...
==> router2: Mounting shared folders...
    router2: /home/admin_insta11/ospf_lab => /vagrant
==> router3: You assigned a static IP ending in ".1" or ":1" to this machine.
==> router3: This is very often used by the router and can cause the
==> router3: network to not work properly. If the network doesn't work
==> router3: properly, try changing this IP.
==> router3: You assigned a static IP ending in ".1" or ":1" to this machine.
==> router3: This is very often used by the router and can cause the
==> router3: network to not work properly. If the network doesn't work
==> router3: properly, try changing this IP.
==> router3: Importing base box 'ubuntu-22.04-virtualbox'...
==> router3: Matching MAC address for NAT networking...
==> router3: You assigned a static IP ending in ".1" or ":1" to this machine.
==> router3: This is very often used by the router and can cause the
==> router3: network to not work properly. If the network doesn't work
==> router3: properly, try changing this IP.
==> router3: You assigned a static IP ending in ".1" or ":1" to this machine.
==> router3: This is very often used by the router and can cause the
==> router3: network to not work properly. If the network doesn't work
==> router3: properly, try changing this IP.
==> router3: Setting the name of the VM: ospf_lab_router3_1794662153351_43326
==> router3: Fixed port collision for 22 => 2222. Now on port 2201.
==> router3: Clearing any previously set network interfaces...
==> router3: Preparing network interfaces based on configuration...
    router3: Adapter 1: nat
    router3: Adapter 2: intnet
    router3: Adapter 3: intnet
    router3: Adapter 4: intnet
    router3: Adapter 5: hostonly
==> router3: Forwarding ports...
    router3: 22 (guest) => 2201 (host) (adapter 1)
==> router3: Booting VM...
==> router3: Waiting for machine to boot. This may take a few minutes...
    router3: SSH address: 127.0.0.1:2201
    router3: SSH username: vagrant
    router3: SSH auth method: private key
    router3: Warning: Connection reset. Retrying...
    router3: Warning: Remote connection disconnect. Retrying...
    router3: 
    router3: Vagrant insecure key detected. Vagrant will automatically replace
    router3: this with a newly generated keypair for better security.
    router3: 
    router3: Inserting generated public key within guest...
    router3: Removing insecure key from the guest if it's present...
    router3: Key inserted! Disconnecting and reconnecting using new SSH key...
==> router3: Machine booted and ready!
==> router3: Checking for guest additions in VM...
    router3: The guest additions on this VM do not match the installed version of
    router3: VirtualBox! In most cases this is fine, but in rare cases it can
    router3: prevent things such as shared folders from working properly. If you see
    router3: shared folder errors, please make sure the guest additions within the
    router3: virtual machine match the version of VirtualBox you have installed on
    router3: your host and reload your VM.
    router3: 
    router3: Guest Additions Version: 7.2.4
    router3: VirtualBox Version: 7.1
==> router3: Setting hostname...
==> router3: Configuring and enabling network interfaces...
==> router3: Mounting shared folders...
    router3: /home/admin_insta11/ospf_lab => /vagrant
==> router3: Running provisioner: ansible...
`playbook` does not exist on the host: /home/admin_insta11/ospf_lab/ansible/provision.yml
[admin_insta11@mv334 ospf_lab]$ 
[admin_insta11@mv334 ospf_lab]$ vagrant status
Current machine states:

router1                   running (virtualbox)
router2                   running (virtualbox)
router3                   running (virtualbox)

[admin_insta11@mv334 ospf_lab]$
```


2.1 Установка пакетов и конфигурирование router1

Отключаем ufw:

```
admin_insta11@mv334 ospf_lab]$ vagrant ssh router1
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-160-generic x86_64)

Use of this system is acceptance of the OS vendor EULA and License Agreements.
vagrant@router1:~$ 
vagrant@router1:~$ sudo -i
root@router1:~# 
root@router1:~# systemctl stop ufw
root@router1:~# systemctl disable ufw
Synchronizing state of ufw.service with SysV service script with /lib/systemd/systemd-sysv-install.
Executing: /lib/systemd/systemd-sysv-install disable ufw
Removed /etc/systemd/system/multi-user.target.wants/ufw.service.
root@router1:~# 
root@router1:~# 

```

Устанавливаем ключи пакета frr, репозиторий frr и устанавливаем пакет frr:

**ПРИМЕЧАНИЕ:** установка ключей при помощи apt-key выдаёт предупреждение:

```
root@router1:~# curl -s https://deb.frrouting.org/frr/keys.asc | sudo apt-key add -
Warning: apt-key is deprecated. Manage keyring files in trusted.gpg.d instead (see apt-key(8)).
OK
root@router1:~#
```

 => метод установки ключей с помощью apt-key устарел, и будет работать только до Ubuntu 22.04.

 Поэтому устанавливаем ключи репозитория следующим методом:

-    ключ скачивается, «разарморивается» (gpg --dearmor, потому что он в текстовом ASCII-виде, переводится обратно в бинарный вид для использования при проверке репозиториев) и кладётся в /etc/apt/keyrings/ — место, предназначенное именно для ключей конкретных репозиториев. **Примечание:** Файл должен называться *.gpg (бинарный keyring) или *.asc (ASCII) — apt игнорирует другие расширения. И не кладите туда «сырой» ASCII-ключ с расширением .gpg без dearmor'а — apt его не прочитает. Файл в формате .asc - это так называемый ASCII-armor: «настоящие» двоичные данные PGP закодированы в текст (по сути, в Base64), к ним добавлены заголовки и разделители.;

-    в строке репозитория опция [signed-by=...] привязывает его к этому конкретному репозиторию — пакетный менеджер будет проверять подписи только им, а не всеми ключами подряд;

-    ключ не попадает в общесистемный trusted.gpg.d, где он доверялся бы вообще для всех репозиториев (в том числе сторонних) — это плюс к безопасности.


 ```
root@router1:~# sudo mkdir -p /etc/apt/keyrings
root@router1:~# 
root@router1:~# curl -fsSL https://deb.frrouting.org/frr/keys.asc | sudo gpg --dearmor -o /etc/apt/keyrings/frr.gpg
root@router1:~# 
root@router1:~# echo "deb [signed-by=/etc/apt/keyrings/frr.gpg] https://deb.frrouting.org/frr $(lsb_release -cs) frr-stable" | sudo tee /etc/apt/sources.list.d/frr.list
deb [signed-by=/etc/apt/keyrings/frr.gpg] https://deb.frrouting.org/frr jammy frr-stable
root@router1:~#
```

Далее устанавливаем пакет frr:

```
root@router1:~# sudo apt update
Hit:1 http://us.archive.ubuntu.com/ubuntu jammy InRelease                                       
Get:2 http://security.ubuntu.com/ubuntu jammy-security InRelease [129 kB]                       
Get:3 http://us.archive.ubuntu.com/ubuntu jammy-updates InRelease [128 kB]
<...>
root@router1:~# apt install frr frr-pythontools
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
The following additional packages will be installed:
  libc-ares2 libpcre2-posix3 libyang3
Suggested packages:
  frr-doc
The following NEW packages will be installed:
  frr frr-pythontools libc-ares2 libpcre2-posix3 libyang3
0 upgraded, 5 newly installed, 0 to remove and 200 not upgraded.
Need to get 7,808 kB of archives.
After this operation, 43.1 MB of additional disk space will be used.
Do you want to continue? [Y/n] y
Get:1 http://us.archive.ubuntu.com/ubuntu jammy-updates/main amd64 libc-ares2 amd64 1.18.1-1ubuntu0.22.04.4 [45.2 kB]
Get:2 http://us.archive.ubuntu.com/ubuntu jammy-updates/main amd64 libpcre2-posix3 amd64 10.39-3ubuntu0.2 [6,134 B]
Get:3 https://deb.frrouting.org/frr jammy/frr-stable amd64 libyang3 amd64 3.13.6-1~ubuntu22.04u1 [610 kB]
Get:4 https://deb.frrouting.org/frr jammy/frr-stable amd64 frr amd64 10.7.1-0~ubuntu22.04.1 [7,081 kB]
Get:5 https://deb.frrouting.org/frr jammy/frr-stable amd64 frr-pythontools all 10.7.1-0~ubuntu22.04.1 [66.1 kB]
Fetched 7,808 kB in 4s (1,788 kB/s)
<...>
root@router1:~#
```

Устанавливаем также дополнительные пакеты:

```
root@router1:~# apt install traceroute tcpdump net-tools
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
<...>
No VM guests are running outdated hypervisor (qemu) binaries on this host.
root@router1:~# 
```

Включаем форвардинг пакетов в ядре (обязательный пункт для всех маршрутизаторов - разрешает пересылку пакетов между интерфейсами):

```
root@router1:~# sysctl net.ipv4.conf.all.forwarding=1
net.ipv4.conf.all.forwarding = 1
root@router1:~#
```

Отключаем ipv6 (необязательный пункт, отключает использование IPv6 в ядре - в данном случае только для того, чтобы
команды 'ip address' и ‘show interfaces brief’ в frr vtysh не выводили IPv6 адреса, с которыми мы не работаем):

```
root@router1:~# sysctl -w net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.all.disable_ipv6 = 1
root@router1:~# 
```

Включаем в конфигурации frr необходимые демоны и перезагружаем frr для применения:

```
root@router1:~# vi /etc/frr/daemons
root@router1:~#
root@router1:~# cat /etc/frr/daemons | grep "zebra\|ospf\|bgp"
# The watchfrr, zebra and staticd daemons are always started.
bgpd=yes
ospfd=yes
ospf6d=no
<...>
root@router1:~# 
oot@router1:~# systemctl restart frr.service
root@router1:~# 
root@router1:~# systemctl status frr.service
● frr.service - FRRouting
     Loaded: loaded (/lib/systemd/system/frr.service; enabled; vendor preset: enabled)
     Active: active (running) since Sat 2026-11-14 15:49:12 UTC; 16s ago
       Docs: https://frrouting.readthedocs.io/en/latest/setup.html
    Process: 3229 ExecStart=/usr/lib/frr/frrinit.sh start (code=exited, status=0/SUCCESS)
   Main PID: 3240 (watchfrr)
     Status: "FRR Operational"
      Tasks: 17 (limit: 3425)
     Memory: 29.2M
        CPU: 523ms
     CGroup: /system.slice/frr.service
             ├─3240 /usr/lib/frr/watchfrr -d mgmtd zebra bgpd ospfd staticd
             ├─3252 /usr/lib/frr/mgmtd -d -F traditional -A 127.0.0.1
             ├─3254 /usr/lib/frr/zebra -d -F traditional -A 127.0.0.1 -s 90000000
             ├─3259 /usr/lib/frr/bgpd -d -F traditional -A 127.0.0.1
             ├─3266 /usr/lib/frr/ospfd -d -F traditional -A 127.0.0.1
             └─3269 /usr/lib/frr/staticd -d -F traditional -A 127.0.0.1

Nov 14 15:49:12 router1 watchfrr[3240]: [QDG3Y-BY5TN] zebra state -> up : connect succeeded
Nov 14 15:49:12 router1 watchfrr[3240]: [QDG3Y-BY5TN] bgpd state -> up : connect succeeded
Nov 14 15:49:12 router1 watchfrr[3240]: [QDG3Y-BY5TN] ospfd state -> up : connect succeeded
Nov 14 15:49:12 router1 watchfrr[3240]: [QDG3Y-BY5TN] staticd state -> up : connect succeeded
Nov 14 15:49:12 router1 watchfrr[3240]: [KWE5Q-QNGFC] all daemons up, doing startup-complete notify
Nov 14 15:49:12 router1 frrinit.sh[3229]:  * Started watchfrr
Nov 14 15:49:12 router1 systemd[1]: Started FRRouting.
Nov 14 15:49:13 router1 zebra[3254]: [V98V0-MTWPF] client 59 says hello and bids fair to announce only bgp routes vrf=0
Nov 14 15:49:27 router1 zebra[3254]: [SAPXX-HP5B5][EC 4043309108] Extended Error: failed to retrieve link settings
Nov 14 15:49:27 router1 zebra[3254]: [WVJCK-PPMGD][EC 4043309093] generic-netlink-cmd (NS 0) error: Operation not supported, type=RTM_DELADDR(21>
root@router1:~# 
```

Далее конфигурируем ospf в frr в соответствии с заданием:

```
oot@router1:~# vtysh

Hello, this is FRRouting (version 10.7.1).
Copyright 1996-2005 Kunihiro Ishiguro, et al.

router1# show interface brief
Interface       Status  VRF             Addresses
---------       ------  ---             ---------
eth0            up      default         10.0.2.15/24
eth1            up      default         10.0.10.1/30
eth2            up      default         10.0.12.1/30
eth3            up      default         192.168.10.1/24
eth4            up      default         192.168.50.10/24
lo              up      default         

router1# sh run
Building configuration...

Current configuration:
!
frr version 10.7.1
frr defaults traditional
hostname router1
log syslog informational
service integrated-vtysh-config
!
end
router1# 
router1# conf t
router1(config)# interface eth1
router1(config-if)# description r1-r2
router1(config-if)# ip address 10.0.10.1/30
router1(config-if)# ip ospf mtu-ignore
router1(config-if)# ip ospf hello-interval 10
router1(config-if)# ip ospf dead-interval 30
router1(config-if)# interface eth2
router1(config-if)# description r1-r3
router1(config-if)# ip address 10.0.12.1/30
router1(config-if)# ip ospf mtu-ignore
router1(config-if)# ip ospf hello-interval 10
router1(config-if)# ip ospf dead-interval 30
router1(config-if)# 
router1(config-if)# interface eth3
router1(config-if)# description net_router1
router1(config-if)# ip address 192.168.10.1/24
router1(config-if)# ip ospf mtu-ignore
router1(config-if)# ip ospf hello-interval 10
router1(config-if)# ip ospf dead-interval 30
router1(config-if)# 
router1(config-if)# exit
router1(config)# 
router1(config)# router ospf
router1(config-router)# router-id 1.1.1.1
router1(config-router)# network 10.0.10.0/30 area 0
router1(config-router)#  
router1(config-router)#  network 192.168.10.0/24 area 0
router1(config-router)# 
router1(config-router)# neighbor 10.0.10.2
router1(config-router)# neighbor 10.0.12.2
router1(config-router)# default-information originate always
router1(config-router)# exit
router1(config)# log file /var/log/frr/frr.log
router1(config)# exit
router1# 
router1# write memory 
Note: this version of vtysh never writes vtysh.conf
Building Configuration...
Integrated configuration saved to /etc/frr/frr.conf
[OK]
router1# 
router1# exit
root@router1:~# 
root@router1:~# cat /etc/frr/frr.conf
frr version 10.7.1
frr defaults traditional
hostname router1
log syslog informational
log file /var/log/frr/frr.log
service integrated-vtysh-config
!
interface eth1
 description r1-r2
 ip address 10.0.10.1/30
 ip ospf dead-interval 30
 ip ospf mtu-ignore
exit
!
interface eth2
 description r1-r3
 ip address 10.0.12.1/30
 ip ospf dead-interval 30
 ip ospf mtu-ignore
exit
!
interface eth3
 description net_router1
 ip address 192.168.10.1/24
 ip ospf dead-interval 30
 ip ospf mtu-ignore
exit
!
router ospf
 ospf router-id 1.1.1.1
 network 10.0.10.0/30 area 0
 network 10.0.12.0/30 area 0
 network 192.168.10.0/24 area 0
 neighbor 10.0.10.2
 neighbor 10.0.12.2
 default-information originate always
exit
!
root@router1:~#
root@router1:~# ll /etc/frr/frr.conf
-rw-r----- 1 frr frr 706 Nov 14 16:00 /etc/frr/frr.conf
root@router1:~# 
```

Аналогично конфигурируем маршрутизаторы router2 и router3:

```
[admin_insta11@mv334 ospf_lab]$ vagrant ssh router2
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-160-generic x86_64)

Use of this system is acceptance of the OS vendor EULA and License Agreements.
Last login: Sat Nov 14 15:24:03 2026 from 10.0.2.2
vagrant@router2:~$ 
vagrant@router2:~$ sudo -i
root@router2:~# 
root@router2:~# systemctl stop ufw
root@router2:~# 
root@router2:~# systemctl disable ufw
Synchronizing state of ufw.service with SysV service script with /lib/systemd/systemd-sysv-install.
Executing: /lib/systemd/systemd-sysv-install disable ufw
Removed /etc/systemd/system/multi-user.target.wants/ufw.service.
root@router2:~# 
root@router2:~# mkdir -p /etc/apt/keyrings
root@router2:~# 
root@router2:~# curl -fsSL https://deb.frrouting.org/frr/keys.asc | sudo gpg --dearmor -o /etc/apt/keyrings/frr.gpg
root@router2:~# 
root@router2:~# echo "deb [signed-by=/etc/apt/keyrings/frr.gpg] https://deb.frrouting.org/frr $(lsb_release -cs) frr-stable" | sudo tee /etc/apt/sources.list.d/frr.list
deb [signed-by=/etc/apt/keyrings/frr.gpg] https://deb.frrouting.org/frr jammy frr-stable
root@router2:~# 
root@router2:~# cat /etc/apt/sources.list.d/frr.list
deb [signed-by=/etc/apt/keyrings/frr.gpg] https://deb.frrouting.org/frr jammy frr-stable
root@router2:~# 
root@router2:~# apt update
<...>
200 packages can be upgraded. Run 'apt list --upgradable' to see them.
root@router2:~# 
root@router2:~# apt install frr frr-pythontools
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
The following additional packages will be installed:
  libc-ares2 libpcre2-posix3 libyang3
Suggested packages:
  frr-doc
The following NEW packages will be installed:
  frr frr-pythontools libc-ares2 libpcre2-posix3 libyang3
0 upgraded, 5 newly installed, 0 to remove and 200 not upgraded.
Need to get 7,808 kB of archives.
After this operation, 43.1 MB of additional disk space will be used.
Do you want to continue? [Y/n] y
<...>
root@router2:~# 
root@router2:~# apt install traceroute tcpdump net-tools
<...>
root@router2:~# 
root@router2:~# sysctl net.ipv4.conf.all.forwarding=1
net.ipv4.conf.all.forwarding = 1
root@router2:~# 
root@router2:~# sysctl -w net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.all.disable_ipv6 = 1
root@router2:~# 
root@router2:~# vi /etc/frr/daemons
root@router2:~# 
root@router2:~# cat /etc/frr/daemons | grep "zebra\|ospf"
# The watchfrr, zebra and staticd daemons are always started.
ospfd=yes
ospf6d=no
zebra_options="  -A 127.0.0.1 -s 90000000"
bgpd_options="   -A 127.0.0.1"
ospfd_options="  -A 127.0.0.1"
ospf6d_options=" -A ::1"
# bgpd_wrap="/usr/bin/daemonize /usr/bin/mywrapper"
root@router2:~# 
root@router2:~# systemctl restart frr.service
root@router2:~# 
root@router2:~# systemctl status frr.service
● frr.service - FRRouting
     Loaded: loaded (/lib/systemd/system/frr.service; enabled; vendor preset: enabled)
     Active: active (running) since Sun 2026-11-15 10:40:40 UTC; 21s ago
       Docs: https://frrouting.readthedocs.io/en/latest/setup.html
    Process: 3850 ExecStart=/usr/lib/frr/frrinit.sh start (code=exited, status=0/SUCCESS)
   Main PID: 3861 (watchfrr)
     Status: "FRR Operational"
      Tasks: 17 (limit: 3425)
     Memory: 29.2M
        CPU: 483ms
     CGroup: /system.slice/frr.service
             ├─3861 /usr/lib/frr/watchfrr -d mgmtd zebra bgpd ospfd staticd
             ├─3873 /usr/lib/frr/mgmtd -d -F traditional -A 127.0.0.1
             ├─3875 /usr/lib/frr/zebra -d -F traditional -A 127.0.0.1 -s 90000000
             ├─3880 /usr/lib/frr/bgpd -d -F traditional -A 127.0.0.1
             ├─3887 /usr/lib/frr/ospfd -d -F traditional -A 127.0.0.1
             └─3890 /usr/lib/frr/staticd -d -F traditional -A 127.0.0.1

Nov 15 10:40:40 router2 watchfrr[3861]: [QDG3Y-BY5TN] zebra state -> up : connect succeeded
Nov 15 10:40:40 router2 watchfrr[3861]: [QDG3Y-BY5TN] bgpd state -> up : connect succeeded
Nov 15 10:40:40 router2 watchfrr[3861]: [QDG3Y-BY5TN] ospfd state -> up : connect succeeded
Nov 15 10:40:40 router2 watchfrr[3861]: [QDG3Y-BY5TN] staticd state -> up : connect succeeded
Nov 15 10:40:40 router2 watchfrr[3861]: [KWE5Q-QNGFC] all daemons up, doing startup-complete notify
Nov 15 10:40:40 router2 frrinit.sh[3850]:  * Started watchfrr
Nov 15 10:40:40 router2 systemd[1]: Started FRRouting.
Nov 15 10:40:41 router2 zebra[3875]: [V98V0-MTWPF] client 59 says hello and bids fair to announce only bgp routes vrf=0
Nov 15 10:40:55 router2 zebra[3875]: [SAPXX-HP5B5][EC 4043309108] Extended Error: failed to retrieve link settings
Nov 15 10:40:55 router2 zebra[3875]: [WVJCK-PPMGD][EC 4043309093] generic-netlink-cmd (NS 0) error: Operation not supported, type=RTM_DELADDR(21), seq=98, pid=3874
root@router2:~# 
root@router2:~# vtysh

Hello, this is FRRouting (version 10.7.1).
Copyright 1996-2005 Kunihiro Ishiguro, et al.

router2# 
router2# 
router2# show interface brief 
Interface       Status  VRF             Addresses
---------       ------  ---             ---------
eth0            up      default         10.0.2.15/24
eth1            up      default         10.0.10.2/30
eth2            up      default         10.0.11.2/30
eth3            up      default         192.168.20.1/24
eth4            up      default         192.168.50.11/24
lo              up      default         

router2# 
router2# show running-config 
Building configuration...

Current configuration:
!
frr version 10.7.1
frr defaults traditional
hostname router2
log syslog informational
service integrated-vtysh-config
!
end
router2# 
router2# conf t
router2(config)# int eth1
router2(config-if)# desc r1-r2
router2(config-if)# ip address 10.0.10.2/30
router2(config-if)# ip ospf mtu-ignore
router2(config-if)# ip ospf hello-interval 10
router2(config-if)# ip ospf dead-interval 30
router2(config-if)# interface eth2
router2(config-if)# desc r2-r3
router2(config-if)# ip address 10.0.11.2/30
router2(config-if)# ip ospf mtu-ignore
router2(config-if)# ip ospf hello-interval 10
router2(config-if)# ip ospf dead-interval 30
router2(config-if)# 
router2(config-if)# interface eth3
router2(config-if)# desc net_router2
router2(config-if)# ip address 192.168.20.1/24
router2(config-if)# ip ospf mtu-ignore
router2(config-if)# ip ospf hello-interval 10
router2(config-if)# ip ospf dead-interval 30
router2(config-if)# exit
router2(config)# 
router2(config)# router ospf
router2(config-router)# router-id 2.2.2.2
router2(config-router)# network 10.0.10.0/30 area 0
router2(config-router)# network 10.0.11.0/30 area 0
router2(config-router)# network 192.168.20.0/24 area 0
router2(config-router)# 
router2(config-router)# neighbor 10.0.10.1
router2(config-router)# neighbor 10.0.11.1
router2(config-router)# 
router2(config-router)# exit
router2(config)# 
router2(config)# log file /var/log/frr/frr.log
router2(config)# exit
router2# 
router2# write memory 
Note: this version of vtysh never writes vtysh.conf
Building Configuration...
Integrated configuration saved to /etc/frr/frr.conf
[OK]
router2# 
router2# exit
root@router2:~# 
root@router2:~# cat /etc/frr/frr.conf
frr version 10.7.1
frr defaults traditional
hostname router2
log syslog informational
log file /var/log/frr/frr.log
service integrated-vtysh-config
!
interface eth1
 description r1-r2
 ip address 10.0.10.2/30
 ip ospf dead-interval 30
 ip ospf mtu-ignore
exit
!
interface eth2
 description r2-r3
 ip address 10.0.11.2/30
 ip ospf dead-interval 30
 ip ospf mtu-ignore
exit
!
interface eth3
 description net_router2
 ip address 192.168.20.1/24
 ip ospf dead-interval 30
 ip ospf mtu-ignore
exit
!
router ospf
 ospf router-id 2.2.2.2
 network 10.0.10.0/30 area 0
 network 10.0.11.0/30 area 0
 network 192.168.20.0/24 area 0
 neighbor 10.0.10.1
 neighbor 10.0.11.1
exit
!
root@router2:~# 
root@router2:~# ll /etc/frr/frr.conf
-rw-r----- 1 frr frr 706 Nov 14 16:00 /etc/frr/frr.conf
root@router2:~# 


[admin_insta11@mv334 ospf_lab]$ vagrant ssh router3
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-160-generic x86_64)

Last login: Sat Nov 14 15:33:43 2026 from 10.0.2.2
vagrant@router3:~$ 
vagrant@router3:~$ sudo -i
root@router3:~# 
root@router3:~# systemctl stop ufw
root@router3:~# systemctl disable ufw
Synchronizing state of ufw.service with SysV service script with /lib/systemd/systemd-sysv-install.
Executing: /lib/systemd/systemd-sysv-install disable ufw
Removed /etc/systemd/system/multi-user.target.wants/ufw.service.
root@router3:~# 
root@router3:~# mkdir -p /etc/apt/keyrings
root@router3:~# 
root@router3:~# curl -fsSL https://deb.frrouting.org/frr/keys.asc | sudo gpg --dearmor -o /etc/apt/keyrings/frr.gpg
root@router3:~# 
root@router3:~# echo "deb [signed-by=/etc/apt/keyrings/frr.gpg] https://deb.frrouting.org/frr $(lsb_release -cs) frr-stable" | sudo tee /etc/apt/sources.list.d/frr.list
deb [signed-by=/etc/apt/keyrings/frr.gpg] https://deb.frrouting.org/frr jammy frr-stable
root@router3:~# 
root@router3:~# apt update
<...>
root@router3:~# 
root@router3:~# apt install frr frr-pythontools
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
The following additional packages will be installed:
  libc-ares2 libpcre2-posix3 libyang3
Suggested packages:
  frr-doc
The following NEW packages will be installed:
  frr frr-pythontools libc-ares2 libpcre2-posix3 libyang3
0 upgraded, 5 newly installed, 0 to remove and 200 not upgraded.
Need to get 7,808 kB of archives.
After this operation, 43.1 MB of additional disk space will be used.
Do you want to continue? [Y/n] y
<...>
root@router3:~# 
root@router3:~# apt install traceroute tcpdump net-tools
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
tcpdump is already the newest version (4.99.1-3ubuntu0.2).
The following NEW packages will be installed:
  net-tools traceroute
0 upgraded, 2 newly installed, 0 to remove and 200 not upgraded.
Need to get 250 kB of archives.
After this operation, 971 kB of additional disk space will be used.
Do you want to continue? [Y/n] y
<...>
root@router3:~# 
root@router3:~# sysctl net.ipv4.conf.all.forwarding=1
net.ipv4.conf.all.forwarding = 1
root@router3:~# 
root@router3:~# sysctl -w net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.all.disable_ipv6 = 1
root@router3:~# 
root@router3:~# vi /etc/frr/daemons
root@router3:~# 
root@router3:~# 
root@router3:~# cat /etc/frr/daemons | grep "zebra\|ospf"
# The watchfrr, zebra and staticd daemons are always started.
ospfd=yes
ospf6d=no
zebra_options="  -A 127.0.0.1 -s 90000000"
ospfd_options="  -A 127.0.0.1"
ospf6d_options=" -A ::1"
root@router3:~# 
root@router3:~# systemctl restart frr.service
root@router3:~# 
root@router3:~# systemctl status frr.service
● frr.service - FRRouting
     Loaded: loaded (/lib/systemd/system/frr.service; enabled; vendor preset: enabled)
     Active: active (running) since Sun 2026-11-15 11:09:07 UTC; 13s ago
       Docs: https://frrouting.readthedocs.io/en/latest/setup.html
    Process: 3165 ExecStart=/usr/lib/frr/frrinit.sh start (code=exited, status=0/SUCCESS)
   Main PID: 3176 (watchfrr)
     Status: "FRR Operational"
      Tasks: 17 (limit: 3425)
     Memory: 29.3M
        CPU: 542ms
     CGroup: /system.slice/frr.service
             ├─3176 /usr/lib/frr/watchfrr -d mgmtd zebra bgpd ospfd staticd
             ├─3188 /usr/lib/frr/mgmtd -d -F traditional -A 127.0.0.1
             ├─3190 /usr/lib/frr/zebra -d -F traditional -A 127.0.0.1 -s 90000000
             ├─3195 /usr/lib/frr/bgpd -d -F traditional -A 127.0.0.1
             ├─3202 /usr/lib/frr/ospfd -d -F traditional -A 127.0.0.1
             └─3205 /usr/lib/frr/staticd -d -F traditional -A 127.0.0.1

Nov 15 11:09:07 router3 frrinit.sh[3229]: [3229|watchfrr] done
Nov 15 11:09:07 router3 watchfrr[3176]: [QDG3Y-BY5TN] mgmtd state -> up : connect succeeded
Nov 15 11:09:07 router3 watchfrr[3176]: [QDG3Y-BY5TN] zebra state -> up : connect succeeded
Nov 15 11:09:07 router3 watchfrr[3176]: [QDG3Y-BY5TN] bgpd state -> up : connect succeeded
Nov 15 11:09:07 router3 watchfrr[3176]: [QDG3Y-BY5TN] ospfd state -> up : connect succeeded
Nov 15 11:09:07 router3 watchfrr[3176]: [QDG3Y-BY5TN] staticd state -> up : connect succeeded
Nov 15 11:09:07 router3 watchfrr[3176]: [KWE5Q-QNGFC] all daemons up, doing startup-complete notify
Nov 15 11:09:07 router3 frrinit.sh[3165]:  * Started watchfrr
Nov 15 11:09:07 router3 systemd[1]: Started FRRouting.
Nov 15 11:09:08 router3 zebra[3190]: [V98V0-MTWPF] client 59 says hello and bids fair to announce only bgp routes vrf=0
root@router3:~# 
root@router3:~# vtysh

Hello, this is FRRouting (version 10.7.1).
Copyright 1996-2005 Kunihiro Ishiguro, et al.

router3# show interface brief
Interface       Status  VRF             Addresses
---------       ------  ---             ---------
eth0            up      default         10.0.2.15/24
eth1            up      default         10.0.11.1/30
eth2            up      default         10.0.12.2/30
eth3            up      default         192.168.30.1/24
eth4            up      default         192.168.50.12/24
lo              up      default         

router3# 
router3# sh run
Building configuration...

Current configuration:
!
frr version 10.7.1
frr defaults traditional
hostname router3
log syslog informational
service integrated-vtysh-config
!
end
router3# 
router3# conf t
router3(config)# interface eth1
router3(config-if)# description r3-r2
router3(config-if)# ip a
address         authentication  
router3(config-if)# ip address 10.0.11.1/30
router3(config-if)# ip ospf mtu-ignore
router3(config-if)# ip ospf hello-interval 10
router3(config-if)# ip ospf dead-interval 30
router3(config-if)# 
router3(config-if)# interface eth2
router3(config-if)# description r3-r1
router3(config-if)# ip address 10.0.12.2/30
router3(config-if)# ip ospf mtu-ignore
router3(config-if)# ip ospf hello-interval 10
router3(config-if)# ip ospf dead-interval 30
router3(config-if)# 
router3(config-if)# interface eth3
router3(config-if)# description net_router3
router3(config-if)# ip address 192.168.30.1/24
router3(config-if)# ip ospf mtu-ignore
router3(config-if)# ip ospf hello-interval 10
router3(config-if)# ip ospf dead-interval 30
router3(config-if)# 
router3(config-if)# exit
router3(config)# 
router3(config)# router ospf
router3(config-router)# router-id 3.3.3.3
router3(config-router)# network 10.0.11.0/30 area 0
router3(config-router)# network 10.0.12.0/30 area 0
router3(config-router)# network 192.168.30.1/24 area 0
router3(config-router)# neighbor 10.0.11.2
router3(config-router)# neighbor 10.0.12.1
router3(config-router)# exit
router3(config)# 
router3(config)# log file /var/log/frr/frr.log
router3(config)# exit
router3# 
router3# wri mem
Note: this version of vtysh never writes vtysh.conf
Building Configuration...
Integrated configuration saved to /etc/frr/frr.conf
[OK]
router3# 
router3# exit
root@router3:~# cat /etc/frr/frr.conf
frr version 10.7.1
frr defaults traditional
hostname router3
log syslog informational
log file /var/log/frr/frr.log
service integrated-vtysh-config
!
interface eth1
 description r3-r2
 ip address 10.0.11.1/30
 ip ospf dead-interval 30
 ip ospf mtu-ignore
exit
!
interface eth2
 description r3-r1
 ip address 10.0.12.2/30
 ip ospf dead-interval 30
 ip ospf mtu-ignore
exit
!
interface eth3
 description net_router3
 ip address 192.168.30.1/24
 ip ospf dead-interval 30
 ip ospf mtu-ignore
exit
!
router ospf
 ospf router-id 3.3.3.3
 network 10.0.11.0/30 area 0
 network 10.0.12.0/30 area 0
 network 192.168.30.0/24 area 0
 neighbor 10.0.11.2
 neighbor 10.0.12.1
exit
!
root@router3:~#
root@router3:~# ll /etc/frr/frr.conf
-rw-r----- 1 frr frr 706 Nov 14 16:00 /etc/frr/frr.conf
root@router3:~# 
```


После выполненного конфигурирования проверяем наличие маршрутов на маршрутизаторах:

На router1:

```
root@router1:~# vtysh

Hello, this is FRRouting (version 10.7.1).
Copyright 1996-2005 Kunihiro Ishiguro, et al.

router1# sh ip ro
ro         route      router-id  
router1# sh ip route
Codes: K - kernel route, C - connected, L - local, S - static,
       R - RIP, O - OSPF, I - IS-IS, B - BGP, E - EIGRP, N - NHRP,
       T - Table, v - VNC, V - VNC-Direct, A - Babel, F - PBR,
       f - OpenFabric, t - Table-Direct,
       > - selected route, * - FIB route, q - queued, r - rejected, b - backup
       t - trapped, o - offload failure

IPv4 unicast VRF default:
K>* 0.0.0.0/0 [0/100] via 10.0.2.2, eth0, src 10.0.2.15, weight 1, 21:39:04
C>* 10.0.2.0/24 [0/100] is directly connected, eth0, weight 1, 21:39:04
K>* 10.0.2.2/32 [0/100] is directly connected, eth0, weight 1, 21:39:04
K>* 10.0.2.3/32 [0/100] is directly connected, eth0, weight 1, 21:39:04
L>* 10.0.2.15/32 is directly connected, eth0, weight 1, 21:39:04
C>* 10.0.10.0/30 is directly connected, eth1, weight 1, 21:39:04
L>* 10.0.10.1/32 is directly connected, eth1, weight 1, 21:39:04
O>* 10.0.11.0/30 [110/200] via 10.0.10.2, eth1, weight 1, 02:09:31
  *                        via 10.0.12.2, eth2, weight 1, 02:09:31
C>* 10.0.12.0/30 is directly connected, eth2, weight 1, 21:39:04
L>* 10.0.12.1/32 is directly connected, eth2, weight 1, 21:39:04
C>* 192.168.10.0/24 is directly connected, eth3, weight 1, 21:39:04
L>* 192.168.10.1/32 is directly connected, eth3, weight 1, 21:39:04
O>* 192.168.20.0/24 [110/200] via 10.0.10.2, eth1, weight 1, 02:34:15
O>* 192.168.30.0/24 [110/200] via 10.0.12.2, eth2, weight 1, 02:09:30
C>* 192.168.50.0/24 is directly connected, eth4, weight 1, 21:39:04
L>* 192.168.50.10/32 is directly connected, eth4, weight 1, 21:39:04
router1# 
router1# sh ip route ospf
Codes: K - kernel route, C - connected, L - local, S - static,
       R - RIP, O - OSPF, I - IS-IS, B - BGP, E - EIGRP, N - NHRP,
       T - Table, v - VNC, V - VNC-Direct, A - Babel, F - PBR,
       f - OpenFabric, t - Table-Direct,
       > - selected route, * - FIB route, q - queued, r - rejected, b - backup
       t - trapped, o - offload failure

IPv4 unicast VRF default:
O>* 10.0.11.0/30 [110/200] via 10.0.10.2, eth1, weight 1, 02:10:52
  *                        via 10.0.12.2, eth2, weight 1, 02:10:52
O>* 192.168.20.0/24 [110/200] via 10.0.10.2, eth1, weight 1, 02:35:36
O>* 192.168.30.0/24 [110/200] via 10.0.12.2, eth2, weight 1, 02:10:51
router1# exit
router1#
root@router1:~# ip r
default via 10.0.2.2 dev eth0 proto dhcp src 10.0.2.15 metric 100 
10.0.2.0/24 dev eth0 proto kernel scope link src 10.0.2.15 metric 100 
10.0.2.2 dev eth0 proto dhcp scope link src 10.0.2.15 metric 100 
10.0.2.3 dev eth0 proto dhcp scope link src 10.0.2.15 metric 100 
10.0.10.0/30 dev eth1 proto kernel scope link src 10.0.10.1 
10.0.11.0/30 nhid 31 proto ospf metric 20 
	nexthop via 10.0.10.2 dev eth1 weight 1 
	nexthop via 10.0.12.2 dev eth2 weight 1 
10.0.12.0/30 dev eth2 proto kernel scope link src 10.0.12.1 
192.168.10.0/24 dev eth3 proto kernel scope link src 192.168.10.1 
192.168.20.0/24 nhid 26 via 10.0.10.2 dev eth1 proto ospf metric 20 
192.168.30.0/24 nhid 32 via 10.0.12.2 dev eth2 proto ospf metric 20 
192.168.50.0/24 dev eth4 proto kernel scope link src 192.168.50.10 
root@router1:~#
root@router1:~# ip r | grep ospf
10.0.11.0/30 nhid 31 proto ospf metric 20 
192.168.20.0/24 nhid 26 via 10.0.10.2 dev eth1 proto ospf metric 20 
192.168.30.0/24 nhid 32 via 10.0.12.2 dev eth2 proto ospf metric 20 
root@router1:~# 
```

router2:

```
oot@router2:~# vtysh

Hello, this is FRRouting (version 10.7.1).
Copyright 1996-2005 Kunihiro Ishiguro, et al.

router2# show ip route
Codes: K - kernel route, C - connected, L - local, S - static,
       R - RIP, O - OSPF, I - IS-IS, B - BGP, E - EIGRP, N - NHRP,
       T - Table, v - VNC, V - VNC-Direct, A - Babel, F - PBR,
       f - OpenFabric, t - Table-Direct,
       > - selected route, * - FIB route, q - queued, r - rejected, b - backup
       t - trapped, o - offload failure

IPv4 unicast VRF default:
O   0.0.0.0/0 [110/1] via 10.0.10.1, eth1, weight 1, 02:44:25
K>* 0.0.0.0/0 [0/100] via 10.0.2.2, eth0, src 10.0.2.15, weight 1, 02:56:50
C>* 10.0.2.0/24 [0/100] is directly connected, eth0, weight 1, 02:56:50
K>* 10.0.2.2/32 [0/100] is directly connected, eth0, weight 1, 02:56:50
K>* 10.0.2.3/32 [0/100] is directly connected, eth0, weight 1, 02:56:50
L>* 10.0.2.15/32 is directly connected, eth0, weight 1, 02:56:50
C>* 10.0.10.0/30 is directly connected, eth1, weight 1, 02:56:50
L>* 10.0.10.2/32 is directly connected, eth1, weight 1, 02:56:50
C>* 10.0.11.0/30 is directly connected, eth2, weight 1, 02:56:50
L>* 10.0.11.2/32 is directly connected, eth2, weight 1, 02:56:50
O>* 10.0.12.0/30 [110/200] via 10.0.10.1, eth1, weight 1, 02:18:56
  *                        via 10.0.11.1, eth2, weight 1, 02:18:56
O>* 192.168.10.0/24 [110/200] via 10.0.10.1, eth1, weight 1, 02:44:26
C>* 192.168.20.0/24 is directly connected, eth3, weight 1, 02:56:51
L>* 192.168.20.1/32 is directly connected, eth3, weight 1, 02:56:51
O>* 192.168.30.0/24 [110/200] via 10.0.11.1, eth2, weight 1, 02:18:46
C>* 192.168.50.0/24 is directly connected, eth4, weight 1, 02:56:51
L>* 192.168.50.11/32 is directly connected, eth4, weight 1, 02:56:51
router2# 
router2# show ip route ospf
Codes: K - kernel route, C - connected, L - local, S - static,
       R - RIP, O - OSPF, I - IS-IS, B - BGP, E - EIGRP, N - NHRP,
       T - Table, v - VNC, V - VNC-Direct, A - Babel, F - PBR,
       f - OpenFabric, t - Table-Direct,
       > - selected route, * - FIB route, q - queued, r - rejected, b - backup
       t - trapped, o - offload failure

IPv4 unicast VRF default:
O   0.0.0.0/0 [110/1] via 10.0.10.1, eth1, weight 1, 02:44:32
O>* 10.0.12.0/30 [110/200] via 10.0.10.1, eth1, weight 1, 02:19:03
  *                        via 10.0.11.1, eth2, weight 1, 02:19:03
O>* 192.168.10.0/24 [110/200] via 10.0.10.1, eth1, weight 1, 02:44:33
O>* 192.168.30.0/24 [110/200] via 10.0.11.1, eth2, weight 1, 02:18:52
router2# exit
root@router2:~#
root@router2:~# ip r
default via 10.0.2.2 dev eth0 proto dhcp src 10.0.2.15 metric 100 
10.0.2.0/24 dev eth0 proto kernel scope link src 10.0.2.15 metric 100 
10.0.2.2 dev eth0 proto dhcp scope link src 10.0.2.15 metric 100 
10.0.2.3 dev eth0 proto dhcp scope link src 10.0.2.15 metric 100 
10.0.10.0/30 dev eth1 proto kernel scope link src 10.0.10.2 
10.0.11.0/30 dev eth2 proto kernel scope link src 10.0.11.2 
10.0.12.0/30 nhid 21 proto ospf metric 20 
	nexthop via 10.0.10.1 dev eth1 weight 1 
	nexthop via 10.0.11.1 dev eth2 weight 1 
192.168.10.0/24 nhid 16 via 10.0.10.1 dev eth1 proto ospf metric 20 
192.168.20.0/24 dev eth3 proto kernel scope link src 192.168.20.1 
192.168.30.0/24 nhid 22 via 10.0.11.1 dev eth2 proto ospf metric 20 
192.168.50.0/24 dev eth4 proto kernel scope link src 192.168.50.11 
root@router2:~# 
root@router2:~# ip route | grep ospf
10.0.12.0/30 nhid 21 proto ospf metric 20 
192.168.10.0/24 nhid 16 via 10.0.10.1 dev eth1 proto ospf metric 20 
192.168.30.0/24 nhid 22 via 10.0.11.1 dev eth2 proto ospf metric 20 
root@router2:~#
```


router3:

```
oot@router3:~# vtysh

Hello, this is FRRouting (version 10.7.1).
Copyright 1996-2005 Kunihiro Ishiguro, et al.

router3# sh ip route
Codes: K - kernel route, C - connected, L - local, S - static,
       R - RIP, O - OSPF, I - IS-IS, B - BGP, E - EIGRP, N - NHRP,
       T - Table, v - VNC, V - VNC-Direct, A - Babel, F - PBR,
       f - OpenFabric, t - Table-Direct,
       > - selected route, * - FIB route, q - queued, r - rejected, b - backup
       t - trapped, o - offload failure

IPv4 unicast VRF default:
O   0.0.0.0/0 [110/1] via 10.0.12.1, eth2, weight 1, 02:21:22
K>* 0.0.0.0/0 [0/100] via 10.0.2.2, eth0, src 10.0.2.15, weight 1, 02:30:55
C>* 10.0.2.0/24 [0/100] is directly connected, eth0, weight 1, 02:30:55
K>* 10.0.2.2/32 [0/100] is directly connected, eth0, weight 1, 02:30:55
K>* 10.0.2.3/32 [0/100] is directly connected, eth0, weight 1, 02:30:55
L>* 10.0.2.15/32 is directly connected, eth0, weight 1, 02:30:55
O>* 10.0.10.0/30 [110/200] via 10.0.11.2, eth1, weight 1, 02:21:23
  *                        via 10.0.12.1, eth2, weight 1, 02:21:23
C>* 10.0.11.0/30 is directly connected, eth1, weight 1, 02:30:55
L>* 10.0.11.1/32 is directly connected, eth1, weight 1, 02:30:55
C>* 10.0.12.0/30 is directly connected, eth2, weight 1, 02:30:55
L>* 10.0.12.2/32 is directly connected, eth2, weight 1, 02:30:55
O>* 192.168.10.0/24 [110/200] via 10.0.12.1, eth2, weight 1, 02:21:23
O>* 192.168.20.0/24 [110/200] via 10.0.11.2, eth1, weight 1, 02:21:33
C>* 192.168.30.0/24 is directly connected, eth3, weight 1, 02:30:55
L>* 192.168.30.1/32 is directly connected, eth3, weight 1, 02:30:55
C>* 192.168.50.0/24 is directly connected, eth4, weight 1, 02:30:55
L>* 192.168.50.12/32 is directly connected, eth4, weight 1, 02:30:55
router3# 
router3# sh ip route ospf
Codes: K - kernel route, C - connected, L - local, S - static,
       R - RIP, O - OSPF, I - IS-IS, B - BGP, E - EIGRP, N - NHRP,
       T - Table, v - VNC, V - VNC-Direct, A - Babel, F - PBR,
       f - OpenFabric, t - Table-Direct,
       > - selected route, * - FIB route, q - queued, r - rejected, b - backup
       t - trapped, o - offload failure

IPv4 unicast VRF default:
O   0.0.0.0/0 [110/1] via 10.0.12.1, eth2, weight 1, 02:21:29
O>* 10.0.10.0/30 [110/200] via 10.0.11.2, eth1, weight 1, 02:21:30
  *                        via 10.0.12.1, eth2, weight 1, 02:21:30
O>* 192.168.10.0/24 [110/200] via 10.0.12.1, eth2, weight 1, 02:21:30
O>* 192.168.20.0/24 [110/200] via 10.0.11.2, eth1, weight 1, 02:21:40
router3# 
router3# exit
root@router3:~# ip r
default via 10.0.2.2 dev eth0 proto dhcp src 10.0.2.15 metric 100 
10.0.2.0/24 dev eth0 proto kernel scope link src 10.0.2.15 metric 100 
10.0.2.2 dev eth0 proto dhcp scope link src 10.0.2.15 metric 100 
10.0.2.3 dev eth0 proto dhcp scope link src 10.0.2.15 metric 100 
10.0.10.0/30 nhid 22 proto ospf metric 20 
	nexthop via 10.0.11.2 dev eth1 weight 1 
	nexthop via 10.0.12.1 dev eth2 weight 1 
10.0.11.0/30 dev eth1 proto kernel scope link src 10.0.11.1 
10.0.12.0/30 dev eth2 proto kernel scope link src 10.0.12.2 
192.168.10.0/24 nhid 23 via 10.0.12.1 dev eth2 proto ospf metric 20 
192.168.20.0/24 nhid 16 via 10.0.11.2 dev eth1 proto ospf metric 20 
192.168.30.0/24 dev eth3 proto kernel scope link src 192.168.30.1 
192.168.50.0/24 dev eth4 proto kernel scope link src 192.168.50.12 
root@router3:~#
root@router3:~# ip r | grep ospf
10.0.10.0/30 nhid 22 proto ospf metric 20 
192.168.10.0/24 nhid 23 via 10.0.12.1 dev eth2 proto ospf metric 20 
192.168.20.0/24 nhid 16 via 10.0.11.2 dev eth1 proto ospf metric 20 
root@router3:~# 
```

По таблицам маршрутизации выше видно, что:

1. На всех маршрутизаторах:
   
1.1 в таблицах маршрутизации всех маршрутизаторов есть маршруты на подсети - либо как непосредственно подключенные/connected/link
   (если эти сети подключены непосредственно к маршрутизатору),    либо как изученные по OSPF (если данные сети не подключены непосредственно):

```
192.168.10.0/24
192.168.20.0/24
192.168.30.0/24
10.0.10.0/30 
10.0.11.0/30
10.0.13.0/30
```

1.2 на всех маршрутизаторах есть в таблицах маршрутизации маршрут по умолчанию, направленный в сторону интерфейса eth0 - это маршрут в сторону маршрутизатора virtualbox - это стандартный выход в интернет (далее мы его отключим на router2 и router3, чтобы у всей сети был маршрут по умолчанию через router1).

В таблице маршрутизации frr эти маршруты по умолчанию видны как K (Kernel):

2. на router2 и router3 в таблице маршрутизации frr также есть маршрут по умолчанию, полученный через OSPF - так как на маршрутизаторе router1 включено анонсирование маршрута по умолчанию командой 'default-information originate always'. Но этот маршрут менее приоритетный и поэтому не используется:
   
```
router3# sh ip route
Codes: K - kernel route, C - connected, L - local, S - static,
       R - RIP, O - OSPF, I - IS-IS, B - BGP, E - EIGRP, N - NHRP,
       T - Table, v - VNC, V - VNC-Direct, A - Babel, F - PBR,
       f - OpenFabric, t - Table-Direct,
       > - selected route, * - FIB route, q - queued, r - rejected, b - backup
       t - trapped, o - offload failure

IPv4 unicast VRF default:
O   0.0.0.0/0 [110/1] via 10.0.12.1, eth2, weight 1, 02:21:22
K>* 0.0.0.0/0 [0/100] via 10.0.2.2, eth0, src 10.0.2.15, weight 1, 02:30:55
<...>
```


Удалим маршруты по умолчанию в сторону интерфейсов eth0/virtualbox на маршрутизаторах router2 и router3:

- отключаем использование маршрутов на интерфейсе eth0 в файле /etc/netplan/01-netcfg.yaml

- отключаем конфигурирование cloud-init и удаляем файл /etc/netplan/50-cloud-init.yaml

- применяем новую конфигурацию netplan


После этого в таблице маршрутизации router2 и router3 маршрут в сторону eth0 исчезает, поэтому появляется маршрут по умолчанию в сторону router1, полученный по OSPF:

```
root@router2:~# 
root@router2:~# ll /etc/netplan/
total 20
drwxr-xr-x  2 root root 4096 Nov 14 13:15 ./
drwxr-xr-x 98 root root 4096 Nov 15 10:38 ../
-rw-r--r--  1 root root   63 Oct 23  2025 01-netcfg.yaml
-rw-------  1 root root  391 Nov 14 13:14 50-cloud-init.yaml
-rw-r--r--  1 root root  259 Nov 14 13:15 50-vagrant.yaml
root@router2:~# 
root@router2:~# cat /etc/netplan/01-netcfg.yaml 
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
root@router2:~# 
root@router2:~# cat /etc/netplan/50-cloud-init.yaml 
# This file is generated from information provided by the datasource.  Changes
# to it will not persist across an instance reboot.  To disable cloud-init's
# network configuration capabilities, write a file
# /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg with the following:
# network: {config: disabled}
network:
    ethernets:
        enp0s3:
            dhcp4: true
    version: 2
root@router2:~# 
root@router2:~# cat /etc/netplan/50-vagrant.yaml
---
network:
  version: 2
  renderer: networkd
  ethernets:
    eth1:
      addresses:
      - 10.0.10.2/30
    eth2:
      addresses:
      - 10.0.11.2/30
    eth3:
      addresses:
      - 192.168.20.1/24
    eth4:
      addresses:
      - 192.168.50.11/24
root@router2:~# 
root@router2:~# 
root@router2:~# vi /etc/netplan/01-netcfg.yaml 
root@router2:~# 
root@router2:~# cat /etc/netplan/01-netcfg.yaml
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
      dhcp4-overrides:
          use-routes: false
      dhcp6: false
root@router2:~# 
root@router2:~# cat > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
network: {config: disabled}
root@router2:~# 
root@router2:~# rm /etc/netplan/50-cloud-init.yaml
root@router2:~# 
root@router2:~# netplan apply
root@router2:~# 
root@router2:~# ip r
default nhid 16 via 10.0.10.1 dev eth1 proto ospf metric 20 
10.0.2.0/24 dev eth0 proto kernel scope link src 10.0.2.15 metric 100 
10.0.2.3 dev eth0 proto dhcp scope link src 10.0.2.15 metric 100 
10.0.10.0/30 dev eth1 proto kernel scope link src 10.0.10.2 
10.0.11.0/30 dev eth2 proto kernel scope link src 10.0.11.2 
10.0.12.0/30 nhid 16 via 10.0.10.1 dev eth1 proto ospf metric 20 
192.168.10.0/24 nhid 16 via 10.0.10.1 dev eth1 proto ospf metric 20 
192.168.20.0/24 dev eth3 proto kernel scope link src 192.168.20.1 
192.168.30.0/24 nhid 16 via 10.0.10.1 dev eth1 proto ospf metric 20 
192.168.50.0/24 dev eth4 proto kernel scope link src 192.168.50.11 
root@router2:~#
root@router2:~# vtysh

Hello, this is FRRouting (version 10.7.1).
Copyright 1996-2005 Kunihiro Ishiguro, et al.

router2# show ip route
Codes: K - kernel route, C - connected, L - local, S - static,
       R - RIP, O - OSPF, I - IS-IS, B - BGP, E - EIGRP, N - NHRP,
       T - Table, v - VNC, V - VNC-Direct, A - Babel, F - PBR,
       f - OpenFabric, t - Table-Direct,
       > - selected route, * - FIB route, q - queued, r - rejected, b - backup
       t - trapped, o - offload failure

IPv4 unicast VRF default:
O>* 0.0.0.0/0 [110/1] via 10.0.10.1, eth1, weight 1, 00:13:21
C>* 10.0.2.0/24 [0/100] is directly connected, eth0, weight 1, 00:13:25
K>* 10.0.2.3/32 [0/100] is directly connected, eth0, weight 1, 00:13:25
L>* 10.0.2.15/32 is directly connected, eth0, weight 1, 00:13:25
C>* 10.0.10.0/30 is directly connected, eth1, weight 1, 00:13:25
L>* 10.0.10.2/32 is directly connected, eth1, weight 1, 00:13:25
C>* 10.0.11.0/30 is directly connected, eth2, weight 1, 00:13:25
L>* 10.0.11.2/32 is directly connected, eth2, weight 1, 00:13:25
O>* 10.0.12.0/30 [110/200] via 10.0.10.1, eth1, weight 1, 00:01:01
  *                        via 10.0.11.1, eth2, weight 1, 00:01:01
O>* 192.168.10.0/24 [110/200] via 10.0.10.1, eth1, weight 1, 00:13:22
C>* 192.168.20.0/24 is directly connected, eth3, weight 1, 00:13:25
L>* 192.168.20.1/32 is directly connected, eth3, weight 1, 00:13:25
O>* 192.168.30.0/24 [110/200] via 10.0.11.1, eth2, weight 1, 00:01:02
C>* 192.168.50.0/24 is directly connected, eth4, weight 1, 00:13:25
L>* 192.168.50.11/32 is directly connected, eth4, weight 1, 00:13:25
router2# 
```

На маршрутизаторе router3 делаем полностью аналогично.

```
root@router3:~# ll /etc/netplan/
total 20
drwxr-xr-x  2 root root 4096 Nov 14 13:16 ./
drwxr-xr-x 98 root root 4096 Nov 15 11:01 ../
-rw-r--r--  1 root root   63 Oct 23  2025 01-netcfg.yaml
-rw-------  1 root root  391 Nov 14 13:16 50-cloud-init.yaml
-rw-r--r--  1 root root  259 Nov 14 13:16 50-vagrant.yaml
root@router3:~# 
root@router3:~# cat /etc/netplan/01-netcfg.yaml
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
root@router3:~# 
root@router3:~# cat /etc/netplan/50-cloud-init.yaml
# This file is generated from information provided by the datasource.  Changes
# to it will not persist across an instance reboot.  To disable cloud-init's
# network configuration capabilities, write a file
# /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg with the following:
# network: {config: disabled}
network:
    ethernets:
        enp0s3:
            dhcp4: true
    version: 2
root@router3:~# 
root@router3:~# cat /etc/netplan/50-vagrant.yaml
---
network:
  version: 2
  renderer: networkd
  ethernets:
    eth1:
      addresses:
      - 10.0.11.1/30
    eth2:
      addresses:
      - 10.0.12.2/30
    eth3:
      addresses:
      - 192.168.30.1/24
    eth4:
      addresses:
      - 192.168.50.12/24
root@router3:~# 
root@router3:~# vi /etc/netplan/01-netcfg.yaml
root@router3:~# 
root@router3:~# cat > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
network: {config: disabled}
root@router3:~# 
root@router3:~# rm /etc/netplan/50-cloud-init.yaml
root@router3:~# 
root@router3:~# cat /etc/netplan/01-netcfg.yaml
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
      dhcp4-overrides:
          use-routes: false
      dhcp6: false
root@router3:~# 
root@router3:~# netplan apply

root@router3:~# 
root@router3:~# ip route
default nhid 23 via 10.0.12.1 dev eth2 proto ospf metric 20 
10.0.2.0/24 dev eth0 proto kernel scope link src 10.0.2.15 metric 100 
10.0.2.3 dev eth0 proto dhcp scope link src 10.0.2.15 metric 100 
10.0.10.0/30 nhid 22 proto ospf metric 20 
	nexthop via 10.0.11.2 dev eth1 weight 1 
	nexthop via 10.0.12.1 dev eth2 weight 1 
10.0.11.0/30 dev eth1 proto kernel scope link src 10.0.11.1 
10.0.12.0/30 dev eth2 proto kernel scope link src 10.0.12.2 
192.168.10.0/24 nhid 23 via 10.0.12.1 dev eth2 proto ospf metric 20 
192.168.20.0/24 nhid 16 via 10.0.11.2 dev eth1 proto ospf metric 20 
192.168.30.0/24 dev eth3 proto kernel scope link src 192.168.30.1 
192.168.50.0/24 dev eth4 proto kernel scope link src 192.168.50.12 
root@router3:~# 
root@router3:~# vtysh

Hello, this is FRRouting (version 10.7.1).
Copyright 1996-2005 Kunihiro Ishiguro, et al.

router3# ip route
% Unknown command: ip route
router3# show ip route
Codes: K - kernel route, C - connected, L - local, S - static,
       R - RIP, O - OSPF, I - IS-IS, B - BGP, E - EIGRP, N - NHRP,
       T - Table, v - VNC, V - VNC-Direct, A - Babel, F - PBR,
       f - OpenFabric, t - Table-Direct,
       > - selected route, * - FIB route, q - queued, r - rejected, b - backup
       t - trapped, o - offload failure

IPv4 unicast VRF default:
O>* 0.0.0.0/0 [110/1] via 10.0.12.1, eth2, weight 1, 00:00:33
C>* 10.0.2.0/24 [0/100] is directly connected, eth0, weight 1, 00:00:38
K>* 10.0.2.3/32 [0/100] is directly connected, eth0, weight 1, 00:00:38
L>* 10.0.2.15/32 is directly connected, eth0, weight 1, 00:00:38
O>* 10.0.10.0/30 [110/200] via 10.0.11.2, eth1, weight 1, 00:00:34
  *                        via 10.0.12.1, eth2, weight 1, 00:00:34
C>* 10.0.11.0/30 is directly connected, eth1, weight 1, 00:00:39
L>* 10.0.11.1/32 is directly connected, eth1, weight 1, 00:00:39
C>* 10.0.12.0/30 is directly connected, eth2, weight 1, 00:00:39
L>* 10.0.12.2/32 is directly connected, eth2, weight 1, 00:00:39
O>* 192.168.10.0/24 [110/200] via 10.0.12.1, eth2, weight 1, 00:00:34
O>* 192.168.20.0/24 [110/200] via 10.0.11.2, eth1, weight 1, 00:00:34
C>* 192.168.30.0/24 is directly connected, eth3, weight 1, 00:00:39
L>* 192.168.30.1/32 is directly connected, eth3, weight 1, 00:00:39
C>* 192.168.50.0/24 is directly connected, eth4, weight 1, 00:00:38
L>* 192.168.50.12/32 is directly connected, eth4, weight 1, 00:00:38
router3# 
```

Для обеспечения доступа в Интернет со всех хостов сети на router1 конфигурируем NAT средствами iptables, устанавливаем пакет iptables-persistent, сохраняем сонфигурацию созданную конфигурацию iptables для последующего автоматического применения при перезагрузках хоста router1:

```
root@router1:~# iptables -L -n -v
Chain INPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain FORWARD (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain OUTPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         
root@router1:~# 
root@router1:~# iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
root@router1:~# 
root@router1:~# iptables -t nat -L -n -v
Chain PREROUTING (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain INPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain OUTPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain POSTROUTING (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         
    2   160 MASQUERADE  all  --  *      eth0    0.0.0.0/0            0.0.0.0/0           
root@router1:~# 
root@router1:~# iptables-save
# Generated by iptables-save v1.8.7 on Sun Nov 15 15:12:27 2026
*nat
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -o eth0 -j MASQUERADE
COMMIT
# Completed on Sun Nov 15 15:12:27 2026
root@router1:~# 
root@router1:~# apt install iptables-persistant
<...>
The following additional packages will be installed:
  netfilter-persistent
The following NEW packages will be installed:
  iptables-persistent netfilter-persistent
<...>
Do you want to continue? [Y/n] y
<...>
root@router1:~# 
root@router1:~# iptables-save > /etc/iptables/rules.v4
root@router1:~# 
```

После сделанных конфигураций проверяем связность между всеми сетями, а также с внешним интернетом через анонсированный по протоколу OSPF с router1 маршрут по умолчанию:


1. с router2 проверяем доступность сетей 192.168.10.0/24 и 192.168.30/24, подключенных к маршрутизаторам router1 и router3 соответственно:

```
root@router2:~# ip r
default nhid 16 via 10.0.10.1 dev eth1 proto ospf metric 20 
10.0.2.0/24 dev eth0 proto kernel scope link src 10.0.2.15 metric 100 
10.0.2.3 dev eth0 proto dhcp scope link src 10.0.2.15 metric 100 
10.0.10.0/30 dev eth1 proto kernel scope link src 10.0.10.2 
10.0.11.0/30 dev eth2 proto kernel scope link src 10.0.11.2 
10.0.12.0/30 nhid 21 proto ospf metric 20 
	nexthop via 10.0.10.1 dev eth1 weight 1 
	nexthop via 10.0.11.1 dev eth2 weight 1 
192.168.10.0/24 nhid 16 via 10.0.10.1 dev eth1 proto ospf metric 20 
192.168.20.0/24 dev eth3 proto kernel scope link src 192.168.20.1 
192.168.30.0/24 nhid 22 via 10.0.11.1 dev eth2 proto ospf metric 20 
192.168.50.0/24 dev eth4 proto kernel scope link src 192.168.50.11 
root@router2:~# 
root@router2:~# ping 192.168.30.1
PING 192.168.30.1 (192.168.30.1) 56(84) bytes of data.
64 bytes from 192.168.30.1: icmp_seq=1 ttl=64 time=1.08 ms
64 bytes from 192.168.30.1: icmp_seq=2 ttl=64 time=1.03 ms
64 bytes from 192.168.30.1: icmp_seq=3 ttl=64 time=1.01 ms
64 bytes from 192.168.30.1: icmp_seq=4 ttl=64 time=1.09 ms
^C
--- 192.168.30.1 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3009ms
rtt min/avg/max/mdev = 1.014/1.054/1.092/0.031 ms
root@router2:~# 
root@router2:~# traceroute 192.168.30.1
traceroute to 192.168.30.1 (192.168.30.1), 30 hops max, 60 byte packets
 1  192.168.30.1 (192.168.30.1)  0.822 ms  0.726 ms  0.579 ms
root@router2:~# 
```

Выше по трейсу видно, что трафик идёт по прямому линку между router2 и router3.

Отключаем прямой линк eth2 между маршрутизаторами router2 и router3 - при этом изменятся маршрут на сеть 192.168.30.0/24,
но при этом связность сохраняется, и по трейсу видно, что трафик в сеть 192.168.30.0/24 стал идти через router1 и router3.
После тестирования восстанавливаем прямой линк eth2 между router2 и router3 - трафик в сеть 192.168.30.0/24 начинает опять идти по прямому линку между router2 и router3.

```
oot@router2:~# ip link set eth2 down
root@router2:~#
root@router2:~# ip route
default nhid 16 via 10.0.10.1 dev eth1 proto ospf metric 20 
10.0.2.0/24 dev eth0 proto kernel scope link src 10.0.2.15 metric 100 
10.0.2.3 dev eth0 proto dhcp scope link src 10.0.2.15 metric 100 
10.0.10.0/30 dev eth1 proto kernel scope link src 10.0.10.2 
10.0.11.0/30 nhid 16 via 10.0.10.1 dev eth1 proto ospf metric 20 
10.0.12.0/30 nhid 21 via 10.0.10.1 dev eth1 proto ospf metric 20 
192.168.10.0/24 nhid 16 via 10.0.10.1 dev eth1 proto ospf metric 20 
192.168.20.0/24 dev eth3 proto kernel scope link src 192.168.20.1 
192.168.30.0/24 nhid 16 via 10.0.10.1 dev eth1 proto ospf metric 20 
192.168.50.0/24 dev eth4 proto kernel scope link src 192.168.50.11 
root@router2:~# 
root@router2:~# ping 192.168.30.1
PING 192.168.30.1 (192.168.30.1) 56(84) bytes of data.
64 bytes from 192.168.30.1: icmp_seq=1 ttl=63 time=1.78 ms
64 bytes from 192.168.30.1: icmp_seq=2 ttl=63 time=2.10 ms
64 bytes from 192.168.30.1: icmp_seq=3 ttl=63 time=1.90 ms
^C
--- 192.168.30.1 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2005ms
rtt min/avg/max/mdev = 1.784/1.929/2.100/0.130 ms
root@router2:~# traceroute 192.168.30.1
traceroute to 192.168.30.1 (192.168.30.1), 30 hops max, 60 byte packets
 1  _gateway (10.0.10.1)  0.809 ms  0.752 ms  0.660 ms
 2  192.168.30.1 (192.168.30.1)  1.540 ms  1.443 ms  1.335 ms
root@router2:~# 
root@router2:~# ip link set eth2 up
root@router2:~# 
root@router2:~# ping 192.168.30.1
PING 192.168.30.1 (192.168.30.1) 56(84) bytes of data.
64 bytes from 192.168.30.1: icmp_seq=1 ttl=64 time=0.759 ms
64 bytes from 192.168.30.1: icmp_seq=2 ttl=64 time=0.893 ms
^C
--- 192.168.30.1 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1020ms
rtt min/avg/max/mdev = 0.759/0.826/0.893/0.067 ms
root@router2:~# 
root@router2:~# traceroute 192.168.30.1
traceroute to 192.168.30.1 (192.168.30.1), 30 hops max, 60 byte packets
 1  192.168.30.1 (192.168.30.1)  1.082 ms  0.892 ms  0.803 ms
root@router2:~# 
```

Аналогичные результаты для маршрутизаторов router1 и router3:

```
root@router1:~# ping 192.168.20.1
PING 192.168.20.1 (192.168.20.1) 56(84) bytes of data.
64 bytes from 192.168.20.1: icmp_seq=1 ttl=64 time=1.13 ms
64 bytes from 192.168.20.1: icmp_seq=2 ttl=64 time=1.18 ms
^C
--- 192.168.20.1 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1003ms
rtt min/avg/max/mdev = 1.129/1.155/1.182/0.026 ms
root@router1:~# traceroute 192.168.20.1
traceroute to 192.168.20.1 (192.168.20.1), 30 hops max, 60 byte packets
 1  192.168.20.1 (192.168.20.1)  0.908 ms  0.710 ms  0.646 ms
root@router1:~# 
root@router1:~# ping 192.168.30.1
PING 192.168.30.1 (192.168.30.1) 56(84) bytes of data.
64 bytes from 192.168.30.1: icmp_seq=1 ttl=64 time=1.18 ms
64 bytes from 192.168.30.1: icmp_seq=2 ttl=64 time=0.900 ms
64 bytes from 192.168.30.1: icmp_seq=3 ttl=64 time=0.976 ms
^C
--- 192.168.30.1 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2005ms
rtt min/avg/max/mdev = 0.900/1.017/1.176/0.116 ms
root@router1:~# traceroute 192.168.30.1
traceroute to 192.168.30.1 (192.168.30.1), 30 hops max, 60 byte packets
 1  192.168.30.1 (192.168.30.1)  1.040 ms  0.916 ms  0.696 ms
root@router1:~#


router3# ping 192.168.10.1
PING 192.168.10.1 (192.168.10.1) 56(84) bytes of data.
64 bytes from 192.168.10.1: icmp_seq=1 ttl=64 time=1.00 ms
64 bytes from 192.168.10.1: icmp_seq=2 ttl=64 time=1.02 ms
^C
--- 192.168.10.1 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1002ms
rtt min/avg/max/mdev = 1.000/1.010/1.020/0.010 ms
router3# traceroute 192.168.10.1
traceroute to 192.168.10.1 (192.168.10.1), 30 hops max, 60 byte packets
 1  192.168.10.1 (192.168.10.1)  0.799 ms  0.738 ms  0.517 ms
router3# 
outer3# ping 192.168.20.1
PING 192.168.20.1 (192.168.20.1) 56(84) bytes of data.
64 bytes from 192.168.20.1: icmp_seq=1 ttl=63 time=2.18 ms
64 bytes from 192.168.20.1: icmp_seq=2 ttl=63 time=2.00 ms
64 bytes from 192.168.20.1: icmp_seq=3 ttl=63 time=2.09 ms
64 bytes from 192.168.20.1: icmp_seq=4 ttl=63 time=1.82 ms
64 bytes from 192.168.20.1: icmp_seq=5 ttl=63 time=2.07 ms
^C
--- 192.168.20.1 ping statistics ---
5 packets transmitted, 5 received, 0% packet loss, time 4011ms
rtt min/avg/max/mdev = 1.816/2.030/2.180/0.121 ms
router3#
router3# traceroute 192.168.20.1
traceroute to 192.168.20.1 (192.168.20.1), 30 hops max, 60 byte packets
 1  192.168.20.1 (192.168.20.1)  0.938 ms  0.826 ms  0.955 ms
router3# 
```

Проверяем доступ в публичный интернет с маршрутизаторов router2 и router3 через анонсированный с маршрутизатора router1 маршрута по умолчанию:

```
root@router2:~# ip r
default nhid 16 via 10.0.10.1 dev eth1 proto ospf metric 20 
10.0.2.0/24 dev eth0 proto kernel scope link src 10.0.2.15 metric 100 
10.0.2.3 dev eth0 proto dhcp scope link src 10.0.2.15 metric 100 
10.0.10.0/30 dev eth1 proto kernel scope link src 10.0.10.2 
10.0.11.0/30 dev eth2 proto kernel scope link src 10.0.11.2 
10.0.12.0/30 nhid 21 proto ospf metric 20 
	nexthop via 10.0.10.1 dev eth1 weight 1 
	nexthop via 10.0.11.1 dev eth2 weight 1 
192.168.10.0/24 nhid 16 via 10.0.10.1 dev eth1 proto ospf metric 20 
192.168.20.0/24 dev eth3 proto kernel scope link src 192.168.20.1 
192.168.30.0/24 nhid 22 via 10.0.11.1 dev eth2 proto ospf metric 20 
192.168.50.0/24 dev eth4 proto kernel scope link src 192.168.50.11 
root@router2:~# 
root@router2:~# ping 8.8.8.8
PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.
64 bytes from 8.8.8.8: icmp_seq=1 ttl=254 time=91.4 ms
64 bytes from 8.8.8.8: icmp_seq=2 ttl=254 time=91.4 ms
64 bytes from 8.8.8.8: icmp_seq=3 ttl=254 time=91.3 ms
^C
--- 8.8.8.8 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2005ms
rtt min/avg/max/mdev = 91.260/91.326/91.359/0.046 ms
root@router2:~# 
root@router2:~# traceroute 8.8.8.8
traceroute to 8.8.8.8 (8.8.8.8), 30 hops max, 60 byte packets
 1  _gateway (10.0.10.1)  1.202 ms  1.064 ms  0.993 ms
 2  10.0.2.2 (10.0.2.2)  1.649 ms  1.573 ms  1.509 ms
 3  172.17.15.1 (172.17.15.1)  1.781 ms  1.424 ms  1.600 ms
 4  192.168.10.14 (192.168.10.14)  1.773 ms  1.711 ms  1.570 ms
 5  192.168.200.7 (192.168.200.7)  68.334 ms  68.269 ms  67.889 ms
 6  192.168.200.6 (192.168.200.6)  67.674 ms  68.585 ms  68.488 ms
 7  192.168.1.3 (192.168.1.3)  70.894 ms  70.516 ms  70.283 ms
 8  Moscow-GIN-PE11-ae4-2499.rosprint.net (195.151.21.1)  70.497 ms  70.485 ms  70.363 ms
 9  Umbrella-PE01-ae1-0.rosprint.net (195.151.241.162)  73.351 ms  73.051 ms  73.003 ms
10  Moscow-GIN-IX01-et-2-0-5-0.rosprint.net (195.151.233.53)  71.437 ms  71.392 ms  71.255 ms
11  * * 178.18.225.111.ix.dataix.eu (178.18.225.111)  118.158 ms
12  * * *
13  72.14.237.55 (72.14.237.55)  93.571 ms 216.239.48.77 (216.239.48.77)  96.288 ms 72.14.237.55 (72.14.237.55)  95.711 ms
14  142.251.65.81 (142.251.65.81)  106.625 ms 142.251.48.39 (142.251.48.39)  95.249 ms 142.251.236.71 (142.251.236.71)  93.234 ms
15  dns.google (8.8.8.8)  97.235 ms  109.470 ms  92.984 ms
root@router2:~#
```

Выше по трейсу видно, что трафик идёт по прямому линку между router2 и router1.

Отключаем прямой линк eth1 между маршрутизаторами router2 и router1 - при этом дефолтынй маршрут,
но при этом связность сохраняется, и по трейсу видно, что трафик в сеть 8.8.8.8 стал идти через router3 и затем через router1.
После тестирования восстанавливаем прямой линк eth1 между router1 и router3 - трафик в сеть 8.8.8.8 начинает опять идти по прямому линку между router2 и router1.

```
root@router2:~# ip r
default nhid 22 via 10.0.11.1 dev eth2 proto ospf metric 20 
10.0.2.0/24 dev eth0 proto kernel scope link src 10.0.2.15 metric 100 
10.0.2.3 dev eth0 proto dhcp scope link src 10.0.2.15 metric 100 
10.0.10.0/30 nhid 22 via 10.0.11.1 dev eth2 proto ospf metric 20 
10.0.11.0/30 dev eth2 proto kernel scope link src 10.0.11.2 
10.0.12.0/30 nhid 21 via 10.0.11.1 dev eth2 proto ospf metric 20 
192.168.10.0/24 nhid 22 via 10.0.11.1 dev eth2 proto ospf metric 20 
192.168.20.0/24 dev eth3 proto kernel scope link src 192.168.20.1 
192.168.30.0/24 nhid 22 via 10.0.11.1 dev eth2 proto ospf metric 20 
192.168.50.0/24 dev eth4 proto kernel scope link src 192.168.50.11 
root@router2:~#
root@router2:~# ping 8.8.8.8
PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.
64 bytes from 8.8.8.8: icmp_seq=1 ttl=253 time=92.6 ms
64 bytes from 8.8.8.8: icmp_seq=2 ttl=253 time=91.9 ms
64 bytes from 8.8.8.8: icmp_seq=3 ttl=253 time=92.3 ms
64 bytes from 8.8.8.8: icmp_seq=4 ttl=253 time=92.7 ms
^C
--- 8.8.8.8 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3006ms
rtt min/avg/max/mdev = 91.897/92.373/92.713/0.325 ms
root@router2:~#
root@router2:~# ip link set eth1 down
root@router2:~# 
root@router2:~# traceroute 8.8.8.8
traceroute to 8.8.8.8 (8.8.8.8), 30 hops max, 60 byte packets
 1  _gateway (10.0.11.1)  1.190 ms  1.061 ms  0.995 ms
 2  10.0.12.1 (10.0.12.1)  1.668 ms  1.592 ms  1.522 ms
 3  10.0.2.2 (10.0.2.2)  2.959 ms  2.489 ms  2.408 ms
 4  172.17.15.1 (172.17.15.1)  2.270 ms  1.979 ms  2.367 ms
 5  192.168.10.14 (192.168.10.14)  3.590 ms  3.460 ms  3.394 ms
 6  192.168.200.7 (192.168.200.7)  69.326 ms  69.414 ms  69.337 ms
 7  192.168.200.6 (192.168.200.6)  69.302 ms  71.235 ms  71.181 ms
 8  192.168.1.3 (192.168.1.3)  74.471 ms  71.379 ms  71.202 ms
 9  Moscow-GIN-PE11-ae4-2499.rosprint.net (195.151.21.1)  72.773 ms  71.108 ms  71.273 ms
10  Umbrella-PE01-ae1-0.rosprint.net (195.151.241.162)  71.600 ms  72.267 ms  71.760 ms
11  Moscow-GIN-IX01-et-2-0-5-0.rosprint.net (195.151.233.53)  71.294 ms  71.520 ms  72.386 ms
12  * 178.18.225.111.ix.dataix.eu (178.18.225.111)  108.503 ms *
13  178.18.235.253 (178.18.235.253)  94.835 ms  96.715 ms  95.040 ms
14  216.239.48.77 (216.239.48.77)  93.914 ms 192.178.248.215 (192.178.248.215)  94.141 ms 216.239.57.151 (216.239.57.151)  96.668 ms
15  142.251.48.45 (142.251.48.45)  94.418 ms 142.251.236.73 (142.251.236.73)  93.705 ms 172.253.72.123 (172.253.72.123)  96.120 ms
16  dns.google (8.8.8.8)  93.605 ms  95.599 ms  97.297 ms
root@router2:~#
root@router2:~# ip link set eth1 up
root@router2:~# 
root@router2:~# traceroute 8.8.8.8
traceroute to 8.8.8.8 (8.8.8.8), 30 hops max, 60 byte packets
 1  _gateway (10.0.10.1)  0.977 ms  0.865 ms  0.682 ms
 2  10.0.2.2 (10.0.2.2)  1.529 ms  1.715 ms  1.637 ms
 3  172.17.15.1 (172.17.15.1)  1.489 ms  1.789 ms  1.712 ms
 4  192.168.10.14 (192.168.10.14)  1.650 ms  1.999 ms  1.931 ms
 5  192.168.200.7 (192.168.200.7)  68.229 ms  68.154 ms  67.971 ms
 6  192.168.200.6 (192.168.200.6)  67.902 ms  68.023 ms  67.954 ms
 7  192.168.1.3 (192.168.1.3)  70.320 ms  70.238 ms  70.179 ms
 8  Moscow-GIN-PE11-ae4-2499.rosprint.net (195.151.21.1)  75.278 ms  71.602 ms  73.290 ms
 9  Umbrella-PE01-ae1-0.rosprint.net (195.151.241.162)  72.264 ms  72.198 ms  72.347 ms
10  Moscow-GIN-IX01-et-2-0-5-0.rosprint.net (195.151.233.53)  72.267 ms  71.893 ms  72.038 ms
11  * 178.18.225.111.ix.dataix.eu (178.18.225.111)  140.670 ms  96.455 ms
12  178.18.235.253 (178.18.235.253)  97.638 ms  95.564 ms  95.720 ms
13  216.239.48.77 (216.239.48.77)  96.066 ms 192.178.248.215 (192.178.248.215)  97.196 ms 72.14.237.55 (72.14.237.55)  93.928 ms
14  172.253.72.123 (172.253.72.123)  98.045 ms 142.251.48.43 (142.251.48.43)  92.747 ms 142.251.48.39 (142.251.48.39)  93.300 ms
15  dns.google (8.8.8.8)  92.012 ms  93.778 ms  94.918 ms
root@router2:~# 
```

Меняем cost прямого канала между маршрутизаторами router2 и router3:

```
outer2# traceroute 192.168.30.1
traceroute to 192.168.30.1 (192.168.30.1), 30 hops max, 60 byte packets
 1  192.168.30.1 (192.168.30.1)  0.845 ms  0.804 ms  0.728 ms
router2# 
router2# conf t
router2(config)# int eth2
% Configuration applied with notes:
No changes found to be committed!
router2(config-if)# int eth2
% Configuration applied with notes:
No changes found to be committed!
router2(config-if)# ip ospf cost 1000
router2(config-if)# exit
router2(config)# 
router2(config)# exit
router2# 
router2# traceroute 192.168.30.1
traceroute to 192.168.30.1 (192.168.30.1), 30 hops max, 60 byte packets
 1  _gateway (10.0.10.1)  0.899 ms  0.807 ms  0.750 ms
 2  192.168.30.1 (192.168.30.1)  1.967 ms  1.905 ms  1.844 ms
router2# 
router2# show ip route ospf
Codes: K - kernel route, C - connected, L - local, S - static,
       R - RIP, O - OSPF, I - IS-IS, B - BGP, E - EIGRP, N - NHRP,
       T - Table, v - VNC, V - VNC-Direct, A - Babel, F - PBR,
       f - OpenFabric, t - Table-Direct,
       > - selected route, * - FIB route, q - queued, r - rejected, b - backup
       t - trapped, o - offload failure

IPv4 unicast VRF default:
O>* 0.0.0.0/0 [110/1] via 10.0.10.1, eth1, weight 1, 00:13:56
O>* 10.0.12.0/30 [110/200] via 10.0.10.1, eth1, weight 1, 00:01:38
O>* 192.168.10.0/24 [110/200] via 10.0.10.1, eth1, weight 1, 00:13:57
O>* 192.168.30.0/24 [110/300] via 10.0.10.1, eth1, weight 1, 00:01:38
router2# 


router3# traceroute 192.168.20.1
traceroute to 192.168.20.1 (192.168.20.1), 30 hops max, 60 byte packets
 1  192.168.20.1 (192.168.20.1)  1.070 ms  0.955 ms  1.135 ms
router3#
router3# show ip route ospf
Codes: K - kernel route, C - connected, L - local, S - static,
       R - RIP, O - OSPF, I - IS-IS, B - BGP, E - EIGRP, N - NHRP,
       T - Table, v - VNC, V - VNC-Direct, A - Babel, F - PBR,
       f - OpenFabric, t - Table-Direct,
       > - selected route, * - FIB route, q - queued, r - rejected, b - backup
       t - trapped, o - offload failure

IPv4 unicast VRF default:
O>* 0.0.0.0/0 [110/1] via 10.0.12.1, eth2, weight 1, 01:26:40
O>* 10.0.10.0/30 [110/200] via 10.0.11.2, eth1, weight 1, 00:00:13
  *                        via 10.0.12.1, eth2, weight 1, 00:00:13
O>* 192.168.10.0/24 [110/200] via 10.0.12.1, eth2, weight 1, 01:26:41
O>* 192.168.20.0/24 [110/200] via 10.0.11.2, eth1, weight 1, 00:00:13
router3# 
router3# conf t
router3(config)# int eth1
% Configuration applied with notes:
No changes found to be committed!
router3(config-if)# ip ospf cost 1000
router3(config-if)# exit
router3(config)# traceroute 192.168.20.1
% Unknown command: traceroute 192.168.20.1
router3(config)# exit
router3# traceroute 192.168.20.1
traceroute to 192.168.20.1 (192.168.20.1), 30 hops max, 60 byte packets
 1  _gateway (10.0.12.1)  1.038 ms  0.927 ms  0.861 ms
 2  192.168.20.1 (192.168.20.1)  1.817 ms  1.815 ms  1.764 ms
router3#
router3# show ip route ospf
Codes: K - kernel route, C - connected, L - local, S - static,
       R - RIP, O - OSPF, I - IS-IS, B - BGP, E - EIGRP, N - NHRP,
       T - Table, v - VNC, V - VNC-Direct, A - Babel, F - PBR,
       f - OpenFabric, t - Table-Direct,
       > - selected route, * - FIB route, q - queued, r - rejected, b - backup
       t - trapped, o - offload failure

IPv4 unicast VRF default:
O>* 0.0.0.0/0 [110/1] via 10.0.12.1, eth2, weight 1, 01:25:14
O>* 10.0.10.0/30 [110/200] via 10.0.12.1, eth2, weight 1, 00:01:17
O>* 192.168.10.0/24 [110/200] via 10.0.12.1, eth2, weight 1, 01:25:15
O>* 192.168.20.0/24 [110/300] via 10.0.12.1, eth2, weight 1, 00:01:17
router3# 
```

Все выполненные вручную задачи сведены в ansible playbook, выполняющий полностью автоматическое конфигурирование:

```
[admin_insta11@mv334 ospf_lab]$ cat ansible/playbook.yml 
---
- name: Task 1 - Disable Cloud-init on all routers
  hosts: all
  become: true
  tasks:

    # ------------------------------------------------------------------
    # ЭТАП 1: Отключаем cloud-init, чтобы он не затирал наши конфиги
    # ВСТАВЛЯТЬ СТРОГО В САМОЕ НАЧАЛО
    # ------------------------------------------------------------------
    
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

- name: Play 2 - Set up NAT on router1
  hosts: all
  become: true
  tasks:
    - name: Set up NAT on router1
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
      when: inventory_hostname == "router1"

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
      when: inventory_hostname == "router1"

    - name: Enable and start iptables-nat service
      systemd:
        name: iptables-nat
        enabled: true
        state: started
        daemon_reload: true
      when: inventory_hostname == "router1"


- name: Play 3 - Disable ufw firewall and Enable packets forwarding
  hosts: all
  become: true
  tasks:
  #Отключаем UFW и удаляем его из автозагрузки
  - name: disable ufw service
    service:
      name: ufw
      state: stopped
      enabled: false

  # Включаем маршрутизацию транзитных пакетов
  - name: set up forward packages across routers
    sysctl:
      name: net.ipv4.conf.all.forwarding
      value: '1'
      state: present


- name: Play 4 - Install and configure FRR
  hosts: all
  become: true
  tasks:
  # Каталог /etc/apt/keyrings создаём, если его нет
  - name: ensure keyrings dir exists
    ansible.builtin.file:
      path: "/etc/apt/keyrings"
      state: directory
      mode: "0755"

  # Скачиваем ключ репозитория FRR
  - name: download frr gpg key
    ansible.builtin.get_url:
      url: "https://deb.frrouting.org/frr/keys.asc"
      dest: "/etc/apt/keyrings/frr-ascii.asc"
      mode: "0644"

  # Разармориваем ключ в бинарный keyring
  - name: dearmor frr gpg key
    ansible.builtin.command:
      cmd: "gpg --dearmor -o /etc/apt/keyrings/frr.gpg /etc/apt/keyrings/frr-ascii.asc"
      creates: "/etc/apt/keyrings/frr.gpg"

  - name: add frr repo
    ansible.builtin.apt_repository:
      repo: "deb [signed-by=/etc/apt/keyrings/frr.gpg] https://deb.frrouting.org/frr {{ ansible_distribution_release }} frr-stable"
      state: present

  
  # Обновляем пакеты и устанавливаем FRR
  - name: install FRR packages
    apt:
      name: 
        - frr
        - frr-pythontools
      state: present
      update_cache: true

  # Включаем маршрутизацию транзитных пакетов
  - name: set up forward packages across routers
    sysctl:
      name: net.ipv4.conf.all.forwarding
      value: '1'
      state: present
  
  # Копируем файл daemons на хосты, указываем владельца и права
  - name: base set up OSPF 
    template:
      src: daemons
      dest: /etc/frr/daemons
      owner: frr
      group: frr
      mode: 0640

  # Копируем файлы frr.conf на хосты, указываем владельца и права
  - name: add frr configurations to each host
    template:
      src: "frr-{{ inventory_hostname }}.conf"
      dest: "/etc/frr/frr.conf"
      owner: frr
      group: frr
      mode: "0640"

  # Перезапускам FRR и добавляем в автозагрузку
  - name: restart FRR
    service:
      name: frr
      state: restarted
      enabled: true


- name: Play 5 - Disable default route (except router1)
  hosts: all
  become: true
  tasks:
    - name: disable default route
      template:
        src: "01-netcfg.yaml"
        dest: "/etc/netplan/01-netcfg.yaml"
        owner: root
        group: root
        mode: "0644"
      when: inventory_hostname != "router1"
    #  when: inventory_hostname not in ["inetRouter", "inetRouter2"]

    # netplan try интерактивен и будет висеть. Для автоматизации используем apply.
    # С try плейбук не пройдёт без ручного подтверждения.
    - name: apply netplan config
      command: netplan apply
      when: inventory_hostname != "router1"


- name: Play 6 - Reboot hosts
  hosts: all
  become: true
  tasks:

    - name: restart all hosts
      reboot:
        reboot_timeout: 600


- name: Play 7 - Install traceroute
  hosts: all
  become: true
  tasks:
    - name: wait for OSPF default route
      command: ip route show default
      register: rt
      until: "rt.stdout | length > 0"
      retries: 12
      delay: 10
      when: inventory_hostname != "router1"

    - name: Install traceroute
      apt:
        name: traceroute
        state: present
        update_cache: true

```


Общая структура проекта и остальные файлы приведены ниже:

```
[admin_insta11@mv334 ospf_lab]$ tree
.
├── ansible
│   ├── ansible.cfg
│   ├── hosts
│   ├── playbook.yml
│   └── templates
│       ├── 01-netcfg.yaml
│       ├── daemons
│       ├── frr-router1.conf
│       ├── frr-router2.conf
│       ├── frr-router3.conf
│       └── iptables_rules.ipv4
└── Vagrantfile

2 directories, 10 files
[admin_insta11@mv334 ospf_lab]$ 
[admin_insta11@mv334 ospf_lab]$ 
[admin_insta11@mv334 ospf_lab]$ cat ansible/templates/01-netcfg.yaml 
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
      dhcp4-overrides:
          use-routes: false
      dhcp6: false
[admin_insta11@mv334 ospf_lab]$ 
[admin_insta11@mv334 ospf_lab]$ 
[admin_insta11@mv334 ospf_lab]$ cat ansible/templates/daemons 
# This file tells the frr package which daemons to start.
#
# Sample configurations for these daemons can be found in
# /usr/share/doc/frr/examples/.
#
# ATTENTION:
#
# When activating a daemon for the first time, a config file, even if it is
# empty, has to be present *and* be owned by the user and group "frr", else
# the daemon will not be started by /etc/init.d/frr. The permissions should
# be u=rw,g=r,o=.
# When using "vtysh" such a config file is also needed. It should be owned by
# group "frrvty" and set to ug=rw,o= though. Check /etc/pam.d/frr, too.
#
# The watchfrr, zebra and staticd daemons are always started.
#
bgpd=yes
ospfd=yes
ospf6d=no
ripd=no
ripngd=no
isisd=no
pimd=no
pim6d=no
ldpd=no
nhrpd=no
eigrpd=no
babeld=no
sharpd=no
pbrd=no
bfdd=no
fabricd=no
vrrpd=no
pathd=no

#
# If this option is set the /etc/init.d/frr script automatically loads
# the config via "vtysh -b" when the servers are started.
# Check /etc/pam.d/frr if you intend to use "vtysh"!
#
vtysh_enable=yes
zebra_options="  -A 127.0.0.1 -s 90000000"
mgmtd_options="  -A 127.0.0.1"
bgpd_options="   -A 127.0.0.1"
ospfd_options="  -A 127.0.0.1"
ospf6d_options=" -A ::1"
ripd_options="   -A 127.0.0.1"
ripngd_options=" -A ::1"
isisd_options="  -A 127.0.0.1"
pimd_options="   -A 127.0.0.1"
pim6d_options="  -A ::1"
ldpd_options="   -A 127.0.0.1"
nhrpd_options="  -A 127.0.0.1"
eigrpd_options=" -A 127.0.0.1"
babeld_options=" -A 127.0.0.1"
sharpd_options=" -A 127.0.0.1"
pbrd_options="   -A 127.0.0.1"
staticd_options="-A 127.0.0.1"
bfdd_options="   -A 127.0.0.1"
fabricd_options="-A 127.0.0.1"
vrrpd_options="  -A 127.0.0.1"
pathd_options="  -A 127.0.0.1"


# If you want to pass a common option to all daemons, you can use the
# "frr_global_options" variable.
#
#frr_global_options=""


# The list of daemons to watch is automatically generated by the init script.
# This variable can be used to pass options to watchfrr that will be passed
# prior to the daemon list.
#
# To make watchfrr create/join the specified netns, add the the "--netns"
# option here. It will only have an effect in /etc/frr/<somename>/daemons, and
# you need to start FRR with "/usr/lib/frr/frrinit.sh start <somename>".
#
#watchfrr_options=""


# configuration profile
#
#frr_profile="traditional"
#frr_profile="datacenter"


# This is the maximum number of FD's that will be available.  Upon startup this
# is read by the control files and ulimit is called.  Uncomment and use a
# reasonable value for your setup if you are expecting a large number of peers
# in say BGP.
#
#MAX_FDS=1024

# Uncomment this option if you want to run FRR as a non-root user. Note that
# you should know what you are doing since most of the daemons need root
# to work. This could be useful if you want to run FRR in a container
# for instance.
# FRR_NO_ROOT="yes"

# For any daemon, you can specify a "wrap" command to start instead of starting
# the daemon directly. This will simply be prepended to the daemon invocation.
# These variables have the form daemon_wrap, where 'daemon' is the name of the
# daemon (the same pattern as the daemon_options variables).
#
# Note that when daemons are started, they are told to daemonize with the `-d`
# option. This has several implications. For one, the init script expects that
# when it invokes a daemon, the invocation returns immediately. If you add a
# wrap command here, it must comply with this expectation and daemonize as
# well, or the init script will never return. Furthermore, because daemons are
# themselves daemonized with -d, you must ensure that your wrapper command is
# capable of following child processes after a fork() if you need it to do so.
#
# If your desired wrapper does not support daemonization, you can wrap it with
# a utility program that daemonizes programs, such as 'daemonize'. An example
# of this might look like:
#
# bgpd_wrap="/usr/bin/daemonize /usr/bin/mywrapper"
#
# This is particularly useful for programs which record processes but lack
# daemonization options, such as perf and rr.
#
# If you wish to wrap all daemons in the same way, you may set the "all_wrap"
# variable.
#
#all_wrap=""
[admin_insta11@mv334 ospf_lab]$ cat ansible/templates/frr-router1.conf 
frr version 10.7.1
frr defaults traditional
hostname router1
log syslog informational
log file /var/log/frr/frr.log
service integrated-vtysh-config
!
interface eth1
 description r1-r2
 ip address 10.0.10.1/30
 ip ospf dead-interval 30
 ip ospf mtu-ignore
exit
!
interface eth2
 description r1-r3
 ip address 10.0.12.1/30
 ip ospf dead-interval 30
 ip ospf mtu-ignore
exit
!
interface eth3
 description net_router1
 ip address 192.168.10.1/24
 ip ospf dead-interval 30
 ip ospf mtu-ignore
exit
!
router ospf
 ospf router-id 1.1.1.1
 network 10.0.10.0/30 area 0
 network 10.0.12.0/30 area 0
 network 192.168.10.0/24 area 0
 neighbor 10.0.10.2
 neighbor 10.0.12.2
 default-information originate always
exit
!
[admin_insta11@mv334 ospf_lab]$ 
[admin_insta11@mv334 ospf_lab]$ cat ansible/templates/frr-router2.conf 
rr version 10.7.1
frr defaults traditional
hostname router2
log syslog informational
log file /var/log/frr/frr.log
service integrated-vtysh-config
!
interface eth1
 description r1-r2
 ip address 10.0.10.2/30
 ip ospf dead-interval 30
 ip ospf mtu-ignore
exit
!
interface eth2
 description r2-r3
 ip address 10.0.11.2/30
 ip ospf dead-interval 30
 ip ospf mtu-ignore
exit
!
interface eth3
 description net_router2
 ip address 192.168.20.1/24
 ip ospf dead-interval 30
 ip ospf mtu-ignore
exit
!
router ospf
 ospf router-id 2.2.2.2
 network 10.0.10.0/30 area 0
 network 10.0.11.0/30 area 0
 network 192.168.20.0/24 area 0
 neighbor 10.0.10.1
 neighbor 10.0.11.1
exit
!
[admin_insta11@mv334 ospf_lab]$ cat ansible/templates/frr-router3.conf 
frr version 10.7.1
frr defaults traditional
hostname router3
log syslog informational
log file /var/log/frr/frr.log
service integrated-vtysh-config
!
interface eth1
 description r3-r2
 ip address 10.0.11.1/30
 ip ospf dead-interval 30
 ip ospf mtu-ignore
exit
!
interface eth2
 description r3-r1
 ip address 10.0.12.2/30
 ip ospf dead-interval 30
 ip ospf mtu-ignore
exit
!
interface eth3
 description net_router3
 ip address 192.168.30.1/24
 ip ospf dead-interval 30
 ip ospf mtu-ignore
exit
!
router ospf
 ospf router-id 3.3.3.3
 network 10.0.11.0/30 area 0
 network 10.0.12.0/30 area 0
 network 192.168.30.0/24 area 0
 neighbor 10.0.11.2
 neighbor 10.0.12.1
exit
!
[admin_insta11@mv334 ospf_lab]$ cat ansible/templates/iptables_rules.ipv4 
# Generated by iptables-save v1.8.7 on Sun Nov 15 15:13:49 2026
*nat
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -o eth0 -j MASQUERADE
COMMIT
# Completed on Sun Nov 15 15:13:49 2026
[admin_insta11@mv334 ospf_lab]$ 
[admin_insta11@mv334 ospf_lab]$ cat ansible/hosts 
[routers]
router1 ansible_host=192.168.50.10 ansible_user=vagrant ansible_ssh_private_key_file=.vagrant/machines/router1/virtualbox/private_key 
router2 ansible_host=192.168.50.11 ansible_user=vagrant ansible_ssh_private_key_file=.vagrant/machines/router2/virtualbox/private_key 
router3 ansible_host=192.168.50.12 ansible_user=vagrant ansible_ssh_private_key_file=.vagrant/machines/router3/virtualbox/private_key
[admin_insta11@mv334 ospf_lab]$ 
[admin_insta11@mv334 ospf_lab]$ cat ansible/ansible.cfg 
[defaults]
#Отключение проверки ключа хоста
host_key_checking = false
#Указываем имя файла инвентаризации
inventory = hosts
#Отключаем игнорирование предупреждений
command_warnings= false
[admin_insta11@mv334 ospf_lab]$ 
```

После создания ВМ задачи провизионинга выполняются успешно:

```
[admin_insta11@mv334 ospf_lab]$ VAGRANT_BOX=ubuntu-22.04-virtualbox vagrant up --provision
Bringing machine 'router1' up with 'virtualbox' provider...
Bringing machine 'router2' up with 'virtualbox' provider...
Bringing machine 'router3' up with 'virtualbox' provider...
<...>
==> router3: Running provisioner: ansible...
    router3: Running ansible-playbook...

PLAY [Task 1 - Disable Cloud-init on all routers] ******************************

TASK [Gathering Facts] *********************************************************
ok: [router2]
ok: [router3]
ok: [router1]

TASK [Disable cloud-init network configuration] ********************************
ok: [router2]
ok: [router3]
ok: [router1]

TASK [Clean cloud-init network cache (автоматически убирает/очищает 50-cloud-init.yaml)] ***
ok: [router1]
ok: [router3]
ok: [router2]

PLAY [Play 2 - Set up NAT on router1] ******************************************

TASK [Gathering Facts] *********************************************************
ok: [router3]
ok: [router1]
ok: [router2]

TASK [Set up NAT on router1] ***************************************************
skipping: [router2] => (item={'src': 'iptables_rules.ipv4', 'dest': '/etc/iptables_rules.ipv4', 'mode': '0644'}) 
skipping: [router3] => (item={'src': 'iptables_rules.ipv4', 'dest': '/etc/iptables_rules.ipv4', 'mode': '0644'}) 
ok: [router1] => (item={'src': 'iptables_rules.ipv4', 'dest': '/etc/iptables_rules.ipv4', 'mode': '0644'})

TASK [Create systemd unit for applying NAT rules] ******************************
skipping: [router2]
skipping: [router3]
ok: [router1]

TASK [Enable and start iptables-nat service] ***********************************
skipping: [router2]
skipping: [router3]
ok: [router1]

PLAY [Play 3 - Disable ufw firewall and Enable packets forwarding] *************

TASK [Gathering Facts] *********************************************************
ok: [router1]
ok: [router2]
ok: [router3]

TASK [disable ufw service] *****************************************************
ok: [router1]
ok: [router2]
ok: [router3]

TASK [set up forward packages across routers] **********************************
ok: [router1]
ok: [router3]
ok: [router2]

PLAY [Play 4 - Install and configure FRR] **************************************

TASK [Gathering Facts] *********************************************************
ok: [router2]
ok: [router3]
ok: [router1]

TASK [ensure keyrings dir exists] **********************************************
ok: [router1]
ok: [router2]
ok: [router3]

TASK [download frr gpg key] ****************************************************
ok: [router2]
ok: [router3]
ok: [router1]

TASK [dearmor frr gpg key] *****************************************************
ok: [router2]
ok: [router3]
ok: [router1]

TASK [add frr repo] ************************************************************
ok: [router1]
ok: [router3]
ok: [router2]

TASK [install FRR packages] ****************************************************
ok: [router1]
ok: [router2]
ok: [router3]

TASK [set up forward packages across routers] **********************************
ok: [router1]
ok: [router2]
ok: [router3]

TASK [base set up OSPF] ********************************************************
ok: [router1]
ok: [router2]
ok: [router3]

TASK [add default gateway and static routes for each host] *********************
ok: [router3]
ok: [router2]
ok: [router1]

TASK [restart FRR] *************************************************************
changed: [router1]
changed: [router3]
changed: [router2]

PLAY [Play 5 - Disable default route (except router1)] *************************

TASK [Gathering Facts] *********************************************************
ok: [router1]
ok: [router2]
ok: [router3]

TASK [disable default route] ***************************************************
skipping: [router1]
ok: [router2]
ok: [router3]

TASK [apply netplan config] ****************************************************
skipping: [router1]
changed: [router3]
changed: [router2]

PLAY [Play 6 - Reboot hosts] ***************************************************

TASK [Gathering Facts] *********************************************************
ok: [router1]
ok: [router2]
ok: [router3]

TASK [restart all hosts] *******************************************************
changed: [router3]
changed: [router2]
changed: [router1]

PLAY [Play 7 - Install traceroute] *********************************************

TASK [Gathering Facts] *********************************************************
ok: [router1]
ok: [router3]
ok: [router2]

TASK [wait for OSPF default route] *********************************************
skipping: [router1]
FAILED - RETRYING: [router2]: wait for OSPF default route (12 retries left).
FAILED - RETRYING: [router3]: wait for OSPF default route (12 retries left).
FAILED - RETRYING: [router3]: wait for OSPF default route (11 retries left).
FAILED - RETRYING: [router2]: wait for OSPF default route (11 retries left).
FAILED - RETRYING: [router2]: wait for OSPF default route (10 retries left).
FAILED - RETRYING: [router3]: wait for OSPF default route (10 retries left).
changed: [router2]
changed: [router3]

TASK [Install traceroute] ******************************************************
ok: [router1]
changed: [router3]
changed: [router2]

PLAY RECAP *********************************************************************
router1                    : ok=25   changed=2    unreachable=0    failed=0    skipped=3    rescued=0    ignored=0   
router2                    : ok=25   changed=5    unreachable=0    failed=0    skipped=3    rescued=0    ignored=0   
router3                    : ok=25   changed=5    unreachable=0    failed=0    skipped=3    rescued=0    ignored=0   

[admin_insta11@mv334 ospf_lab]$ 
```

**ПРИМЕЧАНИЕ:** После перезагрузки хостов требуется некоторое время для обмена маршрутами по OSPF, поэтому пришлось добавить в playbook задачу по ожиданию появления дефолтных маршрутов по OSPF - иначе задача по установке пакета traceroute часто выполнялась с ошибкой на router2 и router3.
