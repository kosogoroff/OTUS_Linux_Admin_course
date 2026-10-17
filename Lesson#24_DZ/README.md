# Занятие 28.09.2026 "24. Пользователи и группы. Авторизация и аутентификация"

PAM

## Цель:

научиться создавать пользователей и добавлять им ограничения;

## Описание/Пошаговая инструкция выполнения домашнего задания:

#### 🎯 Что нужно сделать?

Ограничить доступ к системе для всех пользователей, кроме группы администраторов, в выходные дни (суббота и воскресенье), за исключением праздничных дней.


### ⭐️ Задание повышенной сложности

Предоставить определённому пользователю доступ к Docker и право перезапускать Docker-сервис.



В чат ДЗ отправьте ссылку на ваш git-репозиторий . Обычно мы проверяем ДЗ в течение 48 часов.

# Решение

### 1. Создание конфигурирование ВМ, первоначальное конфигурирование доступа средствами vagrant

### Описание 

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

Исходный файл Vagrantfile из методички :

```
MACHINES = {
  :"pam" => {
              :box_name => "ubuntu/jammy64",
              :cpus => 2,
              :memory => 1024,
              :ip => "192.168.57.10",
            }
}

Vagrant.configure("2") do |config|
  MACHINES.each do |boxname, boxconfig|
    config.vm.synced_folder ".", "/vagrant", disabled: true
    config.vm.network "private_network", ip: boxconfig[:ip]
    config.vm.define boxname do |box|
      box.vm.box = boxconfig[:box_name]
      box.vm.box_version = boxconfig[:box_version]
      box.vm.host_name = boxname.to_s

      box.vm.provider "virtualbox" do |v|
        v.memory = boxconfig[:memory]
        v.cpus = boxconfig[:cpus]
      end
      box.vm.provision "shell", inline: <<-SHELL
          sed -i 's/^PasswordAuthentication.*$/PasswordAuthentication yes/' /etc/ssh/sshd_config
          systemctl restart sshd.service
  	  SHELL
    end
  end
end

```

Приведённый выше файл создан для работы с virtualbox и с боксом Ubuntu находящимся на vagrantcloud. Поэтому для использования с libvirt/KVM, а также с локально установленными боксами в нём нужно сделать несколько изменений. Нужно поменять три вещи: 

- провайдер (virtualbox по умолчанию, либо vibvirt),

- сеть (libvirt имеет другую организацию сети и не поддерживает проброс порта в том виде, как это делает virtualbox),

- источник бокса (использовать удалённый бокс расположенный на Hashcorp vagrantcloud либо локально установленный бокс).

Модифицированный Vagrantfile (используется в лабораторном проекте) приведён ниже:

```
# Провайдер из переменной окружения или virtualbox по умолчанию
PROVIDER = ENV["VAGRANT_DEFAULT_PROVIDER"] || "virtualbox"

# Имя бокса можно переопределить через переменную окружения:
#   VAGRANT_BOX=almalinux9-stand vagrant up --provider=libvirt
BOX_NAME = ENV['VAGRANT_BOX'] || 'generic/ubuntu2204'

MACHINES = {
  :"pam" => {
    :box_name => BOX_NAME,
    :cpus     => 2,
    :memory   => 1024,
    :ip       => "192.168.57.10",
  }
}

Vagrant.configure("2") do |config|
  # Глобальные настройки (если нужны)
  config.vm.synced_folder ".", "/vagrant", disabled: true

  MACHINES.each do |name, boxconfig|
    config.vm.define name.to_s do |box|
      box.vm.box = boxconfig[:box_name]
      box.vm.box_version = boxconfig[:box_version] if boxconfig[:box_version]
      box.vm.hostname = name.to_s

      # --- Сеть (только для этой машины) ---
      box.vm.network "private_network", ip: boxconfig[:ip]

      # --- Провайдер VirtualBox ---
      box.vm.provider :virtualbox do |vb|
        vb.memory = boxconfig[:memory]
        vb.cpus = boxconfig[:cpus]
      end

      # --- Провайдер libvirt ---
      box.vm.provider :libvirt do |lv|
        lv.memory = boxconfig[:memory]
        lv.cpus = boxconfig[:cpus]
        # libvirt по умолчанию создаёт сеть, можно дополнительно задать network_name при необходимости
      end

      # --- Провижининг: включить PasswordAuthentication ---
      box.vm.provision "shell", inline: <<-SHELL
        if [ -f /etc/ssh/sshd_config ]; then
          sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
          if command -v systemctl >/dev/null 2>&1; then
            systemctl restart sshd
          elif command -v service >/dev/null 2>&1; then
            service sshd restart
          fi
        fi
      SHELL
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
Также после запуска и еонфигурирования ВМ в virtualbox иногда остаётся интерфейс vboxnet0, который может потом конфликтовать с запускаемой ВМ в libvirt.

Его можно удалить командами:

```
VBoxManage hostonlyif remove vboxnet0
sudo ip link delete vboxnet0
```

### 2. Выполнение лабораторной работы из домашнего задания

Подключаемся с хоста к ВМ, создаём пользователей otus и otusadm и группу admin, добавляем пользователя otus в группу admin.
Проверяем, что созданные пользователи нормально входят в ВМ по SSH со своими логинами и паролями:

```
[admin_insta11@mv334 users_rights]$ vagrant ssh
[vagrant@pam ~]$ 
[vagrant@pam ~]$ sudo -i
[root@pam ~]# 
[root@pam ~]# sudo useradd otusadm && sudo useradd otus
[root@pam ~]# 
[root@pam ~]# echo "Otus2022!" | sudo passwd --stdin otusadm && echo "Otus2022!" | sudo passwd --stdin otus
Changing password for user otusadm.
passwd: all authentication tokens updated successfully.
Changing password for user otus.
passwd: all authentication tokens updated successfully.
[root@pam ~]# 
[root@pam ~]# sudo groupadd -f admin
[root@pam ~]# 
[root@pam ~]# usermod otusadm -a -G admin && usermod root -a -G admin && usermod vagrant -a -G admin
[root@pam ~]#
[root@pam ~]# cat /etc/group | grep admin
printadmin:x:996:
admin:x:1003:otusadm,root,vagrant
[root@pam ~]# 
[root@pam ~]# exit
logout
[vagrant@pam ~]$
[vagrant@pam ~]$ ssh otus@192.168.57.10
The authenticity of host '192.168.57.10 (192.168.57.10)' can't be established.
ED25519 key fingerprint is SHA256:Wx7staT8yLtR6i/r9EFiYM2Q3StJWcoEuFeGQK0ZBz4.
This key is not known by any other names.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '192.168.57.10' (ED25519) to the list of known hosts.
otus@192.168.57.10's password: 
[otus@pam ~]$ 
[otus@pam ~]$ whoami
otus
[otus@pam ~]$ exit
logout
Connection to 192.168.57.10 closed.
[vagrant@pam ~]$ 
[vagrant@pam ~]$ ssh otusadm@192.168.57.10
otusadm@192.168.57.10's password: 
[otusadm@pam ~]$ whoami
otusadm
[otusadm@pam ~]$ exit
logout
Connection to 192.168.57.10 closed.
[vagrant@pam ~]$ exit
logout
```

Далее необходимо ограничить доступ к системе для всех пользователей, кроме группы администраторов, в выходные дни (суббота и воскресенье). Для этого конфигурируем PAM, создаём скрипт для модeля PAM pam_exec скрипт контроля аутентификации пользователей. 

В скрипте подписаны все условия. Скрипт работает по принципу: 

1. Если сегодня суббота или воскресенье, то нужно проверить, входит ли пользователь в группу admin, если не входит — то подключение запрещено.

2. При любых других вариантах подключение разрешено. 

Созданный скрипт делаем исполняемым, и прописываем его в файл правил PAM для соединений SSH:

```
[admin_insta11@mv334 users_rights]$ vagrant ssh
Last login: Sat Oct 17 15:03:00 2026 from 192.168.121.1
[vagrant@pam ~]$ 
[vagrant@pam ~]$ sudo -i
[root@pam ~]# 
[root@pam ~]# vi /usr/local/bin/login.sh
[root@pam ~]# 
[root@pam ~]# cat /usr/local/bin/login.sh
#!/bin/bash
#Первое условие: если день недели суббота или воскресенье
if [ $(date +%a) = "Sat" ] || [ $(date +%a) = "Sun" ]; then
 #Второе условие: входит ли пользователь в группу admin
 if getent group admin | grep -qw "$PAM_USER"; then
        #Если пользователь входит в группу admin, то он может подключиться
        exit 0
      else
        #Иначе ошибка (не сможет подключиться)
        exit 1
    fi
  #Если день не выходной, то подключиться может любой пользователь
  else
    exit 0
fi

[root@pam ~]# 
[root@pam ~]# chmod +x /usr/local/bin/login.sh
[root@pam ~]# 
[root@pam ~]# 
[root@pam ~]# cat /etc/pam.d/sshd
#%PAM-1.0
auth       substack     password-auth
auth       include      postlogin
account    required     pam_sepermit.so
account    required     pam_nologin.so
account    include      password-auth
password   include      password-auth
# pam_selinux.so close should be the first session rule
session    required     pam_selinux.so close
session    required     pam_loginuid.so
# pam_selinux.so open should only be followed by sessions to be executed in the user context
session    required     pam_selinux.so open env_params
session    required     pam_namespace.so
session    optional     pam_keyinit.so force revoke
session    optional     pam_motd.so
session    include      password-auth
session    include      postlogin
[root@pam ~]# 
[root@pam ~]# vi /etc/pam.d/sshd
[root@pam ~]# 
[root@pam ~]# cat /etc/pam.d/sshd
#%PAM-1.0
auth       substack     password-auth
auth       include      postlogin
auth       required     pam_exec.so debug /usr/local/bin/login.sh

account    required     pam_sepermit.so
account    required     pam_nologin.so
account    include      password-auth
password   include      password-auth
# pam_selinux.so close should be the first session rule
session    required     pam_selinux.so close
session    required     pam_loginuid.so
# pam_selinux.so open should only be followed by sessions to be executed in the user context
session    required     pam_selinux.so open env_params
session    required     pam_namespace.so
session    optional     pam_keyinit.so force revoke
session    optional     pam_motd.so
session    include      password-auth
session    include      postlogin
[root@pam ~]#
```

Далее проверяем возможность входа созданных пользователей по SSH в зависимости от дня недели.
Сначала устанавливаем в ВМ дату 16 октября 2026 (пятница). С этой датой в ВМ по SSH могут войти оба созданных пользователя - и otus , и otusadm:

```
[vagrant@pam ~]$ sudo date -s "2026-10-16"
Fri Oct 16 12:00:00 AM UTC 2026
[vagrant@pam ~]$ 
[vagrant@pam ~]$ 
[vagrant@pam ~]$ ssh otus@192.168.57.10
otus@192.168.57.10's password: 
Last failed login: Sat Oct 17 15:18:50 UTC 2026 from 192.168.57.10 on ssh:notty
There was 1 failed login attempt since the last successful login.
Last login: Sat Oct 17 15:06:29 2026 from 192.168.57.10
[otus@pam ~]$ whoami
otus
[otus@pam ~]$ exit
logout
Connection to 192.168.57.10 closed.
[vagrant@pam ~]$ 
[vagrant@pam ~]$ ssh otusadm@192.168.57.10
otusadm@192.168.57.10's password: 
Last login: Sat Oct 17 15:19:06 2026 from 192.168.57.10
[otusadm@pam ~]$ exit
logout
Connection to 192.168.57.10 closed.
[vagrant@pam ~]$
```

Затем устанавливаем в ВМ дату 17 октября 2026 (суббота). С этой датой в ВМ по SSH может войти только пользователь otusadm,
входящий в группу admin. Пользователь otus по SSH войти не может:

```
[vagrant@pam ~]$ sudo date -s "2026-10-17"
Sat Oct 17 12:00:00 AM UTC 2026
[vagrant@pam ~]$ 
[vagrant@pam ~]$ ssh otus@192.168.57.10
otus@192.168.57.10's password: 
Permission denied, please try again.
otus@192.168.57.10's password: 

[vagrant@pam ~]$ 
[vagrant@pam ~]$ ssh otusadm@192.168.57.10
otusadm@192.168.57.10's password: 
Last login: Fri Oct 16 00:01:09 2026 from 192.168.57.10
[otusadm@pam ~]$ 
[otusadm@pam ~]$ exit
logout
Connection to 192.168.57.10 closed.
[vagrant@pam ~]$ 
```

Репозиторий проекта выложен на Github по ссылке https://github.com/kosogoroff/users_rights.git

