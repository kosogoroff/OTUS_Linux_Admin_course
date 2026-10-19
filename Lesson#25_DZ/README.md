# Занятие 01.10.2026 "Основы сбора и хранения логов"

Настраиваем центральный сервер для сбора логов

## Цель:

научиться проектировать централизованный сбор логов;
рассмотреть особенности разных платформ для сбора логов.

## Описание/Пошаговая инструкция выполнения домашнего задания:

#### 🎯 Что нужно сделать?

    Поднимаем две машины — web и log.
    На web поднимаем nginx.
    Настраиваем центральный лог-сервер на любой системе по выбору:

    - journald;
    
    - rsyslog;
    
    - elk.

    Настраиваем аудит, который будет отслеживать изменения конфигураций nginx.

    Все критичные логи с web должны собираться и локально и удаленно.
    Все логи с nginx должны уходить на удаленный сервер (локально только критичные).
    Логи аудита должны также уходить на удаленную систему.

# Решение

На центральном сервере конфигурируем вариант с использованием rsyslog.

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

Создаём две ВМ с использованием Vagrantfile :

```
[admin_insta11@mv334 ~]$ mkdir logs_lab
[admin_insta11@mv334 ~]$ cd logs_lab
[admin_insta11@mv334 logs_lab]$ vi Vagrantfile
[admin_insta11@mv334 logs_lab]$ 
[admin_insta11@mv334 logs_lab]$ vi Vagrantfile
[admin_insta11@mv334 logs_lab]$
[admin_insta11@mv334 logs_lab]$ VAGRANT_BOX=ubuntu-22.04-virtualbox vagrant up
Bringing machine 'web' up with 'virtualbox' provider...
Bringing machine 'log' up with 'virtualbox' provider...
==> web: Clearing any previously set forwarded ports...
==> web: Clearing any previously set network interfaces...
==> web: Preparing network interfaces based on configuration...
    web: Adapter 1: nat
    web: Adapter 2: hostonly
==> web: Forwarding ports...
    web: 22 (guest) => 2222 (host) (adapter 1)
==> web: Running 'pre-boot' VM customizations...
==> web: Booting VM...
==> web: Waiting for machine to boot. This may take a few minutes...
    web: SSH address: 127.0.0.1:2222
    web: SSH username: vagrant
    web: SSH auth method: private key
    web: Warning: Connection reset. Retrying...
    web: Warning: Remote connection disconnect. Retrying...
    web: 
    web: Vagrant insecure key detected. Vagrant will automatically replace
    web: this with a newly generated keypair for better security.
    web: 
    web: Inserting generated public key within guest...
    web: Removing insecure key from the guest if it's present...
    web: Key inserted! Disconnecting and reconnecting using new SSH key...
==> web: Machine booted and ready!
==> web: Checking for guest additions in VM...
    web: The guest additions on this VM do not match the installed version of
    web: VirtualBox! In most cases this is fine, but in rare cases it can
    web: prevent things such as shared folders from working properly. If you see
    web: shared folder errors, please make sure the guest additions within the
    web: virtual machine match the version of VirtualBox you have installed on
    web: your host and reload your VM.
    web: 
    web: Guest Additions Version: 7.2.4
    web: VirtualBox Version: 7.1
==> web: Setting hostname...
==> web: Configuring and enabling network interfaces...
==> web: Mounting shared folders...
    web: /home/admin_insta11/logs_lab => /vagrant
==> log: Importing base box 'ubuntu-22.04-virtualbox'...
==> log: Matching MAC address for NAT networking...
==> log: Setting the name of the VM: logs_lab_log_1792331159105_72323
==> log: Fixed port collision for 22 => 2222. Now on port 2200.
==> log: Clearing any previously set network interfaces...
==> log: Preparing network interfaces based on configuration...
    log: Adapter 1: nat
    log: Adapter 2: hostonly
==> log: Forwarding ports...
    log: 22 (guest) => 2200 (host) (adapter 1)
==> log: Running 'pre-boot' VM customizations...
==> log: Booting VM...
==> log: Waiting for machine to boot. This may take a few minutes...
    log: SSH address: 127.0.0.1:2200
    log: SSH username: vagrant
    log: SSH auth method: private key
    log: 
    log: Vagrant insecure key detected. Vagrant will automatically replace
    log: this with a newly generated keypair for better security.
    log: 
    log: Inserting generated public key within guest...
    log: Removing insecure key from the guest if it's present...
    log: Key inserted! Disconnecting and reconnecting using new SSH key...
==> log: Machine booted and ready!
==> log: Checking for guest additions in VM...
    log: The guest additions on this VM do not match the installed version of
    log: VirtualBox! In most cases this is fine, but in rare cases it can
    log: prevent things such as shared folders from working properly. If you see
    log: shared folder errors, please make sure the guest additions within the
    log: virtual machine match the version of VirtualBox you have installed on
    log: your host and reload your VM.
    log: 
    log: Guest Additions Version: 7.2.4
    log: VirtualBox Version: 7.1
==> log: Setting hostname...
==> log: Configuring and enabling network interfaces...
==> log: Mounting shared folders...
    log: /home/admin_insta11/logs_lab => /vagrant
[admin_insta11@mv334 logs_lab]$
[admin_insta11@mv334 logs_lab]$ ping 192.168.56.10
PING 192.168.56.10 (192.168.56.10) 56(84) bytes of data.
64 bytes from 192.168.56.10: icmp_seq=1 ttl=64 time=0.987 ms
64 bytes from 192.168.56.10: icmp_seq=2 ttl=64 time=0.651 ms
64 bytes from 192.168.56.10: icmp_seq=3 ttl=64 time=0.556 ms
^C
--- 192.168.56.10 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2011ms
rtt min/avg/max/mdev = 0.556/0.731/0.987/0.184 ms
[admin_insta11@mv334 logs_lab]$ ping 192.168.56.15
PING 192.168.56.15 (192.168.56.15) 56(84) bytes of data.
64 bytes from 192.168.56.15: icmp_seq=1 ttl=64 time=1.02 ms
64 bytes from 192.168.56.15: icmp_seq=2 ttl=64 time=0.719 ms
64 bytes from 192.168.56.15: icmp_seq=3 ttl=64 time=0.744 ms
^C
--- 192.168.56.15 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2042ms
rtt min/avg/max/mdev = 0.719/0.829/1.024/0.138 ms
[admin_insta11@mv334 logs_lab]$ 
[admin_insta11@mv334 logs_lab]$ vagrant status
Current machine states:

web                       running (virtualbox)
log                       running (virtualbox)

This environment represents multiple VMs. The VMs are all listed
above with their current state. For more information about a specific
VM, run `vagrant status NAME`.
[admin_insta11@mv334 logs_lab]$ 
```

