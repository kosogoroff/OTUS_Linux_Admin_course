# Занятие 19.10.2026 "30. Фильтрация трафика - iptables"

Сценарии iptables

## Цель:

Написать сценарии iptables.

## Описание/Пошаговая инструкция выполнения домашнего задания:

Что нужно сделать?

1. Реализовать knocking port. centralRouter может попасть на ssh inetrRouter через knock скрипт. Пример в материалах.

2. Добавить inetRouter2, который виден(маршрутизируется (host-only тип сети для виртуалки)) с хоста или форвардится порт через локалхост.
    
3. запустить nginx на centralServer. Пробросить 80й порт на inetRouter2 8080. Дефолт в инет оставить через inetRouter.



Формат сдачи ДЗ - vagrant + ansible


Задача со звёздочкой. Реализовать проход на 80й порт без маскарадинга*

# Решение

Репозиторий со стендом домашнего задания выложен по ссылке https://github.com/kosogoroff/iptables_lab.git

Ниже приведено описание выполнения домашнего задания.


## 0. Создание сети ВМ


За основу лабораторной сети взята лабораторная сеть из занятия "28. Архитектура сетей", из которой для облегчения удалены ненужные хосты office1Router, office1Server, office2Router и office2Server. А также добавлени дополнительный маршрутизатор inetRouter2:

<img width="382" height="373" alt="изображение" src="https://github.com/user-attachments/assets/074258fc-3b49-445c-8a07-3a048d228a6c" />

Таблица IP-адресации интерфейсов хостов (не подключенные и несущественные для лабораторной работы интерфейсы не указаны):


| Server      | IP and netmask      | Interface       | Default route on the host    |
|:---------------------------------------|:---------------|:-------------------------|:------------------------|
| inetRouter     | Default NAT address DHCP virtualbox    | eth0      | To 10.0.2.2 virtualbox router via eth0 |
|                | 192.168.255.1/30                       | eth1         |           |        
| inetRouter2    | Default NAT address DHCP virtualbox    | eth0      | To 10.0.2.2 virtualbox router via eth0 |
|                | 192.168.255.21/30                      | eth1        |           |
| centralRouter  | 192.168.255.2/30                       | eth1        | To 192.168.255.1 via eth1        |
|                | 192.168.255.22/30                      | eth2        |           |
|                | 192.168.0.1/28                      | eth3        |           |
| centralServer  | 192.168.0.2/28                      | eth1        | To 192.168.0.1 via eth1          |


Схема создаваемой лабораторной сети из методички:


Vagrantfile для создания лабораторной сети приведён ниже:

```
[admin_insta11@mv334 iptables_lab]$ cat Vagrantfile
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

  :inetRouter2 => {
        :box_name => BOX_NAME,
        :vm_name => "inetRouter2",
        #:public => {:ip => "10.10.10.1", :adapter => 1},
        :net => [
                    #ip, adpter, netmask, virtualbox__intnet
                    ["192.168.255.21", 2, "255.255.255.252",  "router2-net"],
                    ["192.168.50.20", 8, "255.255.255.0"],
                ],
        :fwd => [
          [22, 2332],
          [8080, 8082],
        ],
  },

  :centralRouter => {
        :box_name => BOX_NAME,
        :vm_name => "centralRouter",
        :net => [
                   ["192.168.255.2",  2, "255.255.255.252",  "router-net"],
                   ["192.168.255.22",  3, "255.255.255.252",  "router2-net"],
                   ["192.168.0.1",    4, "255.255.255.240",  "dir-net"],
                   ["192.168.0.33",   5, "255.255.255.240",  "hw-net"],
                   ["192.168.0.65",   6, "255.255.255.192",  "mgt-net"],
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

      if boxconfig[:fwd]
        boxconfig[:fwd].each do |guest_port, host_port|
          box.vm.network "forwarded_port", guest: guest_port, host: host_port,
            host_ip: "127.0.0.1", auto_correct: true
        end
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
[admin_insta11@mv334 iptables_lab]$ VAGRANT_BOX=ubuntu-22.04-virtualbox vagrant up
Bringing machine 'inetRouter' up with 'virtualbox' provider...
Bringing machine 'inetRouter2' up with 'virtualbox' provider...
Bringing machine 'centralRouter' up with 'virtualbox' provider...
Bringing machine 'centralServer' up with 'virtualbox' provider...
==> inetRouter: You assigned a static IP ending in ".1" or ":1" to this machine.
==> inetRouter: This is very often used by the router and can cause the
==> inetRouter: network to not work properly. If the network doesn't work
==> inetRouter: properly, try changing this IP.
==> inetRouter: Importing base box 'ubuntu-22.04-virtualbox'...
==> inetRouter: Matching MAC address for NAT networking...
==> inetRouter: You assigned a static IP ending in ".1" or ":1" to this machine.
==> inetRouter: This is very often used by the router and can cause the
==> inetRouter: network to not work properly. If the network doesn't work
==> inetRouter: properly, try changing this IP.
==> inetRouter: Setting the name of the VM: iptables_lab_inetRouter_1794051213293_12662
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
    inetRouter: /home/admin_insta11/iptables_lab => /vagrant
==> inetRouter: Running provisioner: shell...
    inetRouter: Running: inline script
==> inetRouter2: Importing base box 'ubuntu-22.04-virtualbox'...
==> inetRouter2: Matching MAC address for NAT networking...
==> inetRouter2: Setting the name of the VM: iptables_lab_inetRouter2_1794051326805_2884
==> inetRouter2: Fixed port collision for 22 => 2222. Now on port 2200.
==> inetRouter2: Clearing any previously set network interfaces...
==> inetRouter2: Preparing network interfaces based on configuration...
    inetRouter2: Adapter 1: nat
    inetRouter2: Adapter 2: intnet
    inetRouter2: Adapter 8: hostonly
==> inetRouter2: Forwarding ports...
    inetRouter2: 22 (guest) => 2332 (host) (adapter 1)
    inetRouter2: 8080 (guest) => 8082 (host) (adapter 1)
    inetRouter2: 22 (guest) => 2200 (host) (adapter 1)
==> inetRouter2: Running 'pre-boot' VM customizations...
==> inetRouter2: Booting VM...
==> inetRouter2: Waiting for machine to boot. This may take a few minutes...
    inetRouter2: SSH address: 127.0.0.1:2200
    inetRouter2: SSH username: vagrant
    inetRouter2: SSH auth method: private key
    inetRouter2: Warning: Connection reset. Retrying...
    inetRouter2: Warning: Remote connection disconnect. Retrying...
    inetRouter2: 
    inetRouter2: Vagrant insecure key detected. Vagrant will automatically replace
    inetRouter2: this with a newly generated keypair for better security.
    inetRouter2: 
    inetRouter2: Inserting generated public key within guest...
    inetRouter2: Removing insecure key from the guest if it's present...
    inetRouter2: Key inserted! Disconnecting and reconnecting using new SSH key...
==> inetRouter2: Machine booted and ready!
==> inetRouter2: Checking for guest additions in VM...
    inetRouter2: The guest additions on this VM do not match the installed version of
    inetRouter2: VirtualBox! In most cases this is fine, but in rare cases it can
    inetRouter2: prevent things such as shared folders from working properly. If you see
    inetRouter2: shared folder errors, please make sure the guest additions within the
    inetRouter2: virtual machine match the version of VirtualBox you have installed on
    inetRouter2: your host and reload your VM.
    inetRouter2: 
    inetRouter2: Guest Additions Version: 7.2.4
    inetRouter2: VirtualBox Version: 7.1
==> inetRouter2: Setting hostname...
==> inetRouter2: Configuring and enabling network interfaces...
==> inetRouter2: Mounting shared folders...
    inetRouter2: /home/admin_insta11/iptables_lab => /vagrant
==> inetRouter2: Running provisioner: shell...
    inetRouter2: Running: inline script
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
==> centralRouter: Setting the name of the VM: iptables_lab_centralRouter_1794051438362_99242
==> centralRouter: Fixed port collision for 22 => 2222. Now on port 2201.
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
    centralRouter: 22 (guest) => 2201 (host) (adapter 1)
==> centralRouter: Running 'pre-boot' VM customizations...
==> centralRouter: Booting VM...
==> centralRouter: Waiting for machine to boot. This may take a few minutes...
    centralRouter: SSH address: 127.0.0.1:2201
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
    centralRouter: /home/admin_insta11/iptables_lab => /vagrant
==> centralRouter: Running provisioner: shell...
    centralRouter: Running: inline script
==> centralServer: Importing base box 'ubuntu-22.04-virtualbox'...
==> centralServer: Matching MAC address for NAT networking...
==> centralServer: Setting the name of the VM: iptables_lab_centralServer_1794051549535_79258
==> centralServer: Fixed port collision for 22 => 2222. Now on port 2202.
==> centralServer: Clearing any previously set network interfaces...
==> centralServer: Preparing network interfaces based on configuration...
    centralServer: Adapter 1: nat
    centralServer: Adapter 2: intnet
    centralServer: Adapter 8: hostonly
==> centralServer: Forwarding ports...
    centralServer: 22 (guest) => 2202 (host) (adapter 1)
==> centralServer: Running 'pre-boot' VM customizations...
==> centralServer: Booting VM...
==> centralServer: Waiting for machine to boot. This may take a few minutes...
    centralServer: SSH address: 127.0.0.1:2202
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
    centralServer: /home/admin_insta11/iptables_lab => /vagrant
==> centralServer: Running provisioner: shell...
    centralServer: Running: inline script
[admin_insta11@mv334 iptables_lab]$
[admin_insta11@mv334 iptables_lab]$ vagrant status
Current machine states:

inetRouter                running (virtualbox)
inetRouter2               running (virtualbox)
centralRouter             running (virtualbox)
centralServer             running (virtualbox)

This environment represents multiple VMs. The VMs are all listed
above with their current state. For more information about a specific
VM, run `vagrant status NAME`.
[admin_insta11@mv334 iptables_lab]$ 
```

0.2 Далее производим провизионинг созданных ВМ с помощью ansible. Ниже приведены playbook.yml для провизионинга и файлы для загрузки на ВМ
для конфигурирования статических маршрутов и адресов на хостах, а также NAT на основном маршрутизаторе inetRouter :

