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

'''
VBoxManage hostonlyif remove vboxnet0
sudo ip link delete vboxnet0
'''


По ссылке https://github.com/kosogoroff/ansible_lab.git выложен работающий репозиторий с выполненным домашним заданием.

Полный состав лабораторного проекта:
