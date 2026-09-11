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

Выполняем клонирование репозитория, переходим в него, модифицируем исходный Vagrantfile репозитория для работы в гипервизоре kvm/libvirt и с локально установленным боксом almalinux/9. Исходный файл для virtualbox:

```
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  config.vm.box = "almalinux/9"
  config.vm.box_version = "9.4.20240805"
  config.vm.provision "ansible" do |ansible|
    #ansible.verbose = "vvv"
    ansible.playbook = "provisioning/playbook.yml"
    ansible.become = "true"
  end

  config.vm.provider "virtualbox" do |v|
	  v.memory = 2048
    v.cpus = 2    
  end

  config.vm.define "ns01" do |ns01|
    ns01.vm.synced_folder ".", "/vagrant", disabled: true
    ns01.vm.network "private_network", ip: "192.168.50.10", virtualbox__intnet: "dns"
    ns01.vm.hostname = "ns01"
  end

  config.vm.define "client" do |client|
    client.vm.synced_folder ".", "/vagrant", disabled: true
    client.vm.network "private_network", ip: "192.168.50.15", virtualbox__intnet: "dns"
    client.vm.hostname = "client"
  end

end
```

Модифицированный Vagrantfile для kvm/libvirt:

```
[admin_insta11@mv334 vagrant_selinux_dns_problems_kvm]$ cat Vagrantfile 
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  config.vm.box = "almalinux9-stand"
#  config.vm.box_version = "9.4.20240805"

  config.vm.provision "ansible" do |ansible|
    #ansible.verbose = "vvv"
    ansible.playbook = "provisioning/playbook.yml"
    ansible.become = "true"
  end

  config.vm.provider "libvirt" do |v|
    v.memory = 2048
    v.cpus = 2
  end

  config.vm.define "ns01" do |ns01|
    ns01.vm.synced_folder ".", "/vagrant", disabled: true
    ns01.vm.network "private_network",
      ip: "192.168.50.10",
      libvirt__network_name: "dns",
      libvirt__host_ip: "192.168.50.1",
      libvirt__netmask: "255.255.255.0"
    ns01.vm.hostname = "ns01"
  end

  config.vm.define "client" do |client|
    client.vm.synced_folder ".", "/vagrant", disabled: true
    client.vm.network "private_network",
      ip: "192.168.50.15",
      libvirt__network_name: "dns",
      libvirt__host_ip: "192.168.50.1",
      libvirt__netmask: "255.255.255.0"
    client.vm.hostname = "client"
  end
end
[admin_insta11@mv334 vagrant_selinux_dns_problems_kvm]$
```

Создаём учебный стенд с помощью vargant и провизионинга ansible:

```
[admin_insta11@mv334 vagrant_selinux_dns_problems_kvm]$ vagrant up
Bringing machine 'ns01' up with 'libvirt' provider...
Bringing machine 'client' up with 'libvirt' provider...
==> client: No version detected for almalinux9-stand, using timestamp to watch for modifications. Consider
==> client: generating a local metadata for the box with a version to allow better handling.
==> client: See https://www.vagrantup.com/docs/boxes/format#box-metadata for further details.
==> ns01: No version detected for almalinux9-stand, using timestamp to watch for modifications. Consider
==> ns01: generating a local metadata for the box with a version to allow better handling.
==> ns01: See https://www.vagrantup.com/docs/boxes/format#box-metadata for further details.
==> client: Creating image (snapshot of base box volume).
==> ns01: Creating image (snapshot of base box volume).
==> client: Creating domain with the following settings...
==> ns01: Creating domain with the following settings...
==> client:  -- Name:              vagrant_selinux_dns_problems_kvm_client
==> ns01:  -- Name:              vagrant_selinux_dns_problems_kvm_ns01
==> client:  -- Description:       Source: /home/admin_insta11/vagrant_selinux_dns_problems_kvm/Vagrantfile
==> ns01:  -- Description:       Source: /home/admin_insta11/vagrant_selinux_dns_problems_kvm/Vagrantfile
==> client:  -- Domain type:       kvm
==> ns01:  -- Domain type:       kvm
==> client:  -- Cpus:              2
==> ns01:  -- Cpus:              2
==> client:  -- Feature:           acpi
==> ns01:  -- Feature:           acpi
==> client:  -- Feature:           apic
==> ns01:  -- Feature:           apic
==> client:  -- Feature:           pae
==> ns01:  -- Feature:           pae
==> client:  -- Clock offset:      utc
==> ns01:  -- Clock offset:      utc
==> client:  -- Memory:            2048M
==> ns01:  -- Memory:            2048M
==> client:  -- Base box:          almalinux9-stand
==> ns01:  -- Base box:          almalinux9-stand
==> client:  -- Storage pool:      default
==> ns01:  -- Storage pool:      default
==> client:  -- Image(vda):        /var/lib/libvirt/images/vagrant_selinux_dns_problems_kvm_client.img, virtio, 20G
==> ns01:  -- Image(vda):        /var/lib/libvirt/images/vagrant_selinux_dns_problems_kvm_ns01.img, virtio, 20G
==> client:  -- Disk driver opts:  cache='default'
==> ns01:  -- Disk driver opts:  cache='default'
==> client:  -- Graphics Type:     vnc
==> ns01:  -- Graphics Type:     vnc
==> client:  -- Video Type:        cirrus
==> ns01:  -- Video Type:        cirrus
==> client:  -- Video VRAM:        16384
==> ns01:  -- Video VRAM:        16384
==> client:  -- Video 3D accel:    false
==> ns01:  -- Video 3D accel:    false
==> client:  -- Keymap:            en-us
==> ns01:  -- Keymap:            en-us
==> client:  -- TPM Backend:       passthrough
==> ns01:  -- TPM Backend:       passthrough
==> client:  -- INPUT:             type=mouse, bus=ps2
==> ns01:  -- INPUT:             type=mouse, bus=ps2
==> client: Creating shared folders metadata...
==> ns01: Creating shared folders metadata...
==> client: Starting domain.
==> ns01: Starting domain.
==> client: Domain launching with graphics connection settings...
==> ns01: Domain launching with graphics connection settings...
==> client:  -- Graphics Port:      5901
==> ns01:  -- Graphics Port:      5902
==> client:  -- Graphics IP:        127.0.0.1
==> ns01:  -- Graphics IP:        127.0.0.1
==> client:  -- Graphics Password:  Not defined
==> ns01:  -- Graphics Password:  Not defined
==> client:  -- Graphics Websocket: 5700
==> ns01:  -- Graphics Websocket: 5701
==> client: Waiting for domain to get an IP address...
==> ns01: Waiting for domain to get an IP address...
==> client: Waiting for machine to boot. This may take a few minutes...
==> ns01: Waiting for machine to boot. This may take a few minutes...
    client: SSH address: 192.168.121.66:22
    ns01: SSH address: 192.168.121.134:22
    client: SSH username: vagrant
    client: SSH auth method: private key
    ns01: SSH username: vagrant
    ns01: SSH auth method: private key
    client: Warning: Connection refused. Retrying...
    client: 
    client: Vagrant insecure key detected. Vagrant will automatically replace
    client: this with a newly generated keypair for better security.
    ns01: 
    ns01: Vagrant insecure key detected. Vagrant will automatically replace
    ns01: this with a newly generated keypair for better security.
    client: 
    client: Inserting generated public key within guest...
    ns01: 
    ns01: Inserting generated public key within guest...
    client: Removing insecure key from the guest if it's present...
    ns01: Removing insecure key from the guest if it's present...
    ns01: Key inserted! Disconnecting and reconnecting using new SSH key...
    client: Key inserted! Disconnecting and reconnecting using new SSH key...
==> client: Machine booted and ready!
==> client: Setting hostname...
==> ns01: Machine booted and ready!
==> ns01: Setting hostname...
==> ns01: Configuring and enabling network interfaces...
==> client: Configuring and enabling network interfaces...
==> ns01: Running provisioner: ansible...
==> client: Running provisioner: ansible...
    ns01: Running ansible-playbook...
    client: Running ansible-playbook...

PLAY [all] *********************************************************************

PLAY [all] *********************************************************************

TASK [Gathering Facts] *********************************************************

TASK [Gathering Facts] *********************************************************
ok: [client]

TASK [install packages] ********************************************************
ok: [ns01]

TASK [install packages] ********************************************************
changed: [client]

PLAY [ns01] ********************************************************************
skipping: no hosts matched

PLAY [client] ******************************************************************

TASK [Gathering Facts] *********************************************************
changed: [ns01]

PLAY [ns01] ********************************************************************

TASK [Gathering Facts] *********************************************************
ok: [client]

TASK [copy resolv.conf to the client] ******************************************
ok: [ns01]

TASK [copy named.conf] *********************************************************
changed: [client]

TASK [copy rndc conf file] *****************************************************
changed: [ns01]

TASK [copy master zone dns.lab] ************************************************
changed: [client]

TASK [copy motd to the client] *************************************************
changed: [ns01] => (item=/home/admin_insta11/vagrant_selinux_dns_problems_kvm/provisioning/files/ns01/named.dns.lab.view1)
changed: [client]

TASK [copy transferkey to client] **********************************************
changed: [ns01] => (item=/home/admin_insta11/vagrant_selinux_dns_problems_kvm/provisioning/files/ns01/named.dns.lab)

TASK [copy dynamic zone ddns.lab] **********************************************
changed: [client]

PLAY RECAP *********************************************************************
client                     : ok=7    changed=5    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   

changed: [ns01]

TASK [copy dynamic zone ddns.lab.view1] ****************************************
changed: [ns01]

TASK [copy master zone newdns.lab] *********************************************
changed: [ns01]

TASK [copy rev zones] **********************************************************
changed: [ns01]

TASK [copy resolv.conf to server] **********************************************
changed: [ns01]

TASK [copy transferkey to server] **********************************************
changed: [ns01]

TASK [set /etc/named permissions] **********************************************
changed: [ns01]

TASK [set /etc/named/dynamic permissions] **************************************
changed: [ns01]

TASK [ensure named is running and enabled] *************************************
changed: [ns01]

PLAY [client] ******************************************************************
skipping: no hosts matched

PLAY RECAP *********************************************************************
ns01                       : ok=14   changed=12   unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   

[admin_insta11@mv334 vagrant_selinux_dns_problems_kvm]$
[admin_insta11@mv334 vagrant_selinux_dns_problems_kvm]$ sudo virsh list
[sudo] пароль для admin_insta11: 
 ID   Имя                                       Состояние
-----------------------------------------------------------
 1    ubuntu-24.04-01                           работает
 2    vagrant_selinux_dns_problems_kvm_client   работает
 3    vagrant_selinux_dns_problems_kvm_ns01     работает

[admin_insta11@mv334 vagrant_selinux_dns_problems_kvm]$
```