```
[admin_insta11@mv334 iptables_lab]$ tree
.
├── ansible
│   ├── playbook.yml
│   └── templates
│       ├── 00-installer-config.yaml
│       ├── 50-vagrant_centralRouter.yaml
│       ├── 50-vagrant_centralServer.yaml
│       ├── 50-vagrant_inetRouter2.yaml
│       ├── 50-vagrant_inetRouter.yaml
│       └── iptables_rules.ipv4
├── ansible.cfg
├── generate_inventory.sh
├── inventory.ini
├── README.md
└── Vagrantfile
[admin_insta11@mv334 iptables_lab]$ cat ansible/templates/00-installer-config.yaml 
# This is the network config written by 'subiquity'
network:
  ethernets:
    eth0:
      dhcp4: true
      dhcp4-overrides:
          use-routes: false
      dhcp6: false
  version: 2
[admin_insta11@mv334 iptables_lab]$ 
[admin_insta11@mv334 iptables_lab]$ cat ansible/templates/50-vagrant_centralRouter.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: true
      dhcp4-overrides:
          use-routes: false
    eth1:
      addresses:
        - 192.168.255.2/30
      routes:
        - to: 0.0.0.0/0
          via: 192.168.255.1
    eth2:
      addresses:
        - 192.168.255.22/30
    eth3:
      addresses:
        - 192.168.0.1/28
    eth4:
      addresses:
        - 192.168.0.33/28
    eth5:
      addresses:
        - 192.168.0.65/26
    eth6:
      addresses:
        - 192.168.255.5/30
      routes:
        - to: 192.168.1.0/28
          via: 192.168.255.6
    eth7:
      addresses:
        - 192.168.50.11/24
[admin_insta11@mv334 iptables_lab]$ cat ansible/templates/50-vagrant_centralServer.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: true
      dhcp4-overrides:
          use-routes: false
    eth1:
      addresses:
        - 192.168.0.2/28
      routes:
        - to: 0.0.0.0/0
          via: 192.168.0.1
    eth2:
      addresses:
        - 192.168.50.12/24      
[admin_insta11@mv334 iptables_lab]$ 
[admin_insta11@mv334 iptables_lab]$ cat ansible/templates/50-vagrant_inetRouter2.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: true
    eth1:
      addresses:
        - 192.168.255.21/30
      routes:
        - to: 192.168.0.0/25
          via: 192.168.255.22
        - to: 192.168.1.0/24
          via: 192.168.255.22
        - to: 192.168.2.0/24
          via: 192.168.255.22
        - to: 192.168.255.0/30
          via: 192.168.255.22
        - to: 192.168.255.4/30
          via: 192.168.255.22
        - to: 192.168.255.8/30
          via: 192.168.255.22
    eth2:
      addresses:
        - 192.168.50.10/24
[admin_insta11@mv334 iptables_lab]$ 
[admin_insta11@mv334 iptables_lab]$ cat ansible/templates/50-vagrant_inetRouter.yaml
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
        - to: 192.168.255.20/30
          via: 192.168.255.2
    eth2:
      addresses:
        - 192.168.50.10/24
[admin_insta11@mv334 iptables_lab]$ 
[admin_insta11@mv334 iptables_lab]$ cat ansible/templates/iptables_rules.ipv4
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
[admin_insta11@mv334 iptables_lab]$
[admin_insta11@mv334 iptables_lab]$
[admin_insta11@mv334 iptables_lab]$ cat ansible/playbook.yml 
---
- name: Task 1 - NAT on inetRouter
  hosts: vagrant_boxes
  become: true
  tasks:

    # ------------------------------------------------------------------
    # ЭТАП 1: Глушим cloud-init, чтобы он не перетирал наши конфиги
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
  vars:
    routers:
      - inetRouter
      - inetRouter2
      - centralRouter
  tasks:
    - name: set up forward packages across routers
      sysctl:
        name: net.ipv4.ip_forward
        value: '1'
        state: present
      when: inventory_hostname in routers


- name: Task 3 - Disable default route (except inetRouter and inetRouter2)
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
    # when: inventory_hostname != "inetRouter" and inventory_hostname != "inetRouter2"
      when: inventory_hostname not in ["inetRouter", "inetRouter2"]

    # netplan try интерактивен и будет висеть. Для автоматизации используем apply.
    # Если критично именно try — скажи, но тогда плейбук не пройдёт без ручного подтверждения.
    - name: apply netplan config
      command: netplan apply
      when: inventory_hostname != "inetRouter"


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


- name: Task 6 - Install traceroute
  hosts: vagrant_boxes
  become: true
  tasks:
    - name: Install traceroute
      apt:
        name: traceroute
        state: present
[admin_insta11@mv iptables_lab]$
```

Для автоматического создания файла inventory.ini создан специальный скрипт generate_inventory.sh , который однорактно запускается и создаёт файл inventory.ini на основе вывода vagrant ssh-config :

```
[admin_insta11@mv334 iptables_lab]$ cat ./generate_inventory.sh 
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
#    echo "line= $line"

    # Если встретили Host, запоминаем имя текущего хоста
    if [[ "$line" =~ ^Host[[:space:]]+([^[:space:]]+) ]]; then
        current_host="${BASH_REMATCH[1]}"
#        echo ">>> Обнаружен хост: $current_host"
    fi

    # Если есть текущий хост, пытаемся собрать для него данные
    if [[ -n "$current_host" ]]; then
        # Собираем Port
        if [[ "$line" =~ ^[[:space:]]*Port[[:space:]]+([0-9]+) ]]; then
            HOSTS_PORT["$current_host"]="${BASH_REMATCH[1]}"
#            echo "Port= ${HOSTS_PORT[$current_host]}"
        fi

        # Собираем IdentityFile
        if [[ "$line" =~ ^[[:space:]]*IdentityFile[[:space:]]+\"?([^\"]+)\"? ]]; then
            HOSTS_KEY["$current_host"]="${BASH_REMATCH[1]}"
#            echo "Key= ${HOSTS_KEY[$current_host]}"
        fi

	        # Собираем HostName
        if [[ "$line" =~ ^[[:space:]]*HostName[[:space:]]+\"?([^\"]+)\"? ]]; then
            HOSTS_NAME["$current_host"]="${BASH_REMATCH[1]}"
#            echo "Key= ${HOSTS_NAME[$current_host]}"
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

[admin_insta11@mv334 iptables_lab]$
[admin_insta11@mv334 iptables_lab]$ ./generate_inventory.sh 
>>> ЗАПИСАНО: inetRouter2 (port=2200)
>>> ЗАПИСАНО: inetRouter (port=2222)
>>> ЗАПИСАНО: centralServer (port=2202)
>>> ЗАПИСАНО: centralRouter (port=2201)
✅ Готово! Содержимое inventory.ini:
[vagrant_boxes]

inetRouter2 ansible_host=127.0.0.1 ansible_port=2200 ansible_private_key_file=/home/admin_insta11/iptables_lab/.vagrant/machines/inetRouter2/virtualbox/private_key
inetRouter ansible_host=127.0.0.1 ansible_port=2222 ansible_private_key_file=/home/admin_insta11/iptables_lab/.vagrant/machines/inetRouter/virtualbox/private_key
centralServer ansible_host=127.0.0.1 ansible_port=2202 ansible_private_key_file=/home/admin_insta11/iptables_lab/.vagrant/machines/centralServer/virtualbox/private_key
centralRouter ansible_host=127.0.0.1 ansible_port=2201 ansible_private_key_file=/home/admin_insta11/iptables_lab/.vagrant/machines/centralRouter/virtualbox/private_key

[vagrant_boxes:vars]
ansible_user=vagrant
ansible_python_interpreter=/usr/bin/python3
host_key_checking=False
[admin_insta11@mv334 iptables_lab]$
[admin_insta11@mv334 iptables_lab]$ cat inventory.ini 
[vagrant_boxes]

inetRouter2 ansible_host=127.0.0.1 ansible_port=2200 ansible_private_key_file=/home/admin_insta11/iptables_lab/.vagrant/machines/inetRouter2/virtualbox/private_key
inetRouter ansible_host=127.0.0.1 ansible_port=2222 ansible_private_key_file=/home/admin_insta11/iptables_lab/.vagrant/machines/inetRouter/virtualbox/private_key
centralServer ansible_host=127.0.0.1 ansible_port=2202 ansible_private_key_file=/home/admin_insta11/iptables_lab/.vagrant/machines/centralServer/virtualbox/private_key
centralRouter ansible_host=127.0.0.1 ansible_port=2201 ansible_private_key_file=/home/admin_insta11/iptables_lab/.vagrant/machines/centralRouter/virtualbox/private_key

[vagrant_boxes:vars]
ansible_user=vagrant
ansible_python_interpreter=/usr/bin/python3
host_key_checking=False
[admin_insta11@mv334 iptables_lab]$ 
```

После создания файла инвентаря запускаем ansible playbook для провизионинга:

```
[admin_insta11@mv334 iptables_lab]$ 
[admin_insta11@mv334 iptables_lab]$ ansible-playbook -i inventory.ini ansible/playbook.yml 

PLAY [Task 1 - NAT on inetRouter] ************************************************************************************************************************************************************

TASK [Gathering Facts] ***********************************************************************************************************************************************************************
ok: [inetRouter]
ok: [centralServer]
ok: [centralRouter]
ok: [inetRouter2]

TASK [Disable cloud-init network configuration] **********************************************************************************************************************************************
changed: [centralRouter]
changed: [centralServer]
changed: [inetRouter2]
changed: [inetRouter]

TASK [Clean cloud-init network cache (автоматически убирает/очищает 50-cloud-init.yaml)] *****************************************************************************************************
ok: [centralRouter]
ok: [centralServer]
ok: [inetRouter2]
ok: [inetRouter]

TASK [Set up NAT on inetRouter] **************************************************************************************************************************************************************
skipping: [inetRouter2] => (item={'src': 'iptables_rules.ipv4', 'dest': '/etc/iptables_rules.ipv4', 'mode': '0644'}) 
skipping: [centralServer] => (item={'src': 'iptables_rules.ipv4', 'dest': '/etc/iptables_rules.ipv4', 'mode': '0644'}) 
skipping: [centralRouter] => (item={'src': 'iptables_rules.ipv4', 'dest': '/etc/iptables_rules.ipv4', 'mode': '0644'}) 
changed: [inetRouter] => (item={'src': 'iptables_rules.ipv4', 'dest': '/etc/iptables_rules.ipv4', 'mode': '0644'})

TASK [Create systemd unit for applying NAT rules] ********************************************************************************************************************************************
skipping: [inetRouter2]
skipping: [centralServer]
skipping: [centralRouter]
changed: [inetRouter]

TASK [Enable and start iptables-nat service] *************************************************************************************************************************************************
skipping: [inetRouter2]
skipping: [centralServer]
skipping: [centralRouter]
changed: [inetRouter]

PLAY [Task 2 - IP forwarding on all routers] *************************************************************************************************************************************************

TASK [Gathering Facts] ***********************************************************************************************************************************************************************
ok: [inetRouter2]
ok: [centralServer]
ok: [inetRouter]
ok: [centralRouter]

TASK [set up forward packages across routers] ************************************************************************************************************************************************
skipping: [centralServer]
changed: [inetRouter]
changed: [centralRouter]
changed: [inetRouter2]

PLAY [Task 3 - Disable default route (except inetRouter and inetRouter2)] ********************************************************************************************************************

TASK [Gathering Facts] ***********************************************************************************************************************************************************************
ok: [inetRouter]
ok: [inetRouter2]
ok: [centralServer]
ok: [centralRouter]

TASK [disable default route] *****************************************************************************************************************************************************************
skipping: [inetRouter2]
skipping: [inetRouter]
changed: [centralRouter]
changed: [centralServer]

TASK [apply netplan config] ******************************************************************************************************************************************************************
skipping: [inetRouter]
changed: [inetRouter2]
changed: [centralServer]
changed: [centralRouter]

PLAY [Task 5 - Add static routes and reboot] *************************************************************************************************************************************************

TASK [Gathering Facts] ***********************************************************************************************************************************************************************
ok: [inetRouter2]
ok: [centralServer]
ok: [inetRouter]
ok: [centralRouter]

TASK [add default gateway and static routes for each host] ***********************************************************************************************************************************
changed: [inetRouter2]
changed: [centralServer]
changed: [inetRouter]
changed: [centralRouter]

TASK [restart all hosts] *********************************************************************************************************************************************************************
changed: [inetRouter]
changed: [centralServer]
changed: [centralRouter]
changed: [inetRouter2]

PLAY [Task 6 - Install traceroute] ***********************************************************************************************************************************************************

TASK [Gathering Facts] ***********************************************************************************************************************************************************************
ok: [centralServer]
ok: [inetRouter2]
ok: [inetRouter]
ok: [centralRouter]

TASK [Install traceroute] ********************************************************************************************************************************************************************
changed: [centralServer]
changed: [centralRouter]
changed: [inetRouter]
changed: [inetRouter2]

PLAY RECAP ***********************************************************************************************************************************************************************************
centralRouter              : ok=13   changed=7    unreachable=0    failed=0    skipped=3    rescued=0    ignored=0   
centralServer              : ok=12   changed=6    unreachable=0    failed=0    skipped=4    rescued=0    ignored=0   
inetRouter                 : ok=14   changed=8    unreachable=0    failed=0    skipped=2    rescued=0    ignored=0   
inetRouter2                : ok=12   changed=6    unreachable=0    failed=0    skipped=4    rescued=0    ignored=0   

[admin_insta11@mv334 iptables_lab]$
```

Конфигурации интерфейсов и маршрутов сразу после создания ВМ Vagrant и провизионинга ansible следующие:

```
[admin_insta11@mv334 iptables_lab]$ vagrant ssh inetRouter
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-160-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

 System information as of Sat Nov  7 05:14:08 PM UTC 2026

  System load:           0.08
  Usage of /:            16.3% of 30.34GB
  Memory usage:          30%
  Swap usage:            0%
  Processes:             132
  Users logged in:       0
  IPv4 address for eth0: 10.0.2.15
  IPv6 address for eth0: fd17:625c:f037:2:a00:27ff:fe16:ddef


This system is built by the Bento project by Chef Software
More information can be found at https://github.com/chef/bento

Use of this system is acceptance of the OS vendor EULA and License Agreements.
Last login: Sat Nov  7 12:09:12 2026 from 10.0.2.2
vagrant@inetRouter:~$ 
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
       valid_lft 68062sec preferred_lft 68062sec
    inet6 fd17:625c:f037:2:a00:27ff:fe16:ddef/64 scope global dynamic mngtmpaddr noprefixroute 
       valid_lft 86279sec preferred_lft 14279sec
    inet6 fe80::a00:27ff:fe16:ddef/64 scope link 
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:ef:f7:31 brd ff:ff:ff:ff:ff:ff
    altname enp0s8
    inet 192.168.255.1/30 brd 192.168.255.3 scope global eth1
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:feef:f731/64 scope link 
       valid_lft forever preferred_lft forever
4: eth2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:2f:6f:04 brd ff:ff:ff:ff:ff:ff
    altname enp0s19
    inet 192.168.50.10/24 brd 192.168.50.255 scope global eth2
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fe2f:6f04/64 scope link 
       valid_lft forever preferred_lft forever
vagrant@inetRouter:~$ 
vagrant@inetRouter:~$ ip r
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
192.168.255.20/30 via 192.168.255.2 dev eth1 proto static 
vagrant@inetRouter:~$ 
vagrant@inetRouter:~$ exit
logout
[admin_insta11@mv334 iptables_lab]$ 
[admin_insta11@mv334 iptables_lab]$ vagrant ssh inetRouter2
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-160-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

 System information as of Sat Nov  7 05:14:45 PM UTC 2026

  System load:           0.0
  Usage of /:            15.7% of 30.34GB
  Memory usage:          32%
  Swap usage:            0%
  Processes:             134
  Users logged in:       1
  IPv4 address for eth0: 10.0.2.15
  IPv6 address for eth0: fd17:625c:f037:2:a00:27ff:fe16:ddef


This system is built by the Bento project by Chef Software
More information can be found at https://github.com/chef/bento

Use of this system is acceptance of the OS vendor EULA and License Agreements.
Last login: Sat Nov  7 13:42:02 2026 from 10.0.2.2
vagrant@inetRouter2:~$ 
vagrant@inetRouter2:~$ ip a
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
       valid_lft 68028sec preferred_lft 68028sec
    inet6 fd17:625c:f037:2:a00:27ff:fe16:ddef/64 scope global dynamic mngtmpaddr noprefixroute 
       valid_lft 86264sec preferred_lft 14264sec
    inet6 fe80::a00:27ff:fe16:ddef/64 scope link 
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:fb:0a:71 brd ff:ff:ff:ff:ff:ff
    altname enp0s8
    inet 192.168.255.21/30 brd 192.168.255.23 scope global eth1
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fefb:a71/64 scope link 
       valid_lft forever preferred_lft forever
4: eth2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:54:88:61 brd ff:ff:ff:ff:ff:ff
    altname enp0s19
    inet 192.168.50.10/24 brd 192.168.50.255 scope global eth2
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fe54:8861/64 scope link 
       valid_lft forever preferred_lft forever
vagrant@inetRouter2:~$ 
vagrant@inetRouter2:~$ ip r
default via 10.0.2.2 dev eth0 proto dhcp src 10.0.2.15 metric 100 
10.0.2.0/24 dev eth0 proto kernel scope link src 10.0.2.15 metric 100 
10.0.2.2 dev eth0 proto dhcp scope link src 10.0.2.15 metric 100 
10.0.2.3 dev eth0 proto dhcp scope link src 10.0.2.15 metric 100 
192.168.0.0/25 via 192.168.255.22 dev eth1 proto static 
192.168.1.0/24 via 192.168.255.22 dev eth1 proto static 
192.168.2.0/24 via 192.168.255.22 dev eth1 proto static 
192.168.50.0/24 dev eth2 proto kernel scope link src 192.168.50.10 
192.168.255.0/30 via 192.168.255.22 dev eth1 proto static 
192.168.255.4/30 via 192.168.255.22 dev eth1 proto static 
192.168.255.8/30 via 192.168.255.22 dev eth1 proto static 
192.168.255.20/30 dev eth1 proto kernel scope link src 192.168.255.21 
vagrant@inetRouter2:~$ 
vagrant@inetRouter2:~$ exit
logout
[admin_insta11@mv334 iptables_lab]$ 
[admin_insta11@mv334 iptables_lab]$ vagrant ssh centralRouter
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-160-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

 System information as of Sat Nov  7 05:15:25 PM UTC 2026

  System load:           0.08
  Usage of /:            15.7% of 30.34GB
  Memory usage:          34%
  Swap usage:            0%
  Processes:             135
  Users logged in:       0
  IPv4 address for eth0: 10.0.2.15
  IPv6 address for eth0: fd17:625c:f037:2:a00:27ff:fe16:ddef
  IPv4 address for eth1: 192.168.255.2


This system is built by the Bento project by Chef Software
More information can be found at https://github.com/chef/bento

Use of this system is acceptance of the OS vendor EULA and License Agreements.
Last login: Sat Nov  7 12:09:12 2026 from 10.0.2.2
vagrant@centralRouter:~$ 
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
       valid_lft 67981sec preferred_lft 67981sec
    inet6 fd17:625c:f037:2:a00:27ff:fe16:ddef/64 scope global dynamic mngtmpaddr noprefixroute 
       valid_lft 86159sec preferred_lft 14159sec
    inet6 fe80::a00:27ff:fe16:ddef/64 scope link 
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:9e:eb:6f brd ff:ff:ff:ff:ff:ff
    altname enp0s8
    inet 192.168.255.2/30 brd 192.168.255.3 scope global eth1
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fe9e:eb6f/64 scope link 
       valid_lft forever preferred_lft forever
4: eth2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:e7:4a:36 brd ff:ff:ff:ff:ff:ff
    altname enp0s9
    inet 192.168.255.22/30 brd 192.168.255.23 scope global eth2
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fee7:4a36/64 scope link 
       valid_lft forever preferred_lft forever
5: eth3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:c9:5c:e9 brd ff:ff:ff:ff:ff:ff
    altname enp0s10
    inet 192.168.0.1/28 brd 192.168.0.15 scope global eth3
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fec9:5ce9/64 scope link 
       valid_lft forever preferred_lft forever
6: eth4: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:1f:6c:51 brd ff:ff:ff:ff:ff:ff
    altname enp0s16
    inet 192.168.0.33/28 brd 192.168.0.47 scope global eth4
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fe1f:6c51/64 scope link 
       valid_lft forever preferred_lft forever
7: eth5: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:b2:4d:ee brd ff:ff:ff:ff:ff:ff
    altname enp0s17
    inet 192.168.0.65/26 brd 192.168.0.127 scope global eth5
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:feb2:4dee/64 scope link 
       valid_lft forever preferred_lft forever
8: eth6: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:5e:83:e3 brd ff:ff:ff:ff:ff:ff
    altname enp0s18
    inet 192.168.255.5/30 brd 192.168.255.7 scope global eth6
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fe5e:83e3/64 scope link 
       valid_lft forever preferred_lft forever
9: eth7: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:79:06:ef brd ff:ff:ff:ff:ff:ff
    altname enp0s19
    inet 192.168.50.11/24 brd 192.168.50.255 scope global eth7
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fe79:6ef/64 scope link 
       valid_lft forever preferred_lft forever
vagrant@centralRouter:~$ 
vagrant@centralRouter:~$ ip r
default via 192.168.255.1 dev eth1 proto static 
10.0.2.0/24 dev eth0 proto kernel scope link src 10.0.2.15 metric 100 
10.0.2.3 dev eth0 proto dhcp scope link src 10.0.2.15 metric 100 
192.168.0.0/28 dev eth3 proto kernel scope link src 192.168.0.1 
192.168.0.32/28 dev eth4 proto kernel scope link src 192.168.0.33 
192.168.0.64/26 dev eth5 proto kernel scope link src 192.168.0.65 
192.168.1.0/28 via 192.168.255.6 dev eth6 proto static 
192.168.50.0/24 dev eth7 proto kernel scope link src 192.168.50.11 
192.168.255.0/30 dev eth1 proto kernel scope link src 192.168.255.2 
192.168.255.4/30 dev eth6 proto kernel scope link src 192.168.255.5 
192.168.255.20/30 dev eth2 proto kernel scope link src 192.168.255.22 
vagrant@centralRouter:~$ 
vagrant@centralRouter:~$ exit
logout
[admin_insta11@mv334 iptables_lab]$ 
[admin_insta11@mv334 iptables_lab]$ vagrant ssh centralServer
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-160-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

 System information as of Sat Nov  7 05:15:54 PM UTC 2026

  System load:           0.0
  Usage of /:            16.0% of 30.34GB
  Memory usage:          33%
  Swap usage:            0%
  Processes:             139
  Users logged in:       1
  IPv4 address for eth0: 10.0.2.15
  IPv6 address for eth0: fd17:625c:f037:2:a00:27ff:fe16:ddef
  IPv4 address for eth1: 192.168.0.2


This system is built by the Bento project by Chef Software
More information can be found at https://github.com/chef/bento

Use of this system is acceptance of the OS vendor EULA and License Agreements.
Last login: Sat Nov  7 14:07:11 2026 from 10.0.2.2
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
       valid_lft 71824sec preferred_lft 71824sec
    inet6 fd17:625c:f037:2:a00:27ff:fe16:ddef/64 scope global dynamic mngtmpaddr noprefixroute 
       valid_lft 86331sec preferred_lft 14331sec
    inet6 fe80::a00:27ff:fe16:ddef/64 scope link 
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:2a:34:0d brd ff:ff:ff:ff:ff:ff
    altname enp0s8
    inet 192.168.0.2/28 brd 192.168.0.15 scope global eth1
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fe2a:340d/64 scope link 
       valid_lft forever preferred_lft forever
4: eth2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:6e:b8:a2 brd ff:ff:ff:ff:ff:ff
    altname enp0s19
    inet 192.168.50.12/24 brd 192.168.50.255 scope global eth2
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fe6e:b8a2/64 scope link 
       valid_lft forever preferred_lft forever
vagrant@centralServer:~$ 
vagrant@centralServer:~$ ip r
default via 192.168.0.1 dev eth1 proto static 
10.0.2.0/24 dev eth0 proto kernel scope link src 10.0.2.15 metric 100 
10.0.2.3 dev eth0 proto dhcp scope link src 10.0.2.15 metric 100 
192.168.0.0/28 dev eth1 proto kernel scope link src 192.168.0.2 
192.168.50.0/24 dev eth2 proto kernel scope link src 192.168.50.12 
vagrant@centralServer:~$ 

```

