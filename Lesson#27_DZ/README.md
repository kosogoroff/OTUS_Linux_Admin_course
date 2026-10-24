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

- репозиторий для резервных копий должен быть зашифрован ключом или паролем - на ваше усмотрение;
  
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


**Примечание:** vagrant в libvirt сам не умеет создавать диски при создании виртуальных машин. Поэтому перед запуском создания ВМ в libvirt/KVM
необходимо вручную создать диск командой

```
# Для libvirt Vagrant не умеет сам создавать диск — его нужно создать заранее на хосте командой:
qemu-img create -f qcow2 backup_disk.qcow2 5G
```

После запуска с вышеприведённым Vagrantfile ВМ создаются, также в virtualbox создаётся диск ВМ backup.

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
[admin_insta11@mv334 backups_lab]$ cat playbook-mount-disk.yml 
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
```

При запуске playbook все задачи выполняются, после этого в ВМ диск примонтирован и доступен. При повторном запуска этого плейбука задачи повторно уже не выполняются из-за индепонентности:

```
[admin_insta11@mv334 backups_lab]$ ansible-playbook -i inventory.ini playbook.yml

PLAY [Prepare and mount backup disk on backup VM] ********************************************************************************************************************************************

TASK [Gathering Facts] ***********************************************************************************************************************************************************************
ok: [backup]

TASK [Create GPT partition on disk] **********************************************************************************************************************************************************
ok: [backup]

TASK [Create ext4 filesystem on partition] ***************************************************************************************************************************************************
changed: [backup]

TASK [Ensure mount directory exists] *********************************************************************************************************************************************************
changed: [backup]

TASK [Mount filesystem] **********************************************************************************************************************************************************************
changed: [backup]

PLAY RECAP ***********************************************************************************************************************************************************************************
backup                     : ok=5    changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   

[admin_insta11@mv334 backups_lab]$ vagrant ssh backup
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-160-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

 System information as of Sat Oct 24 06:27:50 AM UTC 2026

  System load:           0.09
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
Last login: Sat Oct 24 06:27:55 2026 from 192.168.56.1
vagrant@backup:~$ df -h
Filesystem                         Size  Used Avail Use% Mounted on
tmpfs                              144M  1.1M  143M   1% /run
/dev/mapper/ubuntu--vg-ubuntu--lv   31G  5.0G   24G  18% /
tmpfs                              718M     0  718M   0% /dev/shm
tmpfs                              5.0M     0  5.0M   0% /run/lock
/dev/sda2                          2.0G  131M  1.7G   8% /boot
vagrant                            156G   77G   79G  50% /vagrant
tmpfs                              144M  8.0K  144M   1% /run/user/1000
/dev/sdb1                          4.9G   24K  4.6G   1% /data
vagrant@backup:~$ 
vagrant@backup:~$ exit
logout
[admin_insta11@mv334 backups_lab]$ 
[admin_insta11@mv334 backups_lab]$ ansible-playbook -i inventory.ini playbook.yml

PLAY [Prepare and mount backup disk on backup VM] ********************************************************************************************************************************************

TASK [Gathering Facts] ***********************************************************************************************************************************************************************
ok: [backup]

TASK [Create GPT partition on disk] **********************************************************************************************************************************************************
ok: [backup]

TASK [Create ext4 filesystem on partition] ***************************************************************************************************************************************************
ok: [backup]

TASK [Ensure mount directory exists] *********************************************************************************************************************************************************
ok: [backup]

TASK [Mount filesystem] **********************************************************************************************************************************************************************
ok: [backup]

PLAY RECAP ***********************************************************************************************************************************************************************************
backup                     : ok=5    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   

[admin_insta11@mv334 backups_lab]$ 
```

### 2. Конфигурирование резервирования на ВМ 

#### 2.1 Создаём пользователя borg на сервере backup, настраиваем аутентификацию по ключам и вводим ограничение для данного ключа на сервере только на работу с логами borg

На сервере backup создаём пользователя borg, файл для публичных ключей для него с нужными правами:

```
root@backup:~# adduser borg
Adding user `borg' ...
Adding new group `borg' (1001) ...
Adding new user `borg' (1001) with group `borg' ...
Creating home directory `/home/borg' ...
Copying files from `/etc/skel' ...
New password: 
Retype new password: 
passwd: password updated successfully
root@backup:~# 
root@backup:~# mkdir /var/backup/
root@backup:~# chown borg:borg /var/backup/
root@backup:~# 
root@backup:~# su - borg
borg@backup:~$ mkdir .ssh
borg@backup:~$ touch .ssh/authorized_keys
borg@backup:~$ chmod 700 .ssh
borg@backup:~$ chmod 600 .ssh/authorized_keys
```

На ВМ client генерируем клучи и конфигурируем аутентификацию по ключам из пользователя root на клиенте к пользователю borg на сервере backup:

```
root@client:~# ssh-keygen -t ed25519
Generating public/private ed25519 key pair.
Enter file in which to save the key (/root/.ssh/id_ed25519): 
Enter passphrase (empty for no passphrase): 
Enter same passphrase again: 
Your identification has been saved in /root/.ssh/id_ed25519
Your public key has been saved in /root/.ssh/id_ed25519.pub
The key fingerprint is:
SHA256:owr98iikEI10Mrnpe+JMNJR8fJhhFohu9SuUsV4VUfo root@client
The key's randomart image is:
+--[ED25519 256]--+
|. o=.  o+.       |
|o*=++  ..        |
|o*B==...         |
|+=o+.o  .        |
|o+o . . SE       |
|o.o+ . . .       |
|.+o o .          |
|+o.o.+           |
|.oo.ooo          |
+----[SHA256]-----+
root@client:~# 
root@client:~# ssh-copy-id -i /root/.ssh/id_ed25519.pub borg@192.168.56.160
/usr/bin/ssh-copy-id: INFO: Source of key(s) to be installed: "/root/.ssh/id_ed25519.pub"
/usr/bin/ssh-copy-id: INFO: attempting to log in with the new key(s), to filter out any that are already installed
/usr/bin/ssh-copy-id: INFO: 1 key(s) remain to be installed -- if you are prompted now it is to install the new keys
borg@192.168.56.160's password: 