Далее выполняем непосредственно лобораторную работу. Подключаемся к ВМ client, пытаемся выполнить изменение динамической зоны DNS на сервере DNS в ВМ ns01 - изменения зоны не выполняются, выдаётся ошибка 'update failed: SERVFAIL':

```
[admin_insta11@mv334 vagrant_selinux_dns_problems_kvm]$ vagrant status
Current machine states:

ns01                      running (libvirt)
client                    running (libvirt)

This environment represents multiple VMs. The VMs are all listed
above with their current state. For more information about a specific
VM, run `vagrant status NAME`.
[admin_insta11@mv334 vagrant_selinux_dns_problems_kvm]$ vagrant ssh client
###############################
### Welcome to the DNS lab! ###
###############################

- Use this client to test the enviroment
- with dig or nslookup. Ex:
    dig @192.168.50.10 ns01.dns.lab

- nsupdate is available in the ddns.lab zone. Ex:
    nsupdate -k /etc/named.zonetransfer.key
    server 192.168.50.10
    zone ddns.lab 
    update add www.ddns.lab. 60 A 192.168.50.15
    send

- rndc is also available to manage the servers
    rndc -c ~/rndc.conf reload

###############################
### Enjoy! ####################
###############################
Last login: Fri Sep 11 14:39:23 2026 from 192.168.121.1
[vagrant@client ~]$
[vagrant@client ~]$ ping 192.168.50.10
PING 192.168.50.10 (192.168.50.10) 56(84) bytes of data.
64 bytes from 192.168.50.10: icmp_seq=1 ttl=64 time=0.508 ms
64 bytes from 192.168.50.10: icmp_seq=2 ttl=64 time=0.659 ms
64 bytes from 192.168.50.10: icmp_seq=3 ttl=64 time=0.728 ms
^C
--- 192.168.50.10 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2069ms
rtt min/avg/max/mdev = 0.508/0.631/0.728/0.091 ms
[vagrant@client ~]$
[vagrant@client ~]$ nsupdate -k /etc/named.zonetransfer.key
> server 192.168.50.10
> zone ddns.lab
> update add www.ddns.lab. 60 A 192.168.50.15
> send
update failed: SERVFAIL
> quit
[vagrant@client ~]$ 
```

В логе SELinux нет ошибок:

```
[vagrant@client ~]$ sudo -i
[root@client ~]# 
[root@client ~]# cat /var/log/audit/audit.log | audit2why
[root@client ~]#
```

Проверяем на ВМ севера ns01:

```
[admin_insta11@mv334 vagrant_selinux_dns_problems_kvm]$ vagrant ssh ns01
Last login: Fri Sep 11 14:39:30 2026 from 192.168.121.1
[vagrant@ns01 ~]$
[vagrant@ns01 ~]$ sudo -i
[root@ns01 ~]# 
[root@ns01 ~]# cat /var/log/audit/audit.log | audit2why
type=AVC msg=audit(1789138634.020:1535): avc:  denied  { write } for  pid=9527 comm="isc-net-0001" name="dynamic" dev="vda4" ino=1926 scontext=system_u:system_r:named_t:s0 tcontext=unconfined_u:object_r:named_conf_t:s0 tclass=dir permissive=0

	Was caused by:
		Missing type enforcement (TE) allow rule.

		You can use audit2allow to generate a loadable module to allow this access.

[root@ns01 ~]#
```

В данном случае домен/контекст процесса named_t , а контекст объекта, к которому он пытается применить операцию write , - named_conf_t , класс объекта dir , название директории dynamic.

Проверяем, какой домен имеет процесс named, какие контексты объектов вообще существют для named:

```
[vagrant@ns01 ~]$ ps -efZ | grep named | grep -v grep
system_u:system_r:named_t:s0    named        719       1  0 16:35 ?        00:00:00 /usr/sbin/named -u named -c /etc/named.conf
[vagrant@ns01 ~]$ 
[root@ns01 ~]# sudo semanage fcontext -l | grep named
<...>
/etc/named(/.*)?                                   all files          system_u:object_r:named_conf_t:s0 
/etc/named\.caching-nameserver\.conf               regular file       system_u:object_r:named_conf_t:s0 
/etc/named\.conf                                   regular file       system_u:object_r:named_conf_t:s0 
/etc/named\.rfc1912.zones                          regular file       system_u:object_r:named_conf_t:s0 
/etc/named\.root\.hints                            regular file       system_u:object_r:named_conf_t:s0 
/etc/rc\.d/init\.d/named                           regular file       system_u:object_r:named_initrc_exec_t:s0 
/etc/rc\.d/init\.d/named-sdb                       regular file       system_u:object_r:named_initrc_exec_t:s0 
/etc/rc\.d/init\.d/unbound                         regular file       system_u:object_r:named_initrc_exec_t:s0 
/etc/rndc.*                                        regular file       system_u:object_r:named_conf_t:s0 
/etc/unbound(/.*)?                                 all files          system_u:object_r:named_conf_t:s0 
/usr/lib/systemd/system/named-sdb.*                regular file       system_u:object_r:named_unit_file_t:s0 
/usr/lib/systemd/system/named.*                    regular file       system_u:object_r:named_unit_file_t:s0 
/usr/lib/systemd/system/unbound.*                  regular file       system_u:object_r:named_unit_file_t:s0 
/usr/lib/systemd/systemd-hostnamed                 regular file       system_u:object_r:systemd_hostnamed_exec_t:s0 
/usr/sbin/lwresd                                   regular file       system_u:object_r:named_exec_t:s0 
/usr/sbin/named                                    regular file       system_u:object_r:named_exec_t:s0 
/usr/sbin/named-checkconf                          regular file       system_u:object_r:named_checkconf_exec_t:s0 
/usr/sbin/named-pkcs11                             regular file       system_u:object_r:named_exec_t:s0 
/usr/sbin/named-sdb                                regular file       system_u:object_r:named_exec_t:s0 
/usr/sbin/unbound                                  regular file       system_u:object_r:named_exec_t:s0 
/usr/sbin/unbound-anchor                           regular file       system_u:object_r:named_exec_t:s0 
/usr/sbin/unbound-checkconf                        regular file       system_u:object_r:named_exec_t:s0 
/usr/sbin/unbound-control                          regular file       system_u:object_r:named_exec_t:s0 
/usr/share/munin/plugins/named                     regular file       system_u:object_r:services_munin_plugin_exec_t:s0 
/var/lib/softhsm(/.*)?                             all files          system_u:object_r:named_cache_t:s0 
/var/lib/unbound(/.*)?                             all files          system_u:object_r:named_cache_t:s0 
/var/log/named.*                                   regular file       system_u:object_r:named_log_t:s0 
/var/named(/.*)?                                   all files          system_u:object_r:named_zone_t:s0 
/var/named/chroot(/.*)?                            all files          system_u:object_r:named_conf_t:s0 
/var/named/chroot/dev                              directory          system_u:object_r:device_t:s0 
/var/named/chroot/dev/log                          socket             system_u:object_r:devlog_t:s0 
/var/named/chroot/dev/null                         character device   system_u:object_r:null_device_t:s0 
/var/named/chroot/dev/random                       character device   system_u:object_r:random_device_t:s0 
/var/named/chroot/dev/urandom                      character device   system_u:object_r:urandom_device_t:s0 
/var/named/chroot/dev/zero                         character device   system_u:object_r:zero_device_t:s0 
/var/named/chroot/etc(/.*)?                        all files          system_u:object_r:etc_t:s0 
/var/named/chroot/etc/localtime                    regular file       system_u:object_r:locale_t:s0 
/var/named/chroot/etc/named\.caching-nameserver\.conf regular file       system_u:object_r:named_conf_t:s0 
/var/named/chroot/etc/named\.conf                  regular file       system_u:object_r:named_conf_t:s0 
/var/named/chroot/etc/named\.rfc1912.zones         regular file       system_u:object_r:named_conf_t:s0 
/var/named/chroot/etc/named\.root\.hints           regular file       system_u:object_r:named_conf_t:s0 
/var/named/chroot/etc/pki(/.*)?                    all files          system_u:object_r:cert_t:s0 
/var/named/chroot/etc/rndc\.key                    regular file       system_u:object_r:dnssec_t:s0 
/var/named/chroot/lib(/.*)?                        all files          system_u:object_r:lib_t:s0 
/var/named/chroot/proc(/.*)?                       all files          <<None>>
/var/named/chroot/run/named.*                      all files          system_u:object_r:named_var_run_t:s0 
/var/named/chroot/usr/lib(/.*)?                    all files          system_u:object_r:lib_t:s0 
/var/named/chroot/var/log                          directory          system_u:object_r:var_log_t:s0 
/var/named/chroot/var/log/named.*                  regular file       system_u:object_r:named_log_t:s0 
/var/named/chroot/var/named(/.*)?                  all files          system_u:object_r:named_zone_t:s0 
/var/named/chroot/var/named/data(/.*)?             all files          system_u:object_r:named_cache_t:s0 
/var/named/chroot/var/named/dynamic(/.*)?          all files          system_u:object_r:named_cache_t:s0 
/var/named/chroot/var/named/named\.ca              regular file       system_u:object_r:named_conf_t:s0 
/var/named/chroot/var/named/slaves(/.*)?           all files          system_u:object_r:named_cache_t:s0 
/var/named/chroot/var/run/dbus(/.*)?               all files          system_u:object_r:system_dbusd_var_run_t:s0 
/var/named/chroot/var/run/named.*                  all files          system_u:object_r:named_var_run_t:s0 
/var/named/chroot/var/tmp(/.*)?                    all files          system_u:object_r:named_cache_t:s0 
/var/named/chroot_sdb/dev                          directory          system_u:object_r:device_t:s0 
/var/named/chroot_sdb/dev/null                     character device   system_u:object_r:null_device_t:s0 
/var/named/chroot_sdb/dev/random                   character device   system_u:object_r:random_device_t:s0 
/var/named/chroot_sdb/dev/urandom                  character device   system_u:object_r:urandom_device_t:s0 
/var/named/chroot_sdb/dev/zero                     character device   system_u:object_r:zero_device_t:s0 
/var/named/data(/.*)?                              all files          system_u:object_r:named_cache_t:s0 
/var/named/dynamic(/.*)?                           all files          system_u:object_r:named_cache_t:s0 
/var/named/named\.ca                               regular file       system_u:object_r:named_conf_t:s0 
/var/named/slaves(/.*)?                            all files          system_u:object_r:named_cache_t:s0 
/var/run/bind(/.*)?                                all files          system_u:object_r:named_var_run_t:s0 
/var/run/ecblp0                                    named pipe         system_u:object_r:cupsd_var_run_t:s0 
/var/run/initctl                                   named pipe         system_u:object_r:initctl_t:s0 
/var/run/named(/.*)?                               all files          system_u:object_r:named_var_run_t:s0 
/var/run/ndc                                       socket             system_u:object_r:named_var_run_t:s0 
/var/run/systemd/initctl/fifo                      named pipe         system_u:object_r:initctl_t:s0 
/var/run/unbound(/.*)?                             all files          system_u:object_r:named_var_run_t:s0 
/var/named/chroot/usr/lib64 = /usr/lib
/var/named/chroot/lib64 = /usr/lib
/var/named/chroot/var = /var
[root@ns01 ~]# 
```

и какие действия разрешены разрешены домену named_t над объектами с контекстами named_conf_t , named_zone_t и named_cache_t , а также смотрим, какие контексты имеют директории и файлы в директориях /etc/named/ и /var/named/ :

```
[vagrant@ns01 ~]$ sesearch -A -s named_t -t named_zone_t
allow domain file_type:blk_file map; [ domain_can_mmap_files ]:True
allow domain file_type:chr_file map; [ domain_can_mmap_files ]:True
allow domain file_type:file map; [ domain_can_mmap_files ]:True
allow domain file_type:lnk_file map; [ domain_can_mmap_files ]:True
allow named_t file_type:filesystem getattr;
allow named_t named_zone_t:dir { add_name create link remove_name rename reparent rmdir setattr unlink watch watch_reads write }; [ named_write_master_zones ]:True
allow named_t named_zone_t:dir { add_name remove_name write }; [ named_write_master_zones ]:True
allow named_t named_zone_t:dir { add_name remove_name write }; [ named_write_master_zones ]:True
allow named_t named_zone_t:dir { add_name remove_name write }; [ named_write_master_zones ]:True
allow named_t named_zone_t:dir { getattr ioctl lock open read search };
allow named_t named_zone_t:file { append create link rename setattr unlink watch watch_reads write }; [ named_write_master_zones ]:True
allow named_t named_zone_t:file { getattr ioctl lock map open read };
allow named_t named_zone_t:lnk_file { append create ioctl link lock rename setattr unlink watch watch_reads write }; [ named_write_master_zones ]:True
allow named_t named_zone_t:lnk_file { getattr read };
[vagrant@ns01 ~]$ 
[vagrant@ns01 ~]$ sesearch -A -s named_t -t named_conf_t | grep write
[vagrant@ns01 ~]$ 
[vagrant@ns01 ~]$ sesearch -A -s named_t -t named_zone_t | grep write
allow named_t named_zone_t:dir { add_name create link remove_name rename reparent rmdir setattr unlink watch watch_reads write }; [ named_write_master_zones ]:True
allow named_t named_zone_t:dir { add_name remove_name write }; [ named_write_master_zones ]:True
allow named_t named_zone_t:dir { add_name remove_name write }; [ named_write_master_zones ]:True
allow named_t named_zone_t:dir { add_name remove_name write }; [ named_write_master_zones ]:True
allow named_t named_zone_t:file { append create link rename setattr unlink watch watch_reads write }; [ named_write_master_zones ]:True
allow named_t named_zone_t:lnk_file { append create ioctl link lock rename setattr unlink watch watch_reads write }; [ named_write_master_zones ]:True
[vagrant@ns01 ~]$
[vagrant@ns01 ~]$ sesearch -A -s named_t -t named_cache_t | grep write
allow named_t named_cache_t:dir { add_name create getattr ioctl link lock open read remove_name rename reparent rmdir search setattr unlink watch watch_reads write };
allow named_t named_cache_t:file { append create getattr ioctl link lock map open read rename setattr unlink watch watch_reads write };
allow named_t named_cache_t:lnk_file { append create getattr ioctl link lock read rename setattr unlink watch watch_reads write };
[vagrant@ns01 ~]$ 
[vagrant@ns01 ~]$ sesearch -A -s named_t -t named_conf_t | grep write
[vagrant@ns01 ~]$
vagrant@ns01 ~]$ sudo ls -alZ /etc/named/
total 28
drw-rwx---.  3 root named system_u:object_r:named_conf_t:s0      121 Sep 11 14:39 .
drwxr-xr-x. 89 root root  system_u:object_r:etc_t:s0            8192 Sep 11 16:35 ..
drw-rwx---.  2 root named unconfined_u:object_r:named_conf_t:s0   88 Sep 11 15:37 dynamic
-rw-rw----.  1 root named system_u:object_r:named_conf_t:s0      784 Sep 11 14:39 named.50.168.192.rev
-rw-rw----.  1 root named system_u:object_r:named_conf_t:s0      610 Sep 11 14:39 named.dns.lab
-rw-rw----.  1 root named system_u:object_r:named_conf_t:s0      609 Sep 11 14:39 named.dns.lab.view1
-rw-rw----.  1 root named system_u:object_r:named_conf_t:s0      657 Sep 11 14:39 named.newdns.lab
[vagrant@ns01 ~]$ 
[vagrant@ns01 ~]$ sudo ls -alZ /etc/named/dynamic
total 12
drw-rwx---. 2 root  named unconfined_u:object_r:named_conf_t:s0  88 Sep 11 15:37 .
drw-rwx---. 3 root  named system_u:object_r:named_conf_t:s0     121 Sep 11 14:39 ..
-rw-rw----. 1 named named system_u:object_r:named_conf_t:s0     509 Sep 11 14:39 named.ddns.lab
-rw-r--r--. 1 named named system_u:object_r:named_conf_t:s0     348 Sep 11 15:37 named.ddns.lab.view1
-rw-r--r--. 1 named named system_u:object_r:named_conf_t:s0     704 Sep 11 15:24 named.ddns.lab.view1.jnl
[vagrant@ns01 ~]$ 
[vagrant@ns01 ~]$ sudo ls -alZ /var/named/
total 20
drwxrwx--T.  5 root  named system_u:object_r:named_zone_t:s0   127 Sep 11 16:35 .
drwxr-xr-x. 20 root  root  system_u:object_r:var_t:s0         4096 Sep 11 14:39 ..
drwxrwx---.  2 named named system_u:object_r:named_cache_t:s0   23 Sep 11 14:39 data
drwxrwx---.  2 named named system_u:object_r:named_cache_t:s0   94 Sep 11 16:36 dynamic
-rw-r-----.  1 root  named system_u:object_r:named_conf_t:s0  2112 Aug 13 11:27 named.ca
-rw-r-----.  1 root  named system_u:object_r:named_zone_t:s0   152 Aug 13 11:27 named.empty
-rw-r-----.  1 root  named system_u:object_r:named_zone_t:s0   152 Aug 13 11:27 named.localhost
-rw-r-----.  1 root  named system_u:object_r:named_zone_t:s0   168 Aug 13 11:27 named.loopback
drwxrwx---.  2 named named system_u:object_r:named_cache_t:s0    6 Aug 13 11:36 slaves
[vagrant@ns01 ~]$ 
[vagrant@ns01 ~]$ sudo ls -alZ /var/named/dynamic
total 16
drwxrwx---. 2 named named system_u:object_r:named_cache_t:s0   94 Sep 11 16:36 .
drwxrwx--T. 5 root  named system_u:object_r:named_zone_t:s0   127 Sep 11 16:35 ..
-rw-r--r--. 1 named named system_u:object_r:named_cache_t:s0 1421 Sep 11 16:36 default.mkeys
-rw-r--r--. 1 named named system_u:object_r:named_cache_t:s0 2590 Sep 11 16:35 default.mkeys.jnl
-rw-r--r--. 1 named named system_u:object_r:named_cache_t:s0 1421 Sep 11 16:36 view1.mkeys
-rw-r--r--. 1 named named system_u:object_r:named_cache_t:s0 2590 Sep 11 16:35 view1.mkeys.jnl
[vagrant@ns01 ~]$ 
```

