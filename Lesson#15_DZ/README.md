# Занятие 20.08.2026 "SELinux"

Практика с SELinux

## Цель:

работать с SELinux: диагностировать проблемы и модифицировать политики SELinux для корректной работы приложений, если это требуется;

## 🎯Задания

## 1.  Запустить nginx на нестандартном порту 3-мя разными способами:

( Код стенда получить из репозитория: https://github.com/Nickmob/vagrant_selinux )

- переключатели setsebool;
    
- добавление нестандартного порта в имеющийся тип;
    
- формирование и установка модуля SELinux.


### 🗂 Формат сдачи

README с описанием каждого решения (скриншоты и демонстрация приветствуются).


## 2. Обеспечить работоспособность приложения при включенном selinux.

- развернуть приложенный стенд https://github.com/mbfx/otus-linux-adm/tree/master/selinux_dns_problems ;

- выяснить причину неработоспособности механизма обновления зоны (см. README);

- предложить решение (или решения) для данной проблемы;

- выбрать одно из решений для реализации, предварительно обосновав выбор;

- реализовать выбранное решение и продемонстрировать его работоспособность.

###  🗂 Формат сдачи

README с анализом причины неработоспособности, возможными способами решения и обоснованием выбора одного из них;

исправленный стенд или демонстрация работоспособной системы скриншотами и описанием.

# Решение

## 0. Создание виртуальных машин:

В Host OS REDOS 7.3 более нативным является гипервизор KVM (основан на libvirt, содержащемся в ядре Linux), поэтому проверялись два варианта установки и работы: KVM+Vagrant и virtualbox+Vagrant.
Для работы Vagrant с KVM требуется установка и сборка плагина vagrant-libvirt

Установка и настройка обоих гипервизоров KVM+плагин для Vagrant и virtualbox и пакета Vagrant для них подробно описаны в домашнем задании к занятию 18 по ссылке:

https://github.com/kosogoroff/OTUS_Linux_Admin_course/blob/8968da26701cc42365cb6e8d5a09db1189928d53/Lesson%2318_DZ/README.md 

Там же подробно описаны различие в построении сетей виртуальных машин, в также их связности с ОС хоста и с внешним миром.

Также в связи с недоступностью портала https://portal.cloud.hashicorp.com/ для проверки и работы заранее локально скачаны несколько Vagrant box для различных версий Linux для гипервизоров KVM/libvirt и virtualbox:

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

### 0.1 Создание ВМ в гипервизоре KVM/libvirt

Регистрируем в Vagrant локально скачанный box для Almalinux 9 для libvirt :

```
[admin_insta11@mv334 ~]$ ll /distrib/vagrant_boxes/
итого 8408428
-rwxrwxrwx 1 admin_insta11 admin_insta11  546709438 авг 31 21:50  almalinux-9-9.8.20260810-amd64-libvirt.box
-rwxrwxrwx 1 admin_insta11 admin_insta11  698021674 авг 31 22:18  almalinux-9-9.8.20260810-amd64-virtualbox.box
-rwxrwxrwx 1 admin_insta11 admin_insta11  838235264 сен  1 06:22  bento-ubuntu-22.04-202510.26.0-amd64-virtualbox.box
-rwxrwxrwx 1 admin_insta11 admin_insta11 3216132560 авг 31 23:48  bento-ubuntu-26.04-202606.01.0-amd64-libvirt.box
-rwxrwxrwx 1 admin_insta11 admin_insta11 3311076684 сен  1 06:00  bento-ubuntu-26.04-202606.01.0-amd64-virtualbox.box
-rwxrwxrwx 1 admin_insta11 admin_insta11       2020 сен  1 18:12 'Vagrant boxes.txt'
[admin_insta11@mv334 ~]$
[admin_insta11@mv334 ~]$ vagrant box list
There are no installed boxes! Use `vagrant box add` to add some.
[admin_insta11@mv334 ~]$
[admin_insta11@mv334 ~]$ export BOX_FILE="/distrib/vagrant_boxes/almalinux-9-9.8.20260810-amd64-libvirt.box"
[admin_insta11@mv334 ~]$ export BOX_NAME="almalinux9-stand"
[admin_insta11@mv334 ~]$ vagrant box add --name "$BOX_NAME" "$BOX_FILE"
==> box: Box file was not detected as metadata. Adding it directly...
==> box: Adding box 'almalinux9-stand' (v0) for provider: 
    box: Unpacking necessary files from: file:///distrib/vagrant_boxes/almalinux-9-9.8.20260810-amd64-libvirt.box
==> box: Successfully added box 'almalinux9-stand' (v0) for ''!
[admin_insta11@mv334 ~]$ 
[admin_insta11@mv334 ~]$ vagrant box list
almalinux9-stand (libvirt, 0)
[admin_insta11@mv334 ~]$
```
Для создания и настройки ВМ используем рабочий Vagrantfile из Задания 13 "SELinux" по ссылке https://github.com/Nickmob/vagrant_selinux следующего содержания:

```
MACHINES = {
  :"selinux" => {
              :box_name => "almalinux/9",
              :box_version => "9.4.20240805",
              :cpus => 2,
              :memory => 2048
            }
}

Vagrant.configure("2") do |config|
  MACHINES.each do |boxname, boxconfig|
    config.vm.synced_folder ".", "/vagrant", disabled: true
    config.vm.define boxname do |box|
      box.vm.box = boxconfig[:box_name]
      box.vm.box_version = boxconfig[:box_version]
      box.vm.host_name = boxname.to_s
      box.vm.network "forwarded_port", guest: 4881, host: 4881
      box.vm.provider "virtualbox" do |v|
        v.memory = boxconfig[:memory]
        v.cpus = boxconfig[:cpus]
      end
      box.vm.provision "shell", inline: <<-SHELL
      yum install -y epel-release
      yum install -y nginx
      yum install -y setroubleshoot-server selinux-policy-mls setools-console policycoreutils-python-utils policycoreutils-newrole
      sed -ie 's/:80/:4881/g' /etc/nginx/nginx.conf
      sed -i 's/listen       80;/listen       4881;/' /etc/nginx/nginx.conf
      systemctl start nginx
      systemctl status nginx
      ss -tlpn | grep 4881
SHELL
    end
  end
end
```

Но данный файл создан для работы с virtualbox и для скачивания бокса с облака Hashicorp , поэтому для использования с KVM в нём нужно сделать несколько изменений:
Нужно поменять три вещи: провайдер, сеть и источник бокса.

| В исходнике	| Проблема	| Решение |
|:---------------------|:--------------------------|:-----------------------------|
| box.vm.provider  "virtualbox"	 | У меня libvirt	| Меняем на "libvirt" |
| almalinux/9, версия 9.4.20240805	| Бокс с облака недоступен	| Используем локальный almalinux9-stand |
| forwarded_port	| libvirt не умеет проброс портов как VirtualBox	| Ставим VM на private network с фиксированным IP |


Адаптированный для KVM Vagrantfile для гипервизора kvm/libvirt и использования локально скачаного бокса Vagrant:

```
MACHINES = {
  :"selinux" => {
              :box_name => "almalinux9-stand",
              :cpus => 2,
              :memory => 2048
            }
}

Vagrant.configure("2") do |config|
  MACHINES.each do |boxname, boxconfig|
    config.vm.synced_folder ".", "/vagrant", disabled: true
    config.vm.define boxname do |box|
      box.vm.box = boxconfig[:box_name]
      box.vm.host_name = boxname.to_s

      # libvirt не поддерживает forwarded_port как VirtualBox,
      # поэтому даём VM фиксированный IP в приватной сети
      box.vm.network "private_network", ip: "192.168.56.10"

      box.vm.provider "libvirt" do |v|
        v.memory = boxconfig[:memory]
        v.cpus = boxconfig[:cpus]
        # Папка хранения образов (опционально)
        # v.storage_pool_name = "default"
      end

      box.vm.provision "shell", inline: <<-SHELL
        dnf install -y epel-release
        dnf install -y nginx
        dnf install -y setroubleshoot-server selinux-policy-mls setools-console policycoreutils-python-utils policycoreutils-newrole
        sed -ie 's/:80/:4881/g' /etc/nginx/nginx.conf
        sed -i 's/listen       80;/listen       4881;/' /etc/nginx/nginx.conf
        systemctl start nginx
        systemctl status nginx
        ss -tlpn | grep 4881
      SHELL
    end
  end
end
```

Создаём директорию для нового проекта и создаём в ней вышеупомянутый Vagrantfile для libvirt/KVM (вместо команды 'vagrant init ...') :

```
[admin_insta11@mv334 ~]$ mkdir -p ~/lab-almalinux9-kvm && cd ~/lab-almalinux9-kvm
[admin_insta11@mv334 lab-almalinux9-kvm]$
[admin_insta11@mv334 lab-almalinux9kvm]$ cat > Vagrantfile
MACHINES = {
  :"selinux" => {
              :box_name => "almalinux9-stand",
              :cpus => 2,
              :memory => 2048
            }
}

Vagrant.configure("2") do |config|
  MACHINES.each do |boxname, boxconfig|
    config.vm.synced_folder ".", "/vagrant", disabled: true
    config.vm.define boxname do |box|
      box.vm.box = boxconfig[:box_name]
      box.vm.host_name = boxname.to_s

      # libvirt не поддерживает forwarded_port как VirtualBox,
      # поэтому даём VM фиксированный IP в приватной сети
      box.vm.network "private_network", ip: "192.168.56.10"

      box.vm.provider "libvirt" do |v|
        v.memory = boxconfig[:memory]
        v.cpus = boxconfig[:cpus]
        # Папка хранения образов (опционально)
        # v.storage_pool_name = "default"
      end

      box.vm.provision "shell", inline: <<-SHELL
        dnf install -y epel-release
        dnf install -y nginx
        dnf install -y setroubleshoot-server selinux-policy-mls setools-console policycoreutils-python-utils policycoreutils-newrole
        sed -ie 's/:80/:4881/g' /etc/nginx/nginx.conf
        sed -i 's/listen       80;/listen       4881;/' /etc/nginx/nginx.conf
        systemctl start nginx
        systemctl status nginx
        ss -tlpn | grep 4881
      SHELL
    end
  end
end
[admin_insta11@mv334 lab-almalinux9-kvm]$
```

После этого запускаем ВМ в Vagrant (при первом запуске происходит её provisioning) и подключаемся к ней по SSH:

```
[admin_insta11@mv334 lab-almalinux9-kvm]$ vagrant box list | grep almalinux9-stand
almalinux9-stand (libvirt, 0)
[admin_insta11@mv334 lab-almalinux9-kvm]$ vagrant up --provider=libvirt
Bringing machine 'selinux' up with 'libvirt' provider...
==> selinux: No version detected for almalinux9-stand, using timestamp to watch for modifications. Consider
==> selinux: generating a local metadata for the box with a version to allow better handling.
==> selinux: See https://www.vagrantup.com/docs/boxes/format#box-metadata for further details.
==> selinux: Uploading base box image as volume into Libvirt storage...
==> selinux: Creating image (snapshot of base box volume).
==> selinux: Creating domain with the following settings...
==> selinux:  -- Name:              lab-almalinux9_selinux
==> selinux:  -- Description:       Source: /home/admin_insta11/lab-almalinux9/Vagrantfile
==> selinux:  -- Domain type:       kvm
==> selinux:  -- Cpus:              2
==> selinux:  -- Feature:           acpi
==> selinux:  -- Feature:           apic
==> selinux:  -- Feature:           pae
==> selinux:  -- Clock offset:      utc
==> selinux:  -- Memory:            2048M
==> selinux:  -- Base box:          almalinux9-stand
==> selinux:  -- Storage pool:      default
==> selinux:  -- Image(vda):        /var/lib/libvirt/images/lab-almalinux9_selinux.img, virtio, 20G
==> selinux:  -- Disk driver opts:  cache='default'
==> selinux:  -- Graphics Type:     vnc
==> selinux:  -- Video Type:        cirrus
==> selinux:  -- Video VRAM:        16384
==> selinux:  -- Video 3D accel:    false
==> selinux:  -- Keymap:            en-us
==> selinux:  -- TPM Backend:       passthrough
==> selinux:  -- INPUT:             type=mouse, bus=ps2
==> selinux: Creating shared folders metadata...
==> selinux: Starting domain.
==> selinux: Domain launching with graphics connection settings...
==> selinux:  -- Graphics Port:      5901
==> selinux:  -- Graphics IP:        127.0.0.1
==> selinux:  -- Graphics Password:  Not defined
==> selinux:  -- Graphics Websocket: 5700
==> selinux: Waiting for domain to get an IP address...
==> selinux: Waiting for machine to boot. This may take a few minutes...
    selinux: SSH address: 192.168.121.206:22
    selinux: SSH username: vagrant
    selinux: SSH auth method: private key
    selinux: 
    selinux: Vagrant insecure key detected. Vagrant will automatically replace
    selinux: this with a newly generated keypair for better security.
    selinux: 
    selinux: Inserting generated public key within guest...
    selinux: Removing insecure key from the guest if it's present...
    selinux: Key inserted! Disconnecting and reconnecting using new SSH key...
==> selinux: Machine booted and ready!
==> selinux: Setting hostname...
==> selinux: Configuring and enabling network interfaces...
==> selinux: Running provisioner: shell...
    selinux: Running: inline script
    selinux: AlmaLinux 9 - AppStream                         4.3 MB/s |  23 MB     00:05
    selinux: AlmaLinux 9 - BaseOS                            6.5 MB/s |  31 MB     00:04
    selinux: AlmaLinux 9 - Extras                             31 kB/s |  22 kB     00:00
    selinux: Dependencies resolved.
    selinux: ================================================================================
    selinux:  Package               Architecture    Version            Repository       Size
    selinux: ================================================================================
    selinux: Installing:
    selinux:  epel-release          noarch          9-9.el9            extras           18 k
    selinux: 
    selinux: Transaction Summary
    selinux: ================================================================================
    selinux: Install  1 Package
    selinux: 
    selinux: Total download size: 18 k
    selinux: Installed size: 26 k
    selinux: Downloading Packages:
    selinux: epel-release-9-9.el9.noarch.rpm                 173 kB/s |  18 kB     00:00
    selinux: --------------------------------------------------------------------------------
    selinux: Total                                            26 kB/s |  18 kB     00:00
    selinux: Running transaction check
    selinux: Transaction check succeeded.
    selinux: Running transaction test
    selinux: Transaction test succeeded.
    selinux: Running transaction
    selinux:   Preparing        :                                                        1/1
    selinux:   Installing       : epel-release-9-9.el9.noarch                            1/1
    selinux:   Running scriptlet: epel-release-9-9.el9.noarch                            1/1
    selinux: Many EPEL packages require the CodeReady Builder (CRB) repository.
    selinux: It is recommended that you run /usr/bin/crb enable to enable the CRB repository.
    selinux: 
    selinux:   Verifying        : epel-release-9-9.el9.noarch                            1/1
    selinux: 
    selinux: Installed:
    selinux:   epel-release-9-9.el9.noarch
    selinux: 
    selinux: Complete!
    selinux: Extra Packages for Enterprise Linux 9 - x86_64  1.9 MB/s |  20 MB     00:10
    selinux: Extra Packages for Enterprise Linux 9 openh264  1.4 kB/s | 2.5 kB     00:01
    selinux: Dependencies resolved.
    selinux: ================================================================================
    selinux:  Package                Arch    Version                        Repository  Size
    selinux: ================================================================================
    selinux: Installing:
    selinux:  nginx                  x86_64  2:1.20.1-28.el9_8.5.alma.1     appstream   38 k
    selinux: Installing dependencies:
    selinux:  almalinux-logos-httpd  noarch  90.7-1.el9                     appstream   18 k
    selinux:  nginx-core             x86_64  2:1.20.1-28.el9_8.5.alma.1     appstream  569 k
    selinux:  nginx-filesystem       noarch  2:1.20.1-28.el9_8.5.alma.1     appstream   11 k
    selinux: 
    selinux: Transaction Summary
    selinux: ================================================================================
    selinux: Install  4 Packages
    selinux: 
    selinux: Total download size: 635 k
    selinux: Installed size: 1.8 M
    selinux: Downloading Packages:
    selinux: (1/4): almalinux-logos-httpd-90.7-1.el9.noarch. 184 kB/s |  18 kB     00:00
    selinux: (2/4): nginx-1.20.1-28.el9_8.5.alma.1.x86_64.rp 376 kB/s |  38 kB     00:00
    selinux: (3/4): nginx-filesystem-1.20.1-28.el9_8.5.alma. 368 kB/s |  11 kB     00:00
    selinux: (4/4): nginx-core-1.20.1-28.el9_8.5.alma.1.x86_ 2.2 MB/s | 569 kB     00:00
    selinux: --------------------------------------------------------------------------------
    selinux: Total                                           670 kB/s | 635 kB     00:00
    selinux: Running transaction check
    selinux: Transaction check succeeded.
    selinux: Running transaction test
    selinux: Transaction test succeeded.
    selinux: Running transaction
    selinux:   Preparing        :                                                        1/1
    selinux:   Running scriptlet: nginx-filesystem-2:1.20.1-28.el9_8.5.alma.1.noarch     1/4
    selinux:   Installing       : nginx-filesystem-2:1.20.1-28.el9_8.5.alma.1.noarch     1/4
    selinux:   Installing       : nginx-core-2:1.20.1-28.el9_8.5.alma.1.x86_64           2/4
    selinux:   Installing       : almalinux-logos-httpd-90.7-1.el9.noarch                3/4
    selinux:   Installing       : nginx-2:1.20.1-28.el9_8.5.alma.1.x86_64                4/4
    selinux:   Running scriptlet: nginx-2:1.20.1-28.el9_8.5.alma.1.x86_64                4/4
    selinux:   Verifying        : almalinux-logos-httpd-90.7-1.el9.noarch                1/4
    selinux:   Verifying        : nginx-2:1.20.1-28.el9_8.5.alma.1.x86_64                2/4
    selinux:   Verifying        : nginx-core-2:1.20.1-28.el9_8.5.alma.1.x86_64           3/4
    selinux:   Verifying        : nginx-filesystem-2:1.20.1-28.el9_8.5.alma.1.noarch     4/4
    selinux: 
    selinux: Installed:
    selinux:   almalinux-logos-httpd-90.7-1.el9.noarch
    selinux:   nginx-2:1.20.1-28.el9_8.5.alma.1.x86_64
    selinux:   nginx-core-2:1.20.1-28.el9_8.5.alma.1.x86_64
    selinux:   nginx-filesystem-2:1.20.1-28.el9_8.5.alma.1.noarch
    selinux: 
    selinux: Complete!
    selinux: Last metadata expiration check: 0:00:06 ago on Wed 02 Sep 2026 05:36:13 PM UTC.
    selinux: Dependencies resolved.
    selinux: ================================================================================
    selinux:  Package                        Arch     Version              Repository   Size
    selinux: ================================================================================
    selinux: Installing:
    selinux:  policycoreutils-newrole        x86_64   3.6-5.el9            baseos       23 k
    selinux:  policycoreutils-python-utils   noarch   3.6-5.el9            appstream    69 k
    selinux:  selinux-policy-mls             noarch   38.1.75-2.el9_8      baseos      4.3 M
    selinux:  setools-console                x86_64   4.4.4-1.el9          baseos       46 k
    selinux:  setroubleshoot-server          x86_64   3.3.35-2.el9         appstream   326 k
    selinux: Installing dependencies:
    selinux:  initscripts-service            noarch   10.11.8-4.el9        baseos       11 k
    selinux:  mcstrans                       x86_64   3.6-1.el9            baseos      141 k
    selinux:  python3-dasbus                 noarch   1.7-1.el9            appstream    88 k
    selinux:  python3-libxml2                x86_64   2.9.13-14.el9_8.2    baseos      225 k
    selinux:  setroubleshoot-plugins         noarch   3.3.14-4.el9         appstream   324 k
    selinux: 
    selinux: Transaction Summary
    selinux: ================================================================================
    selinux: Install  10 Packages
    selinux: 
    selinux: Total download size: 5.5 M
    selinux: Installed size: 16 M
    selinux: Downloading Packages:
    selinux: (1/10): policycoreutils-python-utils-3.6-5.el9. 568 kB/s |  69 kB     00:00
    selinux: (2/10): python3-dasbus-1.7-1.el9.noarch.rpm     673 kB/s |  88 kB     00:00
    selinux: (3/10): initscripts-service-10.11.8-4.el9.noarc 277 kB/s |  11 kB     00:00
    selinux: (4/10): setroubleshoot-plugins-3.3.14-4.el9.noa 1.7 MB/s | 324 kB     00:00
    selinux: (5/10): policycoreutils-newrole-3.6-5.el9.x86_6 548 kB/s |  23 kB     00:00
    selinux: (6/10): mcstrans-3.6-1.el9.x86_64.rpm           2.1 MB/s | 141 kB     00:00
    selinux: (7/10): python3-libxml2-2.9.13-14.el9_8.2.x86_6 2.2 MB/s | 225 kB     00:00
    selinux: (8/10): setools-console-4.4.4-1.el9.x86_64.rpm  1.0 MB/s |  46 kB     00:00
    selinux: (9/10): setroubleshoot-server-3.3.35-2.el9.x86_ 1.2 MB/s | 326 kB     00:00
    selinux: (10/10): selinux-policy-mls-38.1.75-2.el9_8.noa 2.9 MB/s | 4.3 MB     00:01
    selinux: --------------------------------------------------------------------------------
    selinux: Total                                           1.3 MB/s | 5.5 MB     00:04
    selinux: Running transaction check
    selinux: Transaction check succeeded.
    selinux: Running transaction test
    selinux: Transaction test succeeded.
    selinux: Running transaction
    selinux:   Running scriptlet: selinux-policy-mls-38.1.75-2.el9_8.noarch              1/1
    selinux:   Preparing        :                                                        1/1
    selinux:   Installing       : python3-libxml2-2.9.13-14.el9_8.2.x86_64              1/10
    selinux:   Installing       : policycoreutils-newrole-3.6-5.el9.x86_64              2/10
    selinux:   Installing       : mcstrans-3.6-1.el9.x86_64                             3/10
    selinux:   Running scriptlet: mcstrans-3.6-1.el9.x86_64                             3/10
    selinux:   Installing       : initscripts-service-10.11.8-4.el9.noarch              4/10
    selinux:   Installing       : python3-dasbus-1.7-1.el9.noarch                       5/10
    selinux:   Installing       : policycoreutils-python-utils-3.6-5.el9.noarch         6/10
    selinux:   Installing       : setroubleshoot-plugins-3.3.14-4.el9.noarch            7/10
    selinux:   Running scriptlet: setroubleshoot-server-3.3.35-2.el9.x86_64             8/10
    selinux:   Installing       : setroubleshoot-server-3.3.35-2.el9.x86_64             8/10
    selinux:   Running scriptlet: setroubleshoot-server-3.3.35-2.el9.x86_64             8/10
    selinux:   Running scriptlet: selinux-policy-mls-38.1.75-2.el9_8.noarch             9/10
    selinux:   Installing       : selinux-policy-mls-38.1.75-2.el9_8.noarch             9/10
    selinux:   Running scriptlet: selinux-policy-mls-38.1.75-2.el9_8.noarch             9/10
    selinux:   Installing       : setools-console-4.4.4-1.el9.x86_64                   10/10
    selinux:   Running scriptlet: selinux-policy-mls-38.1.75-2.el9_8.noarch            10/10
    selinux:   Running scriptlet: setools-console-4.4.4-1.el9.x86_64                   10/10
    selinux:   Verifying        : policycoreutils-python-utils-3.6-5.el9.noarch         1/10
    selinux:   Verifying        : python3-dasbus-1.7-1.el9.noarch                       2/10
    selinux:   Verifying        : setroubleshoot-plugins-3.3.14-4.el9.noarch            3/10
    selinux:   Verifying        : setroubleshoot-server-3.3.35-2.el9.x86_64             4/10
    selinux:   Verifying        : initscripts-service-10.11.8-4.el9.noarch              5/10
    selinux:   Verifying        : mcstrans-3.6-1.el9.x86_64                             6/10
    selinux:   Verifying        : policycoreutils-newrole-3.6-5.el9.x86_64              7/10
    selinux:   Verifying        : python3-libxml2-2.9.13-14.el9_8.2.x86_64              8/10
    selinux:   Verifying        : selinux-policy-mls-38.1.75-2.el9_8.noarch             9/10
    selinux:   Verifying        : setools-console-4.4.4-1.el9.x86_64                   10/10
    selinux: 
    selinux: Installed:
    selinux:   initscripts-service-10.11.8-4.el9.noarch
    selinux:   mcstrans-3.6-1.el9.x86_64
    selinux:   policycoreutils-newrole-3.6-5.el9.x86_64
    selinux:   policycoreutils-python-utils-3.6-5.el9.noarch
    selinux:   python3-dasbus-1.7-1.el9.noarch
    selinux:   python3-libxml2-2.9.13-14.el9_8.2.x86_64
    selinux:   selinux-policy-mls-38.1.75-2.el9_8.noarch
    selinux:   setools-console-4.4.4-1.el9.x86_64
    selinux:   setroubleshoot-plugins-3.3.14-4.el9.noarch
    selinux:   setroubleshoot-server-3.3.35-2.el9.x86_64
    selinux: 
    selinux: Complete!
    selinux: Job for nginx.service failed because the control process exited with error code.
    selinux: See "systemctl status nginx.service" and "journalctl -xeu nginx.service" for details.
    selinux: × nginx.service - The nginx HTTP and reverse proxy server
    selinux:      Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; preset: disabled)
    selinux:      Active: failed (Result: exit-code) since Wed 2026-09-02 17:36:36 UTC; 17ms ago
    selinux:     Process: 6298 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
    selinux:     Process: 6299 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=1/FAILURE)
    selinux:         CPU: 19ms
    selinux: 
    selinux: Sep 02 17:36:36 selinux systemd[1]: Starting The nginx HTTP and reverse proxy server...
    selinux: Sep 02 17:36:36 selinux nginx[6299]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
    selinux: Sep 02 17:36:36 selinux nginx[6299]: nginx: [emerg] bind() to 0.0.0.0:4881 failed (13: Permission denied)
    selinux: Sep 02 17:36:36 selinux nginx[6299]: nginx: configuration file /etc/nginx/nginx.conf test failed
    selinux: Sep 02 17:36:36 selinux systemd[1]: nginx.service: Control process exited, code=exited, status=1/FAILURE
    selinux: Sep 02 17:36:36 selinux systemd[1]: nginx.service: Failed with result 'exit-code'.
    selinux: Sep 02 17:36:36 selinux systemd[1]: Failed to start The nginx HTTP and reverse proxy server.
The SSH command responded with a non-zero exit status. Vagrant
assumes that this means the command failed. The output for this command
should be in the log above. Please read the output to determine what
went wrong.
[admin_insta11@mv334 lab-almalinux9-kvm]$ vagrant ssh -c "systemctl status nginx"
× nginx.service - The nginx HTTP and reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; preset: disabled)
     Active: failed (Result: exit-code) since Wed 2026-09-02 17:36:36 UTC; 53s ago
    Process: 6298 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
    Process: 6299 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=1/FAILURE)
        CPU: 19ms
[admin_insta11@mv334 lab-almalinux9-kvm]$ 
[admin_insta11@mv334 lab-almalinux9-kvm]$ vagrant status
Current machine states:

selinux                   running (libvirt)

The Libvirt domain is running. To stop this machine, you can run
`vagrant halt`. To destroy the machine, you can run `vagrant destroy`.
[admin_insta11@mv334 lab-almalinux9-kvm]$ vagrant ssh 
Last login: Wed Sep  2 17:37:30 2026 from 192.168.121.1
[vagrant@selinux ~]$
```

Доступ к WEB-странице запущенного сервера nginx с хоста будет осуществляться командой:

```
curl http://192.168.56.10:4881
```

### 0.2 Создание ВМ в гипервизоре virtualbox

Добавляем Бокс ВМ в реестр vagrant:

```
[admin_insta11@mv334 ~]$ ll /distrib/vagrant_boxes/
итого 8408428
-rwxrwxrwx 1 admin_insta11 admin_insta11  546709438 авг 31 21:50  almalinux-9-9.8.20260810-amd64-libvirt.box
-rwxrwxrwx 1 admin_insta11 admin_insta11  698021674 авг 31 22:18  almalinux-9-9.8.20260810-amd64-virtualbox.box
-rwxrwxrwx 1 admin_insta11 admin_insta11  838235264 сен  1 06:22  bento-ubuntu-22.04-202510.26.0-amd64-virtualbox.box
-rwxrwxrwx 1 admin_insta11 admin_insta11 3216132560 авг 31 23:48  bento-ubuntu-26.04-202606.01.0-amd64-libvirt.box
-rwxrwxrwx 1 admin_insta11 admin_insta11 3311076684 сен  1 06:00  bento-ubuntu-26.04-202606.01.0-amd64-virtualbox.box
-rwxrwxrwx 1 admin_insta11 admin_insta11       2020 сен  1 18:12 'Vagrant boxes.txt'
[admin_insta11@mv334 ~]$ export BOX_FILE="almalinux-9-9.8.20260810-amd64-virtualbox.box"
[admin_insta11@mv334 ~]$ export BOX_FILE="/distrib/vagrant_boxes/almalinux-9-9.8.20260810-amd64-virtualbox.box"
[admin_insta11@mv334 ~]$ vagrant box add --name "$BOX_NAME" "$BOX_FILE"
==> box: Box file was not detected as metadata. Adding it directly...
==> box: Adding box 'almalinux9-stand-vb' (v0) for provider: 
    box: Unpacking necessary files from: file:///distrib/vagrant_boxes/almalinux-9-9.8.20260810-amd64-virtualbox.box
==> box: Successfully added box 'almalinux9-stand-vb' (v0) for ''!
[admin_insta11@mv334 ~]$ 
[admin_insta11@mv334 ~]$ 
[admin_insta11@mv334 ~]$ vagrant box list
almalinux9-stand    (libvirt, 0)
almalinux9-stand-vb (virtualbox, 0)
[admin_insta11@mv334 ~]$
```

Создаём проект и Vagrantfile для новой ВМ. При этом делаем в исходном Vagrantfile для virtualbox изменения для использования локально установленного бокса ВМ (вместо скачивания его из облака):
- строку ':box_name => "almalinux/9"' заменяем на строку ':box_name => "almalinux9-stand-vb"' с именем локально установленного бокса из команды 'vagrant box add';
- убираем точную версию и ссылку на неё, так как локально установленная точная версия немного отличается.

Исправленный Vagrantfile для virtualbox приведён ниже:
```
[admin_insta11@mv334 ~]$ mkdir -p ~/lab-almalinux9-virtualbox && cd ~/lab-almalinux9-virtualbox
[admin_insta11@mv334 ~]$
[admin_insta11@mv334 lab-almalinux9-virtualbox]$ cat > Vagrantfile
MACHINES = {
  :"selinux" => {
#              :box_name => "almalinux/9",       # <-- меняем на имя локально установленного бокса из vagrant box add
#              :box_version => "9.4.20240805",   # <-- убираем точную версию, так как локальная отличается
              :box_name => "almalinux9-stand-vb",
              :cpus => 2,
              :memory => 2048
            }
}

Vagrant.configure("2") do |config|
  MACHINES.each do |boxname, boxconfig|
    config.vm.synced_folder ".", "/vagrant", disabled: true
    config.vm.define boxname do |box|
      box.vm.box = boxconfig[:box_name]
#      box.vm.box_version = boxconfig[:box_version]   # <--  убираем ссылку на точную версию в хэше MACHINES
      box.vm.host_name = boxname.to_s
      box.vm.network "forwarded_port", guest: 4881, host: 4881
      box.vm.provider "virtualbox" do |v|
        v.memory = boxconfig[:memory]
        v.cpus = boxconfig[:cpus]
      end
      box.vm.provision "shell", inline: <<-SHELL
      yum install -y epel-release
      yum install -y nginx
      yum install -y setroubleshoot-server selinux-policy-mls setools-console policycoreutils-python-utils policycoreutils-newrole
      sed -ie 's/:80/:4881/g' /etc/nginx/nginx.conf
      sed -i 's/listen       80;/listen       4881;/' /etc/nginx/nginx.conf
      systemctl start nginx
      systemctl status nginx
      ss -tlpn | grep 4881
SHELL
    end
  end
end

```

Создаём и запускаем ВМ для virtualbox. **ВАЖНО:** Для запуска virtualbox необходимо выгрузить драйверы ядра для libvirt/kvm - два гипервизора
не могут быть одновременно запущены на одном хосте, при запуске ВМ для virtualbox выдаётся ошибка:

```
[admin_insta11@mv334 lab-almalinux9-virtualbox]$ vagrant up
Bringing machine 'selinux' up with 'virtualbox' provider...
==> selinux: Importing base box 'almalinux9-stand-vb'...
==> selinux: Matching MAC address for NAT networking...
==> selinux: Setting the name of the VM: lab-almalinux9-virtualbox_selinux_1788544356267_45854
==> selinux: Clearing any previously set network interfaces...
==> selinux: Preparing network interfaces based on configuration...
    selinux: Adapter 1: nat
==> selinux: Forwarding ports...
    selinux: 4881 (guest) => 4881 (host) (adapter 1)
    selinux: 22 (guest) => 2222 (host) (adapter 1)
==> selinux: Running 'pre-boot' VM customizations...
==> selinux: Booting VM...
There was an error while executing `VBoxManage`, a CLI used by Vagrant
for controlling VirtualBox. The command and stderr is shown below.

Command: ["startvm", "4141b4ad-07d8-4f90-8be7-d215c6d2db39", "--type", "headless"]

Stderr: VBoxManage: error: VT-x is being used by another hypervisor (VERR_VMX_IN_VMX_ROOT_MODE).
VBoxManage: error: VirtualBox can't operate in VMX root mode. Please disable the KVM kernel extension, recompile your kernel and reboot (VERR_VMX_IN_VMX_ROOT_MODE)
VBoxManage: error: Details: code NS_ERROR_FAILURE (0x80004005), component ConsoleWrap, interface IConsole

[admin_insta11@mv334 lab-almalinux9-virtualbox]$
```

Поэтому перед запуском ВМ для virtualbox сначала ВРЕМЕННО останавливаем виртуальные машины, запущенные в KVM, сам гипервизор KVM и его драйвера ядра:

```
[admin_insta11@mv334 lab-almalinux9-kvm]$ vagrant halt
==> selinux: Attempting graceful shutdown of VM...
[admin_insta11@mv334 lab-almalinux9-kvm]$ 
[admin_insta11@mv334 lab-almalinux9-kvm]$ 
[admin_insta11@mv334 lab-almalinux9-kvm]$ sudo virsh list
[sudo] пароль для admin_insta11: 
 ID   Имя   Состояние
-----------------------

[admin_insta11@mv334 lab-almalinux9-kvm]$ sudo systemctl stop libvirtd.socket libvirtd-ro.socket libvirtd-admin.socket libvirtd.service
[admin_insta11@mv334 lab-almalinux9-kvm]$
[admin_insta11@mv334 lab-almalinux9-kvm]$ lsmod | grep kvm
kvm_intel             389120  0
kvm                  1118208  1 kvm_intel
irqbypass              16384  1 kvm
[admin_insta11@mv334 lab-almalinux9-kvm]$
[admin_insta11@mv334 lab-almalinux9-kvm]$ sudo modprobe -r kvm_intel
[admin_insta11@mv334 lab-almalinux9-kvm]$
[admin_insta11@mv334 lab-almalinux9-kvm]$ lsmod | grep kvm
[admin_insta11@mv334 lab-almalinux9-kvm]$ 
```

А затем запускаем ВМ для virtualbox:

```
[admin_insta11@mv334 lab-almalinux9-kvm]$ cd ..
[admin_insta11@mv334 ~]$ cd lab-almalinux9-virtualbox/
[admin_insta11@mv334 lab-almalinux9-virtualbox]$ vagrant up
Bringing machine 'selinux' up with 'virtualbox' provider...
==> selinux: Clearing any previously set forwarded ports...
==> selinux: Clearing any previously set network interfaces...
==> selinux: Preparing network interfaces based on configuration...
    selinux: Adapter 1: nat
==> selinux: Forwarding ports...
    selinux: 4881 (guest) => 4881 (host) (adapter 1)
    selinux: 22 (guest) => 2222 (host) (adapter 1)
==> selinux: Running 'pre-boot' VM customizations...
==> selinux: Booting VM...
==> selinux: Waiting for machine to boot. This may take a few minutes...
    selinux: SSH address: 127.0.0.1:2222
    selinux: SSH username: vagrant
    selinux: SSH auth method: private key
==> selinux: Machine booted and ready!
==> selinux: Checking for guest additions in VM...
    selinux: The guest additions on this VM do not match the installed version of
    selinux: VirtualBox! In most cases this is fine, but in rare cases it can
    selinux: prevent things such as shared folders from working properly. If you see
    selinux: shared folder errors, please make sure the guest additions within the
    selinux: virtual machine match the version of VirtualBox you have installed on
    selinux: your host and reload your VM.
    selinux: 
    selinux: Guest Additions Version: 7.2.16
    selinux: VirtualBox Version: 7.1
==> selinux: Setting hostname...
==> selinux: Machine already provisioned. Run `vagrant provision` or use the `--provision`
==> selinux: flag to force provisioning. Provisioners marked to run always will still run.
[admin_insta11@mv334 lab-almalinux9-virtualbox]$ 
[admin_insta11@mv334 lab-almalinux9-virtualbox]$ vagrant ssh
Last login: Fri Sep  4 18:08:48 2026 from 10.0.2.2
[vagrant@selinux ~]$
```

Доступ к WEB-странице запущенного сервера nginx с хоста будет осуществляться командой:

```
curl http://localhost:4881
```

## 1. Запуск nginx на нестандартном порту 3-мя разными способами

В обеих созданных ВМ созданы одинаковые настройки и одинаковая лабораторная конфигурация, поэтому далее выполнение лабораторной
работы в созданной ВМ в обоих гипервизорах не различаются. Вывод приводится на примере запущенной ВМ в KVM/libvirt:

```
[admin_insta11@mv334 lab-almalinux9-kvm]$ vagrant up
Bringing machine 'selinux' up with 'libvirt' provider...
==> selinux: Creating shared folders metadata...
==> selinux: Starting domain.
==> selinux: Domain launching with graphics connection settings...
==> selinux:  -- Graphics Port:      5901
==> selinux:  -- Graphics IP:        127.0.0.1
==> selinux:  -- Graphics Password:  Not defined
==> selinux:  -- Graphics Websocket: 5700
==> selinux: Waiting for domain to get an IP address...
==> selinux: Waiting for machine to boot. This may take a few minutes...
    selinux: SSH address: 192.168.121.226:22
    selinux: SSH username: vagrant
    selinux: SSH auth method: private key
    selinux: Warning: Connection refused. Retrying...
==> selinux: Machine booted and ready!
==> selinux: Machine already provisioned. Run `vagrant provision` or use the `--provision`
==> selinux: flag to force provisioning. Provisioners marked to run always will still run.
[admin_insta11@mv334 lab-almalinux9-kvm]$ 
[admin_insta11@mv334 lab-almalinux9-kvm]$ 
```

**3.1 Разрешим в SELinux работу nginx на порту TCP 4881 c помощью переключателей setsebool**


Просматриваем лог SELinux и результат просмотра отправляем в утилиту audit2why, которая на основе анализа лога определяет причину и даёт рецепт по поводу включения необходимого разрешающего бинарного флага, включаем флаг разрешающей политики SELinux. После этого сервер nginx успешно запускается и начинает слушать нестандартный порт 4881:

```
[root@selinux ~]# systemctl status nginx
× nginx.service - The nginx HTTP and reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; preset: disabled)
     Active: failed (Result: exit-code) since Thu 2026-09-10 17:43:35 UTC; 9min ago
    Process: 2479 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
    Process: 2480 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=1/FAILURE)
        CPU: 18ms

Sep 10 17:43:35 selinux systemd[1]: Starting The nginx HTTP and reverse proxy server...
Sep 10 17:43:35 selinux nginx[2480]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
Sep 10 17:43:35 selinux nginx[2480]: nginx: [emerg] bind() to 0.0.0.0:4881 failed (13: Permission denied)
Sep 10 17:43:35 selinux nginx[2480]: nginx: configuration file /etc/nginx/nginx.conf test failed
Sep 10 17:43:35 selinux systemd[1]: nginx.service: Control process exited, code=exited, status=1/FAILURE
Sep 10 17:43:35 selinux systemd[1]: nginx.service: Failed with result 'exit-code'.
Sep 10 17:43:35 selinux systemd[1]: Failed to start The nginx HTTP and reverse proxy server.
[root@selinux ~]# 
[root@selinux ~]# grep nginx /var/log/audit/audit.log
type=ADD_GROUP msg=audit(1788627429.417:765): pid=5601 uid=0 auid=1000 ses=3 subj=unconfined_u:unconfined_r:groupadd_t:s0-s0:c0.c1023 msg='op=add-group id=994 exe="/usr/sbin/groupadd" hostname=? addr=? terminal=? res=success'UID="root" AUID="vagrant" ID="nginx"
type=GRP_MGMT msg=audit(1788627429.423:766): pid=5601 uid=0 auid=1000 ses=3 subj=unconfined_u:unconfined_r:groupadd_t:s0-s0:c0.c1023 msg='op=add-shadow-group id=994 exe="/usr/sbin/groupadd" hostname=? addr=? terminal=? res=success'UID="root" AUID="vagrant" ID="nginx"
type=ADD_USER msg=audit(1788627429.471:767): pid=5609 uid=0 auid=1000 ses=3 subj=unconfined_u:unconfined_r:useradd_t:s0-s0:c0.c1023 msg='op=add-user acct="nginx" exe="/usr/sbin/useradd" hostname=? addr=? terminal=? res=success'UID="root" AUID="vagrant"
type=SOFTWARE_UPDATE msg=audit(1788627430.153:796): pid=5578 uid=0 auid=1000 ses=3 subj=unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023 msg='op=install sw="nginx-filesystem-2:1.20.1-28.el9_8.5.alma.1.noarch" sw_type=rpm key_enforce=0 gpg_res=1 root_dir="/" comm="dnf" exe="/usr/bin/python3.9" hostname=? addr=? terminal=? res=success'UID="root" AUID="vagrant"
type=SOFTWARE_UPDATE msg=audit(1788627430.153:797): pid=5578 uid=0 auid=1000 ses=3 subj=unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023 msg='op=install sw="nginx-core-2:1.20.1-28.el9_8.5.alma.1.x86_64" sw_type=rpm key_enforce=0 gpg_res=1 root_dir="/" comm="dnf" exe="/usr/bin/python3.9" hostname=? addr=? terminal=? res=success'UID="root" AUID="vagrant"
type=SOFTWARE_UPDATE msg=audit(1788627430.153:799): pid=5578 uid=0 auid=1000 ses=3 subj=unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023 msg='op=install sw="nginx-2:1.20.1-28.el9_8.5.alma.1.x86_64" sw_type=rpm key_enforce=0 gpg_res=1 root_dir="/" comm="dnf" exe="/usr/bin/python3.9" hostname=? addr=? terminal=? res=success'UID="root" AUID="vagrant"
type=AVC msg=audit(1788627446.725:844): avc:  denied  { name_bind } for  pid=6289 comm="nginx" src=4881 scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0
type=SYSCALL msg=audit(1788627446.725:844): arch=c000003e syscall=49 success=no exit=-13 a0=6 a1=5602bb8b1870 a2=10 a3=7ffee2aaa300 items=0 ppid=1 pid=6289 auid=4294967295 uid=0 gid=0 euid=0 suid=0 fsuid=0 egid=0 sgid=0 fsgid=0 tty=(none) ses=4294967295 comm="nginx" exe="/usr/sbin/nginx" subj=system_u:system_r:httpd_t:s0 key=(null)ARCH=x86_64 SYSCALL=bind AUID="unset" UID="root" GID="root" EUID="root" SUID="root" FSUID="root" EGID="root" SGID="root" FSGID="root"
type=SERVICE_START msg=audit(1788627446.727:845): pid=1 uid=0 auid=4294967295 ses=4294967295 subj=system_u:system_r:init_t:s0 msg='unit=nginx comm="systemd" exe="/usr/lib/systemd/systemd" hostname=? addr=? terminal=? res=failed'UID="root" AUID="unset"
type=AVC msg=audit(1789062215.342:305): avc:  denied  { name_bind } for  pid=2480 comm="nginx" src=4881 scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0
type=SYSCALL msg=audit(1789062215.342:305): arch=c000003e syscall=49 success=no exit=-13 a0=6 a1=564b9f4a8870 a2=10 a3=7ffc6c6e7d00 items=0 ppid=1 pid=2480 auid=4294967295 uid=0 gid=0 euid=0 suid=0 fsuid=0 egid=0 sgid=0 fsgid=0 tty=(none) ses=4294967295 comm="nginx" exe="/usr/sbin/nginx" subj=system_u:system_r:httpd_t:s0 key=(null)ARCH=x86_64 SYSCALL=bind AUID="unset" UID="root" GID="root" EUID="root" SUID="root" FSUID="root" EGID="root" SGID="root" FSGID="root"
type=SERVICE_START msg=audit(1789062215.345:306): pid=1 uid=0 auid=4294967295 ses=4294967295 subj=system_u:system_r:init_t:s0 msg='unit=nginx comm="systemd" exe="/usr/lib/systemd/systemd" hostname=? addr=? terminal=? res=failed'UID="root" AUID="unset"
[root@selinux ~]# 
[root@selinux ~]# grep 1789062215.342:305 /var/log/audit/audit.log
type=AVC msg=audit(1789062215.342:305): avc:  denied  { name_bind } for  pid=2480 comm="nginx" src=4881 scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0
type=SYSCALL msg=audit(1789062215.342:305): arch=c000003e syscall=49 success=no exit=-13 a0=6 a1=564b9f4a8870 a2=10 a3=7ffc6c6e7d00 items=0 ppid=1 pid=2480 auid=4294967295 uid=0 gid=0 euid=0 suid=0 fsuid=0 egid=0 sgid=0 fsgid=0 tty=(none) ses=4294967295 comm="nginx" exe="/usr/sbin/nginx" subj=system_u:system_r:httpd_t:s0 key=(null)ARCH=x86_64 SYSCALL=bind AUID="unset" UID="root" GID="root" EUID="root" SUID="root" FSUID="root" EGID="root" SGID="root" FSGID="root"
type=PROCTITLE msg=audit(1789062215.342:305): proctitle=2F7573722F7362696E2F6E67696E78002D74
[root@selinux ~]# 
[root@selinux ~]# 
[root@selinux ~]# grep 1789062215.342:305 /var/log/audit/audit.log | audit2why
type=AVC msg=audit(1789062215.342:305): avc:  denied  { name_bind } for  pid=2480 comm="nginx" src=4881 scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0

	Was caused by:
	The boolean nis_enabled was set incorrectly. 
	Description:
	Allow nis to enabled

	Allow access by executing:
	# setsebool -P nis_enabled 1
[root@selinux ~]# 
[root@selinux ~]# setsebool -P nis_enabled 1
[root@selinux ~]# 
[root@selinux ~]# systemctl restart nginx
[root@selinux ~]# 
[root@selinux ~]# systemctl status nginx
● nginx.service - The nginx HTTP and reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; preset: disabled)
     Active: active (running) since Thu 2026-09-10 17:56:54 UTC; 7s ago
    Process: 2539 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
    Process: 2540 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=0/SUCCESS)
    Process: 2541 ExecStart=/usr/sbin/nginx (code=exited, status=0/SUCCESS)
   Main PID: 2542 (nginx)
      Tasks: 3 (limit: 12052)
     Memory: 3.1M (peak: 3.2M)
        CPU: 38ms
     CGroup: /system.slice/nginx.service
             ├─2542 "nginx: master process /usr/sbin/nginx"
             ├─2543 "nginx: worker process"
             └─2544 "nginx: worker process"

Sep 10 17:56:54 selinux systemd[1]: Starting The nginx HTTP and reverse proxy server...
Sep 10 17:56:54 selinux nginx[2540]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
Sep 10 17:56:54 selinux nginx[2540]: nginx: configuration file /etc/nginx/nginx.conf test is successful
Sep 10 17:56:54 selinux systemd[1]: Started The nginx HTTP and reverse proxy server.
[root@selinux ~]# 
[root@selinux ~]# netstat -an | grep -i listen
-bash: netstat: command not found
[root@selinux ~]# ss -tn | grep -i listen
[root@selinux ~]# ss -tn
State                   Recv-Q                   Send-Q                                        Local Address:Port                                        Peer Address:Port                    
ESTAB                   0                        0                                           192.168.121.226:22                                         192.168.121.1:55764                   
[root@selinux ~]# ss -tnlp
State        Recv-Q       Send-Q              Local Address:Port               Peer Address:Port       Process                                                                                
LISTEN       0            128                       0.0.0.0:22                      0.0.0.0:*           users:(("sshd",pid=1002,fd=7))                                                        
LISTEN       0            4096                      0.0.0.0:111                     0.0.0.0:*           users:(("rpcbind",pid=622,fd=4),("systemd",pid=1,fd=31))                              
LISTEN       0            511                       0.0.0.0:4881                    0.0.0.0:*           users:(("nginx",pid=2544,fd=6),("nginx",pid=2543,fd=6),("nginx",pid=2542,fd=6))       
LISTEN       0            128                          [::]:22                         [::]:*           users:(("sshd",pid=1002,fd=8))                                                        
LISTEN       0            4096                         [::]:111                        [::]:*           users:(("rpcbind",pid=622,fd=6),("systemd",pid=1,fd=34))                              
LISTEN       0            511                          [::]:4881                       [::]:*           users:(("nginx",pid=2544,fd=7),("nginx",pid=2543,fd=7),("nginx",pid=2542,fd=7))       
[root@selinux ~]#
```

Проверяем статус установленного флага разрешения:

```
[root@selinux ~]# getsebool -a | grep nis_enabled
nis_enabled --> on
[root@selinux ~]# 

```

Также появился доступ к WEB-странице nginx с ОС хоста:

```
[admin_insta11@mv334 ~]$ curl http://192.168.56.10:4881
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">

<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
	<head>
		<title>Test Page for the HTTP Server on AlmaLinux</title>
		<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
		<style type="text/css">
<...>
```
<img width="952" height="762" alt="изображение" src="https://github.com/user-attachments/assets/0f047b66-5cba-4ad1-bf84-a15dc808a345" />

После проверки вернём запрет SELinux:

```
[root@selinux ~]# setsebool -P nis_enabled off
[root@selinux ~]# 
[root@selinux ~]# getsebool -a | grep nis_enabled
nis_enabled --> off
[root@selinux ~]#
[root@selinux ~]# systemctl restart nginx
Job for nginx.service failed because the control process exited with error code.
See "systemctl status nginx.service" and "journalctl -xeu nginx.service" for details.
[root@selinux ~]# 
```

После этого nginx снова запускаться не будет.


**Теперь разрешим в SELinux работу nginx на порту TCP 4881 c помощью добавления нестандартного порта в имеющийся тип**

Просматриваем списки разрешённых портов http, добавляем в список http_port_t нестандартный порт 4881. После этого сервер nginx успешно запускается и начинает слушать нестандартный порт 4881:

```
[root@selinux ~]# semanage port -l | grep http
http_cache_port_t              tcp      8080, 8118, 8123, 10001-10010
http_cache_port_t              udp      3130
http_port_t                    tcp      80, 81, 443, 488, 8008, 8009, 8443, 9000
pegasus_http_port_t            tcp      5988
pegasus_https_port_t           tcp      5989
[root@selinux ~]# 
[root@selinux ~]# semanage port -a -t http_port_t -p tcp 4881
[root@selinux ~]# 
[root@selinux ~]# semanage port -l | grep http
http_cache_port_t              tcp      8080, 8118, 8123, 10001-10010
http_cache_port_t              udp      3130
http_port_t                    tcp      4881, 80, 81, 443, 488, 8008, 8009, 8443, 9000
pegasus_http_port_t            tcp      5988
pegasus_https_port_t           tcp      5989
[root@selinux ~]# 
[root@selinux ~]# systemctl restart nginx
[root@selinux ~]# 
[root@selinux ~]# systemctl status nginx
● nginx.service - The nginx HTTP and reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; preset: disabled)
     Active: active (running) since Thu 2026-09-10 18:22:34 UTC; 9s ago
    Process: 2625 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
    Process: 2626 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=0/SUCCESS)
    Process: 2627 ExecStart=/usr/sbin/nginx (code=exited, status=0/SUCCESS)
   Main PID: 2628 (nginx)
      Tasks: 3 (limit: 12052)
     Memory: 3.1M (peak: 3.2M)
        CPU: 37ms
     CGroup: /system.slice/nginx.service
             ├─2628 "nginx: master process /usr/sbin/nginx"
             ├─2629 "nginx: worker process"
             └─2630 "nginx: worker process"

Sep 10 18:22:34 selinux systemd[1]: Starting The nginx HTTP and reverse proxy server...
Sep 10 18:22:34 selinux nginx[2626]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
Sep 10 18:22:34 selinux nginx[2626]: nginx: configuration file /etc/nginx/nginx.conf test is successful
Sep 10 18:22:34 selinux systemd[1]: Started The nginx HTTP and reverse proxy server.
[root@selinux ~]#
[root@selinux ~]# ss -tnlp
State        Recv-Q       Send-Q              Local Address:Port               Peer Address:Port       Process                                                                                
LISTEN       0            128                       0.0.0.0:22                      0.0.0.0:*           users:(("sshd",pid=1002,fd=7))                                                        
LISTEN       0            4096                      0.0.0.0:111                     0.0.0.0:*           users:(("rpcbind",pid=622,fd=4),("systemd",pid=1,fd=31))                              
LISTEN       0            511                       0.0.0.0:4881                    0.0.0.0:*           users:(("nginx",pid=2544,fd=6),("nginx",pid=2543,fd=6),("nginx",pid=2542,fd=6))       
LISTEN       0            128                          [::]:22                         [::]:*           users:(("sshd",pid=1002,fd=8))                                                        
LISTEN       0            4096                         [::]:111                        [::]:*           users:(("rpcbind",pid=622,fd=6),("systemd",pid=1,fd=34))                              
LISTEN       0            511                          [::]:4881                       [::]:*           users:(("nginx",pid=2544,fd=7),("nginx",pid=2543,fd=7),("nginx",pid=2542,fd=7))       
[root@selinux ~]#
```

После проверки удалим порт 4881 из списка разрешённых портов SELinux:

```
[root@selinux ~]# 
[root@selinux ~]# semanage port -d -t http_port_t -p tcp 4881
[root@selinux ~]# 
[root@selinux ~]# semanage port -l | grep http
http_cache_port_t              tcp      8080, 8118, 8123, 10001-10010
http_cache_port_t              udp      3130
http_port_t                    tcp      80, 81, 443, 488, 8008, 8009, 8443, 9000
pegasus_http_port_t            tcp      5988
pegasus_https_port_t           tcp      5989
[root@selinux ~]# 
[root@selinux ~]# systemctl restart nginx
Job for nginx.service failed because the control process exited with error code.
See "systemctl status nginx.service" and "journalctl -xeu nginx.service" for details.
[root@selinux ~]#
[root@selinux ~]# systemctl status nginx
× nginx.service - The nginx HTTP and reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; preset: disabled)
     Active: failed (Result: exit-code) since Thu 2026-09-10 18:23:33 UTC; 5min ago
   Duration: 58.945s
    Process: 2644 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
    Process: 2645 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=1/FAILURE)
        CPU: 19ms

Sep 10 18:23:33 selinux systemd[1]: Starting The nginx HTTP and reverse proxy server...
Sep 10 18:23:33 selinux nginx[2645]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
Sep 10 18:23:33 selinux nginx[2645]: nginx: [emerg] bind() to 0.0.0.0:4881 failed (13: Permission denied)
Sep 10 18:23:33 selinux nginx[2645]: nginx: configuration file /etc/nginx/nginx.conf test failed
Sep 10 18:23:33 selinux systemd[1]: nginx.service: Control process exited, code=exited, status=1/FAILURE
Sep 10 18:23:33 selinux systemd[1]: nginx.service: Failed with result 'exit-code'.
Sep 10 18:23:33 selinux systemd[1]: Failed to start The nginx HTTP and reverse proxy server.
[root@selinux ~]# 
```

После этого nginx снова запускаться не будет из-зи запрета доступа к порту 4881.

**Разрешим в SELinux работу nginx на порту TCP 4881 c помощью формирования и установки модуля SELinux**

Просматриваем лог SELinux и результат просмотра отправляем в утилиту audit2why, которая на основе анализа лога создаёт модуль с заданным нами названием nginx.pp и сообщает команду для применения созданного модуля, применяем созданный модуль SELinux. После этого сервер nginx успешно запускается и начинает слушать нестандартный порт 4881:

```
[root@selinux ~]# grep nginx /var/log/audit/audit.log
type=ADD_GROUP msg=audit(1788627429.417:765): pid=5601 uid=0 auid=1000 ses=3 subj=unconfined_u:unconfined_r:groupadd_t:s0-s0:c0.c1023 msg='op=add-group id=994 exe="/usr/sbin/groupadd" hostname=? addr=? terminal=? res=success'UID="root" AUID="vagrant" ID="nginx"
type=GRP_MGMT msg=audit(1788627429.423:766): pid=5601 uid=0 auid=1000 ses=3 subj=unconfined_u:unconfined_r:groupadd_t:s0-s0:c0.c1023 msg='op=add-shadow-group id=994 exe="/usr/sbin/groupadd" hostname=? addr=? terminal=? res=success'UID="root" AUID="vagrant" ID="nginx"
type=ADD_USER msg=audit(1788627429.471:767): pid=5609 uid=0 auid=1000 ses=3 subj=unconfined_u:unconfined_r:useradd_t:s0-s0:c0.c1023 msg='op=add-user acct="nginx" exe="/usr/sbin/useradd" hostname=? addr=? terminal=? res=success'UID="root" AUID="vagrant"
type=SOFTWARE_UPDATE msg=audit(1788627430.153:796): pid=5578 uid=0 auid=1000 ses=3 subj=unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023 msg='op=install sw="nginx-filesystem-2:1.20.1-28.el9_8.5.alma.1.noarch" sw_type=rpm key_enforce=0 gpg_res=1 root_dir="/" comm="dnf" exe="/usr/bin/python3.9" hostname=? addr=? terminal=? res=success'UID="root" AUID="vagrant"
type=SOFTWARE_UPDATE msg=audit(1788627430.153:797): pid=5578 uid=0 auid=1000 ses=3 subj=unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023 msg='op=install sw="nginx-core-2:1.20.1-28.el9_8.5.alma.1.x86_64" sw_type=rpm key_enforce=0 gpg_res=1 root_dir="/" comm="dnf" exe="/usr/bin/python3.9" hostname=? addr=? terminal=? res=success'UID="root" AUID="vagrant"
type=SOFTWARE_UPDATE msg=audit(1788627430.153:799): pid=5578 uid=0 auid=1000 ses=3 subj=unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023 msg='op=install sw="nginx-2:1.20.1-28.el9_8.5.alma.1.x86_64" sw_type=rpm key_enforce=0 gpg_res=1 root_dir="/" comm="dnf" exe="/usr/bin/python3.9" hostname=? addr=? terminal=? res=success'UID="root" AUID="vagrant"
type=AVC msg=audit(1788627446.725:844): avc:  denied  { name_bind } for  pid=6289 comm="nginx" src=4881 scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0
type=SYSCALL msg=audit(1788627446.725:844): arch=c000003e syscall=49 success=no exit=-13 a0=6 a1=5602bb8b1870 a2=10 a3=7ffee2aaa300 items=0 ppid=1 pid=6289 auid=4294967295 uid=0 gid=0 euid=0 suid=0 fsuid=0 egid=0 sgid=0 fsgid=0 tty=(none) ses=4294967295 comm="nginx" exe="/usr/sbin/nginx" subj=system_u:system_r:httpd_t:s0 key=(null)ARCH=x86_64 SYSCALL=bind AUID="unset" UID="root" GID="root" EUID="root" SUID="root" FSUID="root" EGID="root" SGID="root" FSGID="root"
type=SERVICE_START msg=audit(1788627446.727:845): pid=1 uid=0 auid=4294967295 ses=4294967295 subj=system_u:system_r:init_t:s0 msg='unit=nginx comm="systemd" exe="/usr/lib/systemd/systemd" hostname=? addr=? terminal=? res=failed'UID="root" AUID="unset"
type=AVC msg=audit(1789062215.342:305): avc:  denied  { name_bind } for  pid=2480 comm="nginx" src=4881 scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0
type=SYSCALL msg=audit(1789062215.342:305): arch=c000003e syscall=49 success=no exit=-13 a0=6 a1=564b9f4a8870 a2=10 a3=7ffc6c6e7d00 items=0 ppid=1 pid=2480 auid=4294967295 uid=0 gid=0 euid=0 suid=0 fsuid=0 egid=0 sgid=0 fsgid=0 tty=(none) ses=4294967295 comm="nginx" exe="/usr/sbin/nginx" subj=system_u:system_r:httpd_t:s0 key=(null)ARCH=x86_64 SYSCALL=bind AUID="unset" UID="root" GID="root" EUID="root" SUID="root" FSUID="root" EGID="root" SGID="root" FSGID="root"
type=SERVICE_START msg=audit(1789062215.345:306): pid=1 uid=0 auid=4294967295 ses=4294967295 subj=system_u:system_r:init_t:s0 msg='unit=nginx comm="systemd" exe="/usr/lib/systemd/systemd" hostname=? addr=? terminal=? res=failed'UID="root" AUID="unset"
type=SERVICE_START msg=audit(1789063014.722:315): pid=1 uid=0 auid=4294967295 ses=4294967295 subj=system_u:system_r:init_t:s0 msg='unit=nginx comm="systemd" exe="/usr/lib/systemd/systemd" hostname=? addr=? terminal=? res=success'UID="root" AUID="unset"
type=SERVICE_STOP msg=audit(1789064424.698:320): pid=1 uid=0 auid=4294967295 ses=4294967295 subj=system_u:system_r:init_t:s0 msg='unit=nginx comm="systemd" exe="/usr/lib/systemd/systemd" hostname=? addr=? terminal=? res=success'UID="root" AUID="unset"
type=AVC msg=audit(1789064424.742:321): avc:  denied  { name_bind } for  pid=2598 comm="nginx" src=4881 scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0
type=SYSCALL msg=audit(1789064424.742:321): arch=c000003e syscall=49 success=no exit=-13 a0=6 a1=55e045874870 a2=10 a3=7ffec67de2d0 items=0 ppid=1 pid=2598 auid=4294967295 uid=0 gid=0 euid=0 suid=0 fsuid=0 egid=0 sgid=0 fsgid=0 tty=(none) ses=4294967295 comm="nginx" exe="/usr/sbin/nginx" subj=system_u:system_r:httpd_t:s0 key=(null)ARCH=x86_64 SYSCALL=bind AUID="unset" UID="root" GID="root" EUID="root" SUID="root" FSUID="root" EGID="root" SGID="root" FSGID="root"
type=SERVICE_START msg=audit(1789064424.744:322): pid=1 uid=0 auid=4294967295 ses=4294967295 subj=system_u:system_r:init_t:s0 msg='unit=nginx comm="systemd" exe="/usr/lib/systemd/systemd" hostname=? addr=? terminal=? res=failed'UID="root" AUID="unset"
type=SERVICE_START msg=audit(1789064554.660:329): pid=1 uid=0 auid=4294967295 ses=4294967295 subj=system_u:system_r:init_t:s0 msg='unit=nginx comm="systemd" exe="/usr/lib/systemd/systemd" hostname=? addr=? terminal=? res=success'UID="root" AUID="unset"
type=SERVICE_STOP msg=audit(1789064613.618:332): pid=1 uid=0 auid=4294967295 ses=4294967295 subj=system_u:system_r:init_t:s0 msg='unit=nginx comm="systemd" exe="/usr/lib/systemd/systemd" hostname=? addr=? terminal=? res=success'UID="root" AUID="unset"
type=AVC msg=audit(1789064613.656:333): avc:  denied  { name_bind } for  pid=2645 comm="nginx" src=4881 scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0
type=SYSCALL msg=audit(1789064613.656:333): arch=c000003e syscall=49 success=no exit=-13 a0=6 a1=556654dcd870 a2=10 a3=7fffdb3c0240 items=0 ppid=1 pid=2645 auid=4294967295 uid=0 gid=0 euid=0 suid=0 fsuid=0 egid=0 sgid=0 fsgid=0 tty=(none) ses=4294967295 comm="nginx" exe="/usr/sbin/nginx" subj=system_u:system_r:httpd_t:s0 key=(null)ARCH=x86_64 SYSCALL=bind AUID="unset" UID="root" GID="root" EUID="root" SUID="root" FSUID="root" EGID="root" SGID="root" FSGID="root"
type=SERVICE_START msg=audit(1789064613.658:334): pid=1 uid=0 auid=4294967295 ses=4294967295 subj=system_u:system_r:init_t:s0 msg='unit=nginx comm="systemd" exe="/usr/lib/systemd/systemd" hostname=? addr=? terminal=? res=failed'UID="root" AUID="unset"
[root@selinux ~]# 
[root@selinux ~]# grep nginx /var/log/audit/audit.log | audit2allow -M nginx
******************** IMPORTANT ***********************
To make this policy package active, execute:

semodule -i nginx.pp

[root@selinux ~]# find / -name nginx.pp
/root/nginx.pp
[root@selinux ~]# 
[root@selinux ~]# ll /root/nginx.pp
-rw-r--r--. 1 root root 960 Sep 10 18:31 /root/nginx.pp
[root@selinux ~]# 
[root@selinux ~]# semodule -i nginx.pp
[root@selinux ~]# 
[root@selinux ~]# systemctl restart nginx
[root@selinux ~]# 
[root@selinux ~]# systemctl status nginx
● nginx.service - The nginx HTTP and reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; preset: disabled)
     Active: active (running) since Thu 2026-09-10 18:35:07 UTC; 14s ago
    Process: 2701 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
    Process: 2702 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=0/SUCCESS)
    Process: 2703 ExecStart=/usr/sbin/nginx (code=exited, status=0/SUCCESS)
   Main PID: 2704 (nginx)
      Tasks: 3 (limit: 12052)
     Memory: 3.1M (peak: 3.3M)
        CPU: 38ms
     CGroup: /system.slice/nginx.service
             ├─2704 "nginx: master process /usr/sbin/nginx"
             ├─2705 "nginx: worker process"
             └─2706 "nginx: worker process"

Sep 10 18:35:07 selinux systemd[1]: Starting The nginx HTTP and reverse proxy server...
Sep 10 18:35:07 selinux nginx[2702]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
Sep 10 18:35:07 selinux nginx[2702]: nginx: configuration file /etc/nginx/nginx.conf test is successful
Sep 10 18:35:07 selinux systemd[1]: Started The nginx HTTP and reverse proxy server.
[root@selinux ~]# 
[root@selinux ~]# semodule -l | grep nginx
nginx
[root@selinux ~]#
```

После проверки отключаем модуль nginx, 

```
[root@selinux ~]# semodule -r nginx
libsemanage.semanage_direct_remove_key: Removing last nginx module (no other nginx module exists at another priority).
[root@selinux ~]# 
[root@selinux ~]# semodule -l | grep nginx
[root@selinux ~]# 
[root@selinux ~]# 
[root@selinux ~]# systemctl restart nginx
Job for nginx.service failed because the control process exited with error code.
See "systemctl status nginx.service" and "journalctl -xeu nginx.service" for details.
[root@selinux ~]# 
[root@selinux ~]# systemctl status nginx
× nginx.service - The nginx HTTP and reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; preset: disabled)
     Active: failed (Result: exit-code) since Thu 2026-09-10 18:37:11 UTC; 11s ago
   Duration: 2min 4.087s
    Process: 2739 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
    Process: 2740 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=1/FAILURE)
        CPU: 23ms

Sep 10 18:37:11 selinux systemd[1]: Starting The nginx HTTP and reverse proxy server...
Sep 10 18:37:11 selinux nginx[2740]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
Sep 10 18:37:11 selinux nginx[2740]: nginx: [emerg] bind() to 0.0.0.0:4881 failed (13: Permission denied)
Sep 10 18:37:11 selinux nginx[2740]: nginx: configuration file /etc/nginx/nginx.conf test failed
Sep 10 18:37:11 selinux systemd[1]: nginx.service: Control process exited, code=exited, status=1/FAILURE
Sep 10 18:37:11 selinux systemd[1]: nginx.service: Failed with result 'exit-code'.
Sep 10 18:37:11 selinux systemd[1]: Failed to start The nginx HTTP and reverse proxy server.
[root@selinux ~]# 
```

После этого nginx снова запускаться не будет из-зи запрета доступа к порту 4881.


## Обеспечение работоспособности приложения при включенном SELinux