Number of key(s) added: 1

Now try logging into the machine, with:   "ssh 'borg@192.168.56.160'"
and check to make sure that only the key(s) you wanted were added.

root@client:~# 
root@client:~# ssh borg@192.168.56.160
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-160-generic x86_64)

Use of this system is acceptance of the OS vendor EULA and License Agreements.
borg@backup:~$ exit
logout
Connection to 192.168.56.160 closed.
root@client:~# 
root@client:~# 
root@client:~# 
root@client:~# ssh -i /root/.ssh/id_ed25519 borg@192.168.56.160 whoami
borg
root@client:~# 
```

После этого файл authorized_keys на сервере выглядит следующим образом стандртно:

```
borg@backup:~$ cat .ssh/authorized_keys
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFL92VLvEp43DQ4ZvnCPq6puYXEDjfEOtbX0ChiOnho1 root@client
borg@backup:~$ 
```

Далее на сервере ограничиваем права данного публичного ключа выполнением только резервирования borg - после этого при 
заходе с client на backup с данным публичным ключом авторизации вместо интерактивной консоли будет выполняться команда borg:

```
borg@backup:~$ cat .ssh/authorized_keys
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFL92VLvEp43DQ4ZvnCPq6puYXEDjfEOtbX0ChiOnho1 root@client
borg@backup:~$ 
borg@backup:~$ vi .ssh/authorized_keys
borg@backup:~$ 
borg@backup:~$ cat .ssh/authorized_keys
#ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFL92VLvEp43DQ4ZvnCPq6puYXEDjfEOtbX0ChiOnho1 root@client
command="borg serve --restrict-to-repo /var/backup",restrict ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFL92VLvEp43DQ4ZvnCPq6puYXEDjfEOtbX0ChiOnho1 root@client
borg@backup:~$

root@client:~# ssh -i /root/.ssh/id_ed25519 borg@192.168.56.160 whoami
usage: borg [-V] [-h] [--critical] [--error] [--warning] [--info] [--debug]
            [--debug-topic TOPIC] [-p] [--iec] [--log-json]
            [--lock-wait SECONDS] [--bypass-lock] [--show-version] [--show-rc]
            [--umask M] [--remote-path PATH] [--remote-ratelimit RATE]
            [--upload-ratelimit RATE] [--remote-buffer UPLOAD_BUFFER]
            [--upload-buffer UPLOAD_BUFFER] [--consider-part-files]
            [--debug-profile FILE] [--rsh RSH]
            <command> ...

Borg - Deduplicated Backups

options:
<...>
```



```
 
root@client:~# ssh borg@192.168.56.160 whoami
usage: borg [-V] [-h] [--critical] [--error] [--warning] [--info] [--debug]
            [--debug-topic TOPIC] [-p] [--iec] [--log-json]
            [--lock-wait SECONDS] [--bypass-lock] [--show-version] [--show-rc]
            [--umask M] [--remote-path PATH] [--remote-ratelimit RATE]
            [--upload-ratelimit RATE] [--remote-buffer UPLOAD_BUFFER]
            [--upload-buffer UPLOAD_BUFFER] [--consider-part-files]
            [--debug-profile FILE] [--rsh RSH]
            <command> ...

Borg - Deduplicated Backups

options:
<...>

```


#### 2.2 Настраиваем резервирование

На клиенте 

```
root@client:~# borg init --encryption=repokey borg@192.168.56.160:/var/backup/
Enter new passphrase: 
Enter same passphrase again: 
Do you want your passphrase to be displayed for verification? [yN]: 

By default repositories initialized with this version will produce security
errors if written to with an older version (up to and including Borg 1.0.8).

If you want to use these older versions, you can disable the check by running:
borg upgrade --disable-tam ssh://borg@192.168.56.160/var/backup

See https://borgbackup.readthedocs.io/en/stable/changes.html#pre-1-0-9-manifest-spoofing-vulnerability for details about the security implications.

IMPORTANT: you will need both KEY AND PASSPHRASE to access this repo!
If you used a repokey mode, the key is stored in the repo, but you should back it up separately.
Use "borg key export" to export the key, optionally in printable format.
Write down the passphrase. Store both at safe place(s).