Из вывода видно, что процесс запущенный процесс named с доменом named_t не может выполнять операции write/записи над объектами с контекстом named_conf_t , но может выполнять операции записи над объектами с контекстом named_zone_t. При этом директория /etc/named/ и все объекты внутри неё имеют контекст named_conf_t (то есть процесс named с доменом named_t может из них только читать, а писать в них не может - отсюда и возникающая ошибка доступа SELinux) - в директории /etc/named/ лежат конфигурации named, которые сам процесс изменять не должен. А дирктория /var/named/ содержит файлы описания статических и динамических зон, которые процесс named может не только читать, но и записывать при получении изменений, поэтому сама директория /var/named/ имеет контекст named_zone_t, а файлы и директории в ней имеют контексты named_zone_t либо named_cache_t (для этих контекстов домен named_t может применять операцию записи).

Проблема в том, что файлы описания статических и динамических зон находятся в дериктории /etc/named/ (где должны находитсья толькл конфигурации самого named), а не в директории /var/named - где они должны находитсья при правильной конфигурации.

Для временного рещения проблемы пробуем изменить контекст директории /etc/named/ и объектов в ней на named_zone_t :

```
[root@ns01 ~]# chcon -R -t named_zone_t /etc/named
[root@ns01 ~]#
[root@ns01 ~]# ls -alZ /etc/named
total 28
drw-rwx---.  3 root named system_u:object_r:named_zone_t:s0      121 Sep 11 14:39 .
drwxr-xr-x. 89 root root  system_u:object_r:etc_t:s0            8192 Sep 11 16:35 ..
drw-rwx---.  2 root named unconfined_u:object_r:named_zone_t:s0   88 Sep 11 15:37 dynamic
-rw-rw----.  1 root named system_u:object_r:named_zone_t:s0      784 Sep 11 14:39 named.50.168.192.rev
-rw-rw----.  1 root named system_u:object_r:named_zone_t:s0      610 Sep 11 14:39 named.dns.lab
-rw-rw----.  1 root named system_u:object_r:named_zone_t:s0      609 Sep 11 14:39 named.dns.lab.view1
-rw-rw----.  1 root named system_u:object_r:named_zone_t:s0      657 Sep 11 14:39 named.newdns.lab
[root@ns01 ~]# 
```

После этого изменения контекста на ns01 повторно пробуем на ВМ client внести изменения в зону:

```
[root@client ~]# nsupdate -k /etc/named.zonetransfer.key
> server 192.168.50.10
> zone ddns.lab
> update add www.ddns.lab. 60 A 192.168.50.15
> send
> quit
[root@client ~]# 
[root@client ~]# dig www.ddns.lab

; <<>> DiG 9.16.23-RH <<>> www.ddns.lab
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 50138
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: 11181d386ec2ffd8010000006aa41d6300d184df9fdad054 (good)
;; QUESTION SECTION:
;www.ddns.lab.			IN	A

;; ANSWER SECTION:
www.ddns.lab.		60	IN	A	192.168.50.15

;; Query time: 3 msec
;; SERVER: 192.168.50.10#53(192.168.50.10)
;; WHEN: Fri Sep 11 15:25:23 UTC 2026
;; MSG SIZE  rcvd: 85

[root@client ~]# 
[root@client ~]# # Делаем reboot сервера ns01 - после ребута ns01 повторной командой проверяем, что внесённые изменения не потерялись
[root@client ~]# 
[root@client ~]# dig www.ddns.lab

; <<>> DiG 9.16.23-RH <<>> www.ddns.lab
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 46139
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: ef37a178d4948c14010000006aa42e34f1e00e0833390bf8 (good)
;; QUESTION SECTION:
;www.ddns.lab.			IN	A

;; ANSWER SECTION:
www.ddns.lab.		60	IN	A	192.168.50.15

;; Query time: 5 msec
;; SERVER: 192.168.50.10#53(192.168.50.10)
;; WHEN: Fri Sep 11 16:37:08 UTC 2026
;; MSG SIZE  rcvd: 85

[root@client ~]# 
```

Важно, что мы не добавили новые правила в политику для назначения этого контекста в каталоге. Значит, что при перемаркировке файлов контекст вернётся на тот, который прописан в файле политики.
Для того, чтобы вернуть правила обратно, можно ввести команду: restorecon -v -R /etc/named - после этого изменения в зону опять не будут сохраняться:

```
[vagrant@ns01 ~]$ sudo restorecon -v -R /etc/named
Relabeled /etc/named from system_u:object_r:named_zone_t:s0 to system_u:object_r:named_conf_t:s0
Relabeled /etc/named/named.dns.lab.view1 from system_u:object_r:named_zone_t:s0 to system_u:object_r:named_conf_t:s0
Relabeled /etc/named/named.dns.lab from system_u:object_r:named_zone_t:s0 to system_u:object_r:named_conf_t:s0
Relabeled /etc/named/dynamic from unconfined_u:object_r:named_zone_t:s0 to unconfined_u:object_r:named_conf_t:s0
Relabeled /etc/named/dynamic/named.ddns.lab from system_u:object_r:named_zone_t:s0 to system_u:object_r:named_conf_t:s0
Relabeled /etc/named/dynamic/named.ddns.lab.view1 from system_u:object_r:named_zone_t:s0 to system_u:object_r:named_conf_t:s0
Relabeled /etc/named/dynamic/named.ddns.lab.view1.jnl from system_u:object_r:named_zone_t:s0 to system_u:object_r:named_conf_t:s0
Relabeled /etc/named/named.newdns.lab from system_u:object_r:named_zone_t:s0 to system_u:object_r:named_conf_t:s0
Relabeled /etc/named/named.50.168.192.rev from system_u:object_r:named_zone_t:s0 to system_u:object_r:named_conf_t:s0
[vagrant@ns01 ~]$ 

[root@client ~]# # После сброса контекста на ns01 на первоначальный
[root@client ~]# 
[root@client ~]# nsupdate -k /etc/named.zonetransfer.key
> server 192.168.50.15
> server 192.168.50.10
> zone ddns.lab
> update add www.ddns.lab. 60 A 192.168.50.16
> send
update failed: SERVFAIL
> quit
[root@client ~]# 
```

