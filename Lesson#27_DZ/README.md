# Занятие 08.10.2026 "27. Резервное копирование"

Настраиваем бэкапы

## Цель:

Настроить бэкапы.

## Описание/Пошаговая инструкция выполнения домашнего задания:

Для выполнения домашнего задания используйте методичку


#### Что нужно сделать?

Настроить стенд Vagrant с двумя виртуальными машинами: backup_server и client.


Настроить удаленный бекап каталога /etc c сервера client при помощи borgbackup. Резервные копии должны соответствовать следующим критериям:

- директория для резервных копий /var/backup. Это должна быть отдельная точка монтирования. В данном случае для демонстрации размер не принципиален, достаточно будет и 2GB;

- репозиторий дле резервных копий должен быть зашифрован ключом или паролем - на ваше усмотрение;
  
- имя бекапа должно содержать информацию о времени снятия бекапа;

- глубина бекапа должна быть год, хранить можно по последней копии на конец месяца, кроме последних трех.
  
- Последние три месяца должны содержать копии на каждый день. Т.е. должна быть правильно настроена политика удаления старых бэкапов;

- резервная копия снимается каждые 5 минут. Такой частый запуск в целях демонстрации;

- написан скрипт для снятия резервных копий. Скрипт запускается из соответствующей Cron джобы, либо systemd timer-а - на ваше усмотрение;
  
- настроено логирование процесса бекапа. Для упрощения можно весь вывод перенаправлять в logger с соответствующим тегом. Если настроите не в syslog, то обязательна ротация логов.


Запустите стенд на 30 минут.

Убедитесь что резервные копии снимаются.

Остановите бекап, удалите (или переместите) директорию /etc и восстановите ее из бекапа.

Для сдачи домашнего задания ожидаем настроенные стенд, логи процесса бэкапа и описание процесса восстановления.

Формат сдачи ДЗ - vagrant + ansible

# Решение

### 1. Создание конфигурирование ВМ и конфигурирование  средствами ansible

### Описание 

#### 1.1 Создание ВМ и первоначально конфигурирование доступа средствами vagrant

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
PROVIDER = ENV["VAGRANT_DEFAULT_PROVIDER"] || "virtualbox"
BOX_NAME = ENV['VAGRANT_BOX'] || 'bento/ubuntu-22.04'

Vagrant.configure("2") do |config|
  config.vm.box = BOX_NAME

  # Общие настройки ресурсов
  config.vm.provider :virtualbox do |v|
    v.memory = 1512
    v.cpus = 2
  end

  config.vm.provider :libvirt do |lv|
    lv.memory = 1512
    lv.cpus = 2
  end

  boxes = [
    { name: "backup", ip: "192.168.56.160" },
    { name: "client", ip: "192.168.56.150" }
  ]

  boxes.each do |opts|
    config.vm.define opts[:name] do |vm|
      vm.vm.hostname = opts[:name]
      vm.vm.network "private_network", ip: opts[:ip]

      # Диск только для backup
      if opts[:name] == "backup"
        # VirtualBox: создать и подключить .vdi
        vm.vm.provider :virtualbox do |vb|
          disk_path = "./backup_disk.vdi"
          size_mb = 5120  # 5 ГБ

          unless File.exist?(disk_path)
            vb.customize ["createhd", "--filename", disk_path, "--size", size_mb.to_s]
          end

          vb.customize [
            "storageattach", :id,
            "--storagectl", "SATA Controller",
            "--port", 1,
            "--type", "hdd",
            "--medium", disk_path
          ]
        end

        # Libvirt: подключить существующий или создать .qcow2 (через qemu-img на хосте)
        vm.vm.provider :libvirt do |lv|
          # Для libvirt Vagrant не умеет сам создавать диск — его нужно создать заранее на хосте командой:
          #   qemu-img create -f qcow2 backup_disk.qcow2 5G
          disk_path = "./backup_disk.qcow2"

          lv.disk :file => disk_path,
                  :device => "disk",
                  :bus => "sata",
                  :cache => "none"
        end
      end
    end
  end
end
```

Данный модифицированный Vagrantfile допускает следующее использование:

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

2) Для создания ВМ в гипервизоре libvirt/kvm с использованием локально установленного бокса almalinux/9 нужно запустить командой (в данной лабораторной нам вариант с Almalinux не нужен, приведён справочно)

```
VAGRANT_BOX=almalinux9-stand vagrant up --provider=libvirt
```

3) Для создания ВМ в гипервизоре virtualbox с использованием локально установленного бокса almalinux/9 нужно запустить командой

```
VAGRANT_BOX=almalinux9-stand-vb vagrant up --provider=virtualbox
```

или просто

```
VAGRANT_BOX=almalinux9-stand-vb vagrant up
```

Также исходный и модифицированный Vagrantfile рассчитаны на создание нескольких ВМ - каждую ВМ можно индивидуально описывать в массиве MACHINES.

**Примечание:** если на хосте установлено два гипервизора libvirt/kvm и virtualbox одновременно, то для запуска виртуальных машин в гипервизоре virtualbox необходимо сначала остановить все виртуальные машины, запущенные в гипервизоре libvirt/kvm, остановить гипервизор libvirt/kvm и выгрузить драйвера ядра гипервизор libvirt/kvm:

```
[admin_insta11@mv334 ansible_lab]$ sudo bash -c 'for vm in $(virsh list --name); do virsh shutdown "$vm"; done'
Domain 'ubuntu-24.04-01' is being shutdown

[admin_insta11@mv334 ansible_lab]$
[admin_insta11@mv334 ansible_lab]$ sudo systemctl stop libvirtd.socket libvirtd-ro.socket libvirtd-admin.socket libvirtd.service
[sudo] пароль для admin_insta11: 
[admin_insta11@mv334 ansible_lab]$ 
[admin_insta11@mv334 ansible_lab]$ sudo modprobe -r kvm_intel
[admin_insta11@mv334 ansible_lab]$ 
```

Для запуска виртуальных машин в гипервизоре libvirt/kvm необходимо остановить все запущенные в гипервизоре virtualbox виртуальные машины (сервис и драйвера virtualbox останавливать не нужно), загрузить драйвера ядра и запустить сервис libvrt:

```
[admin_insta11@mv334 ansible_lab]$ sudo modprobe kvm_intel
[admin_insta11@mv334 ansible_lab]$
[admin_insta11@mv334 ansible_lab]$ sudo systemctl start libvirtd.service
[admin_insta11@mv334 ansible_lab]$
```
Также после запуска и конфигурирования ВМ в virtualbox иногда остаётся интерфейс vboxnet0, который может потом конфликтовать с запускаемой ВМ в libvirt.

Его можно удалить командами:

```
VBoxManage hostonlyif remove vboxnet0
sudo ip link delete vboxnet0
```

После запуска с вышеприведённым Vagrantfile ВМ создаются, также создаётся диск в ВМ backup:

```
[admin_insta11@mv334 backups_lab]$ VAGRANT_BOX=ubuntu-22.04-virtualbox vagrant up
Bringing machine 'backup' up with 'virtualbox' provider...
Bringing machine 'client' up with 'virtualbox' provider...
==> backup: Clearing any previously set network interfaces...
==> backup: Preparing network interfaces based on configuration...
    backup: Adapter 1: nat
    backup: Adapter 2: hostonly
==> backup: Forwarding ports...
    backup: 22 (guest) => 2222 (host) (adapter 1)
==> backup: Running 'pre-boot' VM customizations...
==> backup: Booting VM...
==> backup: Waiting for machine to boot. This may take a few minutes...
    backup: SSH address: 127.0.0.1:2222
    backup: SSH username: vagrant
    backup: SSH auth method: private key
    backup: 
    backup: Vagrant insecure key detected. Vagrant will automatically replace
    backup: this with a newly generated keypair for better security.
    backup: 
    backup: Inserting generated public key within guest...
    backup: Removing insecure key from the guest if it's present...
    backup: Key inserted! Disconnecting and reconnecting using new SSH key...
==> backup: Machine booted and ready!
==> backup: Checking for guest additions in VM...
    backup: The guest additions on this VM do not match the installed version of
    backup: VirtualBox! In most cases this is fine, but in rare cases it can
    backup: prevent things such as shared folders from working properly. If you see
    backup: shared folder errors, please make sure the guest additions within the
    backup: virtual machine match the version of VirtualBox you have installed on
    backup: your host and reload your VM.
    backup: 
    backup: Guest Additions Version: 7.2.4
    backup: VirtualBox Version: 7.1
==> backup: Setting hostname...
==> backup: Configuring and enabling network interfaces...
==> backup: Mounting shared folders...
    backup: /home/admin_insta11/backups_lab => /vagrant
==> client: Importing base box 'ubuntu-22.04-virtualbox'...
==> client: Matching MAC address for NAT networking...
==> client: Setting the name of the VM: backups_lab_client_1792821305651_94654
==> client: Fixed port collision for 22 => 2222. Now on port 2200.
==> client: Clearing any previously set network interfaces...
==> client: Preparing network interfaces based on configuration...
    client: Adapter 1: nat
    client: Adapter 2: hostonly
==> client: Forwarding ports...
    client: 22 (guest) => 2200 (host) (adapter 1)