root@client:~#
root@client:~# borg create --stats --list borg@192.168.56.160:/var/backup/::"etc-{now:%Y-%m-%d_%H:%M:%S}" /etc
s /etc/mtab
s /etc/os-release
s /etc/resolv.conf
s /etc/rmt
s /etc/vtrgb
d /etc/ModemManager/connection.d

<...>

A /etc/fonts/conf.avail/70-force-bitmaps.conf
A /etc/fonts/conf.avail/70-no-bitmaps.conf
A /etc/fonts/conf.avail/70-yes-bitmaps.conf
A /etc/fonts/conf.avail/80-delicious.conf
A /etc/fonts/conf.avail/90-synthetic.conf
d /etc/fonts/conf.avail
A /etc/fonts/conf.d/README
d /etc/fonts/conf.d
A /etc/fonts/fonts.conf
d /etc/fonts
d /etc
------------------------------------------------------------------------------
Repository: ssh://borg@192.168.56.160/var/backup
Archive name: etc-2026-10-24_09:48:12
Archive fingerprint: 081edf9d80a6466ba41a666895c6f97236922e8a5d709e38c5f633c13ca6e383
Time (start): Sat, 2026-10-24 09:48:13
Time (end):   Sat, 2026-10-24 09:48:16
Duration: 2.75 seconds
Number of files: 804
Utilization of max. archive size: 0%
------------------------------------------------------------------------------
                       Original size      Compressed size    Deduplicated size
This archive:                2.29 MB              1.03 MB            995.72 kB
All archives:                2.28 MB              1.03 MB              1.07 MB

                       Unique chunks         Total chunks
Chunk index:                     757                  795
------------------------------------------------------------------------------
root@client:~#
root@client:~# borg list borg@192.168.56.160:/var/backup/
etc-2026-10-24_09:48:12              Sat, 2026-10-24 09:48:13 [081edf9d80a6466ba41a666895c6f97236922e8a5d709e38c5f633c13ca6e383]
root@client:~# 
root@client:~# borg list borg@192.168.56.160:/var/backup/::etc-2026-10-24_09:48:12
drwxr-xr-x root   root          0 Sat, 2026-10-24 07:53:38 etc
lrwxrwxrwx root   root         19 Wed, 2024-09-11 14:22:06 etc/mtab -> ../proc/self/mounts
lrwxrwxrwx root   root         21 Tue, 2024-09-10 11:18:05 etc/os-release -> ../usr/lib/os-release
lrwxrwxrwx root   root         39 Wed, 2024-09-11 14:22:05 etc/resolv.conf -> ../run/systemd/resolve/stub-resolv.conf
lrwxrwxrwx root   root         13 Tue, 2023-12-05 05:15:51 etc/rmt -> /usr/sbin/rmt
lrwxrwxrwx root   root         23 Wed, 2024-09-11 14:22:40 etc/vtrgb -> /etc/alternatives/vtrgb
drwxr-xr-x root   root          0 Wed, 2024-09-11 14:24:23 etc/ModemManager
<...>
-rw-r--r-- root   root        597 Wed, 2022-03-23 13:52:38 etc/fonts/conf.avail/80-delicious.conf
-rw-r--r-- root   root       1917 Wed, 2022-03-23 13:52:38 etc/fonts/conf.avail/90-synthetic.conf
drwxr-xr-x root   root          0 Thu, 2025-10-23 22:32:53 etc/fonts/conf.d
-rw-r--r-- root   root        978 Wed, 2022-03-23 13:52:38 etc/fonts/conf.d/README
-rw-r--r-- root   root       2808 Wed, 2022-03-23 13:52:38 etc/fonts/fonts.conf
root@client:~# 
root@client:~# borg extract borg@192.168.56.160:/var/backup/::etc-2026-10-24_09:48:12 etc/hostname
root@client:~# ll
total 40
drwx------  7 root root 4096 Oct 24 09:54 ./
drwxr-xr-x 21 root root 4096 Oct 24 05:55 ../
-rw-------  1 root root    5 Oct 24 06:23 .bash_history
-rw-r--r--  1 root root 3106 Oct 15  2021 .bashrc
drwx------  3 root root 4096 Oct 24 07:54 .cache/
drwx------  3 root root 4096 Oct 24 07:54 .config/
drwx------  2 root root 4096 Oct 24 09:54 etc/
-rw-r--r--  1 root root  161 Jul  9  2019 .profile
drwx------  3 root root 4096 Oct 23  2025 snap/
drwx------  2 root root 4096 Oct 24 09:04 .ssh/
root@client:~# 
root@client:~# 
root@client:~# ll etc/hostname
-rw-r--r-- 1 root root 7 Oct 24 05:55 etc/hostname
root@client:~# 
root@client:~# cat etc/hostname
client
root@client:~#
root@client:~# borg info borg@192.168.56.160:/var/backup
Repository ID: 990cdd7b37de49a52e2461b853cd488754877aa6f59919a645d94e2cac479bd8
Location: ssh://borg@192.168.56.160/var/backup
Encrypted: Yes (repokey)
Cache: /root/.cache/borg/990cdd7b37de49a52e2461b853cd488754877aa6f59919a645d94e2cac479bd8
Security dir: /root/.config/borg/security/990cdd7b37de49a52e2461b853cd488754877aa6f59919a645d94e2cac479bd8
------------------------------------------------------------------------------
                       Original size      Compressed size    Deduplicated size