В лабе использовалась команда chcon — это временное изменение, которое restorecon или relabel затрут. Чтобы закрепить навсегда, нужно добавить правило в базу semanage fcontext. Если бы мы хотели закрепить сделанные изменения в политиках SELinux, то следовало бы ввести следующие команды:

```
sudo semanage fcontext -a -t named_zone_t "/etc/named(/.*)?" # Команда вносит постоянное правило в политики fcontext 

sudo restorecon -Rv /etc/named/  # Применяет правило к существующим файлам

sudo semanage fcontext -l | grep "/etc/named"   # Проверка, что правило закрепилось
/etc/named(/.*)?    all files    system_u:object_r:named_zone_t:s0

sudo semanage fcontext -d "/etc/named(/.*)?"  # Если нужно откатить обратно и удалить сделанное правило
sudo restorecon -Rv /etc/named/
```

Таким образом, для решания проблемы с невозможностью внесения изменений в динамичекие зоны DNS можно применить три возможных решения:

1. Изменить контекст директории /etc/named и объектов внутри неё с named_conf_t на named_zone_t , чтобы процесс named с доменом name_t мог производить запись в эту директорию и файлы в ней - данный метод использован в лабораторной работе выше. С точки зрения безопасности данный метод открывает уязвимость, так как предоставляет потенциальную возможность процессу named изменять все файлы в директории /etc/named , включчая собственные конфигурации;

2. Перенести файлы описание статических и динамических зон в директорию /var/named с соответствующим изменением в файле конфигурации . Файлы зон при правильной конфигурации named должны лежать в директориях /var/named/ для статических зон, /var/named/dynamic/ для динамических (DDNS):

```
[root@ns01 ~]# cat /etc/named.conf | grep "zone \| file "
    zone "." IN {
    zone "dns.lab" {
        file "/мфк/named/named.dns.lab.view1";   # в исходном файле было /etc/named/named.dns.lab.view1
    zone "ddns.lab" {
        file "/var/named/dynamic/named.ddns.lab.view1";   # в исходном файле было /etc/named/dynamic/named.ddns.lab.view1
    zone "newdns.lab" {
        file "/var/named/named.newdns.lab";   # в исходном файле было /etc/named/named.newdns.lab
    // labs zone reverse
    zone "50.168.192.in-addr.arpa" {
        file "/var/named/named.50.168.192.rev";   # исходном файле было /etc/named/named.50.168.192.rev
    zone "." IN {
    zone "dns.lab" {
        file "/var/named/named.dns.lab";   # исходном файле было /etc/named/named.dns.lab
    zone "ddns.lab" {
        file "/var/named/dynamic/named.ddns.lab";   # исходном файле было /etc/named/dynamic/named.ddns.lab
    zone "newdns.lab" {
        file "/var/named/named.newdns.lab";   # исходном файле было /etc/named/named.newdns.lab
    // labs zone reverse
    zone "50.168.192.in-addr.arpa" {
        file "/var/named/named.50.168.192.rev";   # исходном файле было /etc/named/named.50.168.192.rev
[root@ns01 ~]# 
```

3. Также можно изменить контекст и разрешить запись только в подкаталог dynamic (где .jnl и динамические зоны), а на остальные файлы в /etc/named вернуть named_conf_t :

```
# Основные конфиги — только чтение
sudo semanage fcontext -a -t named_conf_t "/etc/named(/.*)?"
# Но подкаталог dynamic — запись разрешена
sudo semanage fcontext -a -t named_zone_t "/etc/named/dynamic(/.*)?"

sudo restorecon -Rv /etc/named/
```

Правила применяются по принципу «самое конкретное выигрывает»: для /etc/named/dynamic/ сработает правило named_zone_t, для всего остального — named_conf_t.

При таком подходе named может писать только туда, где это действительно нужно (динамически обновляемые зоны), а конфиги и статические зоны остаются read-only.



# КОНЕЦ

### Ниже также приводится справочная общая информация о построении и работе с SELinux (к лабораторной работе непосредственного отношения не имеет):

Q: А есть приёмы, позволяющие удобно работать с SELinux (просмотреть все контексты, все контексты процессов, все контексты файловых объектов, правила доступа к файловым объектам, права доступа процессов). Ну так, чтобы боль от работы с SELinux не была такой сильной, что большинство рекомендаций сразу рекомендует этот SELinux отключать

A: SELinux — это не враг, а инструмент. Боль возникает от непонимания, что именно он блокирует и почему. Вот набор приёмов, которые делают работу с ним предсказуемой.

Быстрая диагностика: что SELinux блокирует прямо сейчас

Самый полезный навык — читать логи аудита:

```
# Все блокировки SELinux за последние 30 минут
sudo ausearch -m AVC,USER_AVC -ts recent

# Или через journalctl
sudo journalctl -t setroubleshoot --since "1 hour ago"
```

Если setroubleshoot не установлен — поставите, он даёт человекочитаемые объяснения:

```
sudo dnf install setroubleshoot setroubleshoot-server
sudo systemctl enable --now setroubleshootd
```

После этого при блокировке в логе появится не просто denied, а пояснение: «процесс X пытался сделать Y с файлом Z, вот как это исправить».


### Просмотр контекстов

Контексты файлов

```
# Контекст одного файла или директории
ls -Z /var/www/html

# Контексты всех файлов в директории (рекурсивно)
ls -dZ /var/www/html/*

# Найти файлы с конкретным контекстом
find / -context "*httpd_sys_content_t*" 2>/dev/null
```

### Контексты процессов

```
# Контекст текущего процесса
ps -eZ | grep $$
id -Z

# Все процессы с контекстами
ps -eZ

# Контекст конкретного процесса
ps -Z -p $(pidof nginx)
```

В выводе ps -eZ первая колонка — это контекст: user:role:type:mls. Чаще всего важна только третья часть — тип (например, httpd_t).

### Все типы в системе

```
seinfo -t | less
```

### Все роли

```
seinfo -r
```

### Все пользователи SELinux (не путать с системными)

```
seinfo -u
```

### Правила доступа: кто куда может

Какие правила действуют для конкретного типа

```
# Что тип httpd_t может делать
sesearch -A -s httpd_t

# Что тип httpd_t может делать с файлами типа httpd_sys_content_t
sesearch -A -s httpd_t -t httpd_sys_content_t

# Все блокировки (deny) для процесса
sesearch -D -s httpd_t
```

### Разрешения между доменами (переходы)

```
# Какие домены могут переходить в httpd_t
sesearch -T -t httpd_t

# Куда может перейти httpd_t
sesearch -T -s httpd_t
```

sesearch и seinfo — из пакета setools-console:

```
sudo dnf install setools-console
```

### Булеаны — переключатели политики

Булеаны — это флаги, включающие/выключающие целые группы правил без переписывания политики:

```
# Все булеаны и их состояние
getsebool -a

# Найти нужный
getsebool -a | grep -i httpd

# Включить
sudo setsebool -P httpd_enable_homedirs on

# Выключить
sudo setsebool -P httpd_can_network_connect off

-P — сохранить между перезагрузками. Без -P — временно до ребута.

## Полный список с описанием:
semanage boolean -l
```

### Работа с контекстами файлов

Посмотреть, какой контекст ДОЛЖЕН быть у пути

```
matchpathcon /var/www/html/index.html
```

Сравните с реальным ls -Z — если не совпадает, значит контекст сбит.

Исправить контекст по умолчанию

```
# Один файл
sudo restorecon -v /var/www/html/index.html

# Рекурсивно
sudo restorecon -Rv /var/www/html/
```

Задать контекст по умолчанию для своего пути

```
# Добавить правило: файлы в /myapp/ получают тип httpd_sys_content_t
sudo semanage fcontext -a -t httpd_sys_content_t "/myapp(/.*)?"

# Применить
sudo restorecon -Rv /myapp/
```

Посмотреть все кастомные правила контекстов

```
semanage fcontext -l | grep -v "^<<"
```

Удалить кастомное правило

```
sudo semanage fcontext -d "/myapp(/.*)?"
```

### Практический сценарий: что делать при блокировке

Допустим, Nginx не читает файл, и вы подозреваете SELinux.

```
# 1. Проверить режим (Enforcing / Permissive / Disabled)
getenforce

# 2. Посмотреть, что заблокировано
sudo ausearch -m AVC -ts recent | grep nginx

# 3. Проверить контекст файла
ls -Z /path/to/file

# 4. Проверить, какой контекст должен быть
matchpathcon /path/to/file

# 5. Исправить
sudo restorecon -v /path/to/file

# 6. Если нужного правила нет — создать модуль из логов аудита
```