## 1. Реализовать knocking port. centralRouter может попасть на ssh inetrRouter через knock скрипт.

В задании для демонстрации указано сделать доступ через knocking port с centralRouter (в правила добавлен параметр -s 192.168.255.22 , то есть они действуют только для входящего трафика с хоста centralRouter) - с остальных хостов доступ оставлен без изменений, ограничений нет.

Для реализации Knocking port на inetRouter2 делаем следующие конфигурации правил iptables:

```
vagrant@inetRouter2:~$ sudo iptables -L -n -v
Chain INPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain FORWARD (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain OUTPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         
vagrant@inetRouter2:~$ 
vagrant@inetRouter2:~$ sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
vagrant@inetRouter2:~$ 
vagrant@inetRouter2:~$ sudo iptables -A INPUT -i lo -j ACCEPT
vagrant@inetRouter2:~$ 
vagrant@inetRouter2:~$ sudo iptables -A INPUT -s 192.168.255.22 -p tcp --dport 7000 -m recent --name KNOCK --set -j DROP
vagrant@inetRouter2:~$ 
vagrant@inetRouter2:~$ sudo iptables -A INPUT -s 192.168.255.22 -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --name KNOCK --rcheck --seconds 10 -j ACCEPT
vagrant@inetRouter2:~$ 
vagrant@inetRouter2:~$ sudo iptables -A INPUT -s 192.168.255.22 -p tcp --dport 22 -j DROP
vagrant@inetRouter2:~$
vagrant@inetRouter2:~$ sudo iptables -L -n -v --line-numbers
Chain INPUT (policy ACCEPT 0 packets, 0 bytes)
num   pkts bytes target     prot opt in     out     source               destination         
1     3575  243K ACCEPT     all  --  *      *       0.0.0.0/0            0.0.0.0/0            ctstate RELATED,ESTABLISHED
2        3   269 ACCEPT     all  --  lo     *       0.0.0.0/0            0.0.0.0/0           
3        1    60 DROP       tcp  --  *      *       192.168.255.22       0.0.0.0/0            tcp dpt:7000 recent: SET name: KNOCK side: source mask: 255.255.255.255
4        1    60 ACCEPT     tcp  --  *      *       192.168.255.22       0.0.0.0/0            tcp dpt:22 ctstate NEW recent: CHECK seconds: 10 name: KNOCK side: source mask: 255.255.255.255
5        7   420 DROP       tcp  --  *      *       192.168.255.22       0.0.0.0/0            tcp dpt:22

Chain FORWARD (policy ACCEPT 0 packets, 0 bytes)
num   pkts bytes target     prot opt in     out     source               destination         

Chain OUTPUT (policy ACCEPT 0 packets, 0 bytes)
num   pkts bytes target     prot opt in     out     source               destination         
vagrant@inetRouter2:~$ 
```

После этого при заходе с centralRouter по SSH работает nocking port - зайти на порт SSH без предварительного стука на порт 7000 невозможно.
После стука на порт 7000 в течение 10 секунд зайти на порт SSH можно, если прервать соединение SSH, то для повторного вхда опять требуется стук
на порт 7000:

```
vagrant@centralRouter:~$ ssh vagrant@192.168.255.21
^C
vagrant@centralRouter:~$ nc -z -w1 192.168.255.21 7000
vagrant@centralRouter:~$ ssh vagrant@192.168.255.21
vagrant@192.168.255.21's password: 
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-160-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

 System information as of Sat Nov  7 06:47:54 PM UTC 2026

  System load:           0.01
  Usage of /:            15.7% of 30.34GB
  Memory usage:          31%
  Swap usage:            0%
  Processes:             135
  Users logged in:       1
  IPv4 address for eth0: 10.0.2.15
  IPv6 address for eth0: fd17:625c:f037:2:a00:27ff:fe16:ddef


This system is built by the Bento project by Chef Software
More information can be found at https://github.com/chef/bento

Use of this system is acceptance of the OS vendor EULA and License Agreements.
Last login: Sat Nov  7 18:00:46 2026 from 192.168.255.22
vagrant@inetRouter2:~$ 
vagrant@inetRouter2:~$ exit
logout
Connection to 192.168.255.21 closed.
vagrant@centralRouter:~$ ssh vagrant@192.168.255.21
^C
vagrant@centralRouter:~$ 
```

При этом видно срабатывание правил в iptables - увеличение счётчиков соответствующих правил:

```
vagrant@inetRouter2:~$ sudo iptables -L -n -v
Chain INPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         
 2887  203K ACCEPT     all  --  *      *       0.0.0.0/0            0.0.0.0/0            ctstate RELATED,ESTABLISHED
    3   269 ACCEPT     all  --  lo     *       0.0.0.0/0            0.0.0.0/0           
    2   120 DROP       tcp  --  *      *       192.168.255.22       0.0.0.0/0            tcp dpt:7000 recent: SET name: KNOCK side: source mask: 255.255.255.255
    1    60 ACCEPT     tcp  --  *      *       192.168.255.22       0.0.0.0/0            tcp dpt:22 ctstate NEW recent: CHECK seconds: 10 name: KNOCK side: source mask: 255.255.255.255
    4   240 DROP       tcp  --  *      *       192.168.255.22       0.0.0.0/0            tcp dpt:22
    0     0 ACCEPT     tcp  --  *      *       192.168.255.22       0.0.0.0/0            tcp dpt:22 ctstate NEW recent: CHECK seconds: 10 name: KNOCK side: source mask: 255.255.255.255

Chain FORWARD (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain OUTPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         
vagrant@inetRouter2:~$ sudo iptables -D INPUT -s 192.168.255.22 -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --name KNOCK --rcheck --seconds 10 -j ACCEPT
vagrant@inetRouter2:~$ 
```

Также после срабатывания правил видны пришёдшие пакеты в цепочке /proc/net/xt_recent/KNOCK :

```
vagrant@inetRouter2:~$ cat /proc/net/xt_recent/KNOCK
src=192.168.255.22 ttl: 64 last_seen: 4300320728 oldest_pkt: 2 4300179072, 4300320728
vagrant@inetRouter2:~$ 
```

Вывод: Knocking port работает.


## 2. запустить nginx на centralServer. Пробросить 80й порт на inetRouter2 8080. Дефолт в инет оставить через inetRouter.

#### 2.1 Запуск и проверка nginx на centralServer

Устанавливаем, запускаем и проверяем сервер nginx на centralServer:

```
[admin_insta11@mv334 iptables_lab]$ vagrant ssh centralServer
vagrant@centralServer:~$
vagrant@centralServer:~$ sudo apt-get update
Hit:1 http://us.archive.ubuntu.com/ubuntu jammy InRelease
Get:2 http://security.ubuntu.com/ubuntu jammy-security InRelease [129 kB]
Get:3 http://us.archive.ubuntu.com/ubuntu jammy-updates InRelease [128 kB]
<...>
Fetched 28.3 MB in 13s (2,188 kB/s)                                                                                         
Reading package lists... Done
vagrant@centralServer:~$ 
vagrant@centralServer:~$ sudo apt install nginx
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
The following additional packages will be installed:
  fontconfig-config fonts-dejavu-core libdeflate0 libfontconfig1 libgd3 libjbig0 libjpeg-turbo8 libjpeg8
  libnginx-mod-http-geoip2 libnginx-mod-http-image-filter libnginx-mod-http-xslt-filter libnginx-mod-mail
  libnginx-mod-stream libnginx-mod-stream-geoip2 libtiff5 libwebp7 libx11-6 libx11-data libxau6 libxcb1 libxdmcp6 libxpm4
  nginx-common nginx-core
Suggested packages:
  libgd-tools fcgiwrap nginx-doc ssl-cert
The following NEW packages will be installed:
  fontconfig-config fonts-dejavu-core libdeflate0 libfontconfig1 libgd3 libjbig0 libjpeg-turbo8 libjpeg8
  libnginx-mod-http-geoip2 libnginx-mod-http-image-filter libnginx-mod-http-xslt-filter libnginx-mod-mail
  libnginx-mod-stream libnginx-mod-stream-geoip2 libtiff5 libwebp7 libx11-6 libx11-data libxau6 libxcb1 libxdmcp6 libxpm4
  nginx nginx-common nginx-core
0 upgraded, 25 newly installed, 0 to remove and 199 not upgraded.
Need to get 1,710 kB/3,552 kB of archives.
After this operation, 11.5 MB of additional disk space will be used.
Do you want to continue? [Y/n] y
Get:1 http://us.archive.ubuntu.com/ubuntu jammy-updates/main amd64 libx11-data all 2:1.7.5-1ubuntu0.4 [120 kB]
Get:2 http://us.archive.ubuntu.com/ubuntu jammy-updates/main amd64 libx11-6 amd64 2:1.7.5-1ubuntu0.4 [668 kB]
<...>
vagrant@centralServer:~$ 
vagrant@centralServer:~$ sudo systemctl status nginx
● nginx.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/lib/systemd/system/nginx.service; enabled; vendor preset: enabled)
     Active: active (running) since Sat 2026-11-07 13:18:27 UTC; 33s ago
       Docs: man:nginx(8)
    Process: 2157 ExecStartPre=/usr/sbin/nginx -t -q -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
    Process: 2158 ExecStart=/usr/sbin/nginx -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
   Main PID: 2258 (nginx)
      Tasks: 2 (limit: 709)
     Memory: 4.0M
        CPU: 45ms
     CGroup: /system.slice/nginx.service
             ├─2258 "nginx: master process /usr/sbin/nginx -g daemon on; master_process on;"
             └─2262 "nginx: worker process" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" ""

Nov 07 13:18:27 centralServer systemd[1]: Starting A high performance web server and a reverse proxy server...
Nov 07 13:18:27 centralServer systemd[1]: Started A high performance web server and a reverse proxy server.
vagrant@centralServer:~$ 
vagrant@centralServer:~$ sudo vi /var/www/html/index.nginx-debian.html 
vagrant@centralServer:~$ 
vagrant@centralServer:~$ curl http://localhost/
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx - it's running on centralServer !</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
vagrant@centralServer:~$ 
```

Также проверяем доступ к странице nginx на centralServer с хоста через адрес 192.168.50.12 прямого доступа к centralServer:

<img width="787" height="587" alt="изображение" src="https://github.com/user-attachments/assets/eef00db8-5f95-4831-a3f4-5c5782fd2e85" />


#### 2.2 Проброс порта сервера nginx на порт 8080 на inetRouter2

Сервер nginx на centralServer работает на стандартном порту 80. Задача состоит в том, чтобы пробросить 80й порт centralServer на порт 8080 на inetRouter2.

Для этого на inetRouter2 делаем следующую конфигурацию iptables:

```
vagrant@inetRouter2:~$ sudo iptables -L -n -v
Chain INPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain FORWARD (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain OUTPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         
vagrant@inetRouter2:~$ 
vagrant@inetRouter2:~$ sudo iptables -t nat -A PREROUTING -p tcp --dport 8080 -j DNAT --to-destination 192.168.0.2:80
vagrant@inetRouter2:~$
vagrant@inetRouter2:~$ sudo iptables -t nat -A POSTROUTING -o eth1 -p tcp -d 192.168.0.2 --dport 80 -j MASQUERADE
vagrant@inetRouter2:~$ 
vagrant@inetRouter2:~$ sudo iptables -t nat -L -n -v
Chain PREROUTING (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         
    7   308 DNAT       tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            tcp dpt:8080 to:192.168.0.2:80

Chain INPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain OUTPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain POSTROUTING (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         
    1    44 MASQUERADE  tcp  --  *      eth1    0.0.0.0/0            192.168.0.2          tcp dpt:80
vagrant@inetRouter2:~$
```

Правило 

```
iptables -t nat -A PREROUTING -p tcp --dport 8080 -j DNAT --to-destination 192.168.0.2:80
```

обеспечивает проброс с открытого на inetRouter2 порта 8080 на порт 80 хоста centralServer (IP-адрес 192.168.0.2).

Правило

```
iptables -t nat -A POSTROUTING -o eth1 -p tcp -d 192.168.0.2 --dport 80 -j MASQUERADE
```

обеспечивает Source NAT (заменяет Source IP адрес исходящих с интерфейса eth1 пакетов на адрес интерфейса eth1 192.168.255.21).
Без этого Source NAT пакеты будут иметь адрес отправителя 10.0.2.2 маршрутизатора virtualbox, тогда обратные пакеты от centralServer будут
отправляться на centralRouter и с него далее по дефолтному маршруту в сторону inetRouter и далее в virtualbox - в результате ответные пакеты
обратно на inetRouter2 не попадут.  Суонфигурированный Source NAT обеспечивает возврат ответных пакетов обратно на inetRouter2 в соответствии с маршрутами на адрес 192.168.255.21.

### 2.3 Проверка доступа с хоста через проброшенный порт 8080 на inetRouter2 к nginx на centralServer

Доступ к серверу nginx на centralServer через проброшенный порт 8080 на inetRouter2 проверяем с хоста. Для этой цели:

1. В Vagrantfile при создании ВМ сконфигурирован проброс порта хоста localhost 8082 на порт inetRouter2 8080 :

```
  :inetRouter2 => {
        :box_name => BOX_NAME,
        :vm_name => "inetRouter2",
        #:public => {:ip => "10.10.10.1", :adapter => 1},
        :net => [
                    #ip, adpter, netmask, virtualbox__intnet
                    ["192.168.255.21", 2, "255.255.255.252",  "router2-net"],
                    ["192.168.50.20", 8, "255.255.255.0"],
                ],
        :fwd => [
          [22, 2332],
          [8080, 8082],
        ],
  },

И далее в конфигурации ВМ:

      if boxconfig[:fwd]
        boxconfig[:fwd].each do |guest_port, host_port|
          box.vm.network "forwarded_port", guest: guest_port, host: host_port,
            host_ip: "127.0.0.1", auto_correct: true
        end
      end
```

2. Для проверки прохождения пакетов запускаем tcpdump :

- на маршрутизаторе inetRouter2 - ожидается приход пакетов с хоста на проброшенный порт 8080:

```
vagrant@inetRouter2:~$ sudo tcpdump -i eth0 -vvv -nnn tcp port 8080
```

- на сервере centralServer - ожидается приход пакетов с inetRouter2 на порт 80 nginx:

```
vagrant@centralServer:~$ sudo tcpdump -i eth1 -s0 -vvv tcp port 80
```

После этого на хосте в WEB-броузере открываем страницу по ссылке  http://localhost:8082/

Открывается модифицированная нами страница nginx:

<img width="787" height="589" alt="изображение" src="https://github.com/user-attachments/assets/78a1da05-8827-4c1a-8302-661e7b2482ea" />


При этом в выводе tcpdump видно прохождение пакетов:

- на inetRouter2 - пакеты приходят с хоста с порта 8082 через проброс порта virtualbox на порт inetRouter2 8080
  (адрес 10.0.2.2 - адрес маршрутизатора virtualbox, адрес 10.0.2.15 - адрес внешнего интерфейса inetRouter2) :

```
vagrant@centralServer:~$ sudo tcpdump -i eth1 -s0 -vvv tcp port 80
tcpdump: listening on eth1, link-type EN10MB (Ethernet), snapshot length 262144 bytes
15:27:38.843699 IP (tos 0x0, ttl 64, id 6269, offset 0, flags [none], proto TCP (6), length 40)
    10.0.2.2.55414 > 10.0.2.15.8080: Flags [F.], cksum 0x5aec (correct), seq 1273345280, ack 3328212361, win 65535, length 0
15:27:38.843786 IP (tos 0x0, ttl 64, id 0, offset 0, flags [DF], proto TCP (6), length 40)
    10.0.2.15.8080 > 10.0.2.2.55414: Flags [R], cksum 0x5bdf (correct), seq 3328212361, win 0, length 0
15:27:38.844126 IP (tos 0x0, ttl 64, id 6270, offset 0, flags [none], proto TCP (6), length 44)
    10.0.2.2.48176 > 10.0.2.15.8080: Flags [S], cksum 0x8cf8 (correct), seq 1767616001, win 65535, options [mss 1460], length 0
15:27:38.846076 IP (tos 0x0, ttl 62, id 0, offset 0, flags [DF], proto TCP (6), length 44)
    10.0.2.15.8080 > 10.0.2.2.48176: Flags [S.], cksum 0xb684 (correct), seq 3029018342, ack 1767616002, win 64240, options [mss 1460], length 0
15:27:38.846411 IP (tos 0x0, ttl 64, id 6271, offset 0, flags [none], proto TCP (6), length 40)
    10.0.2.2.48176 > 10.0.2.15.8080: Flags [.], cksum 0xc932 (correct), seq 1, ack 1, win 65535, length 0
15:27:38.852242 IP (tos 0x0, ttl 64, id 6273, offset 0, flags [none], proto TCP (6), length 812)
    10.0.2.2.48176 > 10.0.2.15.8080: Flags [P.], cksum 0xaad4 (correct), seq 1:773, ack 1, win 65535, length 772: HTTP, length: 772
	GET / HTTP/1.1
	Host: localhost:8082
	Connection: keep-alive
	Cache-Control: max-age=0
	sec-ch-ua: "Not;A=Brand";v="24", "Chromium";v="128"
	sec-ch-ua-mobile: ?0
	sec-ch-ua-platform: "Linux"
	Upgrade-Insecure-Requests: 1
	User-Agent: Mozilla/5.0 (X11; Linux x86_64; Chromium GOST) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36
	Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7
	Sec-Fetch-Site: none
	Sec-Fetch-Mode: navigate
	Sec-Fetch-User: ?1
	Sec-Fetch-Dest: document
	Accept-Encoding: gzip, deflate, br, zstd
	Accept-Language: ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7
	If-None-Match: W/"6aef2612-285"
	If-Modified-Since: Sat, 07 Nov 2026 13:22:26 GMT
	
15:27:38.853692 IP (tos 0x0, ttl 62, id 53502, offset 0, flags [DF], proto TCP (6), length 40)
    10.0.2.15.8080 > 10.0.2.2.48176: Flags [.], cksum 0xcbe1 (correct), seq 1, ack 773, win 64076, length 0
15:27:38.853941 IP (tos 0x0, ttl 62, id 53503, offset 0, flags [DF], proto TCP (6), length 229)
    10.0.2.15.8080 > 10.0.2.2.48176: Flags [P.], cksum 0x8fd2 (correct), seq 1:190, ack 773, win 64076, length 189: HTTP, length: 189
	HTTP/1.1 304 Not Modified
	Server: nginx/1.18.0 (Ubuntu)
	Date: Sat, 07 Nov 2026 15:27:38 GMT
	Last-Modified: Sat, 07 Nov 2026 13:22:26 GMT
	Connection: keep-alive
	ETag: "6aef2612-285"
	
15:27:38.854124 IP (tos 0x0, ttl 64, id 6274, offset 0, flags [none], proto TCP (6), length 40)
    10.0.2.2.48176 > 10.0.2.15.8080: Flags [.], cksum 0xc571 (correct), seq 773, ack 190, win 65535, length 0
15:27:38.856848 IP (tos 0x0, ttl 64, id 6275, offset 0, flags [none], proto TCP (6), length 44)
    10.0.2.2.48190 > 10.0.2.15.8080: Flags [S], cksum 0x92e9 (correct), seq 1767680001, win 65535, options [mss 1460], length 0
15:27:38.858310 IP (tos 0x0, ttl 62, id 0, offset 0, flags [DF], proto TCP (6), length 44)
    10.0.2.15.8080 > 10.0.2.2.48190: Flags [S.], cksum 0xaf51 (correct), seq 815839221, ack 1767680002, win 64240, options [mss 1460], length 0
15:27:38.858584 IP (tos 0x0, ttl 64, id 6276, offset 0, flags [none], proto TCP (6), length 40)
    10.0.2.2.48190 > 10.0.2.15.8080: Flags [.], cksum 0xc1ff (correct), seq 1, ack 1, win 65535, length 0
15:28:38.862985 IP (tos 0x0, ttl 62, id 22707, offset 0, flags [DF], proto TCP (6), length 40)
    10.0.2.15.8080 > 10.0.2.2.48190: Flags [F.], cksum 0xc70d (correct), seq 1, ack 1, win 64240, length 0
15:28:38.863736 IP (tos 0x0, ttl 64, id 6279, offset 0, flags [none], proto TCP (6), length 40)
    10.0.2.2.48190 > 10.0.2.15.8080: Flags [.], cksum 0xc1fe (correct), seq 1, ack 2, win 65535, length 0
15:28:53.868289 IP (tos 0x0, ttl 62, id 53504, offset 0, flags [DF], proto TCP (6), length 40)
    10.0.2.15.8080 > 10.0.2.2.48176: Flags [F.], cksum 0xcb23 (correct), seq 190, ack 773, win 64076, length 0
15:28:53.868928 IP (tos 0x0, ttl 64, id 6281, offset 0, flags [none], proto TCP (6), length 40)
    10.0.2.2.48176 > 10.0.2.15.8080: Flags [.], cksum 0xc570 (correct), seq 773, ack 191, win 65535, length 0
```