All archives:                2.28 MB              1.03 MB              1.07 MB

                       Unique chunks         Total chunks
Chunk index:                     757                  795
root@client:~# 
root@client:~# 
root@client:~# echo $BORG_PASSPHRASE

root@client:~# 
```

#### 2.3 Настраиваем сервис и таймер systemctl

На клиенте делаем скрипт /usr/local/bin/borg-backup-run.sh , который будет запускаться сервисом systemctl, следующего содержания. Также создаём файл с хранящимся в нём passphrase и правами 600
для исключения утечки пароля на бэкап

Скрипт /usr/local/bin/borg-backup-run.sh читает passphrase из файла /etc/borg/passphrase , создаёт очередной бэкап, а также записывает логи в локальный файл лога, а также в syslog :

```
root@client:~# cat /usr/local/bin/borg-backup-run.sh
#!/usr/bin/env bash
set -euo pipefail

REPO="${REPO:-"borg@192.168.11.160:/var/backup"}"
BACKUP_TARGET="${BACKUP_TARGET:-"/etc"}"
LOG_FILE="/var/log/borg/borg-backup.log"
PASSFILE="/etc/borg/passphrase"

# Создаём директорию и файл лога, если нет
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

# Функция логирования: в файл и в syslog
log_line() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE" | logger -t borg-backup
}

# Читаем пароль из файла
if [[ ! -f "$PASSFILE" ]]; then
    log_line "ERROR: Passphrase file not found: $PASSFILE"
    exit 1
fi

# Экспортируем BORG_PASSPHRASE, чтобы Borg его увидел
export BORG_PASSPHRASE
BORG_PASSPHRASE="$(cat "$PASSFILE")"

ARCHIVE_NAME="etc-$(date +%F_%H-%M-%S)"

log_line "=== START Borg backup ==="
log_line "REPO=$REPO TARGET=$BACKUP_TARGET ARCHIVE=$ARCHIVE_NAME"

# 1. Создание бэкапа
if ! borg create --stats "$REPO::$ARCHIVE_NAME" "$BACKUP_TARGET" 2>&1 | tee -a "$LOG_FILE"; then
    log_line "ERROR: borg create failed"
    exit 1
fi

# 2. Проверка репозитория
if ! borg check "$REPO" 2>&1 | tee -a "$LOG_FILE"; then
    log_line "WARNING: borg check reported issues"
    # Не прерываем, но фиксируем
fi

# 3. Очистка старых бэкапов
if ! borg prune \
    --keep-daily 90 \
    --keep-monthly 12 \
    --keep-yearly 1 \
    "$REPO" 2>&1 | tee -a "$LOG_FILE"; then
    log_line "WARNING: borg prune reported issues"
fi

log_line "=== END Borg backup ==="
root@client:~#
root@client:~# 
root@client:~# chmod 755 /usr/local/bin/borg-backup-run.sh
root@client:~# chown root:root /usr/local/bin/borg-backup-run.sh

root@client:~# cat /etc/borg/passphrase
Otus1234
root@client:~# ll /etc/borg/passphrase
-rw------- 1 root root 9 Oct 24 16:24 /etc/borg/passphrase
root@client:~# 
```

Создаём service и timer в systemctl :

```
root@client:~# cat /etc/systemd/system/borg-backup.service
[Unit]
Description=Borg Backup
After=network.target

[Service]
Type=oneshot
User=root
# Никакого BORG_PASSPHRASE здесь — он берётся из файла внутри скрипта
Environment=REPO="borg@192.168.56.160:/var/backup"
Environment=BACKUP_TARGET="/etc"
ExecStart=/usr/local/bin/borg-backup-run.sh
RemainAfterExit=no
root@client:~# 
root@client:~# cat /etc/systemd/system/borg-backup.timer
[Unit]
Description=Borg Backup
After=network.target

[Timer]
OnUnitActiveSec=5min
Persistent=true
Unit=borg-backup.service

[Install]
WantedBy=timers.target
root@client:~#

```

Конфигурируем ротацию логов:

```
root@client:~# cat > /etc/logrotate.d/borg-backup
/var/log/borg/borg-backup.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 640 root adm
}
root@client:~# 
```

Проверяем вручную запуск сервиса, затем запускаем таймер, проверяем наличие сообщений в файле лога, в journalctl и в syslog:

```
root@client:~# systemctl daemon-reload
root@client:~# 
root@client:~# systemctl enable borg-backup.service
The unit files have no installation config (WantedBy=, RequiredBy=, Also=,
Alias= settings in the [Install] section, and DefaultInstance= for template
units). This means they are not meant to be enabled using systemctl.
 
Possible reasons for having this kind of units are:
• A unit may be statically enabled by being symlinked from another unit's
  .wants/ or .requires/ directory.
• A unit's purpose may be to act as a helper for some other unit which has
  a requirement dependency on it.
• A unit may be started when needed via activation (socket, path, timer,
  D-Bus, udev, scripted systemctl call, ...).
