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
| router2       | Default NAT address DHCP virtualbox    | eth0      | To 10.0.2.2 virtualbox router via eth0 |
|                | 10.0.10.2/30                          | eth1         |           |        
|                | 10.0.11.2/30                          | eth2         |           |        
|                | 192.168.20.1/24                       | eth3         |           |
| router3       | Default NAT address DHCP virtualbox    | eth0      | To 10.0.2.2 virtualbox router via eth0 |
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
        ansible.playbook = "ansible/provision.yml"
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
root@router1:~# systemctlstatus frr.service
-bash: systemctlstatus: command not found
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

router1# interface eth1
% Unknown command: interface eth1
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
router1(config-router)#  network 10.0.12.0/30 area 0
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
```