### 2. На ВМ web поднимаем nginx

Заходим на ВМ web , проверяем синхронизацию времени и правильность даты/времени, затем устанавливаем nginx и проверяем его доступность:

```
[admin_insta11@mv334 logs_lab]$ vagrant ssh web
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-160-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

 System information as of Sun Oct 18 02:35:10 PM UTC 2026

  System load:           0.09
  Usage of /:            15.3% of 30.34GB
  Memory usage:          16%
  Swap usage:            0%
  Processes:             158
  Users logged in:       0
  IPv4 address for eth0: 10.0.2.15
  IPv6 address for eth0: fd17:625c:f037:2:a00:27ff:fe16:ddef


This system is built by the Bento project by Chef Software
More information can be found at https://github.com/chef/bento

Use of this system is acceptance of the OS vendor EULA and License Agreements.
vagrant@web:~$ sudo -i
root@web:~# 
root@web:~# timedatectl set-ntp true
root@web:~# 
root@web:~# timedatectl timesync-status
       Server: 91.189.91.157 (ntp.ubuntu.com)
Poll interval: 32s (min: 32s; max 34min 8s)
         Leap: normal
      Version: 4
      Stratum: 2
    Reference: 84A36001
    Precision: 1us (-24)
Root distance: 22.459ms (max: 5s)
       Offset: -1.377106s
        Delay: 168.645ms
       Jitter: 0
 Packet count: 1
    Frequency: -500.000ppm
root@web:~#
root@web:~# apt update && apt install -y nginx
Get:1 http://security.ubuntu.com/ubuntu jammy-security InRelease [129 kB]
<...>
Processing triggers for ufw (0.36.1-4ubuntu0.1) ...
Processing triggers for man-db (2.10.2-1) ...
Processing triggers for libc-bin (2.35-0ubuntu3.11) ...
Scanning processes...                                                                                             
Scanning linux images...                                                                                          

Running kernel seems to be up-to-date.

No services need to be restarted.

No containers need to be restarted.

No user sessions are running outdated binaries.

No VM guests are running outdated hypervisor (qemu) binaries on this host.
root@web:~# 
root@web:~# 
root@web:~# systemctl status nginx
● nginx.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/lib/systemd/system/nginx.service; enabled; vendor preset: enabled)
     Active: active (running) since Sun 2026-10-18 14:50:33 UTC; 36s ago
       Docs: man:nginx(8)
    Process: 2887 ExecStartPre=/usr/sbin/nginx -t -q -g daemon on; master_process on; (code=exited, status=0/SUCC>
    Process: 2888 ExecStart=/usr/sbin/nginx -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
   Main PID: 2980 (nginx)
      Tasks: 3 (limit: 1585)
     Memory: 4.7M
        CPU: 52ms
     CGroup: /system.slice/nginx.service
             ├─2980 "nginx: master process /usr/sbin/nginx -g daemon on; master_process on;"
             ├─2982 "nginx: worker process" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" >
             └─2983 "nginx: worker process" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" >

Oct 18 14:50:33 web systemd[1]: Starting A high performance web server and a reverse proxy server...
Oct 18 14:50:33 web systemd[1]: Started A high performance web server and a reverse proxy server.
root@web:~# 
root@web:~# 
root@web:~# ss -tln | grep 80
LISTEN 0      511          0.0.0.0:80        0.0.0.0:*          
LISTEN 0      511             [::]:80           [::]:*          
root@web:~# 
root@web:~# ss -tlnp | grep 80
LISTEN 0      511          0.0.0.0:80        0.0.0.0:*    users:(("nginx",pid=2983,fd=6),("nginx",pid=2982,fd=6),("nginx",pid=2980,fd=6))
LISTEN 0      511             [::]:80           [::]:*    users:(("nginx",pid=2983,fd=7),("nginx",pid=2982,fd=7),("nginx",pid=2980,fd=7))
root@web:~#
```

