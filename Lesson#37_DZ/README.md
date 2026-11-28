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
