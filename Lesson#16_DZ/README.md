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

В связи с недоступностью портала https://portal.cloud.hashicorp.com/ для проверки и работы заранее локально скачаны несколько Vagrant box для различных версий Linux:

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

Приведённый выше файл создан для работы с virtualbox и с боксом Ubuntu находящимся на vagrantcloud. Поэтому для использования с libvirt/KVM, а также с локально установленными боксами в нём нужно сделать несколько изменений:
Нужно поменять три вещи: 

- провайдер (virtualbox по умолчанию, либо vibvirt),

- сеть (libvirt имеет другую организацию сети и не поддерживает проброс порта в том виде, как это делает virtualbox),

- источник бокса (использовать удалённый бокс расположенный на Hashcorp vagrantcloud либо локально установленный бокс).

Модифицированный Vagrantfile приведён ниже:

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

Также иходный и модифицированный Vagrantfile рассчитаны на создание нескольких ВМ - каждую ВМ можно индивидуально описывать в массиве MACHINES.

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

После создания виртуальной машины для автоматической генерации файла инвентаря предлагается однократно запустить вспомогательный скрипт , который генерирует файл инвентаря для ansible на основе данных 'vagrant ssh-config' для конкретной ВМ (при работе с разными гипервизорами это необходимо, так как построение сетей в них отличаются, поэтому данные подключений отличаются). Вспомогательный скрипт gen_ansible_inventory.sh выглядит следующим образом:

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

Скрипт gen_ansible_inventory.sh необходимо запустить после создания ВМ для быстрого создания файла инвентаря для ansible - после этого файл инвентаря правильно формируется,
и после этого ansible успешно подключается к ВМ:

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
```