### Автоматическое создание модуля из логов аудита

Если блокировка legit и нужно разрешить, не трогая остальную политику:

```
# 1. Создать модуль из логов
sudo ausearch -m AVC -ts recent | audit2allow -M mynginx

# 2. Посмотреть, что он делает
cat mynginx.te

# 3. Установить
sudo semodule -i mynginx.pp

# 4. Удалить, если ошиблись
sudo semodule -r mynginx
```

audit2allow превращает deny-логи в готовое правило-исключение. Это безопаснее, чем отключать SELinux — вы разрешаете ровно то, что нужно.

### Режимы SELinux — мягкая посадка

Переключить в Permissive (логирует, но не блокирует)

```
sudo setenforce 0
```

В этом режиме SELinux пишет в лог все блокировки, но не применяет их. Идеально для отладки: запускаете приложение, смотрите, что он бы заблокировал, и создаёте правила через audit2allow.

Вернуть обратно:

```
sudo setenforce 1
```

Постоянно (переживает ребут)

```
sudo nano /etc/selinux/config
# SELINUX=permissive   — логирует, не блокирует
# SELINUX=enforcing    — блокирует (нормальный режим)
# SELINUX=disabled     — выключен (НЕ рекомендую)
```

### Permissive для одного процесса, а не всей системы

Можно оставить Enforcing глобально, но перевести в Permissive конкретный домен — например, только httpd:

```
sudo semanage permissive -a httpd_t
```

Вернуть:

```
sudo semanage permissive -d httpd_t
```

Это гораздо безопаснее: остальная система защищена, а проблемный сервис временно не блокируется, но логирует.
### Шпаргалка по ежедневным командам

| Что нужно	| Команда |
|:---------------|:-------------------------------------------|
|Режим SELinux	|getenforce |
|Блокировки	 |sudo ausearch -m AVC -ts recent |
|Контекст файла	 |ls -Z /path |
|Контекст процесса	| ps -eZ  grep nginx |
|Какой контекст должен быть	|matchpathcon /path |
| Исправить контекст	|sudo restorecon -Rv /path |
|Булеаны	| getsebool -a |
|Включить булеан	|sudo setsebool -P name on|
|Задать контекст пути	|sudo semanage fcontext -a -t type "/path(/.*)?" |
| Кастомные контексты	|semanage fcontext -l |
Что тип X может делать	sesearch -A -s httpd_t
| Создать модуль из логов	|sudo ausearch -m AVC  audit2allow -M mymod |
|Установить модуль	| sudo semodule -i mymod.pp |
| Список модулей	|sudo semodule -l |
| Перевести домен в Permissive	|sudo semanage permissive -a httpd_t |

### Ключевой принцип

Алгоритм работы с SELinux всегда один и тот же:

    Что заблокировано? → ausearch
	
    Кто и к чему обращается? → ps -Z, ls -Z
	
    Контекст правильный? → matchpathcon + restorecon
	
    Нужен булеан? → getsebool -a | grep ...
	
    Нужно своё правило? → audit2allow + semodule -i
	
    Временно не блокировать? → semanage permissive -a <type>

Если пройти этот путь, SELinux из врага превращается в инструмент: вы точно знаете, что разрешили и почему. Отключение SELinux — это как снять замок с двери, потому что ключ не подходит. Лучше сделать новый ключ.

Q: Спасибо. Но непонимае работы связано ещё и со сложной структурой SELinux, Дай пожалуйста ещё краткое описание общей структуры (домены, контекста,  как они соотносятся с правами процессов, файловыми объектами и проч.).

A: SELinux: как это устроено

### Главная идея

Обычные права Linux (rwx, владелец, группа) — это дискреционное управление (DAC): владелец файла сам решает, кто может его читать. SELinux — это мандатное управление (MAC): система независимо от DAC решает, может ли процесс вообще трогать файл, независимо от того, какой у него UID.

Оба механизма работают одновременно. Чтобы процесс получил доступ, он должен пройти обе проверки: сначала DAC (обычные права), потом MAC (SELinux). Если SELinux сказал «нет» — доступ запрещён, даже если процесс — root.

### Контекст

Контекст — это «ярлык», который висит на каждом процессе и каждом файле. Он состоит из четырёх частей:

```
user : role : type : mls
```

| Часть	| Что это	|Пример |
|:-----|:----------------------------------------------|:------------------------|
|user	|SELinux-пользователь (не системный!)	|unconfined_u, system_u |
| role	|Роль — связующее звено между пользователем и типом	|object_r, system_r |
| type	|Самая важная часть. Тип (домен) — сущность, к которой применяются правила	|httpd_t, httpd_sys_content_t |
|mls	|Уровень секретности (Multi-Level Security)	|s0 |

На практике 95% работы с SELinux — это работа с третьим полем, типом.

### Тип (он же домен) — для процессов

Когда процесс запущен, его контекст выглядит так:

```
system_u:system_r:httpd_t:s0
```

Здесь httpd_t — это домен процесса. Домен определяет, что процесс может и не может делать. Все правила SELinux — это, по сути, «домен X может трогать тип Y с правом Z».

```
system_u:system_r:httpd_t:s0    → процесс nginx (домен httpd_t)
```

### Тип — для файлов

Файлы тоже имеют контекст:

```
system_u:object_r:httpd_sys_content_t:s0
```

Здесь httpd_sys_content_t — это тип файла. Файлы не «выполняются», у них нет домена — у них просто есть тип, который определяет, какие домены-процессы могут к ним обращаться.

### Как это соотносится: правила доступа

Правило SELinux — это тройка «кто → что → к чему»:

```
allow httpd_t httpd_sys_content_t : file { read getattr open } ;
```

Читается так: процесс домена httpd_t может читать (read) файлы типа httpd_sys_content_t.

    httpd_t — источник (домен процесса, source)
	
    httpd_sys_content_t — цель (тип файла, target)
	
    file — класс объекта (файл, сокет, каталог...)
	
    read getattr open — разрешения

Если такого правила нет — доступ запрещён. Даже если DAC разрешает. Даже если процесс — root.

### Полная картина

```
┌─────────────────────────────────────────────────────────┐
│                     СИСТЕМА                              │
│                                                          │
│  Процесс nginx          Файл index.html                  │
│  ┌──────────────┐       ┌──────────────────────┐         │
│  │ Контекст:      │       │ Контекст:              │         │
│  │ httpd_t        │       │ httpd_sys_content_t  │         │
│  │ (домен)        │       │ (тип файла)           │         │
│  └──────┬───────┘       └──────────┬───────────┘         │
│         │                          │                     │
│         │    DAC: rwxr--r--         │                     │
│         │    (обычные права)        │                     │
│         ├──────────────────────────→│                     │
│         │    ✅ Разрешено            │                     │
│         │                          │                     │
│         │    MAC: allow httpd_t     │                     │
│         │    httpd_sys_content_t    │                     │
│         │    : file { read }        │                     │
│         ├──────────────────────────→│                     │
│         │    ✅ Разрешено            │                     │
│         │                          │                     │
│         │    → Доступ разрешён      │                     │
│                                                          │
│  Процесс nginx          Файл /etc/shadow                │
│  ┌──────────────┐       ┌──────────────────────┐         │
│  │ Контекст:      │       │ Контекст:              │         │
│  │ httpd_t        │       │ shadow_t              │         │
│  └──────┬───────┘       └──────────┬───────────┘         │
│         │                          │                     │
│         │    DAC: r--------         │                     │
│         │    (nginx от root)        │                     │
│         ├──────────────────────────→│                     │
│         │    ✅ Разрешено            │                     │
│         │                          │                     │
│         │    MAC: allow httpd_t     │                     │
│         │    shadow_t : file        │                     │
│         │    → правила НЕТ          │                     │
│         ├─────────────✗────────────→│                     │
│         │    ❌ Запрещено            │                     │
│         │                          │                     │
│         │    → Доступ запрещён      │                     │
│         │      (несмотря на DAC)    │                     │
└─────────────────────────────────────────────────────────┘
```

### Роль пользователей

SELinux-пользователь — это не системный пользователь (ivan, root). Это мета-пользователь, который определяет, какие роли и типы доступны:

```
Системный пользователь ivan
    ↓
SELinux-пользователь user_u
    ↓
Роль user_r
    ↓
Домен user_t
```

Большинство обычных пользователей работают как unconfined_u — без ограничений. Системные процессы — как system_u.

### Роль роли

Роль — это мост между пользователем и типом:

    Пользователь привязан к ролям
	
    Роль привязана к типам (доменам)
	
    Поэтому пользователь может «быть» только в тех доменах, которые разрешены его ролям

