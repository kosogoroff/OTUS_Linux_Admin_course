# Занятие 19.11.2026 "37. Сетевые пакеты. VLAN'ы. LACP"

Строим бонды и вланы

## Цель:

Научиться настраивать VLAN и LACP;

## Описание/Пошаговая инструкция выполнения домашнего задания:

Для выполнения домашнего задания используйте методичку


## Что нужно сделать?

в Office1 в тестовой подсети появляется сервера с доп интерфейсами и адресами
в internal сети testLAN:

    testClient1 - 10.10.10.254
    testClient2 - 10.10.10.254
    testServer1- 10.10.10.1
    testServer2- 10.10.10.1

Равести вланами:
testClient1 <-> testServer1
testClient2 <-> testServer2

Между centralRouter и inetRouter "пробросить" 2 линка (общая inernal сеть) и объединить их в бонд, проверить работу c отключением интерфейсов.

# Решение

Ниже приведена схема лабораторной сети:

<img width="777" height="751" alt="изображение" src="https://github.com/user-attachments/assets/c8cadbb2-525a-43bd-9dd8-84447cb97064" />

Таблица IP-адресации интерфейсов хостов:


| Server      | IP and netmask      | Interface       |
|:---------------------------------------|:---------------|:-------------------------|
| inetRouter     |  192.168.255.1/30                     | Bond0 (eth1,eth2)         |
| centralRouter  | 192.168.255.2/30                      | Bond0 (eth1,eth2)         |       
|                | 192.168.255.9/30                      | eth3                      |
| office1Router  | 192.168.255.10/30                     | eth1                      |
|                | -                                     | eth2         |
|                | -                                     | eth3         |
|                | -                                     | eth4         |
|                | -                                     | eth5         |
| testClient1    | 10.10.10.254/24                       | eth1         |
| testServer1    | 10.10.10.1/24                       | eth1         |
| testClient2    | 10.10.10.253/24                       | eth1         |
| testServer2    | 10.10.10.2/24                       | eth1         |


Vagrantfile для создания лабораторного стенда приведён ниже:

```
# -*- mode: ruby -*-
# vim: set ft=ruby :
BOX_NAME_CENTOS = ENV['VAGRANT_BOX_CENTOS'] || 'centos/stream8'
BOX_NAME_UBUNTU = ENV['VAGRANT_BOX_UBUNTU'] || 'ubuntu/jammy64'


MACHINES = {
  :inetRouter => {
        :box_name => BOX_NAME_CENTOS,
        :vm_name => "inetRouter",
        :net => [
                   {adapter: 2, auto_config: false, virtualbox__intnet: "router-net"},
                   {adapter: 3, auto_config: false, virtualbox__intnet: "router-net"},
                   {ip: '192.168.56.10', adapter: 8},
                ]
  },
  :centralRouter => {
        :box_name => BOX_NAME_CENTOS,
        :vm_name => "centralRouter",
        :net => [
                   {adapter: 2, auto_config: false, virtualbox__intnet: "router-net"},
                   {adapter: 3, auto_config: false, virtualbox__intnet: "router-net"},
                   {ip: '192.168.255.9', adapter: 6, netmask: "255.255.255.252", virtualbox__intnet: "office1-central"},
                   {ip: '192.168.56.11', adapter: 8},
                ]
  },

  :office1Router => {
        :box_name => BOX_NAME_CENTOS,
        :vm_name => "office1Router",
        :net => [
                   {ip: '192.168.255.10', adapter: 2, netmask: "255.255.255.252", virtualbox__intnet: "office1-central"},
                   {adapter: 3, auto_config: false, virtualbox__intnet: "vlan1"},
                   {adapter: 4, auto_config: false, virtualbox__intnet: "vlan1"},
                   {adapter: 5, auto_config: false, virtualbox__intnet: "vlan2"},
                   {adapter: 6, auto_config: false, virtualbox__intnet: "vlan2"},
                   {ip: '192.168.56.20', adapter: 8},
                ]
  },

  :testClient1 => {
        :box_name => BOX_NAME_CENTOS,
        :vm_name => "testClient1",
        :net => [
                   {adapter: 2, auto_config: false, virtualbox__intnet: "testLAN"},
                   {ip: '192.168.56.21', adapter: 8},
                ]
  },

  :testServer1 => {
        :box_name => BOX_NAME_CENTOS,
        :vm_name => "testServer1",
        :net => [
                   {adapter: 2, auto_config: false, virtualbox__intnet: "testLAN"},
                   {ip: '192.168.56.22', adapter: 8},
            ]
  },

  :testClient2 => {
        :box_name => BOX_NAME_UBUNTU,
        :vm_name => "testClient2",
        :net => [
                   {adapter: 2, auto_config: false, virtualbox__intnet: "testLAN"},
                   {ip: '192.168.56.31', adapter: 8},
                ]
  },

  :testServer2 => {
        :box_name => BOX_NAME_UBUNTU,
        :vm_name => "testServer2",
        :net => [
                   {adapter: 2, auto_config: false, virtualbox__intnet: "testLAN"},
                   {ip: '192.168.56.32', adapter: 8},
                ]
  },

}

Vagrant.configure("2") do |config|

  MACHINES.each do |boxname, boxconfig|
    
    config.vm.define boxname do |box|
   
      box.vm.box = boxconfig[:box_name]
      box.vm.host_name = boxconfig[:vm_name]
      box.vm.box_version = boxconfig[:box_version]

      config.vm.provider "virtualbox" do |v|
        v.memory = 1024
        v.cpus = 2
       end

      if boxconfig[:vm_name] == "testServer2"
       box.vm.provision "ansible" do |ansible|
        ansible.playbook = "ansible/provision.yml"
#        ansible.inventory_path = "ansible/hosts"
        ansible.host_key_checking = "false"
        ansible.become = "true"
        ansible.limit = "all"
       end
      end

      boxconfig[:net].each do |ipconf|
        box.vm.network "private_network", **ipconf
      end

      box.vm.provision "shell", inline: <<-SHELL
        mkdir -p ~root/.ssh
        cp ~vagrant/.ssh/auth* ~root/.ssh
      SHELL
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

При запуске vagrant создаются ВМ:

```
[admin_insta11@mv334 lacp_lab]$ VAGRANT_BOX_CENTOS=almalinux9-stand-vb VAGRANT_BOX_UBUNTU=ubuntu-22.04-virtualbox vagrant up
Bringing machine 'inetRouter' up with 'virtualbox' provider...
Bringing machine 'centralRouter' up with 'virtualbox' provider...
Bringing machine 'office1Router' up with 'virtualbox' provider...
Bringing machine 'testClient1' up with 'virtualbox' provider...
Bringing machine 'testServer1' up with 'virtualbox' provider...
Bringing machine 'testClient2' up with 'virtualbox' provider...
Bringing machine 'testServer2' up with 'virtualbox' provider...
==> inetRouter: Importing base box 'almalinux9-stand-vb'...
==> inetRouter: Matching MAC address for NAT networking...
==> inetRouter: Setting the name of the VM: lacp_lab_inetRouter_1795876238721_80893
==> inetRouter: Clearing any previously set network interfaces...
==> inetRouter: Preparing network interfaces based on configuration...
    inetRouter: Adapter 1: nat
    inetRouter: Adapter 2: intnet
    inetRouter: Adapter 3: intnet
    inetRouter: Adapter 8: hostonly
==> inetRouter: Forwarding ports...
    inetRouter: 22 (guest) => 2222 (host) (adapter 1)
==> inetRouter: Running 'pre-boot' VM customizations...
==> inetRouter: Booting VM...
<...>
    testServer2: your host and reload your VM.
    testServer2: 
    testServer2: Guest Additions Version: 7.2.4
    testServer2: VirtualBox Version: 7.1