Добавляем в конфигурацию nginx настройки для передачи сообщений nginx на удалённый сервер 192.168.56.15 :

```
root@web:~# nginx -v
nginx version: nginx/1.18.0 (Ubuntu)
root@web:~#
root@web:~# 
root@web:~# vi /etc/nginx/nginx.conf
root@web:~#
root@web:~# cat /etc/nginx/nginx.conf
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
	worker_connections 768;
	# multi_accept on;
}

http {

	##
	# Basic Settings
	##

	sendfile on;
	tcp_nopush on;
	types_hash_max_size 2048;
	# server_tokens off;

	# server_names_hash_bucket_size 64;
	# server_name_in_redirect off;

	include /etc/nginx/mime.types;
	default_type application/octet-stream;

	##
	# SSL Settings
	##

	ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3; # Dropping SSLv3, ref: POODLE
	ssl_prefer_server_ciphers on;

	##
	# Logging Settings
	##

	access_log /var/log/nginx/access.log;
	access_log syslog:server=192.168.56.15:514,tag=nginx_access,severity=info combined;
	error_log /var/log/nginx/error.log;
	error_log syslog:server=192.168.56.15:514,tag=nginx_error;
	##
	# Gzip Settings
	##

	gzip on;

	# gzip_vary on;
	# gzip_proxied any;
	# gzip_comp_level 6;
	# gzip_buffers 16 8k;
	# gzip_http_version 1.1;
	# gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

	##
	# Virtual Host Configs
	##

	include /etc/nginx/conf.d/*.conf;
	include /etc/nginx/sites-enabled/*;
}
root@web:~#
root@web:~# nginx -t
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
root@web:~# 
root@web:~# systemctl restart nginx
root@web:~# 

```

Также с хоста открывается страница nginx в ВМ web:

<img width="625" height="398" alt="изображение" src="https://github.com/user-attachments/assets/c9aea3d0-7bcc-4f65-84b1-b97887a105b1" />