• In case of template units, the unit is meant to be enabled with some
  instance name specified.
root@client:~# 
root@client:~# 
root@client:~# systemctl start borg-backup.service
root@client:~# 
root@client:~# systemctl status borg-backup.service
○ borg-backup.service - Borg Backup
     Loaded: loaded (/etc/systemd/system/borg-backup.service; static)
     Active: inactive (dead)

Oct 24 16:33:13 client borg-backup-run.sh[3090]:                        Original size      Compressed size    Deduplicated s>
Oct 24 16:33:13 client borg-backup-run.sh[3090]: This archive:                2.29 MB              1.03 MB                98>
Oct 24 16:33:13 client borg-backup-run.sh[3090]: All archives:                4.57 MB              2.06 MB              1.15>
Oct 24 16:33:13 client borg-backup-run.sh[3090]:                        Unique chunks         Total chunks
Oct 24 16:33:13 client borg-backup-run.sh[3090]: Chunk index:                     762                 1593
Oct 24 16:33:13 client borg-backup-run.sh[3090]: --------------------------------------------------------------------------->
Oct 24 16:33:16 client borg-backup[3100]: [2026-10-24 16:33:16] === END Borg backup ===
Oct 24 16:33:16 client systemd[1]: borg-backup.service: Deactivated successfully.
Oct 24 16:33:16 client systemd[1]: Finished Borg Backup.
Oct 24 16:33:16 client systemd[1]: borg-backup.service: Consumed 2.208s CPU time.
root@client:~# 
root@client:~# 
root@client:~# 
root@client:~# systemctl daemon-reload
root@client:~# 
root@client:~# 
root@client:~# cat /etc/systemd/system/borg-backup.timer
[Unit]
Description=Borg Backup
After=network.target

[Timer]
OnUnitActiveSec=5min
Persistent=true
Unit=borg-backup.service

[Install]
WantedBy=timers.target
root@client:~# 
root@client:~# systemctl stop borg-backup.timer
root@client:~# systemctl start borg-backup.timer
root@client:~# 
root@client:~# systemctl list-timers --all | grep borg
Sat 2026-10-24 17:02:11 UTC 1min 15s left n/a                         n/a          borg-backup.timer            borg-backup.service
root@client:~# systemctl list-timers --all | grep borg
Sat 2026-10-24 17:02:11 UTC 55s left      n/a                         n/a          borg-backup.timer            borg-backup.service
root@client:~# systemctl list-timers --all | grep borg
Sat 2026-10-24 17:02:11 UTC 19s left      n/a                         n/a          borg-backup.timer            borg-backup.service
root@client:~# systemctl list-timers --all | grep borg
n/a                         n/a           Sat 2026-10-24 17:02:14 UTC 1s ago       borg-backup.timer            borg-backup.service
root@client:~# systemctl list-timers --all | grep borg
Sat 2026-10-24 17:07:14 UTC 4min 44s left Sat 2026-10-24 17:02:14 UTC 15s ago      borg-backup.timer            borg-backup.service
root@client:~# 
root@client:~# 
root@client:~# borg list borg@192.168.56.160:/var/backup/
Enter passphrase for key ssh://borg@192.168.56.160/var/backup: 
etc-2026-10-24_16:09:03              Sat, 2026-10-24 16:09:16 [56cb5144b11bbdc3f0cd3c9b66dae42c1a9a953c367fb271ac9d9cccd8762777]
etc-2026-10-24_17-02-14              Sat, 2026-10-24 17:02:16 [ffbec918ea950d3531ec4231be176550c961abd86e1570122380b3ebcca0bd1a]
root@client:~# systemctl list-timers --all | grep borg
Sat 2026-10-24 17:07:14 UTC 2min 56s left Sat 2026-10-24 17:02:14 UTC 2min 3s ago  borg-backup.timer            borg-backup.service
root@client:~# systemctl list-timers --all | grep borg
n/a                         n/a           Sat 2026-10-24 17:07:26 UTC 15ms ago    borg-backup.timer            borg-backup.service
root@client:~# 
root@client:~# 
root@client:~# 
root@client:~# 
root@client:~# borg list borg@192.168.56.160:/var/backup/
Enter passphrase for key ssh://borg@192.168.56.160/var/backup: 
etc-2026-10-24_16:09:03              Sat, 2026-10-24 16:09:16 [56cb5144b11bbdc3f0cd3c9b66dae42c1a9a953c367fb271ac9d9cccd8762777]
etc-2026-10-24_17-07-26              Sat, 2026-10-24 17:07:27 [998fb3fee3bad8c5310d6a1032a90141e0d9b8109c67890b8d84fcae06ff815d]
root@client:~# 
root@client:~# borg list borg@192.168.56.160:/var/backup/
Enter passphrase for key ssh://borg@192.168.56.160/var/backup: 
etc-2026-10-24_16:09:03              Sat, 2026-10-24 16:09:16 [56cb5144b11bbdc3f0cd3c9b66dae42c1a9a953c367fb271ac9d9cccd8762777]
etc-2026-10-24_17-07-26              Sat, 2026-10-24 17:07:27 [998fb3fee3bad8c5310d6a1032a90141e0d9b8109c67890b8d84fcae06ff815d]
root@client:~# 
root@client:~# touch /etc/test_file
root@client:~# 
root@client:~# systemctl list-timers --all | grep borg
Sat 2026-10-24 17:12:26 UTC 31s left      Sat 2026-10-24 17:07:26 UTC 4min 28s ago borg-backup.timer            borg-backup.service
root@client:~# 
root@client:~# 
root@client:~# systemctl list-timers --all | grep borg
Sat 2026-10-24 17:17:31 UTC 4min 50s left Sat 2026-10-24 17:12:31 UTC 9s ago      borg-backup.timer            borg-backup.service
root@client:~# 
root@client:~# tail -n 50 /var/log/borg/borg-backup.log
[2026-10-24 16:33:10] === START Borg backup ===
[2026-10-24 16:33:10] REPO=borg@192.168.56.160:/var/backup TARGET=/etc ARCHIVE=etc-2026-10-24_16-33-10
------------------------------------------------------------------------------
Repository: ssh://borg@192.168.56.160/var/backup
Archive name: etc-2026-10-24_16-33-10
Archive fingerprint: fbec18cf2f8c485e4561c56dba1398536de31e308f3109b781d6497cc18fed8b
Time (start): Sat, 2026-10-24 16:33:12
Time (end):   Sat, 2026-10-24 16:33:12
Duration: 0.31 seconds
Number of files: 807
Utilization of max. archive size: 0%
------------------------------------------------------------------------------
                       Original size      Compressed size    Deduplicated size