==> testServer2: Setting hostname...
==> testServer2: Configuring and enabling network interfaces...
==> testServer2: Mounting shared folders...
    testServer2: /home/admin_insta11/lacp_lab => /vagrant
==> testServer2: Running provisioner: ansible...
`playbook` does not exist on the host: /home/admin_insta11/lacp_lab/ansible/provision.yml
[admin_insta11@mv334 lacp_lab]$ 
[admin_insta11@mv334 lacp_lab]$ vagrant status
Current machine states:

inetRouter                running (virtualbox)
centralRouter             running (virtualbox)
office1Router             running (virtualbox)
testClient1               running (virtualbox)
testServer1               running (virtualbox)
testClient2               running (virtualbox)
testServer2               running (virtualbox)

This environment represents multiple VMs. The VMs are all listed
above with their current state. For more information about a specific
VM, run `vagrant status NAME`.
[admin_insta11@mv334 lacp_lab]$ 
```


#### На все ВМ устанавливаем пакеты

На inetRouter (на всех остальных ВМ аналогично - не приводится):

```
[admin_insta11@mv334 lacp_lab]$ vagrant ssh inetRouter
[vagrant@inetRouter ~]$ 
[vagrant@inetRouter ~]$ sudo -i
[root@inetRouter ~]# 
[root@inetRouter ~]# yum install -y vim traceroute tcpdump net-tools
<...>      

Complete!
[root@inetRouter ~]# 
```


#### Конфигурируем интерфейсы на RHEL-based системах

Конфигурируем интерфейсы на RHEL-based системах testClient1 и testServer1 (IP-адреса 10.10.10.254/24 и 10.10.10.1/24 соответственно), проверяем связность:

```
[admin_insta11@mv334 lacp_lab]$ vagrant ssh testClient1
Last login: Sat Nov 28 15:49:46 2026 from 10.0.2.2
[vagrant@testClient1 ~]$ 
[vagrant@testClient1 ~]$ sudo -i
[root@testClient1 ~]# 
[root@testClient1 ~]# cat > /etc/sysconfig/network-scripts/ifcfg-vlan1
VLAN=yes
#Тип интерфейса - VLAN
TYPE=Vlan
#Указываем физическое устройство, через которые будет работать VLAN
PHYSDEV=eth1
#Указываем номер VLAN (VLAN_ID)
VLAN_ID=1
VLAN_NAME_TYPE=DEV_PLUS_VID_NO_PAD
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=none
#Указываем IP-адрес интерфейса
IPADDR=10.10.10.254
#Указываем префикс (маску) подсети
PREFIX=24
#Указываем имя vlan
NAME=vlan1
#Указываем имя подинтерфейса
DEVICE=eth1.1
ONBOOT=yes
[root@testClient1 ~]# 
[root@testClient1 ~]# systemctl restart NetworkManager
[root@testClient1 ~]# 
[root@testClient1 ~]# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:d8:a1:08 brd ff:ff:ff:ff:ff:ff
    altname enp0s3
    inet 10.0.2.15/24 brd 10.0.2.255 scope global dynamic noprefixroute eth0
       valid_lft 86395sec preferred_lft 86395sec
    inet6 fd17:625c:f037:2:d15e:981b:5e64:6e9c/64 scope global dynamic noprefixroute 
       valid_lft 86395sec preferred_lft 14395sec
    inet6 fe80::6640:8ead:e817:629e/64 scope link noprefixroute 
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:c5:03:25 brd ff:ff:ff:ff:ff:ff
    altname enp0s8
    inet6 fe80::16ca:78f5:c5c8:2bbb/64 scope link noprefixroute 
       valid_lft forever preferred_lft forever
4: eth2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:97:d9:17 brd ff:ff:ff:ff:ff:ff
    altname enp0s19
    inet 192.168.56.21/24 brd 192.168.56.255 scope global noprefixroute eth2
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fe97:d917/64 scope link 
       valid_lft forever preferred_lft forever
