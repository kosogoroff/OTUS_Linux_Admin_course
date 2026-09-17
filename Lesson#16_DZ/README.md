# Занятие 24.08.2026 "Автоматизация администрирования. Ansible"

Первые шаги с Ansible

## Описание/Пошаговая инструкция выполнения домашнего задания:


#### 🎯 Что нужно сделать?

Подготовить стенд на Vagrant как минимум с одним сервером. На этом сервере, используя Ansible, необходимо развернуть nginx со следующими условиями:

- необходимо использовать модуль yum/apt;

- конфигурационные файлы должны быть взяты из шаблона jinja2 с переменными;

- после установки nginx должен быть в режиме enabled в systemd;

- должен быть использован notify для старта nginx после установки;

- сайт должен слушать на нестандартном порту — 8080, для этого использовать переменные в Ansible.

# Решение

### 1. Создание конфигурирование ВМ, первоначальное конфигурирование доступа средствами vagrant

По ссылке https://github.com/kosogoroff/ansible_lab.git выложен работающий репозиторий с выполненным домашним заданием.

Полный состав лабораторного проекта:

```
[admin_insta11@mv334 ~]$ tree ansible_lab
ansible_lab
├── ansible.cfg
├── gen_ansible_inventory.sh
├── nginx.yml
├── staging
│   └── hosts
├── templates
│   └── nginx.conf.j2
└── Vagrantfile

2 directories, 6 files

```

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

Исходный файл Vagrantfile из лабораторной работы по ссылке https://drive.google.com/file/d/17MEtg20TFSjKil6ih7PvPez7jmCvo6fb/view?usp=share_link :

```
# -*- mode: ruby -*-
# vim: set ft=ruby :

MACHINES = {
  :nginx => {
        :box_name => "generic/ubuntu2204",
        :vm_name => "nginx",
        :net => [
           ["192.168.11.150",  2, "255.255.255.0", "mynet"],
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
        sudo sed -i 's/\#PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
        systemctl restart sshd
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
# -*- mode: ruby -*-
# vim: set ft=ruby :

# Провайдер из переменной окружения или virtualbox по умолчанию
PROVIDER = ENV["VAGRANT_DEFAULT_PROVIDER"] || "virtualbox"

# Имя бокса можно переопределить через переменную окружения:
#   VAGRANT_BOX=almalinux9-stand vagrant up --provider=libvirt
BOX_NAME = ENV['VAGRANT_BOX'] || 'generic/ubuntu2204'

MACHINES = {
  :nginx => {
    :box_name => BOX_NAME,
    :vm_name => "nginx",
    :mem => 768,
    :cpus => 1,
    :net => [
      ["192.168.11.150", 2, "255.255.255.0", "mynet"],
    ]
#  },
#  :nginx2 => {
#    :box_name => BOX_NAME,
#    :vm_name => "nginx2",
#    :mem => 768,
#    :cpus => 1,
#    :net => [
#      ["192.168.11.151", 2, "255.255.255.0", "mynet"],
#    ]
  }
}

Vagrant.configure("2") do |config|

  # Базовый порт для проброса (только VirtualBox)
  host_port = 8080

  MACHINES.each do |boxname, boxconfig|

    config.vm.define boxname do |box|

      box.vm.box = boxconfig[:box_name]
      box.vm.host_name = boxconfig[:vm_name]

      # --- Настройки провайдера ---
      if PROVIDER == "libvirt"
        box.vm.provider :libvirt do |lv|
          lv.memory = boxconfig[:mem]
          lv.cpus = boxconfig[:cpus]
        end
      else
        box.vm.provider "virtualbox" do |v|
          v.memory = boxconfig[:mem]
          v.cpus = boxconfig[:cpus]
        end
      end

      # --- Сеть: private_network (по-разному для провайдеров) ---
      boxconfig[:net].each do |ipconf|
        if PROVIDER == "libvirt"
          box.vm.network("private_network",
            ip: ipconf[0],
            netmask: ipconf[2],
            libvirt__network_name: ipconf[3]
          )
        else
          box.vm.network("private_network",
            ip: ipconf[0],
            adapter: ipconf[1],
            netmask: ipconf[2],
            virtualbox__intnet: ipconf[3]
          )
        end
      end

      if boxconfig.key?(:public)
        box.vm.network "public_network", boxconfig[:public]
      end

      # --- Проброс портов (только VirtualBox) ---
      if PROVIDER == "virtualbox"
        box.vm.network :forwarded_port,
          guest: 80,
          host: host_port,
          host_ip: "127.0.0.1"
        host_port += 1
      end

      # --- Провижн ---
      box.vm.provision "shell", inline: <<-SHELL
        mkdir -p ~root/.ssh
        cp ~vagrant/.ssh/auth* ~root/.ssh 2>/dev/null || true
        sudo sed -i 's/#PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
        systemctl restart sshd
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
VAGRANT_BOX=almalinux9-stand VAGRANT_DEFAULT_PROVIDER=libvirt vagrant up --provider=libvirt
```