This archive:                2.29 MB              1.03 MB                983 B
All archives:                4.57 MB              2.06 MB              1.15 MB

                       Unique chunks         Total chunks
Chunk index:                     762                 1593
------------------------------------------------------------------------------
[2026-10-24 16:33:16] === END Borg backup ===
root@client:~# 
root@client:~# 
root@client:~# journalctl -u borg-backup.service -n 30
Oct 24 16:33:10 client systemd[1]: Starting Borg Backup...
Oct 24 16:33:13 client borg-backup-run.sh[3090]: --------------------------------------------------------------------------->
Oct 24 16:33:13 client borg-backup-run.sh[3090]: Repository: ssh://borg@192.168.56.160/var/backup
Oct 24 16:33:13 client borg-backup-run.sh[3090]: Archive name: etc-2026-10-24_16-33-10
Oct 24 16:33:13 client borg-backup-run.sh[3090]: Archive fingerprint: fbec18cf2f8c485e4561c56dba1398536de31e308f3109b781d649>
Oct 24 16:33:13 client borg-backup-run.sh[3090]: Time (start): Sat, 2026-10-24 16:33:12
Oct 24 16:33:13 client borg-backup-run.sh[3090]: Time (end):   Sat, 2026-10-24 16:33:12
Oct 24 16:33:13 client borg-backup-run.sh[3090]: Duration: 0.31 seconds
Oct 24 16:33:13 client borg-backup-run.sh[3090]: Number of files: 807
Oct 24 16:33:13 client borg-backup-run.sh[3090]: Utilization of max. archive size: 0%
Oct 24 16:33:13 client borg-backup-run.sh[3090]: --------------------------------------------------------------------------->
Oct 24 16:33:13 client borg-backup-run.sh[3090]:                        Original size      Compressed size    Deduplicated s>
Oct 24 16:33:13 client borg-backup-run.sh[3090]: This archive:                2.29 MB              1.03 MB                98>
Oct 24 16:33:13 client borg-backup-run.sh[3090]: All archives:                4.57 MB              2.06 MB              1.15>
Oct 24 16:33:13 client borg-backup-run.sh[3090]:                        Unique chunks         Total chunks
Oct 24 16:33:13 client borg-backup-run.sh[3090]: Chunk index:                     762                 1593
Oct 24 16:33:13 client borg-backup-run.sh[3090]: --------------------------------------------------------------------------->
Oct 24 16:33:16 client borg-backup[3100]: [2026-10-24 16:33:16] === END Borg backup ===
Oct 24 16:33:16 client systemd[1]: borg-backup.service: Deactivated successfully.
Oct 24 16:33:16 client systemd[1]: Finished Borg Backup.
Oct 24 16:33:16 client systemd[1]: borg-backup.service: Consumed 2.208s CPU time.
root@client:~# 
root@client:~# 
root@client:~# grep borg-backup /var/log/syslog
Oct 24 16:33:10 vagrant borg-backup: [2026-10-24 16:33:10] === START Borg backup ===
Oct 24 16:33:10 vagrant borg-backup: [2026-10-24 16:33:10] REPO=borg@192.168.56.160:/var/backup TARGET=/etc ARCHIVE=etc-2026-10-24_16-33-10
Oct 24 16:33:13 vagrant borg-backup-run.sh[3090]: ------------------------------------------------------------------------------
Oct 24 16:33:13 vagrant borg-backup-run.sh[3090]: Repository: ssh://borg@192.168.56.160/var/backup
Oct 24 16:33:13 vagrant borg-backup-run.sh[3090]: Archive name: etc-2026-10-24_16-33-10
Oct 24 16:33:13 vagrant borg-backup-run.sh[3090]: Archive fingerprint: fbec18cf2f8c485e4561c56dba1398536de31e308f3109b781d6497cc18fed8b
Oct 24 16:33:13 vagrant borg-backup-run.sh[3090]: Time (start): Sat, 2026-10-24 16:33:12
Oct 24 16:33:13 vagrant borg-backup-run.sh[3090]: Time (end):   Sat, 2026-10-24 16:33:12
Oct 24 16:33:13 vagrant borg-backup-run.sh[3090]: Duration: 0.31 seconds
Oct 24 16:33:13 vagrant borg-backup-run.sh[3090]: Number of files: 807
Oct 24 16:33:13 vagrant borg-backup-run.sh[3090]: Utilization of max. archive size: 0%
Oct 24 16:33:13 vagrant borg-backup-run.sh[3090]: ------------------------------------------------------------------------------
Oct 24 16:33:13 vagrant borg-backup-run.sh[3090]:                        Original size      Compressed size    Deduplicated size
Oct 24 16:33:13 vagrant borg-backup-run.sh[3090]: This archive:                2.29 MB              1.03 MB                983 B
Oct 24 16:33:13 vagrant borg-backup-run.sh[3090]: All archives:                4.57 MB              2.06 MB              1.15 MB
Oct 24 16:33:13 vagrant borg-backup-run.sh[3090]:                        Unique chunks         Total chunks
Oct 24 16:33:13 vagrant borg-backup-run.sh[3090]: Chunk index:                     762                 1593
Oct 24 16:33:13 vagrant borg-backup-run.sh[3090]: ------------------------------------------------------------------------------
Oct 24 16:33:16 vagrant borg-backup: [2026-10-24 16:33:16] === END Borg backup ===
Oct 24 16:33:16 vagrant systemd[1]: borg-backup.service: Deactivated successfully.
Oct 24 16:33:16 vagrant systemd[1]: borg-backup.service: Consumed 2.208s CPU time.
root@client:~# 
```

Проверяем работу ротации логов:

```
root@client:~# ll /var/log/borg/
total 20
drwxr-xr-x 2 root root    4096 Oct 24 16:33 ./
drwxrwxr-x 8 root syslog  4096 Oct 24 16:33 ../
-rw-r--r-- 1 root root   11200 Oct 24 17:39 borg-backup.log
root@client:~# 
root@client:~# logrotate -d /etc/logrotate.d/borg-backup
WARNING: logrotate in debug mode does nothing except printing debug messages!  Consider using verbose mode (-v) instead if this is not what you want.