- на centralServer виден приход пакетов с адреса 192.168.255.21 интерфейса eth1 маршрутизатора inetRouter2 на порт 80 сервера nginx:

```
vagrant@centralServer:~$ sudo tcpdump -i eth1 -s0 -vvv tcp port 80
tcpdump: listening on eth1, link-type EN10MB (Ethernet), snapshot length 262144 bytes
15:27:38.619100 IP (tos 0x0, ttl 62, id 6270, offset 0, flags [none], proto TCP (6), length 44)
    192.168.255.21.48176 > centralServer.http: Flags [S], cksum 0x43e0 (correct), seq 1767616001, win 65535, options [mss 1460], length 0
15:27:38.619195 IP (tos 0x0, ttl 64, id 0, offset 0, flags [DF], proto TCP (6), length 44)
    centralServer.http > 192.168.255.21.48176: Flags [S.], cksum 0x8087 (incorrect -> 0x6d6c), seq 3029018342, ack 1767616002, win 64240, options [mss 1460], length 0
15:27:38.621217 IP (tos 0x0, ttl 62, id 6271, offset 0, flags [none], proto TCP (6), length 40)
    192.168.255.21.48176 > centralServer.http: Flags [.], cksum 0x801a (correct), seq 1, ack 1, win 65535, length 0
15:27:38.626930 IP (tos 0x0, ttl 62, id 6273, offset 0, flags [none], proto TCP (6), length 812)
    192.168.255.21.48176 > centralServer.http: Flags [P.], cksum 0x61bc (correct), seq 1:773, ack 1, win 65535, length 772: HTTP, length: 772
	GET / HTTP/1.1
	Host: localhost:8082
	Connection: keep-alive
	Cache-Control: max-age=0
	sec-ch-ua: "Not;A=Brand";v="24", "Chromium";v="128"
	sec-ch-ua-mobile: ?0
	sec-ch-ua-platform: "Linux"
	Upgrade-Insecure-Requests: 1
	User-Agent: Mozilla/5.0 (X11; Linux x86_64; Chromium GOST) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36
	Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7
	Sec-Fetch-Site: none
	Sec-Fetch-Mode: navigate
	Sec-Fetch-User: ?1
	Sec-Fetch-Dest: document
	Accept-Encoding: gzip, deflate, br, zstd
	Accept-Language: ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7
	If-None-Match: W/"6aef2612-285"
	If-Modified-Since: Sat, 07 Nov 2026 13:22:26 GMT
	
15:27:38.626984 IP (tos 0x0, ttl 64, id 53502, offset 0, flags [DF], proto TCP (6), length 40)
    centralServer.http > 192.168.255.21.48176: Flags [.], cksum 0x8083 (incorrect -> 0x82c9), seq 1, ack 773, win 64076, length 0
15:27:38.627345 IP (tos 0x0, ttl 64, id 53503, offset 0, flags [DF], proto TCP (6), length 229)
    centralServer.http > 192.168.255.21.48176: Flags [P.], cksum 0x8140 (incorrect -> 0x46ba), seq 1:190, ack 773, win 64076, length 189: HTTP, length: 189
	HTTP/1.1 304 Not Modified
	Server: nginx/1.18.0 (Ubuntu)
	Date: Sat, 07 Nov 2026 15:27:38 GMT
	Last-Modified: Sat, 07 Nov 2026 13:22:26 GMT
	Connection: keep-alive
	ETag: "6aef2612-285"
	
15:27:38.628699 IP (tos 0x0, ttl 62, id 6274, offset 0, flags [none], proto TCP (6), length 40)
    192.168.255.21.48176 > centralServer.http: Flags [.], cksum 0x7c59 (correct), seq 773, ack 190, win 65535, length 0
15:27:38.631427 IP (tos 0x0, ttl 62, id 6275, offset 0, flags [none], proto TCP (6), length 44)
    192.168.255.21.48190 > centralServer.http: Flags [S], cksum 0x49d1 (correct), seq 1767680001, win 65535, options [mss 1460], length 0
15:27:38.631466 IP (tos 0x0, ttl 64, id 0, offset 0, flags [DF], proto TCP (6), length 44)
    centralServer.http > 192.168.255.21.48190: Flags [S.], cksum 0x8087 (incorrect -> 0x6639), seq 815839221, ack 1767680002, win 64240, options [mss 1460], length 0
15:27:38.633093 IP (tos 0x0, ttl 62, id 6276, offset 0, flags [none], proto TCP (6), length 40)
    192.168.255.21.48190 > centralServer.http: Flags [.], cksum 0x78e7 (correct), seq 1, ack 1, win 65535, length 0
15:28:38.635854 IP (tos 0x0, ttl 64, id 22707, offset 0, flags [DF], proto TCP (6), length 40)
    centralServer.http > 192.168.255.21.48190: Flags [F.], cksum 0x8083 (incorrect -> 0x7df5), seq 1, ack 1, win 64240, length 0
15:28:38.638573 IP (tos 0x0, ttl 62, id 6279, offset 0, flags [none], proto TCP (6), length 40)
    192.168.255.21.48190 > centralServer.http: Flags [.], cksum 0x78e6 (correct), seq 1, ack 2, win 65535, length 0
15:28:53.641171 IP (tos 0x0, ttl 64, id 53504, offset 0, flags [DF], proto TCP (6), length 40)
    centralServer.http > 192.168.255.21.48176: Flags [F.], cksum 0x8083 (incorrect -> 0x820b), seq 190, ack 773, win 64076, length 0
15:28:53.643661 IP (tos 0x0, ttl 62, id 6281, offset 0, flags [none], proto TCP (6), length 40)
    192.168.255.21.48176 > centralServer.http: Flags [.], cksum 0x7c58 (correct), seq 773, ack 191, win 65535, length 0

```

Проброс порта для доступа к порту 80 nginx работает. С учётом доступа с хоста проброс порта получился двойным:

- сначала проброс порта localhost:8082 на порт 8080 ВМ inetRouter2 - средствами встроенного маршрутизатора virtualbox;
  
- затем проброс порта 8080 c inetRouter2 на порт 80 ВМ centralServer - конфигурацией iptables на inetRouter2.


## 3. Общая конфигурация iptables по двух заданиям 

Общая конфигурация iptables по двух заданиям на inetRouter2 представлена ниже:

```
vagrant@inetRouter2:~$ sudo iptables-save
# Generated by iptables-save v1.8.7 on Sat Nov  7 19:54:42 2026
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -s 192.168.255.22/32 -p tcp -m tcp --dport 7000 -m recent --set --name KNOCK --mask 255.255.255.255 --rsource -j DROP
-A INPUT -s 192.168.255.22/32 -p tcp -m tcp --dport 22 -m conntrack --ctstate NEW -m recent --rcheck --seconds 10 --name KNOCK --mask 255.255.255.255 --rsource -j ACCEPT
-A INPUT -s 192.168.255.22/32 -p tcp -m tcp --dport 22 -j DROP
COMMIT
# Completed on Sat Nov  7 19:54:42 2026
# Generated by iptables-save v1.8.7 on Sat Nov  7 19:54:42 2026
*nat
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
-A PREROUTING -p tcp -m tcp --dport 8080 -j DNAT --to-destination 192.168.0.2:80
-A POSTROUTING -d 192.168.0.2/32 -o eth1 -p tcp -m tcp --dport 80 -j MASQUERADE
COMMIT
# Completed on Sat Nov  7 19:54:42 2026
vagrant@inetRouter2:~$ 
```

Для загрузки правил при заждой загрузке ВМ устанавливаем пакет iptables-persistent и сохраняем правила в него :

