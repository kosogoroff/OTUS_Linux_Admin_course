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

<img width="705" height="565" alt="изображение" src="https://github.com/user-attachments/assets/26f87e15-d6da-485d-a001-c47c636ad12f" />

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
        box.vm.network "private_network", ipconf
      end

     end
  end
end
```

По сравнению с Vagrantfile в приведённом сделано несколько изменений:

1. Добавлена возможность в явном виде указывать название бокса Vagrant для создания виртуальных машин из командной строки - в том числе и из
   числа локально скачанных боксов Vagrant:

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