reading config file /etc/logrotate.d/borg-backup
Reading state from file: /var/lib/logrotate/status
Allocating hash table for state file, size 64 entries
Creating new state
Creating new state
Creating new state
Creating new state
Creating new state
Creating new state
Creating new state
Creating new state
Creating new state
Creating new state
Creating new state
Creating new state
Creating new state
Creating new state
Creating new state
Creating new state
Creating new state
Creating new state
Creating new state
Creating new state
Creating new state
Creating new state
Creating new state
Creating new state
Creating new state

Handling 1 logs

rotating pattern: /var/log/borg/borg-backup.log  after 1 days (7 rotations)
empty log files are not rotated, old logs are removed
considering log /var/log/borg/borg-backup.log
Creating new state
  Now: 2026-10-24 17:39
  Last rotated at 2026-10-24 17:00
  log does not need rotating (log has already been rotated)
root@client:~# 
root@client:~# ll /var/log/borg/
total 20
drwxr-xr-x 2 root root    4096 Oct 24 16:33 ./
drwxrwxr-x 8 root syslog  4096 Oct 24 16:33 ../
-rw-r--r-- 1 root root   11200 Oct 24 17:39 borg-backup.log
root@client:~# ll /var/log/borg/
total 24
drwxr-xr-x 2 root root    4096 Oct 24 16:33 ./
drwxrwxr-x 8 root syslog  4096 Oct 24 16:33 ../
-rw-r--r-- 1 root root   13440 Oct 24 17:49 borg-backup.log
root@client:~# 
```

**Примечание:** восстановление из бэкапа - возможны следующие варианты:

***Вариант А:*** восстановить один файл (самый частый случай)

Допустим, ты случайно удалил /etc/hostname и хочешь вернуть именно его:

```
borg extract borg@192.168.56.160:/var/backup::etc-2026-10-24_09:48:12 etc/hostname
```

Borg восстановит файл в текущую директорию как etc/hostname. Дальше ты сам решаешь, куда его положить (например, cp etc/hostname /etc/).

Важно: всегда сначала восстанавливай во временную папку или в текущий каталог, а не сразу поверх существующих файлов. Так ты не перезапишешь что-то лишнее.

***Вариант Б:*** восстановить всю директорию

```
borg extract borg@192.168.56.160:/var/backup::etc-2026-10-24_09:48:12 etc
```

Восстановится вся папка etc (с подпапками и файлами) относительно текущей директории.

***Вариант В:*** восстановить в конкретную целевую директорию

Чтобы не гадать, куда оно упадёт, явно задай путь:

```
mkdir -p /tmp/restore-etc
borg extract borg@192.168.56.160:/var/backup::etc-2026-10-24_09:48:12 --paths /tmp/restore-etc etc
```

Флаг --paths говорит Borg, куда класть файлы. Внутри /tmp/restore-etc появится структура etc/....

***Вариант Г:*** примонтировать бэкап через монтирование (FUSE)

Если хочется посмотреть бэкап как обычную файловую систему (удобно для поиска «а где там лежит этот конфиг»):

```
mkdir -p /mnt/borg-restore
borg mount borg@192.168.56.160:/var/backup::etc-2026-10-24_09:48:12 /mnt/borg-restore
```

Теперь можно ходить по /mnt/borg-restore как по обычной папке: ls, cat, grep. Когда закончил:

```
borg umount /mnt/borg-restore
```

Монтирование требует FUSE (fuse3 или fuse). Если его нет — ставь через apt/dnf (пакет fuse3).

#### Проверка целостности перед восстановлением

Перед массовым восстановлением полезно проверить репозиторий:

```
borg check borg@192.168.56.160:/var/backup --archives-only
```

    --repository-only — проверка структуры репозитория.
    
    --archives-only — проверка самих архивов.
    
    Без флага — полная проверка (долго на больших репозиториях).

#### Практический пример восстановления

Допустим, на одном из мини‑ПК ты случайно стёр конфиги Zabbix. У тебя есть архив zabbix-conf-2026-10-24_12:00:00.

    Смотрим, что внутри:
    
```
    borg list borg@192.168.56.160:/var/backup::zabbix-conf-2026-10-24_12:00:00
```

    Восстанавливаем в /tmp:

```
    mkdir /tmp/zabbix-restore
    borg extract borg@192.168.56.160:/var/backup::zabbix-conf-2026-10-24_12:00:00 --paths /tmp/zabbix-restore etc/zabbix
```

    Проверяем файлы, затем копируем:

```
    cp -r /tmp/zabbix-restore/etc/zabbix/* /etc/zabbix/
```

    Перезапускаем Zabbix, если нужно.

**Примечание:** Перенос бэкапов

Есть три рабочих способа перенести бэкапы Borg на другой диск или сервер — под разные задачи.

#### Способ 1. borg transfer — лучший для миграции репозитория (сохраняет дедупликацию)

Это штатный способ Borg для переноса архивов между репозиториями. Он не копирует файлы как есть, а переносит только те чанки, которых ещё нет в целевом репозитории — дедупликация остаётся.

##### Шаг 1. Подготовить целевой репозиторий

На новом диске/сервере создай пустой репозиторий с тем же типом шифрования, что и у исходного:

```
# Если у тебя repokey:
borg init --encryption=repokey borg@new-server:/var/backup_new

# Если keyfile (и ключ будет отдельно):
borg init --encryption=keyfile borg@new-server:/var/backup_new
```

При repokey попросит passphrase — вводи ту же, что у старого репозитория. Это нужно, чтобы ключи дедупликации совпадали.

##### Шаг 2. Перенести архивы

С любой машины, где есть доступ к обоим репозиториям (или через SSH к новому серверу):

```
borg transfer --other-repo=borg@old-server:/var/backup borg@new-server:/var/backup_new
```
    Сначала запусти с --dry-run, чтобы увидеть, что будет перенесено:

```   
    borg transfer --dry-run --other-repo=borg@old-server:/var/backup borg@new-server:/var/backup_new
```
    Если всё ок — убери --dry-run и запускай.

Плюсы:

   - Сохраняется дедупликация: если в будущем будешь писать в новый репозиторий, он продолжит дедуплицировать против старых данных.
     
   - Можно запускать несколько раз: недокачанные архивы подхватываются, ничего не ломается.
     
   - Работает даже при частичных сбоях: незавершённые архивы не появляются в целевом репо.

Минусы:

    - Нужно, чтобы версии Borg на обоих концах были совместимы.
    
    - Для keyfile важно, чтобы ключ был доступен на машине, с которой делаешь transfer.


#### Способ 2. Простое копирование папки (быстро, но без дедупликации между репозиториями)

Если репозиторий не очень большой и дедупликация между старым и новым не нужна, можно просто скопировать папку.

```
rsync -av --no-perms borg@old-server:/var/backup/ borg@new-server:/var/backup_new/
```

Или локально (если переносишь на другой диск на том же сервере):

```
cp -a /var/backup /var/backup_new
chown -R borg:borg /var/backup_new
chmod 700 /var/backup_new
find /var/backup_new -type f -exec chmod 600 {} \;
```

Важно: после копирования обязательно проверь права и владельца — Borg очень чувствителен к ним.

Когда это уместно:

   - Быстрый перенос на другой диск в рамках одного сервера.
     
   - Временная копия для теста/восстановления.

   - Не планируешь дальше писать в старый репозиторий и дедупликация не важна.


#### Способ 3. borg copy — если нужно перенести отдельные архивы

Если нужно не всё подряд, а конкретные точки восстановления (например, только архивы за последние 7 дней):

```
borg copy borg@old-server:/var/backup::etc-2026-10-24_09:48:12 borg@new-server:/var/backup_new::etc-2026-10-24_09:48:12
```

Можно делать в цикле по списку архивов. Это удобно, когда переносишь выборочно, но для полной миграции лучше transfer.