```
vagrant@inetRouter2:~$ sudo apt update
Get:1 http://security.ubuntu.com/ubuntu jammy-security InRelease [129 kB]
Hit:2 http://us.archive.ubuntu.com/ubuntu jammy InRelease
Get:3 http://us.archive.ubuntu.com/ubuntu jammy-updates InRelease [128 kB]
Get:4 http://us.archive.ubuntu.com/ubuntu jammy-backports InRelease [127 kB]
Get:5 http://security.ubuntu.com/ubuntu jammy-security/main amd64 Packages [3,675 kB]
Get:6 http://us.archive.ubuntu.com/ubuntu jammy-updates/main amd64 Packages [3,963 kB]
Get:7 http://security.ubuntu.com/ubuntu jammy-security/main Translation-en [513 kB]
Get:8 http://security.ubuntu.com/ubuntu jammy-security/restricted amd64 Packages [6,545 kB]   
Get:9 http://us.archive.ubuntu.com/ubuntu jammy-updates/main Translation-en [582 kB]            
Get:10 http://us.archive.ubuntu.com/ubuntu jammy-updates/restricted amd64 Packages [6,815 kB]     
Get:11 http://security.ubuntu.com/ubuntu jammy-security/restricted Translation-en [1,257 kB]      
Get:12 http://security.ubuntu.com/ubuntu jammy-security/universe amd64 Packages [1,057 kB]        
Get:13 http://security.ubuntu.com/ubuntu jammy-security/universe Translation-en [238 kB]                 
Get:14 http://security.ubuntu.com/ubuntu jammy-security/multiverse amd64 Packages [79.6 kB]           
Get:15 http://security.ubuntu.com/ubuntu jammy-security/multiverse Translation-en [13.6 kB]      
Get:16 http://us.archive.ubuntu.com/ubuntu jammy-updates/restricted Translation-en [1,310 kB]                               
Get:17 http://us.archive.ubuntu.com/ubuntu jammy-updates/universe amd64 Packages [1,291 kB]                                 
Get:18 http://us.archive.ubuntu.com/ubuntu jammy-updates/universe Translation-en [327 kB]                                   
Get:19 http://us.archive.ubuntu.com/ubuntu jammy-updates/multiverse amd64 Packages [86.1 kB]                                
Get:20 http://us.archive.ubuntu.com/ubuntu jammy-updates/multiverse Translation-en [16.5 kB]                                
Get:21 http://us.archive.ubuntu.com/ubuntu jammy-backports/main amd64 Packages [70.2 kB]                                    
Get:22 http://us.archive.ubuntu.com/ubuntu jammy-backports/main Translation-en [11.4 kB]                                    
Get:23 http://us.archive.ubuntu.com/ubuntu jammy-backports/universe amd64 Packages [30.8 kB]                                
Get:24 http://us.archive.ubuntu.com/ubuntu jammy-backports/universe Translation-en [16.9 kB]                                
Fetched 28.3 MB in 13s (2,126 kB/s)                                                                                         
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
199 packages can be upgraded. Run 'apt list --upgradable' to see them.
vagrant@inetRouter2:~$ 
vagrant@inetRouter2:~$ sudo apt install iptables-persistent
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
The following additional packages will be installed:
  netfilter-persistent
The following NEW packages will be installed:
  iptables-persistent netfilter-persistent
0 upgraded, 2 newly installed, 0 to remove and 199 not upgraded.
Need to get 13.9 kB of archives.
After this operation, 93.2 kB of additional disk space will be used.
Do you want to continue? [Y/n] y
Get:1 http://us.archive.ubuntu.com/ubuntu jammy/universe amd64 netfilter-persistent all 1.0.16 [7,440 B]
Get:2 http://us.archive.ubuntu.com/ubuntu jammy/universe amd64 iptables-persistent all 1.0.16 [6,488 B]
Fetched 13.9 kB in 1s (17.0 kB/s)         
Preconfiguring packages ...
Selecting previously unselected package netfilter-persistent.
(Reading database ... 45848 files and directories currently installed.)
Preparing to unpack .../netfilter-persistent_1.0.16_all.deb ...
Unpacking netfilter-persistent (1.0.16) ...
Selecting previously unselected package iptables-persistent.
Preparing to unpack .../iptables-persistent_1.0.16_all.deb ...
Unpacking iptables-persistent (1.0.16) ...
Setting up netfilter-persistent (1.0.16) ...
Created symlink /etc/systemd/system/multi-user.target.wants/netfilter-persistent.service → /lib/systemd/system/netfilter-pers
istent.service.
Setting up iptables-persistent (1.0.16) ...
update-alternatives: using /lib/systemd/system/netfilter-persistent.service to provide /lib/systemd/system/iptables.service (
iptables.service) in auto mode
Processing triggers for man-db (2.10.2-1) ...
Scanning processes...                                                                                                        
Scanning linux images...                                                                                                     

Running kernel seems to be up-to-date.

No services need to be restarted.

No containers need to be restarted.

No user sessions are running outdated binaries.

No VM guests are running outdated hypervisor (qemu) binaries on this host.
vagrant@inetRouter2:~$ 
vagrant@inetRouter2:~$ sudo netfilter-persistent save
run-parts: executing /usr/share/netfilter-persistent/plugins.d/15-ip4tables save
run-parts: executing /usr/share/netfilter-persistent/plugins.d/25-ip6tables save
vagrant@inetRouter2:~$ 
vagrant@inetRouter2:~$ 
vagrant@inetRouter2:~$ cat /etc/iptables/rules.v4
cat: /etc/iptables/rules.v4: Permission denied
vagrant@inetRouter2:~$ sudo cat /etc/iptables/rules.v4
# Generated by iptables-save v1.8.7 on Sun Nov  8 05:25:51 2026
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -s 192.168.255.22/32 -p tcp -m tcp --dport 7000 -m recent --set --name KNOCK --mask 255.255.255.255 --rsource -j DROP
-A INPUT -s 192.168.255.22/32 -p tcp -m tcp --dport 22 -m conntrack --ctstate NEW -m recent --rcheck --seconds 10 --name KNOCK --mask 255.255.255.255 --rsource -j ACCEPT
-A INPUT -s 192.168.255.22/32 -p tcp -m tcp --dport 22 -j DROP
COMMIT
# Completed on Sun Nov  8 05:25:51 2026
# Generated by iptables-save v1.8.7 on Sun Nov  8 05:25:51 2026
*nat
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
-A PREROUTING -p tcp -m tcp --dport 8080 -j DNAT --to-destination 192.168.0.2:80
-A POSTROUTING -d 192.168.0.2/32 -o eth1 -p tcp -m tcp --dport 80 -j MASQUERADE
COMMIT
# Completed on Sun Nov  8 05:25:51 2026
vagrant@inetRouter2:~$ 
vagrant@inetRouter2:~$ sudo systemctl status netfilter-persistent
● netfilter-persistent.service - netfilter persistent configuration
     Loaded: loaded (/lib/systemd/system/netfilter-persistent.service; enabled; vendor preset: enabled)
    Drop-In: /etc/systemd/system/netfilter-persistent.service.d
             └─iptables.conf
     Active: active (exited) since Sun 2026-11-08 05:25:29 UTC; 1min 18s ago
       Docs: man:netfilter-persistent(8)
   Main PID: 3067 (code=exited, status=0/SUCCESS)
        CPU: 6ms

Nov 08 05:25:29 inetRouter2 systemd[1]: Starting netfilter persistent configuration...
Nov 08 05:25:29 inetRouter2 netfilter-persistent[3069]: run-parts: executing /usr/share/netfilter-persistent/plugins.d/15-ip>
Nov 08 05:25:29 inetRouter2 netfilter-persistent[3070]: Warning: skipping IPv4 (no rules to load)
Nov 08 05:25:29 inetRouter2 systemd[1]: Finished netfilter persistent configuration.
Nov 08 05:25:29 inetRouter2 netfilter-persistent[3069]: run-parts: executing /usr/share/netfilter-persistent/plugins.d/25-ip>
Nov 08 05:25:29 inetRouter2 netfilter-persistent[3071]: Warning: skipping IPv6 (no rules to load)
vagrant@inetRouter2:~$ 
vagrant@inetRouter2:~$ sudo netfilter-persistent start
run-parts: executing /usr/share/netfilter-persistent/plugins.d/15-ip4tables start
run-parts: executing /usr/share/netfilter-persistent/plugins.d/25-ip6tables start
vagrant@inetRouter2:~$ 
```


# КОНЕЦ


# Примечания и дополнительная информация/заметки:

## Q1: 

Почему у inetRouter и inetRouter2 на внешних интерфейсах выдаются одинаковые адреса 10.0.2.15 ? Как это изменить, чтобы virtualbox dhcp выдавал разные адреса ?

## A1:

Короткий ответ: это не баг и не «один общий DHCP». У каждой ВМ в VirtualBox свой изолированный NAT-движок, и у него дефолтная подсеть — всегда 10.0.2.0/24 с шлюзом 10.0.2.2 и DHCP, раздающим первый адрес 10.0.2.15. Эти два роутера физически не видят друг друга через eth0 — у них просто совпадают адреса в двух разных частных NAT-сетках. Поэтому и в SSH вы заходите не через них, а через вашу отдельную management-сеть 192.168.50.0/24.

### Менять ли что-то вообще

Для лабы по iptables менять ничего не нужно: eth0 — это «выход в интернет» через хост, а вся топология у вас на внутренних сетях. Но если хочется, чтобы внешние интерфейсы имели разные подсети (например, для отработки dual-uplink и выбора маршрута), вот варианты.

### Вариант 1: своя NAT-подсеть на каждую ВМ

VirtualBox позволяет менять подсеть дефолтного NAT через modifyvm --natnet1. В Vagrantfile это делается так:

```
box.vm.provider "virtualbox" do |v|
  v.memory = 768
  v.cpus = 1
  if boxconfig[:nat_net]
    v.customize ["modifyvm", :id, "--natnet1", boxconfig[:nat_net]]
  end
end
```

и в описании машин:

```
:inetRouter => {
  ...
  :nat_net => "10.11.0.0/24",
},
:inetRouter2 => {
  ...
  :nat_net => "10.12.0.0/24",
},
```

После vagrant reload у inetRouter eth0 получит адрес из 10.11.0.0/24, у inetRouter2 — из 10.12.0.0/24 (встроенный DHCP подстроится под новую сетку автоматически). Доступ по vagrant ssh не сломается: Vagrant пробрасывает SSH-порты через тот же NAT-адаптер.


### Вариант 2: общая NAT Network на обе ВМ

Если нужно, чтобы роутеры жили в одной внешней сетке и получали от DHCP разные адреса — это «NAT Network» VirtualBox, а не дефолтный NAT. Создаётся на хосте:

```
VBoxManage natnetwork add --netname labnat --network "10.9.9.0/24" --dhcp on --enable
```