3) Для создания ВМ в гипервизоре virtualbox с использованием локально установленного бокса almalinux/9 нужно запустить командой

```
VAGRANT_BOX=almalinux9-stand-vb vagrant up --provider=virtualbox
```

или

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


### 2. Конфигурирование созданной ВМ средствами ansible.

После создания виртуальной машины для автоматической генерации файла инвентаря предлагается однократно запустить вспомогательный скрипт , который генерирует файл инвентаря для ansible на основе данных 'vagrant ssh-config' для конкретной ВМ. Вспомогательный скрипт gen_ansible_inventory.sh выглядит следующим образом:

```
#!/bin/bash
# gen_inventory.sh — генерирует инвентарь из vagrant ssh-config

PROVIDER="${VAGRANT_DEFAULT_PROVIDER:-virtualbox}"
HOSTS_FILE="./staging/hosts"

# Получаем SSH-конфиг для всех машин
SSH_CONFIG=$(vagrant ssh-config nginx 2>/dev/null)

# Парсим нужные поля
HOST=$(echo "$SSH_CONFIG" | grep -i 'HostName' | awk '{print $2}')
PORT=$(echo "$SSH_CONFIG" | grep -i 'Port' | awk '{print $2}')
KEY=$(echo "$SSH_CONFIG" | grep -i 'IdentityFile' | awk '{print $2}' | sed 's/"//g')

cat > "$HOSTS_FILE" <<EOF
[web]
nginx ansible_host=${HOST} ansible_port=${PORT} ansible_user=vagrant ansible_private_key_file=${KEY}
EOF

echo "Inventory generated:"
cat "$HOSTS_FILE"
```

Скрипт gen_ansible_inventory.sh необходимо запустить однократно после создания ВМ для быстрого создания файла инвентаря для ansible - после этого файл инвентаря правильно формируется (предложенный в методичке файл конфигурации ansible.cfg создан один раз остаётся без изменений), и после этого ansible успешно подключается к ВМ:

```
[admin_insta11@mv334 ansible_lab]$ cat ansible.cfg
[defaults]
inventory = staging/hosts
remote_user = vagrant
host_key_checking = False
retry_files_enabled = False
[admin_insta11@mv334 ansible_lab]$
[admin_insta11@mv334 ansible_lab]$ ./gen_ansible_inventory.sh
Inventory generated:
[web]
nginx ansible_host=127.0.0.1 ansible_port=2222 ansible_user=vagrant ansible_private_key_file=/home/admin_insta11/ansible_lab/.vagrant/machines/nginx/virtualbox/private_key
[admin_insta11@mv334 ansible_lab]$ 
[admin_insta11@mv334 ansible_lab]$ ansible nginx -i ./staging/hosts -m ping
nginx | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
[admin_insta11@mv334 ansible_lab]$ 
```
  
Исходный предложенный в методичке файл Playbook nginx.yml для конфигурирования созданной ВМ средствами ansible и шаблон templates/nginx.conf.j2 формирования файла конфигурации nginx.conf предназначен для конфигурирования nginx в Linux семейства Debian, приведены ниже:

```
[admin_insta11@mv334 ansible_lab]$ cat nginx.yml
---
- name: NGINX | Install and configure NGINX
  hosts: nginx
  become: true
  vars:
    nginx_listen_port: 8080


  tasks:
    - name: update
      apt:
        update_cache=yes
      tags:
        - update apt

    - name: NGINX | Install NGINX
      apt:
        name: nginx
        state: latest
      notify:
        - restart nginx
      tags:
        - nginx-package

    - name: NGINX | Create NGINX config file from template
      template:
        src: templates/nginx.conf.j2
        dest: /tmp/nginx.conf
      notify:
        - reload nginx
      tags:
        - nginx-configuration

  handlers:
    - name: restart nginx
      systemd:
        name: nginx
        state: restarted
        enabled: yes

    - name: reload nginx
      systemd:
        name: nginx
        state: reloaded

[admin_insta11@mv334 ansible_lab]$ 
[admin_insta11@mv334 ansible_lab]$ cat templates/nginx.conf.j2
# {{ ansible_managed }}
events {
    worker_connections 1024;
}

http {
    server {
        listen       {{ nginx_listen_port }} default_server;
        server_name  default_server;
        root         /usr/share/nginx/html;

        location / {
        }
    }
}
[admin_insta11@mv334 ansible_lab]$ 
```