### 3. Настраиваем rsyslog на ВМ log

Настраиваем на ВМ log rsyslog сервер (открываем порты TCP 514 и UDP 514) и правила для приёма сообщений с удалённых хостов, а также для сохранения логов в файлы.

Данные параметры будут отправлять в папку /var/log/rsyslog логи, которые будут приходить от других серверов. Например, Access-логи nginx от сервера web, будут идти в файл /var/log/rsyslog/web/nginx_access.log

Перегружаем rsyslog, убеждаемся, что сервер rsyslog начал слушать порты TCP 514 и UDP 514:

```
root@log:~# apt list rsyslog
Listing... Done
rsyslog/jammy-updates,jammy-security,now 8.2112.0-2ubuntu2.2 amd64 [installed,automatic]
root@log:~# 
root@log:~# cat /etc/rsyslog.conf 
# /etc/rsyslog.conf configuration file for rsyslog
#
# For more information install rsyslog-doc and see
# /usr/share/doc/rsyslog-doc/html/configuration/index.html
#
# Default logging rules can be found in /etc/rsyslog.d/50-default.conf


#################
#### MODULES ####
#################

module(load="imuxsock") # provides support for local system logging
#module(load="immark")  # provides --MARK-- message capability

# provides UDP syslog reception
module(load="imudp")
input(type="imudp" port="514")

# provides TCP syslog reception
module(load="imtcp")
input(type="imtcp" port="514")

# provides kernel logging support and enable non-kernel klog messages
module(load="imklog" permitnonkernelfacility="on")

###########################
#### GLOBAL DIRECTIVES ####
###########################

#
# Use traditional timestamp format.
# To enable high precision timestamps, comment out the following line.
#
$ActionFileDefaultTemplate RSYSLOG_TraditionalFileFormat

# Filter duplicated messages
$RepeatedMsgReduction on

#
# Set the default permissions for all log files.
#
$FileOwner syslog
$FileGroup adm
$FileCreateMode 0640
$DirCreateMode 0755
$Umask 0022
$PrivDropToUser syslog
$PrivDropToGroup syslog

#
# Where to place spool and state files
#
$WorkDirectory /var/spool/rsyslog

#
# Include all config files in /etc/rsyslog.d/
#
$IncludeConfig /etc/rsyslog.d/*.conf

#Add remote logs
$template RemoteLogs,"/var/log/rsyslog/%HOSTNAME%/%PROGRAMNAME%.log"
*.* ?RemoteLogs
& ~
root@log:~#
root@log:~# systemctl restart rsyslog
root@log:~# 
root@log:~# ss -tlnp | grep 514
LISTEN 0      25           0.0.0.0:514       0.0.0.0:*    users:(("rsyslogd",pid=2394,fd=7))       
LISTEN 0      25              [::]:514          [::]:*    users:(("rsyslogd",pid=2394,fd=8))       
root@log:~# 
```

Далее несколько раз обновляем на хосте в броузере WEB-страницу nginx - при этом на ВМ log появляется лог файл access.log с сообщениями о доступе к странице. Лог ошибок пока не появляется, так как ошибок при доступе нет:

```
root@log:~# cat /var/log/rsyslog/web/nginx_access.log
Oct 18 15:13:21 web nginx_access: 192.168.56.1 - - [18/Oct/2026:15:13:21 +0000] "GET / HTTP/1.1" 304 0 "-" "Mozilla/5.0 (X11; Linux x86_64; Chromium GOST) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36"
Oct 18 15:13:27 web nginx_access: 192.168.56.1 - - [18/Oct/2026:15:13:27 +0000] "GET / HTTP/1.1" 304 0 "-" "Mozilla/5.0 (X11; Linux x86_64; Chromium GOST) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36"
Oct 18 15:13:28 web nginx_access: 192.168.56.1 - - [18/Oct/2026:15:13:28 +0000] "GET / HTTP/1.1" 304 0 "-" "Mozilla/5.0 (X11; Linux x86_64; Chromium GOST) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36"
Oct 18 15:13:29 web nginx_access: 192.168.56.1 - - [18/Oct/2026:15:13:29 +0000] "GET / HTTP/1.1" 304 0 "-" "Mozilla/5.0 (X11; Linux x86_64; Chromium GOST) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36"
root@log:~# 
root@log:~# cat /var/log/rsyslog/web/nginx_error.log
cat: /var/log/rsyslog/web/nginx_error.log: No such file or directory
root@log:~# 
root@log:~# ll /var/log/rsyslog/web/
total 16
drwxr-xr-x 2 syslog syslog 4096 Oct 18 15:16 ./
drwxr-xr-x 4 syslog syslog 4096 Oct 18 15:13 ../
-rw-r----- 1 syslog adm    1132 Oct 18 15:16 nginx_access.log
root@log:~# 

```