и подключается к ВМ дополнительным адаптером:

```
v.customize ["modifyvm", :id, "--nic3", "natnetwork"]
v.customize ["modifyvm", :id, "--nat-network3", "labnat"]
```

**Важно:** adapter 1 оставьте обычным NAT — именно через него Vagrant делает проброс SSH-портов, и переключение его на natnetwork ломает vagrant ssh.


### Вариант 3: bridged (real LAN)

Раскомментировать :public => ... — тогда адреса придут от DHCP вашего реального роутера и будут заведомо разными. Но тут вас подстерегает настоящая проблема: у обеих машин eth0 имеет один и тот же MAC — 08:00:27:16:dd:ef (видно и в IPv6 link-local, который из MAC и собирается). В NAT-режиме это безразлично, а вот в bridged две ВМ с одним MAC на одном свитче будут грызться за аренду. Лечится заданием уникального MAC:

```
v.customize ["modifyvm", :id, "--macaddress1", "0800270000XY"]
```

## Q2: 

А почему одинаковые MAC-адреса у двух разных ВМ? Это как исправить ?

## A2:

Причина простая: MAC 08:00:27:16:dd:ef «приехал» из самого бокса. Когда bento собирает образ bento/ubuntu-22.04, первая сетевая карта в экспортированной виртуалке получает какой-то конкретный MAC, и он сохраняется в метаданных бокса. При vagrant up Vagrant не генерирует новый MAC для адаптера 1, а берёт настройки ВМ из бокса как есть — поэтому у всех машин, поднятых из одного бокса, eth0 выходит с одним и тем же адресом. А вот eth1 и eth2 Vagrant добавляет сам, и для них MAC-и генерируются случайно — потому они у вас разные. То же самое с IPv6 link-local: fe80::a00:27ff:fe16:ddef построен из этого самого MAC.

Пока все сетевушки в режиме дефолтного NAT, это безвредно — ВМ не встречаются в одном L2-сегменте. Но как только появится bridged или общая NAT Network, начнутся конфликты.

### Как исправить

**Способ 1:** Самый надёжный способ — задать уникальные MAC прямо в Vagrantfile. Удобно завести их в конфиг машины:

```
MACHINES = {
  :inetRouter => {
    ...
    :mac1 => "0800270000A1",   # адаптер 1 (NAT)
  },
  :inetRouter2 => {
    ...
    :mac1 => "0800270000A2",
  },
}
```

и в блоке провайдера:

```
box.vm.provider "virtualbox" do |v|
  v.memory = 768
  v.cpus = 1
  v.customize ["modifyvm", :id, "--macaddress1", boxconfig[:mac1]] if boxconfig[:mac1]
end
```

Формат MAC: 12 hex-символов без разделителей, первая шестнадцатеричная цифра должна быть чётной (unicast), а 08:00:27 — префикс VirtualBox, его лучше сохранить.


**Способ 2:** Вариант попроще, без ручных адресов — попросить VirtualBox сгенерировать MAC автоматически:

```
v.customize ["modifyvm", :id, "--macaddress1", "auto"]
```

Тогда при каждом пересоздании ВМ получит случайный MAC. Для лабы оба варианта равнозначны; статические удобнее, если захотите позже привязать правила iptables к MAC-адресам (-m mac --mac-source).
Как применить

vagrant reload недостаточно, если MAC «запечён» в существующую ВМ — надёжнее пересоздать машины:

```
vagrant destroy -f
vagrant up
```

После этого ip a на каждой машине покажет разные MAC на eth0.

Нюанс: в Ubuntu 22.04 имена интерфейсов (enp0s3 и т.п.) строятся по слотам PCI, а не по MAC, так что переименования интерфейсов после смены адреса не будет — eth0 останется eth0. А вот если у вас где-то в netplan прописана привязка к MAC — там её придётся обновить, но у дефолтного бокса такого нет.


## Q3: 

Нужно сделать, чтобы inetRouter2 был доступен через форвард порта через локалхост. Так что надо разные IP выданные по DHCP

## A3:

Тут важный момент: форвард портов в Vagrant/VirtualBox не зависит от IP гостя вообще. Механика такая: VirtualBox слушает порт на хосте (например, 127.0.0.1:2222) и заворачивает соединение в NAT-движок конкретной ВМ — а у каждой машины он свой, со своей внутренней сеткой. Поэтому одинаковые 10.0.2.15 у двух ВМ форварду не мешают: каждый форвард «прибит» к конкретной ВМ, а не к адресу.

Так что для доступа к inetRouter2 через localhost достаточно просто добавить форварды с разными хостовыми портами:

```
:inetRouter => {
  ...
  :fwd => [
    [22, 2201],   # guest, host
    [8080, 8081],
  ],
},
:inetRouter2 => {
  ...
  :fwd => [
    [22, 2202],
    [8080, 8082],
  ],
},
```

и в конфигурации:

```
if boxconfig[:fwd]
  boxconfig[:fwd].each do |guest_port, host_port|
    box.vm.network "forwarded_port", guest: guest_port, host: host_port,
      host_ip: "127.0.0.1", auto_correct: true
  end
end
```

После vagrant reload:

```
ssh -p 2202 vagrant@127.0.0.1   # это inetRouter2
curl http://127.0.0.1:8082      # сервис на inetRouter2
```

Пара нюансов:

- auto_correct: true спасёт, если порт на хосте занят — Vagrant подберёт свободный и напишет какой. Для дефолтного SSH-форварда (2222) Vagrant сам разруливает коллизии между машинами.
  
- SSH-форвард для inetRouter2 лучше объявить с другим host: — иначе id: "ssh" совпадёт и порт 2222 достанется первой машине, а вторая уйдёт на 2223. С явными портами (2201/2202) вы контролируете всё сами.

### Если всё-таки нужны разные DHCP-адреса

Форварду они не нужны, но если хочется, чтобы eth0 у машин отличался — снова вариант с --natnet1:

```
:inetRouter  => { ..., :nat_net => "10.11.0.0/24" },
:inetRouter2 => { ..., :nat_net => "10.12.0.0/24" },
```

Встроенный DHCP каждой NAT-сетки выдаст адрес из своей подсети: 10.11.0.15 и 10.12.0.15. Форварды продолжат работать как раньше — они к адаптеру 1 и так привязаны, а не к адресу.

И маленькое наблюдение: у вас обе машины уже имеют разные адреса в management-сети 192.168.50.0/24 (.10 и .20) — вы ведь по ним и подключаетесь по SSH. Так что «доступ через localhost по форварду» и «доступ по 192.168.50.x» — это два независимых пути, можно пользоваться обоими. Что именно планируется пускать через форварды — SSH или какой-то сервис на роутере?

 
### Если с хоста нужно иметь доступ к внутренним сетям virtualbox за маршрутизатором inetRouter2

Если хост должен дотягиваться до внутренних сетей за inetRouter2 (например, до 192.168.255.20/30), нужно два шага:

1. Роутер должен пересылать пакеты. На inetRouter2 нужно включить форвардинг пакетов:

```
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward = 1" | sudo tee /etc/sysctl.d/99-forward.conf
sudo sysctl -p /etc/sysctl.d/99-forward.conf
```

2. На хосте добавить маршрут в внутренние сети через inetRouter2:

```
sudo ip route add 192.168.255.20/30 via 192.168.50.20
sudo ip route add 192.168.255.16/30 via 192.168.50.20   # линк inetRouter2—centralRouter
```

(обратный путь из внутренних сетей в хост-сеть 192.168.50.0/24 уже есть через центральные роутеры, если у них прописаны маршруты — проверьте).

Проверка с хоста:

ping -c 2 192.168.255.21        # свой линк inetRouter2
ping -c 2 192.168.255.22        # линк к centralRouter (если тот отвечает и путь настроен)

Если ping до 192.168.255.22 не проходит, вернитесь с трассировкой — почти всегда это missing route в одну из сторон.

Вариант Б: форвард портов через localhost

Добавьте в описание машин:

```
:inetRouter => {
  ...
  :fwd => [ [22, 2201] ],
},
:inetRouter2 => {
  ...
  :fwd => [ [22, 2202] ],
},
```

и в общий блок:

```
if boxconfig[:fwd]
  boxconfig[:fwd].each do |guest, host|
    box.vm.network "forwarded_port",
      guest: guest, host: host, host_ip: "127.0.0.1", auto_correct: true
  end
end
```

После vagrant reload доступ с хоста:

```
ssh -p 2202 vagrant@127.0.0.1     # попадёте на inetRouter2
```

Два замечания:

- Vagrant по умолчанию и так пробрасывает SSH (порт 2222 и далее по номерам), но делает это «вслепую» — при большом числе машин легко запутаться, какой порт к какой ВМ. Явные порты дают предсказуемость.

- auto_correct: true подстрахует, если 2201/2202 на хосте кем-то заняты — Vagrant возьмёт следующий свободный и напишет об этом.


## Q4: 

Как создавать схемы с последовательным стуком на несколько портов ?


## A4: 


Классическая схема port knocking с recent

Обычно выглядит так — три «стука» на закрытые порты, затем открытие SSH:

```
# 1. Создаём цепочки (обязательно до правил, которые на них ссылаются)
iptables -N KNOCKING
iptables -N KNOCK2
iptables -N KNOCK3

# 2. Логика стука
iptables -A KNOCKING -p tcp --dport 10001 -m recent --name KNOCK1 --set -j DROP
iptables -A KNOCKING -p tcp --dport 10002 -m recent --name KNOCK1 --rcheck --seconds 10 -j KNOCK2
iptables -A KNOCKING -p tcp --dport 10003 -m recent --name KNOCK2 --rcheck --seconds 10 -j KNOCK3
iptables -A KNOCKING -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --name KNOCK3 --rcheck --seconds 10 -j ACCEPT

# 3. Фиксация второго и третьего стука
iptables -A KNOCK2 -m recent --name KNOCK2 --set -j DROP
iptables -A KNOCK3 -m recent --name KNOCK3 --set -j DROP

# 4. INPUT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -j KNOCKING
iptables -A INPUT -p tcp --dport 22 -j DROP
```

Два практических замечания

    Повторный запуск. -N на уже существующую цепочку выдаст File exists. Если гоняешь скрипт многократно, начни с очистки: iptables -X KNOCKING KNOCK2 KNOCK3 сработает только на пустые, так что сначала -F каждой, либо просто выполняй блок один раз в рамках лабы.
	
    Проверка. Постучись последовательно: nc -z <сервер> 10001, 10002, 10003 в течение 10 секунд между стуками, потом сразу ssh. Списки можно смотреть так: ls /proc/net/xt_recent/ — там должны появиться KNOCK1, KNOCK2, KNOCK3 по мере прохождения последовательности.