Ниже приведён модифицированный файл Playbook nginx.yml (используется в проекте) для конфигурирования nginx в зависимости от семейства Linux (Debian или RedHat) :

```
---
- name: NGINX | Install and configure NGINX (Universal + SELinux)
  hosts: nginx
  become: true
  vars:
    nginx_listen_port: 8080
    nginx_service_name: nginx

  tasks:
    # --- Обновление кэша только для Debian/Ubuntu ---
    - name: Update package cache (Debian/Ubuntu family)
      apt:
        update_cache: yes
        cache_valid_time: 3600
      when: ansible_os_family == "Debian"
      tags:
        - update-cache

    # --- Установка NGINX с учётом пакетного менеджера ---
    - name: NGINX | Install NGINX
      block:
        - name: Install NGINX via yum/dnf (RedHat family)
          yum:
            name: nginx
            state: latest
          when: ansible_os_family == "RedHat"
          notify:
            - restart nginx

        - name: Install NGINX via apt (Debian family)
          apt:
            name: nginx
            state: latest
            update_cache: no
          when: ansible_os_family == "Debian"
          notify:
            - restart nginx
      tags:
        - nginx-package

    # --- Конфигурация через шаблон ---
    - name: NGINX | Create NGINX config file from template
      template:
        src: templates/nginx.conf.j2
        dest: /etc/nginx/nginx.conf
        owner: root
        group: root
        mode: "0644"
        backup: yes
      notify:
        - reload nginx
      register: nginx_conf_result
      tags:
        - nginx-configuration

    # --- SELinux: восстановление контекста ТОЛЬКО для RedHat-семейства ---
    - name: SELinux | Restore context for nginx.conf (RedHat only)
      command: restorecon -v /etc/nginx/nginx.conf
      when:
        - ansible_os_family == "RedHat"
        - nginx_conf_result.changed | default(false)
      tags:
        - selinux

  handlers:
    - name: restart nginx
      systemd:
        name: "{{ nginx_service_name }}"
        state: restarted
        enabled: yes

    - name: reload nginx
      systemd:
        name: "{{ nginx_service_name }}"
        state: reloaded

```

В данном Playbook учтены следующие различия при установке и конфигурировании nginx в зависимости от семейства Linux:


**На Ubuntu (семейство Debian):**

- Задача Update package cache — выполняется.
  
- Установка через apt — выполняется.

- Шаблон — применяется при необходимости.

- Задача SELinux | Restore context — пропускается.

**На AlmaLinux (семейство RedHat):** 

- Задача Update package cache — пропускается (не нужна).

- Установка через yum (под капотом dnf) — выполняется.

- Шаблон — применяется при необходимости.

- Если шаблон реально изменил конфиг, запускается restorecon -v /etc/nginx/nginx.conf.


## 3. Проверка создания и конфигурирования ВМ

Для проверки работоспособности проекта выбраны две конфигурации:

- настройка nginx в ВМ c Ubuntu 22.04 в гипервизоре virtualbox;

- настройка nginx в ВМ c Almalinux/9 в гипервизоре libvirt/kvm.

### 3.1 настройка nginx в ВМ c Ubuntu 22.04 в гипервизоре virtualbox

Создаём ВМ Ubuntu 22.04 из локального бокса:

```
[admin_insta11@mv334 ansible_lab]$ 
[admin_insta11@mv334 ansible_lab]$ vagrant box list
almalinux9-stand        (libvirt, 0)
almalinux9-stand-vb     (virtualbox, 0)
ubuntu-22.04-virtualbox (virtualbox, 0)
[admin_insta11@mv334 ansible_lab]$ VAGRANT_BOX=ubuntu-22.04-virtualbox vagrant up
Bringing machine 'nginx' up with 'virtualbox' provider...
==> nginx: Importing base box 'ubuntu-22.04-virtualbox'...
==> nginx: Matching MAC address for NAT networking...
==> nginx: Setting the name of the VM: ansible_lab_nginx_1789658760744_31482
==> nginx: Clearing any previously set network interfaces...
==> nginx: Preparing network interfaces based on configuration...
    nginx: Adapter 1: nat
    nginx: Adapter 2: intnet
==> nginx: Forwarding ports...
    nginx: 8080 (guest) => 8080 (host) (adapter 1)
    nginx: 22 (guest) => 2222 (host) (adapter 1)
==> nginx: Running 'pre-boot' VM customizations...
==> nginx: Booting VM...
==> nginx: Waiting for machine to boot. This may take a few minutes...
    nginx: SSH address: 127.0.0.1:2222
    nginx: SSH username: vagrant
    nginx: SSH auth method: private key
    nginx: Warning: Remote connection disconnect. Retrying...
    nginx: Warning: Connection reset. Retrying...
    nginx: 
    nginx: Vagrant insecure key detected. Vagrant will automatically replace
    nginx: this with a newly generated keypair for better security.
    nginx: 
    nginx: Inserting generated public key within guest...
    nginx: Removing insecure key from the guest if it's present...
    nginx: Key inserted! Disconnecting and reconnecting using new SSH key...
==> nginx: Machine booted and ready!
==> nginx: Checking for guest additions in VM...
    nginx: The guest additions on this VM do not match the installed version of
    nginx: VirtualBox! In most cases this is fine, but in rare cases it can
    nginx: prevent things such as shared folders from working properly. If you see
    nginx: shared folder errors, please make sure the guest additions within the
    nginx: virtual machine match the version of VirtualBox you have installed on
    nginx: your host and reload your VM.
    nginx: 
    nginx: Guest Additions Version: 7.2.4
    nginx: VirtualBox Version: 7.1
==> nginx: Setting hostname...
==> nginx: Configuring and enabling network interfaces...
==> nginx: Mounting shared folders...
    nginx: /home/admin_insta11/ansible_lab => /vagrant
==> nginx: Running provisioner: shell...
    nginx: Running: inline script
[admin_insta11@mv334 ansible_lab]$
```

Создаём скриптом файл инвентаря и после этого проверяем подключение ansible к ВМ:

```
[admin_insta11@mv334 ansible_lab]$ ./gen_ansible_inventory.sh 
Inventory generated:
[web]
nginx ansible_host=127.0.0.1 ansible_port=2222 ansible_user=vagrant ansible_private_key_file=/home/admin_insta11/ansible_lab/.vagrant/machines/nginx/virtualbox/private_key
[admin_insta11@mv334 ansible_lab]$ 
[admin_insta11@mv334 ansible_lab]$ ansible nginx -i ./staging/hosts -m ping
nginx | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
[admin_insta11@mv334 ansible_lab]$ 
[admin_insta11@mv334 ansible_lab]$ ansible nginx -i ./staging/hosts -m setup -a 'filter=ansible_os_family,ansible_distribution,ansible_python_version'
nginx | SUCCESS => {
    "ansible_facts": {
        "ansible_distribution": "Ubuntu",
        "ansible_os_family": "Debian",
        "ansible_python_version": "3.10.12",
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false
}
[admin_insta11@mv334 ansible_lab]$
```

Производим конфигурирование ВМ с помощью playbook, при этом выполняются задачи, требуемые для семейства Linux Debian и пропускаются задачи, требуемые только  для семейства Linux RedHat:

```
[admin_insta11@mv334 ansible_lab]$ ansible-playbook nginx.yml

PLAY [NGINX | Install and configure NGINX (Universal + SELinux)] *****************************************************************************************************************************

TASK [Gathering Facts] ***********************************************************************************************************************************************************************
ok: [nginx]

TASK [Update package cache (Debian/Ubuntu family)] *******************************************************************************************************************************************
ok: [nginx]

TASK [Install NGINX via yum/dnf (RedHat family)] *********************************************************************************************************************************************
skipping: [nginx]

TASK [Install NGINX via apt (Debian family)] *************************************************************************************************************************************************
changed: [nginx]

TASK [NGINX | Create NGINX config file from template] ****************************************************************************************************************************************
changed: [nginx]

TASK [SELinux | Restore context for nginx.conf (RedHat only)] ********************************************************************************************************************************
skipping: [nginx]

RUNNING HANDLER [restart nginx] **************************************************************************************************************************************************************
changed: [nginx]

RUNNING HANDLER [reload nginx] ***************************************************************************************************************************************************************
changed: [nginx]

PLAY RECAP ***********************************************************************************************************************************************************************************
nginx                      : ok=6    changed=4    unreachable=0    failed=0    skipped=2    rescued=0    ignored=0   

[admin_insta11@mv334 ansible_lab]$
```