5: eth1.1@eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether 08:00:27:c5:03:25 brd ff:ff:ff:ff:ff:ff
    inet 10.10.10.254/24 brd 10.10.10.255 scope global noprefixroute eth1.1
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fec5:325/64 scope link 
       valid_lft forever preferred_lft forever
[root@testClient1 ~]# 
[root@testClient1 ~]# exit
logout
[vagrant@testClient1 ~]$ 
[vagrant@testClient1 ~]$ exit
logout
[admin_insta11@mv334 lacp_lab]$ 
[admin_insta11@mv334 lacp_lab]$ vagrant ssh testServer1
Last login: Sat Nov 28 15:49:46 2026 from 10.0.2.2
[vagrant@testServer1 ~]$ 
[vagrant@testServer1 ~]$ sudo -i
[root@testServer1 ~]# 
[root@testServer1 ~]# cat > /etc/sysconfig/network-scripts/ifcfg-vlan1
VLAN=yes
#Тип интерфейса - VLAN
TYPE=Vlan
#Указываем физическое устройство, через которые будет работать VLAN
PHYSDEV=eth1
#Указываем номер VLAN (VLAN_ID)
VLAN_ID=1
VLAN_NAME_TYPE=DEV_PLUS_VID_NO_PAD
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=none
#Указываем IP-адрес интерфейса
IPADDR=10.10.10.1
#Указываем префикс (маску) подсети
PREFIX=24
#Указываем имя vlan
NAME=vlan1
#Указываем имя подинтерфейса
DEVICE=eth1.1
ONBOOT=yes
[root@testServer1 ~]# 
[root@testServer1 ~]# systemctl restart NetworkManager
[root@testServer1 ~]# 
[root@testServer1 ~]# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:d8:a1:08 brd ff:ff:ff:ff:ff:ff
    altname enp0s3
    inet 10.0.2.15/24 brd 10.0.2.255 scope global dynamic noprefixroute eth0
       valid_lft 86396sec preferred_lft 86396sec
    inet6 fd17:625c:f037:2:850:aaac:973d:4744/64 scope global dynamic noprefixroute 
       valid_lft 86397sec preferred_lft 14397sec
    inet6 fe80::5bac:2543:8034:2ea2/64 scope link noprefixroute 
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:ed:04:fd brd ff:ff:ff:ff:ff:ff
    altname enp0s8
    inet6 fe80::2982:4a85:9169:4fd8/64 scope link noprefixroute 
       valid_lft forever preferred_lft forever
4: eth2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:7f:61:34 brd ff:ff:ff:ff:ff:ff
    altname enp0s19
    inet 192.168.56.22/24 brd 192.168.56.255 scope global noprefixroute eth2
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fe7f:6134/64 scope link 
       valid_lft forever preferred_lft forever
5: eth1.1@eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether 08:00:27:ed:04:fd brd ff:ff:ff:ff:ff:ff
    inet 10.10.10.1/24 brd 10.10.10.255 scope global noprefixroute eth1.1
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:feed:4fd/64 scope link 
       valid_lft forever preferred_lft forever
[root@testServer1 ~]# 
[root@testServer1 ~]# ping 10.10.10.254
PING 10.10.10.254 (10.10.10.254) 56(84) bytes of data.
64 bytes from 10.10.10.254: icmp_seq=1 ttl=64 time=1.75 ms
64 bytes from 10.10.10.254: icmp_seq=2 ttl=64 time=1.22 ms
64 bytes from 10.10.10.254: icmp_seq=3 ttl=64 time=1.24 ms
64 bytes from 10.10.10.254: icmp_seq=4 ttl=64 time=1.22 ms
64 bytes from 10.10.10.254: icmp_seq=5 ttl=64 time=1.23 ms
^C
--- 10.10.10.254 ping statistics ---
5 packets transmitted, 5 received, 0% packet loss, time 4074ms
rtt min/avg/max/mdev = 1.216/1.330/1.749/0.209 ms
[root@testServer1 ~]# 
```