==> client: Running 'pre-boot' VM customizations...
==> client: Booting VM...
==> client: Waiting for machine to boot. This may take a few minutes...
    client: SSH address: 127.0.0.1:2200
    client: SSH username: vagrant
    client: SSH auth method: private key
    client: Warning: Connection reset. Retrying...
    client: Warning: Remote connection disconnect. Retrying...
    client: 
    client: Vagrant insecure key detected. Vagrant will automatically replace
    client: this with a newly generated keypair for better security.
    client: 
    client: Inserting generated public key within guest...
    client: Removing insecure key from the guest if it's present...
    client: Key inserted! Disconnecting and reconnecting using new SSH key...
==> client: Machine booted and ready!
==> client: Checking for guest additions in VM...
    client: The guest additions on this VM do not match the installed version of
    client: VirtualBox! In most cases this is fine, but in rare cases it can
    client: prevent things such as shared folders from working properly. If you see
    client: shared folder errors, please make sure the guest additions within the
    client: virtual machine match the version of VirtualBox you have installed on
    client: your host and reload your VM.
    client: 
    client: Guest Additions Version: 7.2.4
    client: VirtualBox Version: 7.1
==> client: Setting hostname...
==> client: Configuring and enabling network interfaces...
==> client: Mounting shared folders...
    client: /home/admin_insta11/backups_lab => /vagrant
[admin_insta11@mv334 backups_lab]$ 
[admin_insta11@mv334 backups_lab]$ 
[admin_insta11@mv334 backups_lab]$ 
[admin_insta11@mv334 backups_lab]$ vagrant status
Current machine states:

backup                    running (virtualbox)
client                    running (virtualbox)

This environment represents multiple VMs. The VMs are all listed
above with their current state. For more information about a specific
VM, run `vagrant status NAME`.
[admin_insta11@mv334 backups_lab]$ ll
итого 36
-rw------- 1 admin_insta11 admin_insta11 2097152 окт 24 08:54 backup_disk.vdi
-rw-rw-r-- 1 admin_insta11 admin_insta11    1894 окт 24 08:52 Vagrantfile
[admin_insta11@mv334 backups_lab]$ 
```


#### 1.2 Провизионинг ВМ средствами ansible

##### 1.2.1 Доступ ansible на ВМ с использованием ключей и логина, созданного vagrant

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

Настройки доступа vagrant в ВМ backup следующие:

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

На основе этих настроек формируем файл inventory:
 
```
[vagrant]
backup ansible_host=192.168.56.160 ansible_port=22 ansible_user=vagrant ansible_private_key_file=/home/admin_insta11/backups_lab/.vagrant/machines/backup/virtualbox/private_key
```

Проверяем доступ в ВМ backup с помощью SSH и с помощью ansible:

```
[admin_insta11@mv334 backups_lab]$ ssh -i /home/admin_insta11/backups_lab/.vagrant/machines/backup/virtualbox/private_key vagrant@192.168.56.160 -p 22
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-160-generic x86_64)

Last login: Sat Oct 24 06:56:34 2026 from 10.0.2.2
vagrant@backup:~$ sudo -i
root@backup:~# exit
logout
vagrant@backup:~$ exit
logout
Connection to 192.168.56.160 closed.
[admin_insta11@mv334 backups_lab]$
admin_insta11@mv334 backups_lab]$ ansible all -m ping -i inventory.ini
backup | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
[admin_insta11@mv334 backups_lab]$ ansible backup -m ping -i inventory.ini
backup | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
[admin_insta11@mv334 backups_lab]$ 
```

Таким образом, необходимый доступ для ansible через credentials, созданные vagrant, настроен.

##### 1.2.2 Провизионинг ВМ backup средствами ansible

Для монтирования и форматирования созданного диска в ВМ backup используется следующий playbook:

```
[admin_insta11@mv334 backups_lab]$ cat playbook.yml 
- name: Prepare and mount backup disk on backup VM
  hosts: backup
  become: true
  vars:
    mount_point: /data
    disk_device: /dev/sdb  # можно позже сделать динамическим по размеру

  tasks:
    # Тег: parted — разметка диска (GPT + 1 раздел)
    - name: Create GPT partition on disk
      community.general.parted:
        device: "{{ disk_device }}"
        label: gpt
        number: 1
        state: present
      register: parted_result
      changed_when: parted_result.changed
      tags:
        - parted

    # Тег: filesystem — создание файловой системы (ext4)
    - name: Create ext4 filesystem on partition
      filesystem:
        fstype: ext4
        dev: "{{ disk_device }}1"
      tags:
        - filesystem

    # Тег: dir — создание точки монтирования
    - name: Ensure mount directory exists
      file:
        path: "{{ mount_point }}"
        state: directory
        mode: "0755"
      tags:
        - dir

    # Теги: mount + fstab — монтирование и запись в fstab
    - name: Mount filesystem
      mount:
        path: "{{ mount_point }}"
        src: "{{ disk_device }}1"
        fstype: ext4
        opts: defaults
        state: mounted
      tags:
        - mount
        - fstab
```1