Далее перемещаем страницу nginx на ВМ web:

```
mv /var/www/html/index.nginx-debian.html /var/www/
```

и пробуем повторно обновить страницу в WEB-броузере. При этом в броузере получаем ошибку 403:

<img width="625" height="404" alt="изображение" src="https://github.com/user-attachments/assets/1a55766f-7e40-4cef-a6ae-b91a6d257d38" />

При этом на ВМ log появляется лог файл error.log с сообщениями об ошибках доступа к странице:

```
root@log:~# ll /var/log/rsyslog/web/
total 16
drwxr-xr-x 2 syslog syslog 4096 Oct 18 15:16 ./
drwxr-xr-x 4 syslog syslog 4096 Oct 18 15:13 ../
-rw-r----- 1 syslog adm    1132 Oct 18 15:16 nginx_access.log
-rw-r----- 1 syslog adm     207 Oct 18 15:16 nginx_error.log
root@log:~# 
root@log:~# cat /var/log/rsyslog/web/nginx_error.log
Oct 18 15:16:39 web nginx_error: 2026/10/18 15:16:39 [error] 3069#3069: *3 directory index of "/var/www/html/" is forbidden, client: 192.168.56.1, server: _, request: "GET / HTTP/1.1", host: "192.168.56.10"
root@log:~# 
root@log:~# 
root@log:~# cat /var/log/rsyslog/web/nginx_access.log
Oct 18 15:13:21 web nginx_access: 192.168.56.1 - - [18/Oct/2026:15:13:21 +0000] "GET / HTTP/1.1" 304 0 "-" "Mozilla/5.0 (X11; Linux x86_64; Chromium GOST) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36"
Oct 18 15:13:27 web nginx_access: 192.168.56.1 - - [18/Oct/2026:15:13:27 +0000] "GET / HTTP/1.1" 304 0 "-" "Mozilla/5.0 (X11; Linux x86_64; Chromium GOST) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36"
Oct 18 15:13:28 web nginx_access: 192.168.56.1 - - [18/Oct/2026:15:13:28 +0000] "GET / HTTP/1.1" 304 0 "-" "Mozilla/5.0 (X11; Linux x86_64; Chromium GOST) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36"
Oct 18 15:13:29 web nginx_access: 192.168.56.1 - - [18/Oct/2026:15:13:29 +0000] "GET / HTTP/1.1" 304 0 "-" "Mozilla/5.0 (X11; Linux x86_64; Chromium GOST) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36"
Oct 18 15:16:39 web nginx_access: 192.168.56.1 - - [18/Oct/2026:15:16:39 +0000] "GET / HTTP/1.1" 403 196 "-" "Mozilla/5.0 (X11; Linux x86_64; Chromium GOST) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36"
root@log:~# 
```

**Вывод:** логи передаются сервером nginx в ВМ web на rsyslog server в ВМ log. При этом rsyslog server в ВМ log распределяет получаемые сообщения по соответствующим логам


## 4. Настраиваем на ВМ web аудит изменения конфигурации nginx и передачу логов аудита на сервер rsyslog

#### 4.1 Установка аудита и настройка правил 

Устанавливаем на ВМ log пакет auditd:

```
root@web:~# apt update
Hit:1 http://security.ubuntu.com/ubuntu jammy-security InRelease
Hit:2 http://us.archive.ubuntu.com/ubuntu jammy InRelease          
Hit:3 http://us.archive.ubuntu.com/ubuntu jammy-updates InRelease
Hit:4 http://us.archive.ubuntu.com/ubuntu jammy-backports InRelease
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
191 packages can be upgraded. Run 'apt list --upgradable' to see them.
root@web:~# 
root@web:~# apt install auditd audispd-plugins
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
The following additional packages will be installed:
  libaudit-common libaudit1 libauparse0
The following NEW packages will be installed:
  audispd-plugins auditd libauparse0
The following packages will be upgraded:
  libaudit-common libaudit1
2 upgraded, 3 newly installed, 0 to remove and 189 not upgraded.
<...>

No VM guests are running outdated hypervisor (qemu) binaries on this host.
root@web:~# 
root@web:~# 
root@web:~# systemctl status auditd
● auditd.service - Security Auditing Service
     Loaded: loaded (/lib/systemd/system/auditd.service; enabled; vendor preset: enabled)
     Active: active (running) since Sun 2026-10-18 15:28:31 UTC; 42s ago
       Docs: man:auditd(8)
             https://github.com/linux-audit/audit-documentation
   Main PID: 3680 (auditd)
      Tasks: 2 (limit: 1585)
     Memory: 472.0K
        CPU: 54ms
     CGroup: /system.slice/auditd.service
             └─3680 /sbin/auditd

Oct 18 15:28:31 web augenrules[3693]: enabled 1
Oct 18 15:28:31 web augenrules[3693]: failure 1
Oct 18 15:28:31 web augenrules[3693]: pid 3680
Oct 18 15:28:31 web augenrules[3693]: rate_limit 0
Oct 18 15:28:31 web augenrules[3693]: backlog_limit 8192
Oct 18 15:28:31 web augenrules[3693]: lost 0
Oct 18 15:28:31 web augenrules[3693]: backlog 0
Oct 18 15:28:31 web augenrules[3693]: backlog_wait_time 60000
Oct 18 15:28:31 web augenrules[3693]: backlog_wait_time_actual 0
Oct 18 15:28:31 web systemd[1]: Started Security Auditing Service.
root@web:~# 
root@web:~# systemctl enable --now auditd
Synchronizing state of auditd.service with SysV service script with /lib/systemd/systemd-sysv-install.
Executing: /lib/systemd/systemd-sysv-install enable auditd
root@web:~# 
root@web:~#
```

и настраиваем правила для наблюдения за изменениями конфигурации nginx (также для реального применения правил необходимо перезагрузить auditd - ниже
видно, что именно после перезагрузки сервиса enabled становится равным 1 - количество применённых правил):

```
root@web:~# vi /etc/audit/rules.d/50-web-audit.rules
root@web:~#
cat /etc/audit/rules.d/50-web-audit.rules
-w /etc/nginx -p wa -k nginx_config
root@web:~#
root@web:~# augenrules --check
/usr/sbin/augenrules: Rules have changed and should be updated
root@web:~# 
root@web:~# augenrules --load
/usr/sbin/augenrules: No change
No rules
enabled 0
failure 1
pid 3680
rate_limit 0
backlog_limit 8192
lost 0
backlog 0
backlog_wait_time 60000
backlog_wait_time_actual 0
enabled 0
failure 1
pid 3680
rate_limit 0
backlog_limit 8192
lost 0
backlog 0
backlog_wait_time 60000
backlog_wait_time_actual 0
enabled 0
failure 1
pid 3680
rate_limit 0
backlog_limit 8192
lost 0
backlog 0
backlog_wait_time 60000
backlog_wait_time_actual 0
root@web:~# 
root@web:~# auditctl -l
-w /etc/nginx -p wa -k nginx_config
root@web:~# 
root@web:~# sudo auditctl -l | grep nginx_config
-w /etc/nginx -p wa -k nginx_config
root@web:~# 
root@web:~# auditctl -s
enabled 0
failure 1
pid 3680
rate_limit 0
backlog_limit 8192
lost 0
backlog 0
backlog_wait_time 60000
backlog_wait_time_actual 0
loginuid_immutable 0 unlocked
root@web:~# 
root@web:~# 
root@web:~# systemctl restart auditd
root@web:~# 
root@web:~# auditctl -s
enabled 1
failure 1
pid 4140
rate_limit 0
backlog_limit 8192
lost 0
backlog 0
backlog_wait_time 60000
backlog_wait_time_actual 0
loginuid_immutable 0 unlocked
root@web:~# 
```