После конфигурирования проверяем, что на хосте открыт порт 8080 (проброшен с порта 8080 гостевой ВМ), а также проверяем доступность WEB-страницы nginx гостевой ВМ:

```
[admin_insta11@mv334 ansible_lab]$ 
[admin_insta11@mv334 ansible_lab]$ ss -tnlp | grep 80
LISTEN 0      10         127.0.0.1:8080       0.0.0.0:*          
[admin_insta11@mv334 ansible_lab]$ 
[admin_insta11@mv334 ansible_lab]$ curl http://localhost:8080
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
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
[admin_insta11@mv334 ansible_lab]$
```

Проверяем заход на гостевую ВМ, конфигурацию nginx (сконфигурирован нестандартный порт 8080) и статус сервиса nginx:

```
[admin_insta11@mv334 ansible_lab]$ vagrant ssh
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-160-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

 System information as of Thu Sep 17 03:41:23 PM UTC 2026

  System load:           0.01
  Usage of /:            16.6% of 30.34GB
  Memory usage:          32%
  Swap usage:            0%
  Processes:             135
  Users logged in:       0
  IPv4 address for eth0: 10.0.2.15
  IPv6 address for eth0: fd17:625c:f037:2:a00:27ff:fe16:ddef


This system is built by the Bento project by Chef Software
More information can be found at https://github.com/chef/bento

Use of this system is acceptance of the OS vendor EULA and License Agreements.
Last login: Thu Sep 17 15:29:09 2026 from 10.0.2.2
vagrant@nginx:~$ 
vagrant@nginx:~$ ss -tnlp | 8080
-bash: 8080: command not found
vagrant@nginx:~$ ss -tnlp | grep 8080
LISTEN 0      511          0.0.0.0:8080      0.0.0.0:*          
vagrant@nginx:~$ 

vagrant@nginx:~$ cat /etc/nginx/nginx.conf
# Ansible managed
events {
    worker_connections 1024;
}

http {
    server {
        listen       8080 default_server;
        server_name  default_server;
        root         /usr/share/nginx/html;

        location / {
        }
    }
}
vagrant@nginx:~$ 
vagrant@nginx:~$ systemctl status nginx.service
● nginx.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/lib/systemd/system/nginx.service; enabled; vendor preset: enabled)
     Active: active (running) since Thu 2026-09-17 15:29:09 UTC; 14min ago
       Docs: man:nginx(8)
   Main PID: 2846 (nginx)
      Tasks: 2 (limit: 709)
     Memory: 1.9M
        CPU: 25ms
     CGroup: /system.slice/nginx.service
             ├─2846 "nginx: master process /usr/sbin/nginx -g daemon on; master_process on;"
             └─2875 "nginx: worker process" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" ""

Sep 17 15:29:09 nginx systemd[1]: nginx.service: Deactivated successfully.
Sep 17 15:29:09 nginx systemd[1]: Stopped A high performance web server and a reverse proxy server.
Sep 17 15:29:09 nginx systemd[1]: Starting A high performance web server and a reverse proxy server...
Sep 17 15:29:09 nginx systemd[1]: Started A high performance web server and a reverse proxy server.
Sep 17 15:29:09 nginx systemd[1]: Reloading A high performance web server and a reverse proxy server...
Sep 17 15:29:09 nginx systemd[1]: Reloaded A high performance web server and a reverse proxy server.
vagrant@nginx:~$ 
```

### 3.2 настройка nginx в ВМ c Almalinux/9 в гипервизоре libvirt/kvm

Создаём ВМ Almalinux/9 из локального бокса:

```
[admin_insta11@mv334 ansible_lab]$ VAGRANT_BOX=almalinux9-stand VAGRANT_DEFAULT_PROVIDER=libvirt vagrant up --provider=libvirt
Bringing machine 'nginx' up with 'libvirt' provider...
==> nginx: No version detected for almalinux9-stand, using timestamp to watch for modifications. Consider
==> nginx: generating a local metadata for the box with a version to allow better handling.
==> nginx: See https://www.vagrantup.com/docs/boxes/format#box-metadata for further details.
==> nginx: Creating image (snapshot of base box volume).
==> nginx: Creating domain with the following settings...
==> nginx:  -- Name:              ansible_lab_nginx
==> nginx:  -- Description:       Source: /home/admin_insta11/ansible_lab/Vagrantfile
==> nginx:  -- Domain type:       kvm
==> nginx:  -- Cpus:              1
==> nginx:  -- Feature:           acpi
==> nginx:  -- Feature:           apic
==> nginx:  -- Feature:           pae
==> nginx:  -- Clock offset:      utc
==> nginx:  -- Memory:            768M
==> nginx:  -- Base box:          almalinux9-stand
==> nginx:  -- Storage pool:      default
==> nginx:  -- Image(vda):        /var/lib/libvirt/images/ansible_lab_nginx.img, virtio, 20G
==> nginx:  -- Disk driver opts:  cache='default'
==> nginx:  -- Graphics Type:     vnc
==> nginx:  -- Video Type:        cirrus
==> nginx:  -- Video VRAM:        16384
==> nginx:  -- Video 3D accel:    false
==> nginx:  -- Keymap:            en-us
==> nginx:  -- TPM Backend:       passthrough
==> nginx:  -- INPUT:             type=mouse, bus=ps2
==> nginx: Creating shared folders metadata...
==> nginx: Starting domain.
==> nginx: Domain launching with graphics connection settings...
==> nginx:  -- Graphics Port:      5900
==> nginx:  -- Graphics IP:        127.0.0.1
==> nginx:  -- Graphics Password:  Not defined
==> nginx:  -- Graphics Websocket: 5700
==> nginx: Waiting for domain to get an IP address...
==> nginx: Waiting for machine to boot. This may take a few minutes...
    nginx: SSH address: 192.168.121.13:22
    nginx: SSH username: vagrant
    nginx: SSH auth method: private key
    nginx: 
    nginx: Vagrant insecure key detected. Vagrant will automatically replace
    nginx: this with a newly generated keypair for better security.
    nginx: 
    nginx: Inserting generated public key within guest...
    nginx: Removing insecure key from the guest if it's present...
    nginx: Key inserted! Disconnecting and reconnecting using new SSH key...
==> nginx: Machine booted and ready!
==> nginx: Setting hostname...
==> nginx: Rsyncing folder: /home/admin_insta11/ansible_lab/ => /vagrant
==> nginx: Configuring and enabling network interfaces...
==> nginx: Running provisioner: shell...
    nginx: Running: inline script
[admin_insta11@mv334 ansible_lab]$
```

Создаём скриптом файл инвентаря и после этого проверяем подключение ansible к ВМ:

``` 
[admin_insta11@mv334 ansible_lab]$ ./gen_ansible_inventory.sh 
Inventory generated:
[web]
nginx ansible_host=192.168.121.13 ansible_port=22 ansible_user=vagrant ansible_private_key_file=/home/admin_insta11/ansible_lab/.vagrant/machines/nginx/libvirt/private_key
[admin_insta11@mv334 ansible_lab]$ 
[admin_insta11@mv334 ansible_lab]$ ansible nginx -i ./staging/hosts -m ping
nginx | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
[admin_insta11@mv334 ansible_lab]$ 
[admin_insta11@mv334 ansible_lab]$ ansible nginx -i ./staging/hosts -m setup -a 'filter=ansible_os_family,ansible_distribution,ansible_python_version'
nginx | SUCCESS => {
    "ansible_facts": {
        "ansible_distribution": "AlmaLinux",
        "ansible_os_family": "RedHat",
        "ansible_python_version": "3.9.25",
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false
}
[admin_insta11@mv334 ansible_lab]$
```

Производим конфигурирование ВМ с помощью playbook, при этом выполняются задачи, требуемые для семейства Linux Debian и пропускаются задачи, требуемые только  для семейства Linux RedHat:

``` 
[admin_insta11@mv334 ansible_lab]$ ansible-playbook nginx.yml

PLAY [NGINX | Install and configure NGINX (Universal + SELinux)] *****************************************************************************************************************************

TASK [Gathering Facts] ***********************************************************************************************************************************************************************
ok: [nginx]

TASK [Update package cache (Debian/Ubuntu family)] *******************************************************************************************************************************************
skipping: [nginx]

TASK [Install NGINX via yum/dnf (RedHat family)] *********************************************************************************************************************************************
changed: [nginx]

TASK [Install NGINX via apt (Debian family)] *************************************************************************************************************************************************
skipping: [nginx]

TASK [NGINX | Create NGINX config file from template] ****************************************************************************************************************************************
changed: [nginx]

TASK [SELinux | Restore context for nginx.conf (RedHat only)] ********************************************************************************************************************************
changed: [nginx]

RUNNING HANDLER [restart nginx] **************************************************************************************************************************************************************
changed: [nginx]

RUNNING HANDLER [reload nginx] ***************************************************************************************************************************************************************
changed: [nginx]

PLAY RECAP ***********************************************************************************************************************************************************************************
nginx                      : ok=6    changed=5    unreachable=0    failed=0    skipped=2    rescued=0    ignored=0   

[admin_insta11@mv334 ansible_lab]$
```