Для файлов роль всегда object_r — она не имеет смысла, но обязательна по формату.

### Переходы (transitions) — как процесс получает домен

Когда вы запускаете /usr/sbin/nginx, происходит переход типа:

    Процесс init (домен init_t) выполняет /usr/sbin/nginx
	
    SELinux видит: файл /usr/sbin/nginx имеет контекст с типом httpd_exec_t
	
    Правило говорит: «при выполнении файла типа httpd_exec_t перейти в домен httpd_t»
	
    Процесс nginx получает домен httpd_t

```
init_t  ──exec──>  httpd_exec_t  ──transition──>  httpd_t
(родитель)         (файл)                      (новый домен)
```

Это ключевая магия SELinux: домен процесса определяется не тем, кто его запустил, а контекстом исполняемого файла. Поэтому даже если root запускает nginx — nginx всё равно получит домен httpd_t, а не unconfined_t.

### Классы объектов

SELinux различает не только файлы, но и классы объектов:

|Класс	|Что это	| Пример разрешений |
|:-----|:------------------------|:-----------------------------------|
|file	|Обычные файлы и каталоги	|read, write, open, create, unlink|
|dir	|Директории	|add_name, remove_name, search, rmdir|
|socket	|Сокеты	|bind, connect, listen, accept|
|tcp_socket	|TCP-сокеты	|connect, sendto, recvfrom|
|process	|Процессы	|transition, fork, signal, ptrace|
|capability	|Капабилити (capabilities)	|net_bind_service, sys_admin |

### Булеаны — быстрые переключатели

Булеаны — это предопределённые условия в правилах:

```
# Правило:
allow httpd_t httpd_port_t:tcp_socket name_bind;
# С булеаном:
allow httpd_t httpd_port_t:tcp_socket name_bind;
if (httpd_can_network_connect) { ... }
```

Включили httpd_can_network_connect — целая группа правил активировалась. Выключили — деактивировалась. Не нужно писать модули, достаточно одного setsebool.

### Unconfined — «без домена»

Большинство пользовательских процессов работают в домене unconfined_t. Для этого домена разрешено всё — SELinux их не ограничивает. Ограничиваются только системные сервисы: httpd_t, named_t, ntpd_t и т.д.

Это разумный компромисс: обычный пользователь не страдает от SELinux, а взломанный сервис (nginx, bind) не может навредить системе, даже если его скомпрометировали.

### Шпаргалка по структуре

```
ПОЛИТИКА SELinux
├── Пользователи (SELinux)     user_u, system_u, unconfined_u
│   └── Роли                   system_r, object_r, unconfined_r
│       └── Типы/Домены         httpd_t, httpd_sys_content_t
│           └── Правила (allow)  allow httpd_t httpd_sys_content_t:file read;
│               ├── Источник    httpd_t (домен процесса)
│               ├── Цель        httpd_sys_content_t (тип объекта)
│               ├── Класс       file (класс объекта)
│               └── Разрешения  read, write, open...
├── Булеаны                    on/off переключатели групп правил
├── Переходы (transition)      exec файла → домен процесса
└── Модули                     кастомные правила (audit2allow)
```

Если свести к одному предложению: каждый процесс имеет домен, каждый файл имеет тип, и правила говорят, какой домен может что делать с каким типом — а всё остальное запрещено по умолчанию.

Q: Узнать, что именно делает булеан, можно прямо в системе — без отрыва от терминала. Есть три уровня: от краткого описания до полных правил.

### Уровень 1. Краткое описание

```
# Описание конкретного булеана
semanage boolean -l | grep httpd_can_network_connect
```

Вывод:

```
httpd_can_network_connect  (off  ,  off)  Allow httpd to can network connect
```

Здесь:

    (off, off) — текущее состояние и состояние по умолчанию
    Текст — краткое описание

Все булеаны с описаниями:

```
semanage boolean -l
```

Это удобно для общего понимания, но описание часто слишком общее — «Allow httpd to can network connect» не говорит, какие именно правила включаются.

### Уровень 2. Какие правила скрываются за булеаном

Это главный инструмент — sesearch с флагом -b:

```
# Все правила, которые управляются булеаном httpd_can_network_connect
sesearch -b httpd_can_network_connect -A
```

Вывод покажет конкретные allow-правила:

```
allow httpd_t port_t : tcp_socket name_connect ; [ httpd_can_network_connect ]:True
allow httpd_t http_port_t : tcp_socket name_connect ; [ httpd_can_network_connect ]:True
```

Здесь [ httpd_can_network_connect ]:True означает: это правило активно, когда булеан включён. Если выключен — правило не действует.

Только заблокированные (deny) правила

```
sesearch -b httpd_can_network_connect -D
```

Покажет, какие запреты снимаются при включении булеана.

Полный вывод с классами и разрешениями

```
sesearch -b httpd_can_network_connect -A -d
```

Флаг -d показывает детали: классы объектов и конкретные разрешения.

### Уровень 3. Исходник политики

Если хочется увидеть прямо в исходном коде политики:

```
# Найти булеан в исходниках политики
grep -r "httpd_can_network_connect" /usr/share/selinux/devel/ 2>/dev/null

# Или в установленных модулях
sudo semodule -l | grep httpd
```

Для этого нужны пакеты с исходниками политики:

```
sudo dnf install selinux-policy-devel
```

После установки в /usr/share/selinux/devel/ появятся .if и .fc файлы, в которых можно grep'ом найти, как булеан используется:

```
grep -rn "httpd_can_network_connect" /usr/share/selinux/devel/
```

### Практический пример: разбираем булеан

Допустим, Nginx не может подключиться к базе данных по сети. Проверяем:

```
# 1. Что говорит описание
semanage boolean -l | grep httpd_can_network_connect

# 2. Какие правила включает
sesearch -b httpd_can_network_connect -A

# 3. Какой контекст у порта БД
semanage port -l | grep 5432

# 4. Подходит ли правило под наш случай
sesearch -b httpd_can_network_connect -A | grep postgresql_port_t
```

Если в выводе есть строка с postgresql_port_t — значит, включение булеана разрешит Nginx подключаться к PostgreSQL. Включаем:

```
sudo setsebool -P httpd_can_network_connect on
```

### Шпаргалка

|Что нужно	|Команда |
|:--------------------------------|:-------------------------------|
|Список всех булеанов с описанием	|semanage boolean -l |
|Описание одного	|semanage boolean -l  grep имя |
|Состояние одного	| getsebool имя |
|Все правила, управляемые булеаном	|sesearch -b имя -A |
|Запреты, снимаемые булеаном	|sesearch -b имя -D |
|Детальные правила с классами	|sesearch -b имя -A -d |
|Исходник в политике	|grep -r "имя" /usr/share/selinux/devel/ |
|Включить постоянно	|sudo setsebool -P имя on |
|Включить временно	|sudo setsebool имя on |

Итого: semanage boolean -l даёт человекочитаемое описание, а sesearch -b показывает конкретные правила, которые булеан включает или выключает. Этой пары достаточно, чтобы понять, что именно произойдёт при переключении — без чтения документации.

Q: Булеаны, домены, контексты и прочие объекты SELinux можно создавать самостоятельно при необходимости, а также изменять при необходимости ?

A: Да, всё это можно создавать и менять самостоятельно. SELinux — это не монолит, а набор модулей, которые можно добавлять, изменять и удалять. Вот что именно можно делать с каждым типом объекта.

### Контексты файлов

Изменить контекст одного файла (временно, до ребута)

```
sudo chcon -t httpd_sys_content_t /var/www/html/index.html
sudo chcon -Rt httpd_sys_content_t /var/www/html/
```

После restorecon или перезагрузки контекст вернётся к стандартному.

Задать контекст постоянно (правило для пути)

```
# Добавить правило: файлы в /myapp/ получают тип myapp_content_t
sudo semanage fcontext -a -t httpd_sys_content_t "/myapp(/.*)?"

# Применить
sudo restorecon -Rv /myapp/
```

Это переживает ребут. Правило хранится в базе semanage.

Создать собственный тип файла

```
# Создать новый тип, производный от существующего
sudo semanage fcontext -a -t httpd_sys_content_t "/myapp(/.*)?"
```

Но если нужен совершенно новый тип, которого нет в системе — это делается через модуль политики (см. ниже).

## Булеаны

### Стандартные булеаны

Стандартные булеаны заданы в политике. Включать/выключать можно, а создать новый булеан из командной строки нельзя — только через модуль политики.

### Создать собственный булеан (через модуль)

Создайте файл myapp.te:

```
module myapp 1.0;

require {
    type httpd_t;
    type myapp_port_t;
    class tcp_socket name_connect;
}

# Объявить новый булеан
bool myapp_allow_connect true;

# Правило, зависящее от булеана
if (myapp_allow_connect) {
    allow httpd_t myapp_port_t:tcp_socket name_connect;
}
```