Для проверки создаём и удаляем в директории /etc/nginx/ файл - при этом в логе auditd появляются сообщения о создании и удалении этого файла:

```
root@web:~# cat > /etc/nginx/tempfile
45234523452354
root@web:~# 
root@web:~# rm /etc/nginx/tempfile
root@web:~# 
root@web:~# ausearch -k nginx_config -i
----
type=PROCTITLE msg=audit(10/18/2026 15:53:42.193:138) : proctitle=/sbin/auditctl -R /etc/audit/audit.rules 
type=SOCKADDR msg=audit(10/18/2026 15:53:42.193:138) : saddr={ saddr_fam=netlink nlnk-fam=16 nlnk-pid=0 } 
type=SYSCALL msg=audit(10/18/2026 15:53:42.193:138) : arch=x86_64 syscall=sendto success=yes exit=1080 a0=0x3 a1=0x7fffd94f17c0 a2=0x438 a3=0x0 items=0 ppid=4144 pid=4154 auid=unset uid=root gid=root euid=root suid=root fsuid=root egid=root sgid=root fsgid=root tty=(none) ses=unset comm=auditctl exe=/usr/sbin/auditctl subj=unconfined key=(null) 
type=CONFIG_CHANGE msg=audit(10/18/2026 15:53:42.193:138) : auid=unset ses=unset subj=unconfined op=add_rule key=nginx_config list=exit res=no 
----
type=PROCTITLE msg=audit(10/18/2026 15:53:56.949:140) : proctitle=-bash 
type=PATH msg=audit(10/18/2026 15:53:56.949:140) : item=1 name=/etc/nginx/tempfile inode=394454 dev=fd:00 mode=file,644 ouid=root ogid=root rdev=00:00 nametype=CREATE cap_fp=none cap_fi=none cap_fe=0 cap_fver=0 cap_frootid=0 
type=PATH msg=audit(10/18/2026 15:53:56.949:140) : item=0 name=/etc/nginx/ inode=394282 dev=fd:00 mode=dir,755 ouid=root ogid=root rdev=00:00 nametype=PARENT cap_fp=none cap_fi=none cap_fe=0 cap_fver=0 cap_frootid=0 
type=CWD msg=audit(10/18/2026 15:53:56.949:140) : cwd=/root 
type=SYSCALL msg=audit(10/18/2026 15:53:56.949:140) : arch=x86_64 syscall=openat success=yes exit=3 a0=AT_FDCWD a1=0x55c88e31bd80 a2=O_WRONLY|O_CREAT|O_TRUNC a3=0x1b6 items=2 ppid=1692 pid=4160 auid=vagrant uid=root gid=root euid=root suid=root fsuid=root egid=root sgid=root fsgid=root tty=pts1 ses=4 comm=bash exe=/usr/bin/bash subj=unconfined key=nginx_config 
----
type=PROCTITLE msg=audit(10/18/2026 15:54:09.545:141) : proctitle=rm /etc/nginx/tempfile 
type=PATH msg=audit(10/18/2026 15:54:09.545:141) : item=1 name=/etc/nginx/tempfile inode=394454 dev=fd:00 mode=file,644 ouid=root ogid=root rdev=00:00 nametype=DELETE cap_fp=none cap_fi=none cap_fe=0 cap_fver=0 cap_frootid=0 
type=PATH msg=audit(10/18/2026 15:54:09.545:141) : item=0 name=/etc/nginx/ inode=394282 dev=fd:00 mode=dir,755 ouid=root ogid=root rdev=00:00 nametype=PARENT cap_fp=none cap_fi=none cap_fe=0 cap_fver=0 cap_frootid=0 
type=CWD msg=audit(10/18/2026 15:54:09.545:141) : cwd=/root 
type=SYSCALL msg=audit(10/18/2026 15:54:09.545:141) : arch=x86_64 syscall=unlinkat success=yes exit=0 a0=AT_FDCWD a1=0x55d4b142e4d0 a2=0x0 a3=0x100 items=2 ppid=1692 pid=4161 auid=vagrant uid=root gid=root euid=root suid=root fsuid=root egid=root sgid=root fsgid=root tty=pts1 ses=4 comm=rm exe=/usr/bin/rm subj=unconfined key=nginx_config 
root@web:~# 
```