После конфигурирования проверяем, что на хосте порт 8080 не занят (порт 8080 открыт гостевой ВМ с адресом 192.168.11.150), а также проверяем доступность WEB-страницы nginx гостевой ВМ:

``` 
[admin_insta11@mv334 ansible_lab]$ ss -tnlp | grep 80
[admin_insta11@mv334 ansible_lab]$ 
[admin_insta11@mv334 ansible_lab]$ curl http://192.168.11.150:8080
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">

<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
	<head>
		<title>Test Page for the HTTP Server on AlmaLinux</title>
		<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
		<style type="text/css">
			/*<![CDATA[*/
			body {
				background-color: #fff;
				color: #000;
				font-size: 1.1em;
				font-family: "Red Hat Text", Helvetica, Tahoma, sans-serif;
				margin: 0;
				padding: 0;
                border-bottom: 30px solid #082336;
				min-height: 100vh;
				box-sizing: border-box;
			}
			:link {
				color: #304B5E;
			}
			:visited {
				color: #304B5E;
			}
			a:hover {
				color: #0069DA;
			}
			h1 {
				text-align: left;
				margin: 0;
				margin-bottom: .6em;
				padding: 1em 2em 1.5em 2em;
				background-color: #082336;
				color: #fff;
				font-weight: normal;
				font-size: 2.5em;
				border-bottom: 2px solid #000;
			}
            h1 img {
                border: none;
                margin-bottom: .4em;
            }
			h1 strong {
				font-weight: bold;
			}
			h2 {
				font-size: 1.1em;
				font-weight: bold;
			}
			hr {
				display: none;
			}
			.content {
				padding: 1em 5em;
			}
			.content-columns {
				/* Setting relative positioning allows for
				absolute positioning for sub-classes */
				position: relative;
				padding-top: 1em;
                display: flex;
				flex-wrap: wrap;
			}
			.content-column-left {
				/* Value for IE/Win; will be overwritten for other browsers */
				width: 47%;
				padding: 15px 30px;
				margin-right: 30px;
				padding-bottom: 2em;
				margin-bottom: 1em;
				flex: 1;
			}
			.content-column-left hr {
				display: none;
			}
			.content-column-right {
				/* Values for IE/Win; will be overwritten for other browsers */
				width: 47%;
				padding: 15px 30px;
				padding-bottom: 2em;
                margin-right: 30px;
				margin-bottom: 1em;
				flex: 1;
			}
			.content-columns>.content-column-left, .content-columns>.content-column-right {
				/* Non-IE/Win */
                border: 1px solid #d2d2d2;
				border-radius: 3px;
				box-sizing: border-box;
			}
			.logos {
				text-align: left;
				margin-top: 2em;
			}
            .logos a img {
                padding-right: 1.5em;
                margin-right: 1.5em;
                border-right: 1px solid #d2d2d2;
            }
			img {
				border: 2px solid #fff;
				padding: 2px;
				margin: 2px;
			}
			a:hover img {
				border: 2px solid #f50;
			}
			.footer {
			    font-size: xx-small;
                padding: 0 10em;
			    padding-bottom: 5em;
			}

            /* Responsive layout */
            @media (max-width: 800px) {
                .content-column-right, .content-column-left {
                flex: 100%;
                }
            }
			/*]]>*/
		</style>
	</head>

	<body>
		<h1>
            <img src="system_noindex_logo.png" alt="AlmaLinux Logo" /><br />
            Web Server <strong>Test Page</strong>
        </h1>

		<div class="content">
			<div class="content-middle">
				<p>This page is used to test the proper operation of the HTTP server after it has been installed. If you can read this page, it means that the HTTP server installed at this site is working properly.</p>
			</div>
			<hr />

			<div class="content-columns">
				<div class="content-column-left">
					<h2>If you are a member of the general public:</h2>

					<p>The fact that you are seeing this page indicates that the website you just visited is either experiencing problems, or is undergoing routine maintenance.</p>

					<p>If you would like to let the administrators of this website know that you've seen this page instead of the page you expected, you should send them e-mail. In general, mail sent to the name "webmaster" and directed to the website's domain should reach the appropriate person.</p>

					<p>For example, if you experienced problems while visiting www.example.com, you should send e-mail to "webmaster@example.com".</p>

					<p>For information on AlmaLinux, please visit the <a href="https://almalinux.org">AlmaLinux website</a>. The documentation for AlmaLinux is <a href="https://wiki.almalinux.org">available in AlmaLinux wiki</a>.</p>
					<hr />
				</div>

				<div class="content-column-right">
					<h2>If you are the website administrator:</h2>

					<p>You may now add content to the webroot directory. Note
					that until you do so, people visiting your website will see
					this page, and not your content.</p>

					<p>For systems using the Apache HTTP Server:
					You may now add content to the directory <tt>/var/www/html/</tt>. Note that until you do so, people visiting your website will see this page, and not your content. To prevent this page from ever being used, follow the instructions in the file <tt>/etc/httpd/conf.d/welcome.conf</tt>.</p>

					<p>For systems using NGINX:
					You should now put your content in a location of your
					choice and edit the <code>root</code> configuration directive
					in the <strong>nginx</strong> configuration file
					<code>/etc/nginx/nginx.conf</code>.</p>

					<div class="logos">
						<a href="https://almalinux.org"><img src= "/icons/poweredby.png" alt="[ Powered by AlmaLinux ]" /></a>
						<img src= "poweredby.png" alt="[ Powered by AlmaLinux ]" />
					</div>
				</div>
			</div>
		</div>
	<div class="footer">
		<a href="https://apache.org">Apache&trade;</a> is a registered trademark of <a href="https://apache.org">the Apache Software Foundation</a> in the United States and/or other countries.
        <br />
		<a href="https://nginx.com">NGINX&trade;</a> is a registered trademark of <a href="https://www.f5.com">F5 Networks, Inc.</a>.
	</div>
	</body>
</html>
[admin_insta11@mv334 ansible_lab]$
```

Проверяем заход на гостевую ВМ, конфигурацию nginx (сконфигурирован нестандартный порт 8080) и статус сервиса nginx, а также восстановленный контекст SELinux созданного файла конфигурации /etc/nginx/nginx.conf :

```
[admin_insta11@mv334 ansible_lab]$ 
[admin_insta11@mv334 ansible_lab]$ vagrant ssh
Last login: Thu Sep 17 15:53:56 2026 from 192.168.121.1
[vagrant@nginx ~]$
[admin_insta11@mv334 ansible_lab]$ vagrant ssh
Last login: Thu Sep 17 15:51:49 2026 from 192.168.121.1
[vagrant@nginx ~]$ 
[vagrant@nginx ~]$ ss -tnlp | grep 80
LISTEN 0      511          0.0.0.0:8080      0.0.0.0:*          
[vagrant@nginx ~]$ 
[vagrant@nginx ~]$ ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 52:54:00:bd:7c:9b brd ff:ff:ff:ff:ff:ff
    altname enp0s5
    altname ens5
    inet 192.168.121.13/24 brd 192.168.121.255 scope global dynamic noprefixroute eth0
       valid_lft 3288sec preferred_lft 3288sec
    inet6 fe80::8560:21c9:efc8:f365/64 scope link noprefixroute 
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 52:54:00:e8:96:a6 brd ff:ff:ff:ff:ff:ff
    altname enp0s6
    altname ens6
    inet 192.168.11.150/24 brd 192.168.11.255 scope global noprefixroute eth1
       valid_lft forever preferred_lft forever
    inet6 fe80::5054:ff:fee8:96a6/64 scope link 
       valid_lft forever preferred_lft forever
[vagrant@nginx ~]$ 
[vagrant@nginx ~]$ ls -lZ /etc/nginx/nginx.conf
-rw-r--r--. 1 root root system_u:object_r:httpd_config_t:s0 242 Sep 17 15:51 /etc/nginx/nginx.conf
[vagrant@nginx ~]$ 
[vagrant@nginx ~]$ cat /etc/nginx/nginx.conf
# Ansible managed
events {
    worker_connections 1024;
}

http {
    server {
        listen       8080 default_server;
        server_name  default_server;
        root         /usr/share/nginx/html;

        location / {
        }
    }
}
[vagrant@nginx ~]$ 
[vagrant@nginx ~]$ exit
logout
[admin_insta11@mv334 ansible_lab]$ 
```