Скомпилируйте и установите:

```
checkmodule -M -m -o myapp.mod myapp.te
semodule_package -o myapp.pp myapp.mod
sudo semodule -i myapp.pp
```

После этого появится новый булеан:

```
getsebool myapp_allow_connect
sudo setsebool -P myapp_allow_connect on
```

### Домены (типы процессов)

Создать собственный домен

Создайте файл myapp_cil.cil (формат CIL — современный способ):

```
; Объявить новый тип
(type myapp_t)
(typeattribute myapp_t)
(roletype object_r myapp_t)

; Объявить исполняемый тип для файла
(type myapp_exec_t)
(typeattribute myapp_exec_t)

; Переход: при запуске файла myapp_exec_t процесс переходит в myapp_t
(allow myapp_t myapp_exec_t (file (read execute open map)))
(typetransition init_t myapp_exec_t process myapp_t)

; Разрешить myapp_t читать свои файлы
(type myapp_content_t)
(typeattribute myapp_content_t)
(allow myapp_t myapp_content_t (file (read write open create unlink)))
(allow myapp_t myapp_content_t (dir (read write add_name remove_name search)))
```

Установите:

```
sudo semodule -i myapp_cil.cil
```

Задайте контекст для исполняемого файла:

```
sudo semanage fcontext -a -t myapp_exec_t "/usr/local/bin/myapp"
sudo restorecon -v /usr/local/bin/myapp
```

Теперь при запуске /usr/local/bin/myapp процесс получит домен myapp_t и будет ограничен вашими правилами.

### Упрощённый путь: audit2allow

Чаще всего новый домен не нужен — достаточно создать модуль с правилами для существующего домена:

```
# Собрать блокировки из лога
sudo ausearch -m AVC -ts recent | audit2allow -M mynginx

# Посмотреть, что внутри
cat mynginx.te

# Установить
sudo semodule -i mynginx.pp
```

audit2allow автоматически генерирует require-блок и allow-правила — ничего вручную писать не нужно.

### Роли и пользователи SELinux

Создать новую роль

```
sudo semanage user -a -R "myapp_r" myapp_u
```

Создать SELinux-пользователя и привязать к системному

```
# Создать SELinux-пользователя с ролью user_r
sudo semanage user -a -R "user_r" -P user myapp_u

# Привязать системного пользователя ivan к SELinux-пользователю myapp_u
sudo semanage login -a -s myapp_u ivan
```

Проверить:

```
semanage login -l
```

### Порты

Назначить тип порту

```
# Разрешить httpd слушать порт 8080
sudo semanage port -a -t http_port_t -p tcp 8080
```

Изменить существующее назначение

```
sudo semanage port -m -t http_port_t -p tcp 8080
```

Посмотреть все назначения портов

```
semanage port -l
```

### Модули политики

Посмотреть установленные модули

```
sudo semodule -l
```

Установить модуль

```
sudo semodule -i myapp.pp
```

Удалить модуль

```
sudo semodule -r myapp
```

Обновить модуль

Просто пересоберите и установите заново — semodule -i заменит старую версию.
Практический пример: веб-приложение в нестандартной директории

Допустим, Nginx должен читать файлы из /opt/myapp/, но SELinux блокирует доступ.

```
# 1. Проверить контекст директории
ls -Z /opt/myapp/
# Допустим, там какой-то default_t

# 2. Задать правильный контекст
sudo semanage fcontext -a -t httpd_sys_content_t "/opt/myapp(/.*)?"
sudo restorecon -Rv /opt/myapp/

# 3. Если Nginx должен писать туда — нужен тип для записи
sudo semanage fcontext -a -t httpd_sys_rw_content_t "/opt/myapp/uploads(/.*)?"
sudo restorecon -Rv /opt/myapp/uploads/

# 4. Если нужно подключение к БД — включить булеан
sudo setsebool -P httpd_can_network_connect_db on

# 5. Если что-то всё ещё блокируется — создать модуль
sudo ausearch -m AVC -ts recent | audit2allow -M mynginx
sudo semodule -i mynginx.pp
```

Что можно и чего нельзя делать

|Объект	|Создать новый	|Изменить	|Из командной строки|
|:--------------|:-----------------|:-----------------------------|:-------------------------------|
|Контекст файла	|—	|chcon, semanage fcontext	|Да |
|Тип файла	|Да, через модуль	|semanage fcontext	|Частично |
|Булеан	|Да, через модуль	|setsebool	|Создание — только модуль |
|Домен (тип процесса)	|Да, через модуль	|Через модуль	|Создание — только модуль |
|Роль	|Да, через semanage user	|semanage user	|Да |
|Пользователь SELinux	|Да, через semanage user	|semanage user	|Да |
|Порт	|—	|semanage port	|Да |
|Модуль политики	|Да, semodule -i	|semodule -i (замена)	|Да |
|Правило allow	|Да, через модуль	|Через модуль	|Создание — audit2allow или вручную |

### Итог

Простые вещи — контексты файлов, порты, булеаны, роли — меняются через semanage и setsebool прямо из командной строки. Сложные вещи — новые домены, типы, булеаны, правила — через модули политики, которые компилируются и устанавливаются через semodule. Модули можно создавать как вручную (.te / .cil), так и автоматически через audit2allow.

Ничего из этого не требует отключения SELinux — и это ровно то, для чего SELinux задумывался: гибкая, расширяемая система, которую можно настроить под любую задачу.

Q: А модули .te и .pp чем отличаются ?

A: .te и .pp — это два этапа одного процесса: исходный код политики и её скомпилированная версия.

### .te (Type Enforcement source) — «исходник»

Это текстовый файл с описанием правил SELinux на специальном декларативном языке. В нём ты пишешь: какие типы (домены) создаёшь, какие allow-правила разрешают доступ, какие булеаны влияют на эти правила и т. д.

Пример myapp.te:

```
policy_module(myapp, 1.0.0)

type myapp_t;
type myapp_exec_t;

allow myapp_t myapp_exec_t:file { execute getattr };
typetransition init_t myapp_exec_t process myapp_t;
```

Что можно делать с .te:

    читать и править в редакторе (vi/nano/vscode) — это обычный текст;
	
    генерировать из логов через audit2allow -M name (он создаст .te);
	
    проверять синтаксис и зависимости через checkmodule.

### .pp (Policy Package) — «бинарник» для ядра

Это бинарный файл, который понимает ядро Linux. Его нельзя читать как текст, но именно его ядро загружает и применяет.

.pp получают из .te в два шага:

    checkmodule -M -m -o myapp.mod myapp.te — компиляция в промежуточный модуль.
	
    semodule_package -o myapp.pp -m myapp.mod — упаковка в готовый пакет политики.

Затем его ставят в систему:

```
sudo semodule -i myapp.pp
```

Ключевые отличия

|Характеристика	|.te	|.pp |
|:---------------------------|:--------------------------------|:--------------------------------|
|Формат	|Текст (читаемый человеком)	|Бинарный (только для ядра) |
|Назначение	|Разработка, правка, аудит правил	|Применение политики в системе |
|Где используется	|В процессе сборки, в Git, в скриптах	|При установке через semodule -i |
|Можно ли редактировать напрямую	|Да	|Нет (нужно пересобирать из .te) |
|Зависимости от других типов/правил	|Описываются явно в require	|Уже разрешены на этапе компиляции |

Как это выглядит в типичном рабочем потоке:

Допустим, ты делаешь свой модуль под KVM‑стенд или Vagrant‑бокс:

```
# 1. Генерируем исходный .te из логов AVC
sudo ausearch -m AVC -ts recent | audit2allow -M mystand

# 2. Смотрим, что получилось (читаем .te)
cat mystand.te

# 3. Компилируем в .pp
checkmodule -M -m -o mystand.mod mystand.te
semodule_package -o mystand.pp -m mystand.mod

# 4. Ставим в систему
sudo semodule -i mystand.pp
```

После этого semodule -l покажет твой модуль, а ядро будет применять эти правила.

### Важные нюансы 

    Никогда не правишь .pp вручную. Если нужно изменить правило — меняешь .te, затем заново компилируешь в .pp.
	
    .te можно хранить в репозитории и деплоить как часть инфраструктуры (например, вместе с Vagrantfile или Ansible-ролью). Это удобно для воспроизводимых стендов.
	
    Если модуль не загружается, ошибка обычно на этапе checkmodule или semodule — она укажет, какого типа или правила не хватает. Это как компиляция C‑кода: сначала сборка, потом линковка, потом запуск.
	
    audit2allow по умолчанию сразу делает и .te, и .pp, поэтому новички часто не видят разницы. Но если ты хочешь доработать правила (добавить булеан, убрать лишнее, сделать аккуратнее под свой стенд) — тебе нужен именно .te.

