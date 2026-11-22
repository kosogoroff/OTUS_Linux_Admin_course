# Занятие 12.11.2026 "35 - Мосты, туннели и VPN"

VPN

## Цель:

Создать домашнюю сетевую лабораторию. Научится настраивать VPN-сервер в Linux-based системах.

## Описание/Пошаговая инструкция выполнения домашнего задания:


### Что нужно сделать?

1)Настроить VPN между двумя ВМ в tun/tap режимах, замерить скорость в туннелях, сделать вывод об отличающихся показателях

2)Поднять RAS на базе OpenVPN с клиентскими сертификатами, подключиться с локальной машины на ВМ

Задание со звездочкой

3)Самостоятельно изучить и настроить ocserv, подключиться с хоста к ВМ
Формат сдачи ДЗ - vagrant + ansible

# Решение 

Ниже приведён Vagrantfile для создания двух ВМ для выполнения домашнего задания:

```
BOX_NAME = ENV['VAGRANT_BOX'] || 'bento/ubuntu-22.04'

Vagrant.configure("2") do |config|
  config.vm.box = BOX_NAME 
  config.vm.define "server" do |server| 
    server.vm.hostname = "server.loc" 
    server.vm.network "private_network", ip: "192.168.56.10" 
  end 

  config.vm.define "client" do |client| 
    client.vm.hostname = "client.loc" 
    client.vm.network "private_network", ip: "192.168.56.20" 
  end 
end
```



```
[admin_insta11@mv334 vpn_lab]$ VAGRANT_BOX=ubuntu-22.04-virtualbox vagrant up
Bringing machine 'server' up with 'virtualbox' provider...
Bringing machine 'client' up with 'virtualbox' provider...
==> server: Importing base box 'ubuntu-22.04-virtualbox'...
==> server: Matching MAC address for NAT networking...
==> server: Setting the name of the VM: vpn_lab_server_1795015387200_60066
==> server: Clearing any previously set network interfaces...
==> server: Preparing network interfaces based on configuration...
    server: Adapter 1: nat
    server: Adapter 2: hostonly
==> server: Forwarding ports...
    server: 22 (guest) => 2222 (host) (adapter 1)
==> server: Booting VM...
==> server: Waiting for machine to boot. This may take a few minutes...
    server: SSH address: 127.0.0.1:2222
    server: SSH username: vagrant
    server: SSH auth method: private key
    server: Warning: Connection reset. Retrying...
    server: Warning: Remote connection disconnect. Retrying...
    server: 
    server: Vagrant insecure key detected. Vagrant will automatically replace
    server: this with a newly generated keypair for better security.
    server: 
    server: Inserting generated public key within guest...
    server: Removing insecure key from the guest if it's present...
    server: Key inserted! Disconnecting and reconnecting using new SSH key...
==> server: Machine booted and ready!
==> server: Checking for guest additions in VM...
    server: The guest additions on this VM do not match the installed version of
    server: VirtualBox! In most cases this is fine, but in rare cases it can
    server: prevent things such as shared folders from working properly. If you see
    server: shared folder errors, please make sure the guest additions within the
    server: virtual machine match the version of VirtualBox you have installed on
    server: your host and reload your VM.
    server: 
    server: Guest Additions Version: 7.2.4
    server: VirtualBox Version: 7.1
==> server: Setting hostname...
==> server: Configuring and enabling network interfaces...
==> server: Mounting shared folders...
    server: /home/admin_insta11/vpn_lab => /vagrant
==> client: Importing base box 'ubuntu-22.04-virtualbox'...
==> client: Matching MAC address for NAT networking...
==> client: Setting the name of the VM: vpn_lab_client_1795015489191_14696
==> client: Fixed port collision for 22 => 2222. Now on port 2200.
==> client: Clearing any previously set network interfaces...
==> client: Preparing network interfaces based on configuration...
    client: Adapter 1: nat
    client: Adapter 2: hostonly
==> client: Forwarding ports...
    client: 22 (guest) => 2200 (host) (adapter 1)
==> client: Booting VM...
==> client: Waiting for machine to boot. This may take a few minutes...
    client: SSH address: 127.0.0.1:2200
    client: SSH username: vagrant
    client: SSH auth method: private key
    client: Warning: Connection reset. Retrying...
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
    client: /home/admin_insta11/vpn_lab => /vagrant
[admin_insta11@mv334 vpn_lab]$ 
[admin_insta11@mv334 vpn_lab]$ 
[admin_insta11@mv334 vpn_lab]$ vagrant status


Current machine states:

server                    running (virtualbox)
client                    running (virtualbox)

This environment represents multiple VMs. The VMs are all listed
above with their current state. For more information about a specific
VM, run `vagrant status NAME`.
[admin_insta11@mv334 vpn_lab]$
```

1. Организация защищённого соединения между ВМ с использованием OpenVPN.


1.1 Установка необходимых пакетов на ВМ1 и ВМ2, отключение SELinux:

```
[admin_insta11@mv334 vpn_lab]$ vagrant ssh server
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-160-generic x86_64)

Use of this system is acceptance of the OS vendor EULA and License Agreements.
vagrant@server:~$ 
vagrant@server:~$ sudo -i
root@server:~# 
root@server:~# apt update
Get:1 http://security.ubuntu.com/ubuntu jammy-security InRelease [129 kB]
Get:2 http://security.ubuntu.com/ubuntu jammy-security/main amd64 Packages [3,718 kB]
<...>
root@server:~# 
root@server:~# apt install openvpn iperf3 selinux-utils
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
The following additional packages will be installed:
  libiperf0 libpkcs11-helper1 libsctp1
Suggested packages:
  lksctp-tools resolvconf openvpn-systemd-resolved easy-rsa
The following NEW packages will be installed:
  iperf3 libiperf0 libpkcs11-helper1 libsctp1 openvpn selinux-utils
0 upgraded, 6 newly installed, 0 to remove and 201 not upgraded.
Need to get 883 kB of archives.
After this operation, 2,781 kB of additional disk space will be used.
Do you want to continue? [Y/n] y
<...>
root@server:~# setenforce 0
setenforce: SELinux is disabled
root@server:~# 
```
На ВМ2 аналогично, не приводится.


1.2 Конфигурирование openvpn

1.2.1 Конфигурирование openvpn на ВМ1, генерация ключа, пересылка его на ВМ2:

```
root@server:~# openvpn --genkey secret /etc/openvpn/static.key
root@server:~# 
root@server:~# vim /etc/openvpn/server.conf
root@server:~#
root@server:~# cat /etc/openvpn/server.conf
dev tap
ifconfig 10.10.10.1 255.255.255.0 
topology subnet 
secret /etc/openvpn/static.key 
comp-lzo 
status /var/log/openvpn-status.log 
log /var/log/openvpn.log  
verb 3
root@server:~# 
root@server:~# vim /etc/systemd/system/openvpn@.service
root@server:~#
root@server:~# cat /etc/systemd/system/openvpn@.service
[Unit] 
Description=OpenVPN Tunneling Application On %I 
After=network.target 
[Service] 
Type=notify 
PrivateTmp=true 
ExecStart=/usr/sbin/openvpn --cd /etc/openvpn/ --config %i.conf 
[Install] 
WantedBy=multi-user.target
root@server:~# 
root@server:~# systemctl start openvpn@server
root@server:~# 
root@server:~# systemctl enable openvpn@server
Created symlink /etc/systemd/system/multi-user.target.wants/openvpn@server.service → /etc/systemd/system/openvpn@.service.
root@server:~# 
root@server:~# systemctl status openvpn@server
● openvpn@server.service - OpenVPN Tunneling Application On server
     Loaded: loaded (/etc/systemd/system/openvpn@.service; enabled; vendor preset: enabled)
     Active: active (running) since Wed 2026-11-18 15:39:02 UTC; 20s ago
   Main PID: 2266 (openvpn)
     Status: "Pre-connection initialization successful"
      Tasks: 1 (limit: 3425)
     Memory: 1.6M
        CPU: 25ms
     CGroup: /system.slice/system-openvpn.slice/openvpn@server.service
             └─2266 /usr/sbin/openvpn --cd /etc/openvpn/ --config server.conf

Nov 18 15:39:02 server systemd[1]: Starting OpenVPN Tunneling Application On server...
Nov 18 15:39:02 server openvpn[2266]: 2026-11-18 15:39:02 WARNING: Compression for receiving enabled. Compression has been used in the past to break encryption. Sent packets are not compres>
Nov 18 15:39:02 server systemd[1]: Started OpenVPN Tunneling Application On server.
root@server:~# 
root@server:~# ll /etc/openvpn/
total 28
drwxr-xr-x  4 root root 4096 Nov 18 15:37 ./
drwxr-xr-x 98 root root 4096 Nov 18 15:36 ../
drwxr-xr-x  2 root root 4096 Oct 14 16:14 client/
drwxr-xr-x  2 root root 4096 Oct 14 16:14 server/
-rw-r--r--  1 root root  173 Nov 18 15:37 server.conf
-rw-------  1 root root  636 Nov 18 15:36 static.key
-rwxr-xr-x  1 root root 1468 Oct 14 16:14 update-resolv-conf*
root@server:~# 
root@server:~# scp /etc/openvpn/static.key vagrant@192.168.56.20:~/
The authenticity of host '192.168.56.20 (192.168.56.20)' can't be established.
ED25519 key fingerprint is SHA256:CifvuKnCFUxaTaHjJPvXJRQcfQVeROGRu5rhIY1FQYs.
This key is not known by any other names
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '192.168.56.20' (ED25519) to the list of known hosts.
root@server:~# scp /etc/openvpn/static.key vagrant@192.168.56.20:/etc/openvpn/
vagrant@192.168.56.20's password: 
static.key                                                                                                                                                  100%  636   282.7KB/s   00:00    
root@server:~# 
root@server:~# cat /etc/openvpn/server.conf
dev tap 
ifconfig 10.10.10.1 255.255.255.0 
topology subnet 
secret /etc/openvpn/static.key 
comp-lzo 
status /var/log/openvpn-status.log 
log /var/log/openvpn.log  
verb 3
root@server:~# 
root@server:~# cat /etc/systemd/system/openvpn@.service
[Unit] 
Description=OpenVPN Tunneling Application On %I 
After=network.target 
[Service] 
Type=notify 
PrivateTmp=true 
ExecStart=/usr/sbin/openvpn --cd /etc/openvpn/ --config %i.conf 
[Install] 
WantedBy=multi-user.target
root@server:~# 
root@server:~# journalctl -u openvpn-server
-- No entries --
root@server:~# journalctl -u openvpn
Nov 18 15:35:55 server systemd[1]: Starting OpenVPN service...
Nov 18 15:35:55 server systemd[1]: Finished OpenVPN service.
root@server:~# 
root@server:~# systemctl status openvpn@server
● openvpn@server.service - OpenVPN Tunneling Application On server
     Loaded: loaded (/etc/systemd/system/openvpn@.service; enabled; vendor preset: enabled)
     Active: active (running) since Wed 2026-11-18 15:39:02 UTC; 14min ago
   Main PID: 2266 (openvpn)
     Status: "Initialization Sequence Completed"
      Tasks: 1 (limit: 3425)
     Memory: 1.6M
        CPU: 73ms
     CGroup: /system.slice/system-openvpn.slice/openvpn@server.service
             └─2266 /usr/sbin/openvpn --cd /etc/openvpn/ --config server.conf

Nov 18 15:39:02 server systemd[1]: Starting OpenVPN Tunneling Application On server...
Nov 18 15:39:02 server openvpn[2266]: 2026-11-18 15:39:02 WARNING: Compression for receiving enabled. Compression has been used in the past to break encryption. Sent packets are not compres>
Nov 18 15:39:02 server systemd[1]: Started OpenVPN Tunneling Application On server.
root@server:~#
root@server:~# systemctl start openvpn@server
root@server:~# 
root@server:~# systemctl enable openvpn@server
Created symlink /etc/systemd/system/multi-user.target.wants/openvpn@server.service → /etc/systemd/system/openvpn@.service.
root@server:~# 
root@server:~# systemctl status openvpn@server
● openvpn@server.service - OpenVPN Tunneling Application On server
     Loaded: loaded (/etc/systemd/system/openvpn@.service; enabled; vendor preset: enabled)
     Active: active (running) since Wed 2026-11-18 15:39:02 UTC; 20s ago
   Main PID: 2266 (openvpn)
     Status: "Pre-connection initialization successful"
      Tasks: 1 (limit: 3425)
     Memory: 1.6M
        CPU: 25ms
     CGroup: /system.slice/system-openvpn.slice/openvpn@server.service
             └─2266 /usr/sbin/openvpn --cd /etc/openvpn/ --config server.conf

Nov 18 15:39:02 server systemd[1]: Starting OpenVPN Tunneling Application On server...
Nov 18 15:39:02 server openvpn[2266]: 2026-11-18 15:39:02 WARNING: Compression for receiving enabled. Compression has been used in the past to break encryption. Sent packets are not compres>
Nov 18 15:39:02 server systemd[1]: Started OpenVPN Tunneling Application On server.
root@server:~#
```

1.2.2 Конфигурирование openvpn на ВМ2, копирование пересланного ключа с ВМ1 в директорию openvpn:

```
root@client:~# vim /etc/openvpn/server.conf
root@client:~#
root@client:~# cat /etc/openvpn/server.conf
dev tap
remote 192.168.56.10 
ifconfig 10.10.10.2 255.255.255.0 
topology subnet 
route 192.168.56.0 255.255.255.0 
secret /etc/openvpn/static.key
comp-lzo
status /var/log/openvpn-status.log 
log /var/log/openvpn.log 
verb 3
root@client:~#
root@client:~# cat /etc/systemd/system/openvpn@.service
root@client:~#
root@client:~# cat /etc/systemd/system/openvpn@.service
[Unit] 
Description=OpenVPN Tunneling Application On %I 
After=network.target 
[Service] 
Type=notify 
PrivateTmp=true 
ExecStart=/usr/sbin/openvpn --cd /etc/openvpn/ --config %i.conf 
[Install] 
WantedBy=multi-user.target
root@client:~#
root@client:~# systemctl start openvpn@server
root@client:~# 
root@client:~# systemctl enable openvpn@server
Created symlink /etc/systemd/system/multi-user.target.wants/openvpn@server.service → /etc/systemd/system/openvpn@.service.

root@client:~# 
root@client:~# systemctl status openvpn@server
● openvpn@server.service - OpenVPN Tunneling Application On server
     Loaded: loaded (/etc/systemd/system/openvpn@.service; enabled; vendor preset: enabled)
     Active: active (running) since Wed 2026-11-18 15:48:59 UTC; 22s ago
   Main PID: 2337 (openvpn)
     Status: "Initialization Sequence Completed"
      Tasks: 1 (limit: 3425)
     Memory: 1.6M
        CPU: 22ms
     CGroup: /system.slice/system-openvpn.slice/openvpn@server.service
             └─2337 /usr/sbin/openvpn --cd /etc/openvpn/ --config server.conf

Nov 18 15:48:59 client systemd[1]: Starting OpenVPN Tunneling Application On server...
Nov 18 15:48:59 client systemd[1]: Started OpenVPN Tunneling Application On server.
Nov 18 15:48:59 client openvpn[2337]: 2026-11-18 15:48:59 WARNING: Compression for receiving enabled. Compression has been used in the past to break encryption. Sent packets a>
root@client:~#
root@client:~# journalctl | grep -i openvpn
Nov 18 15:41:31 client systemd[1]: Starting OpenVPN service...
Nov 18 15:41:31 client systemd[1]: Finished OpenVPN service.
Nov 18 15:48:59 client systemd[1]: Created slice Slice /system/openvpn.
Nov 18 15:48:59 client systemd[1]: Starting OpenVPN Tunneling Application On server...
Nov 18 15:48:59 client systemd[1]: Started OpenVPN Tunneling Application On server.
Nov 18 15:48:59 client openvpn[2337]: 2026-11-18 15:48:59 WARNING: Compression for receiving enabled. Compression has been used in the past to break encryption. Sent packets are not compressed unless "allow-compression yes" is also set.
root@client:~#
```

1.3 Проверка пропускной способности созданного туннеля openvpn в режиме tap

Запускаем iperf3 сервер на ВМ1:

```
root@server:~# iperf3 -s
-----------------------------------------------------------
Server listening on 5201
-----------------------------------------------------------
Accepted connection from 10.10.10.2, port 48544
[  5] local 10.10.10.1 port 5201 connected to 10.10.10.2 port 48554
[ ID] Interval           Transfer     Bitrate
[  5]   0.00-1.02   sec  6.25 MBytes  51.5 Mbits/sec                  
[  5]   1.02-2.02   sec  8.25 MBytes  68.9 Mbits/sec                  
[  5]   2.02-3.01   sec  6.75 MBytes  57.0 Mbits/sec                  
[  5]   3.01-4.04   sec  8.75 MBytes  71.8 Mbits/sec                  
[  5]   4.04-5.02   sec  8.25 MBytes  70.0 Mbits/sec                  
[  5]   5.02-6.04   sec  8.12 MBytes  67.1 Mbits/sec                  
[  5]   6.04-7.01   sec  6.62 MBytes  57.0 Mbits/sec                  
[  5]   7.01-8.01   sec  8.38 MBytes  70.4 Mbits/sec                  
[  5]   8.01-9.02   sec  9.25 MBytes  76.9 Mbits/sec                  
[  5]   9.02-10.02  sec  8.50 MBytes  71.4 Mbits/sec                  
[  5]  10.02-11.03  sec  8.50 MBytes  70.4 Mbits/sec                  
[  5]  11.03-12.02  sec  6.00 MBytes  51.2 Mbits/sec                  
[  5]  12.02-13.04  sec  9.50 MBytes  78.1 Mbits/sec                  
[  5]  13.04-14.02  sec  8.62 MBytes  73.4 Mbits/sec                  
[  5]  14.02-15.02  sec  8.50 MBytes  71.4 Mbits/sec                  
[  5]  15.02-16.02  sec  9.38 MBytes  78.6 Mbits/sec                  
[  5]  16.02-17.02  sec  6.75 MBytes  56.9 Mbits/sec                  
[  5]  17.02-18.03  sec  9.50 MBytes  79.0 Mbits/sec                  
[  5]  18.03-19.02  sec  9.38 MBytes  78.9 Mbits/sec                  
[  5]  19.02-20.01  sec  8.75 MBytes  73.9 Mbits/sec                  
[  5]  20.01-21.02  sec  9.50 MBytes  78.9 Mbits/sec                  
[  5]  21.02-22.02  sec  9.75 MBytes  82.3 Mbits/sec                  
[  5]  22.02-23.04  sec  9.50 MBytes  78.0 Mbits/sec                  
[  5]  23.04-24.03  sec  9.38 MBytes  79.4 Mbits/sec                  
[  5]  24.03-25.02  sec  9.12 MBytes  76.9 Mbits/sec                  
[  5]  25.02-26.03  sec  9.12 MBytes  76.0 Mbits/sec                  
[  5]  26.03-27.02  sec  8.75 MBytes  74.6 Mbits/sec                  
[  5]  27.02-28.07  sec  9.00 MBytes  71.4 Mbits/sec                  
[  5]  28.07-29.04  sec  10.2 MBytes  89.3 Mbits/sec                  
[  5]  29.04-30.02  sec  8.75 MBytes  74.5 Mbits/sec                  
[  5]  30.02-31.03  sec  9.12 MBytes  75.9 Mbits/sec                  
[  5]  31.03-32.03  sec  9.38 MBytes  78.5 Mbits/sec                  
[  5]  32.03-33.01  sec  9.62 MBytes  82.3 Mbits/sec                  
[  5]  33.01-34.02  sec  9.50 MBytes  79.1 Mbits/sec                  
[  5]  34.02-35.03  sec  9.25 MBytes  77.1 Mbits/sec                  
[  5]  35.03-36.02  sec  9.00 MBytes  76.3 Mbits/sec                  
[  5]  36.02-37.03  sec  8.12 MBytes  67.2 Mbits/sec                  
[  5]  37.03-38.02  sec  8.75 MBytes  73.8 Mbits/sec                  
[  5]  38.02-39.02  sec  8.62 MBytes  72.4 Mbits/sec                  
[  5]  39.02-40.02  sec  9.00 MBytes  76.0 Mbits/sec                  
[  5]  40.02-40.10  sec   768 KBytes  78.8 Mbits/sec                  
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate
[  5]   0.00-40.10  sec   348 MBytes  72.9 Mbits/sec                  receiver
-----------------------------------------------------------
Server listening on 5201
-----------------------------------------------------------
^Ciperf3: interrupt - the server has terminated
root@server:~# 
```

На ВМ2 запускаем iperf3 клиент:

```
root@client:~# iperf3 -c 10.10.10.1 -t 40 -i 5
Connecting to host 10.10.10.1, port 5201
[  5] local 10.10.10.2 port 48554 connected to 10.10.10.1 port 5201
[ ID] Interval           Transfer     Bitrate         Retr  Cwnd
[  5]   0.00-5.00   sec  40.9 MBytes  68.6 Mbits/sec   47   1.06 MBytes       
[  5]   5.00-10.00  sec  41.2 MBytes  69.2 Mbits/sec    5    998 KBytes       
[  5]  10.00-15.00  sec  41.2 MBytes  69.2 Mbits/sec  258    605 KBytes       
[  5]  15.00-20.00  sec  43.8 MBytes  73.4 Mbits/sec    0    624 KBytes       
[  5]  20.00-25.00  sec  47.5 MBytes  79.7 Mbits/sec    0    890 KBytes       
[  5]  25.00-30.00  sec  45.0 MBytes  75.5 Mbits/sec   61    506 KBytes       
[  5]  30.00-35.00  sec  47.5 MBytes  79.7 Mbits/sec   70    446 KBytes       
[  5]  35.00-40.00  sec  43.8 MBytes  73.4 Mbits/sec    0    495 KBytes       
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-40.00  sec   351 MBytes  73.6 Mbits/sec  441             sender
[  5]   0.00-40.10  sec   348 MBytes  72.9 Mbits/sec                  receiver

iperf Done.
root@client:~# 
```

1.3 Проверка пропускной способности созданного туннеля openvpn в режиме tun

Переконфигурируем openvpn в режиме tun, запускаем iperf3 сервер на ВМ1:

```
oot@server:~# vi /etc/openvpn/server.conf
root@server:~# 
root@server:~# 
root@server:~# cat /etc/openvpn/server.conf
dev tun
ifconfig 10.10.10.1 255.255.255.0 
topology subnet 
secret /etc/openvpn/static.key 
comp-lzo 
status /var/log/openvpn-status.log 
log /var/log/openvpn.log  
verb 3
root@server:~# 
root@server:~# systemctl restart openvpn@server
root@server:~# 
root@server:~# journalctl | grep -i openvpn
Nov 18 15:35:55 server systemd[1]: Starting OpenVPN service...
Nov 18 15:35:55 server systemd[1]: Finished OpenVPN service.
Nov 18 15:39:02 server systemd[1]: Created slice Slice /system/openvpn.
Nov 18 15:39:02 server systemd[1]: Starting OpenVPN Tunneling Application On server...
Nov 18 15:39:02 server openvpn[2266]: 2026-11-18 15:39:02 WARNING: Compression for receiving enabled. Compression has been used in the past to break encryption. Sent packets are not compressed unless "allow-compression yes" is also set.
Nov 18 15:39:02 server systemd[1]: Started OpenVPN Tunneling Application On server.
Nov 18 15:59:03 server systemd[1]: Stopping OpenVPN Tunneling Application On server...
Nov 18 15:59:03 server systemd[1]: openvpn@server.service: Deactivated successfully.
Nov 18 15:59:03 server systemd[1]: Stopped OpenVPN Tunneling Application On server.
Nov 18 15:59:03 server systemd[1]: openvpn@server.service: Consumed 27.395s CPU time.
Nov 18 15:59:03 server systemd[1]: Starting OpenVPN Tunneling Application On server...
Nov 18 15:59:03 server openvpn[2342]: 2026-11-18 15:59:03 WARNING: Compression for receiving enabled. Compression has been used in the past to break encryption. Sent packets are not compressed unless "allow-compression yes" is also set.
Nov 18 15:59:03 server systemd[1]: Started OpenVPN Tunneling Application On server.
root@server:~# 
root@server:~# 
root@server:~# iperf3 -s
-----------------------------------------------------------
Server listening on 5201
-----------------------------------------------------------
Accepted connection from 10.10.10.2, port 59514
[  5] local 10.10.10.1 port 5201 connected to 10.10.10.2 port 59520
[ ID] Interval           Transfer     Bitrate
[  5]   0.00-1.02   sec  8.88 MBytes  72.9 Mbits/sec                  
[  5]   1.02-2.02   sec  8.75 MBytes  73.4 Mbits/sec                  
[  5]   2.02-3.02   sec  7.38 MBytes  61.7 Mbits/sec                  
[  5]   3.02-4.01   sec  12.0 MBytes   102 Mbits/sec                  
[  5]   4.01-5.02   sec  13.1 MBytes   109 Mbits/sec                  
[  5]   5.02-6.02   sec  8.38 MBytes  70.1 Mbits/sec                  
[  5]   6.02-7.02   sec  8.50 MBytes  71.4 Mbits/sec                  
[  5]   7.02-8.04   sec  7.88 MBytes  65.1 Mbits/sec                  
[  5]   8.04-9.02   sec  7.00 MBytes  59.4 Mbits/sec                  
[  5]   9.02-10.02  sec  8.38 MBytes  70.5 Mbits/sec                  
[  5]  10.02-11.01  sec  9.12 MBytes  76.9 Mbits/sec                  
[  5]  11.01-12.01  sec  8.00 MBytes  67.1 Mbits/sec                  
[  5]  12.01-13.04  sec  7.75 MBytes  63.2 Mbits/sec                  
[  5]  13.04-14.03  sec  7.00 MBytes  59.6 Mbits/sec                  
[  5]  14.03-15.02  sec  8.00 MBytes  67.8 Mbits/sec                  
[  5]  15.02-16.02  sec  8.50 MBytes  70.9 Mbits/sec                  
[  5]  16.02-17.02  sec  9.38 MBytes  78.8 Mbits/sec                  
[  5]  17.02-18.03  sec  7.62 MBytes  63.5 Mbits/sec                  
[  5]  18.03-19.03  sec  6.38 MBytes  53.4 Mbits/sec                  
[  5]  19.03-20.02  sec  8.25 MBytes  70.0 Mbits/sec                  
[  5]  20.02-21.02  sec  8.38 MBytes  69.8 Mbits/sec                  
[  5]  21.02-22.04  sec  7.50 MBytes  62.1 Mbits/sec                  
[  5]  22.04-23.02  sec  8.12 MBytes  69.4 Mbits/sec                  
[  5]  23.02-24.03  sec  8.75 MBytes  72.8 Mbits/sec                  
[  5]  24.03-25.03  sec  8.50 MBytes  71.0 Mbits/sec                  
[  5]  25.03-26.02  sec  8.12 MBytes  68.5 Mbits/sec                  
[  5]  26.02-27.02  sec  7.62 MBytes  63.9 Mbits/sec                  
[  5]  27.02-28.01  sec  6.75 MBytes  57.3 Mbits/sec                  
[  5]  28.01-29.03  sec  9.00 MBytes  74.6 Mbits/sec                  
[  5]  29.03-30.04  sec  6.25 MBytes  51.7 Mbits/sec                  
[  5]  30.04-31.02  sec  7.75 MBytes  66.4 Mbits/sec                  
[  5]  31.02-32.02  sec  8.25 MBytes  68.9 Mbits/sec                  
[  5]  32.02-33.02  sec  8.00 MBytes  67.1 Mbits/sec                  
[  5]  33.02-34.02  sec  8.25 MBytes  69.4 Mbits/sec                  
[  5]  34.02-35.03  sec  7.75 MBytes  64.4 Mbits/sec                  
[  5]  35.03-36.02  sec  6.62 MBytes  56.0 Mbits/sec                  
[  5]  36.02-37.02  sec  7.50 MBytes  62.8 Mbits/sec                  
[  5]  37.02-38.03  sec  7.50 MBytes  62.4 Mbits/sec                  
[  5]  38.03-39.02  sec  8.50 MBytes  72.2 Mbits/sec                  
[  5]  39.02-40.02  sec  8.25 MBytes  69.5 Mbits/sec                  
[  5]  40.02-40.05  sec   384 KBytes  89.1 Mbits/sec                  
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate
[  5]   0.00-40.05  sec   328 MBytes  68.7 Mbits/sec                  receiver
-----------------------------------------------------------
Server listening on 5201
-----------------------------------------------------------
^Ciperf3: interrupt - the server has terminated
root@server:~#
```

На ВМ2 запускаем iperf3 клиент:

```
root@client:~# vim /etc/openvpn/server.conf
root@client:~#
root@client:~# cat /etc/openvpn/server.conf
dev tun 
remote 192.168.56.10 
ifconfig 10.10.10.2 255.255.255.0 
topology subnet 
route 192.168.56.0 255.255.255.0 
secret /etc/openvpn/static.key
comp-lzo
status /var/log/openvpn-status.log 
log /var/log/openvpn.log 
verb 3
root@client:~#
root@client:~# systemctl restart openvpn@server
root@client:~# 
root@client:~# journalctl | grep -i openvpn
Nov 18 15:41:31 client systemd[1]: Starting OpenVPN service...
Nov 18 15:41:31 client systemd[1]: Finished OpenVPN service.
Nov 18 15:48:59 client systemd[1]: Created slice Slice /system/openvpn.
Nov 18 15:48:59 client systemd[1]: Starting OpenVPN Tunneling Application On server...
Nov 18 15:48:59 client systemd[1]: Started OpenVPN Tunneling Application On server.
Nov 18 15:48:59 client openvpn[2337]: 2026-11-18 15:48:59 WARNING: Compression for receiving enabled. Compression has been used in the past to break encryption. Sent packets are not compressed unless "allow-compression yes" is also set.
Nov 18 15:58:45 client systemd[1]: Stopping OpenVPN Tunneling Application On server...
Nov 18 15:58:45 client systemd[1]: openvpn@server.service: Deactivated successfully.
Nov 18 15:58:45 client systemd[1]: Stopped OpenVPN Tunneling Application On server.
Nov 18 15:58:45 client systemd[1]: openvpn@server.service: Consumed 39.847s CPU time.
Nov 18 15:58:45 client systemd[1]: Starting OpenVPN Tunneling Application On server...
Nov 18 15:58:45 client openvpn[2394]: 2026-11-18 15:58:45 WARNING: Compression for receiving enabled. Compression has been used in the past to break encryption. Sent packets are not compressed unless "allow-compression yes" is also set.
Nov 18 15:58:45 client systemd[1]: Started OpenVPN Tunneling Application On server.
root@client:~# 
root@client:~# 
root@client:~# iperf3 -c 10.10.10.1 -t 40 -i 5
Connecting to host 10.10.10.1, port 5201
[  5] local 10.10.10.2 port 59520 connected to 10.10.10.1 port 5201
[ ID] Interval           Transfer     Bitrate         Retr  Cwnd
[  5]   0.00-5.00   sec  53.0 MBytes  89.0 Mbits/sec  699    562 KBytes       
[  5]   5.00-10.00  sec  40.0 MBytes  67.1 Mbits/sec  178    127 KBytes       
[  5]  10.00-15.00  sec  40.0 MBytes  67.1 Mbits/sec   25    153 KBytes       
[  5]  15.00-20.00  sec  40.0 MBytes  67.1 Mbits/sec   33    196 KBytes       
[  5]  20.00-25.00  sec  41.2 MBytes  69.2 Mbits/sec   57    203 KBytes       
[  5]  25.00-30.00  sec  37.5 MBytes  62.9 Mbits/sec   31    203 KBytes       
[  5]  30.00-35.00  sec  41.2 MBytes  69.2 Mbits/sec   79    149 KBytes       
[  5]  35.00-40.00  sec  37.5 MBytes  62.9 Mbits/sec   16    156 KBytes       
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-40.00  sec   331 MBytes  69.3 Mbits/sec  1118             sender
[  5]   0.00-40.05  sec   328 MBytes  68.7 Mbits/sec                  receiver

iperf Done.
root@client:~# 
```

### 2. Организация RAS на базе OpenVPN

Для создания Remote Access Server с авторизацией по ключам и проверки его работы выполняем следующие этапы.

2.1 Установка и конфигурирование openvpn сервера на ВМ

2.1.1 Установка пакетов

Установка необходимых пакетов на ВМ1, отключение SELinux:

```
[admin_insta11@mv334 vpn_lab]$ vagrant ssh server
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-160-generic x86_64)

Use of this system is acceptance of the OS vendor EULA and License Agreements.
vagrant@server:~$ 
vagrant@server:~$ sudo -i
root@server:~# 
root@server:~# apt update
Get:1 http://security.ubuntu.com/ubuntu jammy-security InRelease [129 kB]
Get:2 http://security.ubuntu.com/ubuntu jammy-security/main amd64 Packages [3,718 kB]
<...>
root@server:~# 
root@server:~# apt install openvpn iperf3 selinux-utils
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
The following additional packages will be installed:
  libiperf0 libpkcs11-helper1 libsctp1
Suggested packages:
  lksctp-tools resolvconf openvpn-systemd-resolved easy-rsa
The following NEW packages will be installed:
  iperf3 libiperf0 libpkcs11-helper1 libsctp1 openvpn selinux-utils
0 upgraded, 6 newly installed, 0 to remove and 201 not upgraded.
Need to get 883 kB of archives.
After this operation, 2,781 kB of additional disk space will be used.
Do you want to continue? [Y/n] y
<...>
root@server:~# setenforce 0
setenforce: SELinux is disabled
root@server:~# 
```

2.1.2 Генерация сертификатов и ключей на сервере

```
root@server:~# # Переходим в директорию /etc/openvpn и инициализируем PKI
root@server:~# cd /etc/openvpn
root@server:/etc/openvpn#
root@server:/etc/openvpn# /usr/share/easy-rsa/easyrsa init-pki

init-pki complete; you may now create a CA or requests.
Your newly created PKI dir is: /etc/openvpn/pki

root@server:/etc/openvpn# # Генерируем корневой самоподписанный сертификат
root@server:/etc/openvpn#
root@server:/etc/openvpn# echo 'rasvpn' | /usr/share/easy-rsa/easyrsa build-ca nopass
Using SSL: openssl OpenSSL 3.0.2 15 Mar 2022 (Library: OpenSSL 3.0.2 15 Mar 2022)
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Common Name (eg: your user, host, or server name) [Easy-RSA CA]:
CA creation complete and you may now import and sign cert requests.
Your new CA certificate file for publishing is at:
/etc/openvpn/pki/ca.crt

root@server:/etc/openvpn#  # Генерируем необходимые ключи и сертификаты для сервера
root@server:/etc/openvpn#
root@server:/etc/openvpn# echo 'rasvpn' | /usr/share/easy-rsa/easyrsa gen-req server nopass
Using SSL: openssl OpenSSL 3.0.2 15 Mar 2022 (Library: OpenSSL 3.0.2 15 Mar 2022)
.......+.............+...........+...................+..+....+.........+...+..+.+..+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-----
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Common Name (eg: your user, host, or server name) [server]:
Keypair and certificate request completed. Your files are:
req: /etc/openvpn/pki/reqs/server.req
key: /etc/openvpn/pki/private/server.key

root@server:/etc/openvpn#
oot@server:/etc/openvpn# echo 'yes' | /usr/share/easy-rsa/easyrsa sign-req server server
Using SSL: openssl OpenSSL 3.0.2 15 Mar 2022 (Library: OpenSSL 3.0.2 15 Mar 2022)

You are about to sign the following certificate.
Please check over the details shown below for accuracy. Note that this request
has not been cryptographically verified. Please be sure it came from a trusted
source or that you have verified the request checksum with the sender.

Request subject, to be signed as a server certificate for 825 days:

subject=
    commonName                = rasvpn

Type the word 'yes' to continue, or any other input to abort.
  Confirm request details: Using configuration from /etc/openvpn/pki/easy-rsa-3576.VD7yQj/tmp.UbW7YM
40D7D29FA87F0000:error:0700006C:configuration file routines:NCONF_get_string:no value:../crypto/conf/conf_lib.c:315:group=<NULL> name=unique_subject
Check that the request matches the signature
Signature ok
The Subject's Distinguished Name is as follows
commonName            :ASN.1 12:'rasvpn'
Certificate is to be certified until Feb 21 15:49:29 2029 GMT (825 days)

Write out database with 1 new entries
Data Base Updated

Certificate created at: /etc/openvpn/pki/issued/server.crt

root@server:/etc/openvpn# 
root@server:/etc/openvpn# /usr/share/easy-rsa/easyrsa gen-dh
Using SSL: openssl OpenSSL 3.0.2 15 Mar 2022 (Library: OpenSSL 3.0.2 15 Mar 2022)
Generating DH parameters, 2048 bit long safe prime
...................++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*++*

DH parameters of size 2048 created at /etc/openvpn/pki/dh.pem

root@server:/etc/openvpn# 
root@server:/etc/openvpn# openvpn --genkey secret ca.key
root@server:/etc/openvpn#
root@server:/etc/openvpn# # Генерируем необходимые ключи и сертификаты для клиента
root@server:/etc/openvpn#
root@server:/etc/openvpn# echo 'client' | /usr/share/easy-rsa/easyrsa gen-req client nopass
Using SSL: openssl OpenSSL 3.0.2 15 Mar 2022 (Library: OpenSSL 3.0.2 15 Mar 2022)
....+..+..........+..+......+...+.........+...+.......+......+......+...........+...+.+.....+.+..+.......+........+.+..+...+....+.....+.......+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-----
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Common Name (eg: your user, host, or server name) [client]:
Keypair and certificate request completed. Your files are:
req: /etc/openvpn/pki/reqs/client.req
key: /etc/openvpn/pki/private/client.key

root@server:/etc/openvpn# 
root@server:/etc/openvpn# echo 'yes' | /usr/share/easy-rsa/easyrsa sign-req client client
Using SSL: openssl OpenSSL 3.0.2 15 Mar 2022 (Library: OpenSSL 3.0.2 15 Mar 2022)

You are about to sign the following certificate.
Please check over the details shown below for accuracy. Note that this request
has not been cryptographically verified. Please be sure it came from a trusted
source or that you have verified the request checksum with the sender.

Request subject, to be signed as a client certificate for 825 days:

subject=
    commonName                = client

Type the word 'yes' to continue, or any other input to abort.
  Confirm request details: Using configuration from /etc/openvpn/pki/easy-rsa-3674.rnet81/tmp.NTlgqs
Check that the request matches the signature
Signature ok
The Subject's Distinguished Name is as follows
commonName            :ASN.1 12:'client'
Certificate is to be certified until Feb 21 15:53:00 2029 GMT (825 days)

Write out database with 1 new entries
Data Base Updated

Certificate created at: /etc/openvpn/pki/issued/client.crt

root@server:/etc/openvpn# 
```

2.1.3 Создаём файл конфигурации сервера openvpn

```
root@server:/etc/openvpn# vim /etc/openvpn/server.conf
root@server:/etc/openvpn#
root@server:/home/vagrant# cat /etc/openvpn/server.conf
port 1207 
proto udp 
dev tun 
ca /etc/openvpn/pki/ca.crt 
cert /etc/openvpn/pki/issued/server.crt 
key /etc/openvpn/pki/private/server.key 
dh /etc/openvpn/pki/dh.pem 
server 10.10.10.0 255.255.255.0 
ifconfig-pool-persist ipp.txt 
client-to-client 
client-config-dir /etc/openvpn/client 
keepalive 10 120 
comp-lzo 
persist-key 
persist-tun 
status /var/log/openvpn-status.log 
log /var/log/openvpn.log 
verb 3
root@server:/home/vagrant#
```

2.1.4 Создаём и запускаем сервис openvpn

```
root@server:~# vi /etc/systemd/system/openvpn@.service
root@server:~#
root@server:~# cat /etc/systemd/system/openvpn@.service
[Unit] 
Description=OpenVPN Tunneling Application On %I 
After=network.target 
[Service] 
Type=notify 
PrivateTmp=true 
ExecStart=/usr/sbin/openvpn --cd /etc/openvpn/ --config %i.conf 
[Install] 
WantedBy=multi-user.target
root@server:~#
root@server:~# systemctl start openvpn@server
root@server:~# 
root@server:~# systemctl enable openvpn@server
Created symlink /etc/systemd/system/multi-user.target.wants/openvpn@server.service → /etc/systemd/system/openvpn@.service.
root@server:~# 
root@server:~# systemctl status openvpn@server
● openvpn@server.service - OpenVPN Tunneling Application On server
     Loaded: loaded (/etc/systemd/system/openvpn@.service; enabled; vendor preset: enabled)
     Active: active (running) since Wed 2026-11-18 15:39:02 UTC; 20s ago
   Main PID: 2266 (openvpn)
     Status: "Pre-connection initialization successful"
      Tasks: 1 (limit: 3425)
     Memory: 1.6M
        CPU: 25ms
     CGroup: /system.slice/system-openvpn.slice/openvpn@server.service
             └─2266 /usr/sbin/openvpn --cd /etc/openvpn/ --config server.conf

Nov 18 15:39:02 server systemd[1]: Starting OpenVPN Tunneling Application On server...
Nov 18 15:39:02 server openvpn[2266]: 2026-11-18 15:39:02 WARNING: Compression for receiving enabled. Compression has been used in the past to break encryption. Sent packets are not compres>
Nov 18 15:39:02 server systemd[1]: Started OpenVPN Tunneling Application On server.
root@server:~#
```

2.1.5 Копируем сгенерированные ключи с сервера на клиент:

```
root@server:/etc/openvpn# ll
total 36
drwxr-xr-x   5 root root 4096 Nov 19 15:58 ./
drwxr-xr-x 100 root root 4096 Nov 19 15:39 ../
-rw-------   1 root root  636 Nov 19 15:52 ca.key
drwxr-xr-x   2 root root 4096 Nov 19 15:55 client/
-rw-------   1 root root    0 Nov 19 15:58 ipp.txt
drwx------   8 root root 4096 Nov 19 15:53 pki/
drwxr-xr-x   2 root root 4096 Oct 14 16:14 server/
-rw-r--r--   1 root root  413 Nov 19 15:57 server.conf
-rw-------   1 root root  636 Nov 18 15:36 static.key
-rwxr-xr-x   1 root root 1468 Oct 14 16:14 update-resolv-conf*
root@server:/etc/openvpn# ll pki
total 80
drwx------ 8 root root 4096 Nov 19 15:53 ./
drwxr-xr-x 5 root root 4096 Nov 19 15:58 ../
-rw------- 1 root root 1184 Nov 19 15:49 ca.crt
drwx------ 2 root root 4096 Nov 19 15:53 certs_by_serial/
-rw------- 1 root root  424 Nov 19 15:51 dh.pem
-rw------- 1 root root  138 Nov 19 15:53 index.txt
-rw------- 1 root root   20 Nov 19 15:53 index.txt.attr
-rw------- 1 root root   20 Nov 19 15:49 index.txt.attr.old
-rw------- 1 root root   69 Nov 19 15:49 index.txt.old
drwx------ 2 root root 4096 Nov 19 15:53 issued/
-rw------- 1 root root 4616 Nov 19 15:42 openssl-easyrsa.cnf
drwx------ 2 root root 4096 Nov 19 15:52 private/
drwx------ 5 root root 4096 Nov 19 15:49 renewed/
drwx------ 2 root root 4096 Nov 19 15:52 reqs/
drwx------ 5 root root 4096 Nov 19 15:49 revoked/
-rw------- 1 root root 4550 Nov 19 15:42 safessl-easyrsa.cnf
-rw------- 1 root root   33 Nov 19 15:53 serial
-rw------- 1 root root   33 Nov 19 15:53 serial.old
root@server:/etc/openvpn# 
root@server:/etc/openvpn# cp /etc/openvpn/pki/ca.crt /home/vagrant/
root@server:/etc/openvpn# cp /etc/openvpn/pki/issued/client.crt /home/vagrant/
root@server:/etc/openvpn# cp /etc/openvpn/pki/private/client.key /home/vagrant/
root@server:/etc/openvpn# 
root@server:/etc/openvpn# cd ~
root@server:~# ll
total 32
drwx------  4 root root 4096 Nov 19 15:57 ./
drwxr-xr-x 21 root root 4096 Nov 18 15:23 ../
-rw-r--r--  1 root root 3106 Oct 15  2021 .bashrc
-rw-------  1 root root   20 Nov 18 15:53 .lesshst
-rw-r--r--  1 root root  161 Jul  9  2019 .profile
drwx------  3 root root 4096 Oct 23  2025 snap/
drwx------  2 root root 4096 Nov 18 15:45 .ssh/
-rw-------  1 root root 3761 Nov 19 15:57 .viminfo
root@server:~# cd /home/vagrant
root@server:/home/vagrant# ll
total 48
drwxr-x--- 4 vagrant vagrant 4096 Nov 19 16:08 ./
drwxr-xr-x 3 root    root    4096 Oct 23  2025 ../
-rw-r--r-- 1 vagrant vagrant  220 Jan  6  2022 .bash_logout
-rw-r--r-- 1 vagrant vagrant 3771 Jan  6  2022 .bashrc
drwx------ 2 vagrant vagrant 4096 Oct 23  2025 .cache/
-rw------- 1 root    root    1184 Nov 19 16:07 ca.crt
-rw------- 1 root    root    4471 Nov 19 16:07 client.crt
-rw------- 1 root    root    1704 Nov 19 16:08 client.key
-rw-r--r-- 1 vagrant vagrant  807 Jan  6  2022 .profile
drwx------ 2 vagrant vagrant 4096 Nov 18 15:23 .ssh/
-rw-r--r-- 1 vagrant vagrant    0 Oct 23  2025 .sudo_as_admin_successful
-rw-r--r-- 1 vagrant vagrant    5 Oct 23  2025 .vbox_version
root@server:/home/vagrant# chown vagrant:vagrant ca.crt
root@server:/home/vagrant# chown vagrant:vagrant client.crt 
root@server:/home/vagrant# chown vagrant:vagrant client.key
root@server:/home/vagrant#

[admin_insta11@mv334 vpn_lab]$ 
[admin_insta11@mv334 vpn_lab]$ scp vagrant@192.168.56.10:~/ca.crt .
vagrant@192.168.56.10's password: 
ca.crt                                                                                                                                                      100% 1184   413.4KB/s   00:00    
[admin_insta11@mv334 vpn_lab]$ scp vagrant@192.168.56.10:~/client.crt .
vagrant@192.168.56.10's password: 
client.crt                                                                                                                                                  100% 4471     1.8MB/s   00:00    
[admin_insta11@mv334 vpn_lab]$ scp vagrant@192.168.56.10:~/client.key .
vagrant@192.168.56.10's password: 
client.key                                                                                                                                                  100% 1704   690.2KB/s   00:00    
[admin_insta11@mv334 vpn_lab]$ 
[admin_insta11@mv334 vpn_lab]$ 
[admin_insta11@mv334 vpn_lab]$ ll
итого 20
-rw------- 1 admin_insta11 admin_insta11 1184 ноя 19 19:06 ca.crt
-rw------- 1 admin_insta11 admin_insta11 4471 ноя 19 19:07 client.crt
-rw------- 1 admin_insta11 admin_insta11 1704 ноя 19 19:07 client.key
-rw-rw-r-- 1 admin_insta11 admin_insta11  421 ноя 18 18:22 Vagrantfile
[admin_insta11@mv334 vpn_lab]$ 
```


2.2 Конфигурируем openvpn client на хосте

Пакеты openvpn на хосте/клиенте устанавливаются аналогично. 

Создаём файл конфигурации:

```
[admin_insta11@mv334 vpn_lab]$ vi client.conf
[admin_insta11@mv334 vpn_lab]$
[admin_insta11@mv334 vpn_lab]$ cat client.conf 
dev tun 
proto udp 
remote 192.168.56.10 1207 
client 
resolv-retry infinite 
remote-cert-tls server 
ca ./ca.crt 
cert ./client.crt 
key ./client.key 
persist-key 
persist-tun 
comp-lzo 
verb 3
[admin_insta11@mv334 vpn_lab]$
```

## 2.3 Проверка работы туннеля openvpn

**ПРИМЕЧАНИЕ:** ниже приведены результаты проверки работы туннеля уже с модифицированными настройками сервера openvpn и клиента openvpn. В процессе отладки были внесены следующие модификации в настройки сервера RAS, препятствующие прохождению трафика:

1. в файле конфигурации client.conf в методичке ошибочно указан маршрут на внешнюю сеть 'route 192.168.56.0 255.255.255.0' вместо внутренней тунельной. Исходный файл client.conf из методички:

```
dev tun 
proto udp 
remote 192.168.56.10 1207 
client 
resolv-retry infinite 
remote-cert-tls server 
ca ./ca.crt 
cert ./client.crt 
key ./client.key 
route 192.168.56.0 255.255.255.0 
persist-key 
persist-tun 
comp-lzo 
verb 3
```

Из-за наличия этого маршрута в конфигурации клиента после установки туннеля с клиента маршрут на внешнюю сеть 192.168.56.0/24 направлялся внутрь созданного туннеля - в результате с клиента/хоста переставал пинговаться IP-адрес 192.168.56.10 сервера RAS. 
По итогам отладки строка 'route 192.168.56.0 255.255.255.0' из файла конфигурации клиента удалена, исправленный файл приведён ниже:

```
[admin_insta11@mv334 vpn_lab]$ cat client.conf 
dev tun 
proto udp 
remote 192.168.56.10 1207 
client 
resolv-retry infinite 
remote-cert-tls server 
ca ./ca.crt 
cert ./client.crt 
key ./client.key 
persist-key 
persist-tun 
comp-lzo 
verb 3
[admin_insta11@mv334 vpn_lab]$
```

2. В конфигурации сервера в методичке присутствовал CCD файл /etc/openvpn/client/client
с директивой 'iroute 10.10.10.0 255.255.255.0' назначения внутренней сети для клиента:

```
# Зададим параметр iroute для клиента
echo 'iroute 10.10.10.0 255.255.255.0' > /etc/openvpn/client/client
```

Так как в качестве внутренней сети для клиента была назначена туннельная сеть между сервером и клиентом,
то сервер RAS в результате этого конфликта отменял анонс/пуш этой сети на клиент (REMOVE PUSH ROUTE ...):

```
<...>
2026-11-20 15:12:37 MULTI_sva: pool returned IPv4=10.10.10.6, IPv6=(Not enabled)
2026-11-20 15:12:37 OPTIONS IMPORT: reading client specific options from: /etc/openvpn/client/client
2026-11-20 15:12:37 MULTI: Learn: 10.10.10.6 -> client/192.168.56.1:39800
2026-11-20 15:12:37 MULTI: primary virtual IP for client/192.168.56.1:39800: 10.10.10.6
2026-11-20 15:12:37 MULTI: internal route 10.10.10.0/24 -> client/192.168.56.1:39800
2026-11-20 15:12:37 MULTI: Learn: 10.10.10.0/24 -> client/192.168.56.1:39800
2026-11-20 15:12:37 REMOVE PUSH ROUTE: 'route 10.10.10.0 255.255.255.0'
<...>
```

В результате на клиенте после установления туннеля отсутствовал маршрут в туннельную сеть 10.10.10.0/24 и ответы
на запросы ping уходили в сторону маршрута по умолчанию (интерфейс eth0), а не в сторону туннеля (интерфейс tun0).

Для устранения проблемы файл /etc/openvpn/client/client был удалён, а сервер openvpn перезапущен.

После выполнения двух описанных проблем трафик через установленный туннел начал проходить нормально.


Для проверки запускаем туннель openvpn на клиенте:

```
admin_insta11@mv334 vpn_lab]$ sudo openvpn --config client.conf
[sudo] пароль для admin_insta11: 
2026-11-22 08:49:34 WARNING: Compression for receiving enabled. Compression has been used in the past to break encryption. Sent packets are not compressed unless "allow-compression yes" is also set.
2026-11-22 08:49:34 Note: --cipher is not set. OpenVPN versions before 2.5 defaulted to BF-CBC as fallback when cipher negotiation failed in this case. If you need this fallback please add '--data-ciphers-fallback BF-CBC' to your configuration and/or add BF-CBC to --data-ciphers.
2026-11-22 08:49:34 OpenVPN 2.6.11 x86_64-koji-linux-gnu [SSL (OpenSSL)] [LZO] [LZ4] [EPOLL] [PKCS11] [MH/PKTINFO] [AEAD]
2026-11-22 08:49:34 library versions: OpenSSL 1.1.1zh  9 Jun 2026, LZO 2.10
2026-11-22 08:49:34 TCP/UDP: Preserving recently used remote address: [AF_INET]192.168.56.10:1207
2026-11-22 08:49:34 Socket Buffers: R=[212992->212992] S=[212992->212992]
2026-11-22 08:49:34 UDPv4 link local: (not bound)
2026-11-22 08:49:34 UDPv4 link remote: [AF_INET]192.168.56.10:1207
2026-11-22 08:49:34 TLS: Initial packet from [AF_INET]192.168.56.10:1207, sid=20e62acd cc3706b4
2026-11-22 08:49:34 VERIFY OK: depth=1, CN=rasvpn
2026-11-22 08:49:34 VERIFY KU OK
2026-11-22 08:49:34 Validating certificate extended key usage
2026-11-22 08:49:34 ++ Certificate has EKU (str) TLS Web Server Authentication, expects TLS Web Server Authentication
2026-11-22 08:49:34 VERIFY EKU OK
2026-11-22 08:49:34 VERIFY OK: depth=0, CN=rasvpn
2026-11-22 08:49:34 Control Channel: TLSv1.3, cipher TLSv1.3 TLS_AES_256_GCM_SHA384, peer certificate: 2048 bits RSA, signature: RSA-SHA256, peer temporary key: 253 bits X25519
2026-11-22 08:49:34 [rasvpn] Peer Connection Initiated with [AF_INET]192.168.56.10:1207
2026-11-22 08:49:34 TLS: move_session: dest=TM_ACTIVE src=TM_INITIAL reinit_src=1
2026-11-22 08:49:34 TLS: tls_multi_process: initial untrusted session promoted to trusted
2026-11-22 08:49:34 PUSH: Received control message: 'PUSH_REPLY,route 10.10.10.0 255.255.255.0,topology net30,ping 10,ping-restart 120,ifconfig 10.10.10.6 10.10.10.5,peer-id 0,cipher AES-256-GCM'
2026-11-22 08:49:34 OPTIONS IMPORT: --ifconfig/up options modified
2026-11-22 08:49:34 OPTIONS IMPORT: route options modified
2026-11-22 08:49:34 net_route_v4_best_gw query: dst 0.0.0.0
2026-11-22 08:49:34 net_route_v4_best_gw result: via 172.17.15.1 dev eth0
2026-11-22 08:49:34 ROUTE_GATEWAY 172.17.15.1/255.255.255.0 IFACE=eth0 HWADDR=a0:36:9f:52:7b:92
2026-11-22 08:49:34 TUN/TAP device tun0 opened
2026-11-22 08:49:34 net_iface_mtu_set: mtu 1500 for tun0
2026-11-22 08:49:34 net_iface_up: set tun0 up
2026-11-22 08:49:34 net_addr_ptp_v4_add: 10.10.10.6 peer 10.10.10.5 dev tun0
2026-11-22 08:49:34 net_route_v4_add: 10.10.10.0/24 via 10.10.10.5 dev [NULL] table 0 metric -1
2026-11-22 08:49:34 Initialization Sequence Completed
2026-11-22 08:49:34 Data Channel: cipher 'AES-256-GCM', peer-id: 0, compression: 'lzo'
2026-11-22 08:49:34 Timers: ping 10, ping-restart 120
```

При этом ответный лог соединения на сервере:

```
root@server:/home/vagrant# tail -50 /var/log/openvpn.log
2026-11-22 05:47:00 192.168.56.1:53170 TLS: Initial packet from [AF_INET]192.168.56.1:53170, sid=ecd05c5a 8d2d9bfd
2026-11-22 05:47:00 192.168.56.1:53170 VERIFY OK: depth=1, CN=rasvpn
2026-11-22 05:47:00 192.168.56.1:53170 VERIFY OK: depth=0, CN=client
2026-11-22 05:47:00 192.168.56.1:53170 peer info: IV_VER=2.6.11
2026-11-22 05:47:00 192.168.56.1:53170 peer info: IV_PLAT=linux
2026-11-22 05:47:00 192.168.56.1:53170 peer info: IV_TCPNL=1
2026-11-22 05:47:00 192.168.56.1:53170 peer info: IV_MTU=1600
2026-11-22 05:47:00 192.168.56.1:53170 peer info: IV_NCP=2
2026-11-22 05:47:00 192.168.56.1:53170 peer info: IV_CIPHERS=AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305
2026-11-22 05:47:00 192.168.56.1:53170 peer info: IV_PROTO=990
2026-11-22 05:47:00 192.168.56.1:53170 peer info: IV_LZ4=1
2026-11-22 05:47:00 192.168.56.1:53170 peer info: IV_LZ4v2=1
2026-11-22 05:47:00 192.168.56.1:53170 peer info: IV_LZO=1
2026-11-22 05:47:00 192.168.56.1:53170 peer info: IV_COMP_STUB=1
2026-11-22 05:47:00 192.168.56.1:53170 peer info: IV_COMP_STUBv2=1
2026-11-22 05:47:00 192.168.56.1:53170 Control Channel: TLSv1.3, cipher TLSv1.3 TLS_AES_256_GCM_SHA384, peer certificate: 2048 bit RSA, signature: RSA-SHA256
2026-11-22 05:47:00 192.168.56.1:53170 [client] Peer Connection Initiated with [AF_INET]192.168.56.1:53170
2026-11-22 05:47:00 client/192.168.56.1:53170 MULTI_sva: pool returned IPv4=10.10.10.6, IPv6=(Not enabled)
2026-11-22 05:47:00 client/192.168.56.1:53170 MULTI: Learn: 10.10.10.6 -> client/192.168.56.1:53170
2026-11-22 05:47:00 client/192.168.56.1:53170 MULTI: primary virtual IP for client/192.168.56.1:53170: 10.10.10.6
2026-11-22 05:47:00 client/192.168.56.1:53170 Data Channel: using negotiated cipher 'AES-256-GCM'
2026-11-22 05:47:00 client/192.168.56.1:53170 Outgoing Data Channel: Cipher 'AES-256-GCM' initialized with 256 bit key
2026-11-22 05:47:00 client/192.168.56.1:53170 Incoming Data Channel: Cipher 'AES-256-GCM' initialized with 256 bit key
2026-11-22 05:47:00 client/192.168.56.1:53170 SENT CONTROL [client]: 'PUSH_REPLY,route 10.10.10.0 255.255.255.0,route 10.10.10.0 255.255.255.0,topology net30,ping 10,ping-restart 120,ifconfig 10.10.10.6 10.10.10.5,peer-id 0,cipher AES-256-GCM' (status=1)
```

После установки туннеля проверяем состояние интерфейсов, таблицу маршрутов и связность через туннель:

1) на сервере/ВМ :

```
root@server:/home/vagrant# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:16:dd:ef brd ff:ff:ff:ff:ff:ff
    altname enp0s3
    inet 10.0.2.15/24 metric 100 brd 10.0.2.255 scope global dynamic eth0
       valid_lft 57293sec preferred_lft 57293sec
    inet6 fd17:625c:f037:2:a00:27ff:fe16:ddef/64 scope global dynamic mngtmpaddr noprefixroute 
       valid_lft 86357sec preferred_lft 14357sec
    inet6 fe80::a00:27ff:fe16:ddef/64 scope link 
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:d7:27:f9 brd ff:ff:ff:ff:ff:ff
    altname enp0s8
    inet 192.168.56.10/24 brd 192.168.56.255 scope global eth1
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fed7:27f9/64 scope link 
       valid_lft forever preferred_lft forever
11: tun0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UNKNOWN group default qlen 500
    link/none 
    inet 10.10.10.1 peer 10.10.10.2/32 scope global tun0
       valid_lft forever preferred_lft forever
    inet6 fe80::a26f:48fa:8080:a5cd/64 scope link stable-privacy 
       valid_lft forever preferred_lft forever
root@server:/home/vagrant# 
root@server:/home/vagrant# ip r
default via 10.0.2.2 dev eth0 proto dhcp src 10.0.2.15 metric 100 
10.0.2.0/24 dev eth0 proto kernel scope link src 10.0.2.15 metric 100 
10.0.2.2 dev eth0 proto dhcp scope link src 10.0.2.15 metric 100 
10.0.2.3 dev eth0 proto dhcp scope link src 10.0.2.15 metric 100 
10.10.10.0/24 via 10.10.10.2 dev tun0 
10.10.10.2 dev tun0 proto kernel scope link src 10.10.10.1 
192.168.56.0/24 dev eth1 proto kernel scope link src 192.168.56.10 
root@server:/home/vagrant# 
root@server:/home/vagrant# ping 10.10.10.6
PING 10.10.10.6 (10.10.10.6) 56(84) bytes of data.
64 bytes from 10.10.10.6: icmp_seq=1 ttl=64 time=0.957 ms
64 bytes from 10.10.10.6: icmp_seq=2 ttl=64 time=1.11 ms
64 bytes from 10.10.10.6: icmp_seq=3 ttl=64 time=1.07 ms
64 bytes from 10.10.10.6: icmp_seq=4 ttl=64 time=1.16 ms
^C
--- 10.10.10.6 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3005ms
rtt min/avg/max/mdev = 0.957/1.072/1.155/0.073 ms
root@server:/home/vagrant#
root@server:/home/vagrant# traceroute 10.10.10.6
traceroute to 10.10.10.6 (10.10.10.6), 30 hops max, 60 byte packets
 1  10.10.10.6 (10.10.10.6)  1.295 ms  1.043 ms  2.681 ms
root@server:/home/vagrant#
```

2) на клиенте/хосте:

```
[admin_insta11@mv334 vpn_lab]$ ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether a0:36:9f:52:7b:92 brd ff:ff:ff:ff:ff:ff
    altname enp8s0f0
    inet 172.17.15.74/24 brd 172.17.15.255 scope global noprefixroute eth0
       valid_lft forever preferred_lft forever
3: eth1: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc mq state DOWN group default qlen 1000
    link/ether a0:36:9f:52:7b:93 brd ff:ff:ff:ff:ff:ff
    altname enp8s0f1
4: virbr0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default qlen 1000
    link/ether 52:54:00:01:14:e6 brd ff:ff:ff:ff:ff:ff
    inet 192.168.122.1/24 brd 192.168.122.255 scope global virbr0
       valid_lft forever preferred_lft forever
5: vboxnet0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 0a:00:27:00:00:00 brd ff:ff:ff:ff:ff:ff
    inet 10.0.0.1/24 brd 10.0.0.255 scope global vboxnet0
       valid_lft forever preferred_lft forever
    inet6 fe80::800:27ff:fe00:0/64 scope link 
       valid_lft forever preferred_lft forever
6: vboxnet1: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc fq_codel state DOWN group default qlen 1000
    link/ether 0a:00:27:00:00:01 brd ff:ff:ff:ff:ff:ff
    inet 192.168.50.1/24 brd 192.168.50.255 scope global vboxnet1
       valid_lft forever preferred_lft forever
    inet6 fe80::800:27ff:fe00:1/64 scope link 
       valid_lft forever preferred_lft forever
7: vboxnet2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 0a:00:27:00:00:02 brd ff:ff:ff:ff:ff:ff
    inet 192.168.56.1/24 brd 192.168.56.255 scope global vboxnet2
       valid_lft forever preferred_lft forever
    inet6 fe80::800:27ff:fe00:2/64 scope link 
       valid_lft forever preferred_lft forever
19: tun0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UNKNOWN group default qlen 500
    link/none 
    inet 10.10.10.6 peer 10.10.10.5/32 scope global tun0
       valid_lft forever preferred_lft forever
    inet6 fe80::d6ee:3778:e87:47c8/64 scope link stable-privacy 
       valid_lft forever preferred_lft forever
[admin_insta11@mv334 vpn_lab]$ 
[admin_insta11@mv334 vpn_lab]$ ip r
default via 172.17.15.1 dev eth0 proto static metric 100 
10.0.0.0/24 dev vboxnet0 proto kernel scope link src 10.0.0.1 
10.10.10.0/24 via 10.10.10.5 dev tun0 
10.10.10.5 dev tun0 proto kernel scope link src 10.10.10.6 
172.17.15.0/24 dev eth0 proto kernel scope link src 172.17.15.74 metric 100 
192.168.50.0/24 dev vboxnet1 proto kernel scope link src 192.168.50.1 linkdown 
192.168.56.0/24 dev vboxnet2 proto kernel scope link src 192.168.56.1 
192.168.122.0/24 dev virbr0 proto kernel scope link src 192.168.122.1 linkdown 
[admin_insta11@mv334 vpn_lab]$ 
[admin_insta11@mv334 vpn_lab]$ 
[admin_insta11@mv334 vpn_lab]$ ping 10.10.10.1
PING 10.10.10.1 (10.10.10.1) 56(84) bytes of data.
64 bytes from 10.10.10.1: icmp_seq=1 ttl=64 time=1.35 ms
64 bytes from 10.10.10.1: icmp_seq=2 ttl=64 time=1.17 ms
64 bytes from 10.10.10.1: icmp_seq=3 ttl=64 time=1.17 ms
64 bytes from 10.10.10.1: icmp_seq=4 ttl=64 time=1.22 ms
^C
--- 10.10.10.1 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3004ms
rtt min/avg/max/mdev = 1.166/1.225/1.348/0.073 ms
[admin_insta11@mv334 vpn_lab]$ 
[admin_insta11@mv334 vpn_lab]$ 
[admin_insta11@mv334 vpn_lab]$ traceroute 10.10.10.1
traceroute to 10.10.10.1 (10.10.10.1), 30 hops max, 60 byte packets
 1  10.10.10.1 (10.10.10.1)  2.420 ms  2.404 ms  2.417 ms
[admin_insta11@mv334 vpn_lab]$ 
```


# КОНЕЦ


# Заметки по поводу выполнения лабораторной работы

## 1. Анонсирование маршрутов в туннеле со стороны клиента и сервера

CCD = Client Configuration Directory. Это каталог (у вас /etc/openvpn/client), куда OpenVPN заглядывает при подключении клиента: если там есть файл с именем, совпадающим с CN сертификата клиента (client для CN=client), директивы из него применяются персонально к этому клиенту

Полная карта механизмов

| Где объявлено      | Директива      | Что делает       |
|:----------------|:-----------------------|:--------------------------------------------------|
|CCD-файл клиента	|iroute	|Регистрирует сеть за клиентом во внутренней таблице OpenVPN (кто из клиентов «владеет» какой сетью)|
|CCD-файл клиента	|push "route ..."	|Пушит маршрут только этому клиенту |
|server.conf	|push "route ..."	|Пушит маршрут всем клиентам |
|server.conf	|route	|Добавляет системный маршрут на самом сервере (типично — для сетей за клиентами, в паре с iroute) |
|client.conf	|route	|Добавляет маршрут на клиенте при подъёме туннеля |
|server.conf	|topology subnet	|Автоматический маршрут в туннельную сеть на всех клиентах (без net30-фантомов) |
|Скрипты	|up, learn-address, client-connect	|Добавление/удаление маршрутов своими командами при событиях|
|Поверх туннеля	|OSPF/BGP (FRR, quagga)	|«Взрослая» динамическая маршрутизация, когда сеть большая|

### Уточнения

1.1 iroute — про сети, находящиеся за клиентом. И важно: он виден только в таблице маршрутизации OpenVPN. Чтобы пакеты к такой сети реально ходили, серверу нужен ещё и системный маршрут — через route в server.conf. Пара работает так: route говорит ядру «эту сеть шли пакеты в tun0», а iroute говорит OpenVPN «внутри tun0 такие пакеты отдавай клиенту client».

1.2 route в CCD-файле — это не маршрут на сервере, а push, адресованный конкретному клиенту. В CCD-файле в методичке лежал iroute, и именно его конфликт с туннельной подсетью вызвал REMOVE PUSH ROUTE — OpenVPN сам чистит push, если сеть закреплена iroute за тем же клиентом.

1.3 push из server.conf действует на всех, а из CCD — на одного клиента.

1.4 Кстати, случай в методичке с iroute в CCD файле — образцовая иллюстрация того, почему iroute и route путают: звучат почти одинаково, а работают в противоположных направлениях. 

В методичке настроен client-config-dir /etc/openvpn/client, и файл /etc/openvpn/client/client (CCD-файл по имени сертификата клиента) содержит для этого клиента директиву iroute 10.10.10.0 255.255.255.0 — это видно по строке MULTI: internal route ... -> client. 

```
2026-11-20 15:12:37 192.168.56.1:39800 TLS: Initial packet from [AF_INET]192.168.56.1:39800, sid=4bee08c5 b7eb12a7
2026-11-20 15:12:37 192.168.56.1:39800 VERIFY OK: depth=1, CN=rasvpn
2026-11-20 15:12:37 192.168.56.1:39800 VERIFY OK: depth=0, CN=client
2026-11-20 15:12:37 192.168.56.1:39800 peer info: IV_VER=2.6.11
2026-11-20 15:12:37 192.168.56.1:39800 peer info: IV_PLAT=linux
2026-11-20 15:12:37 192.168.56.1:39800 peer info: IV_TCPNL=1
2026-11-20 15:12:37 192.168.56.1:39800 peer info: IV_MTU=1600
2026-11-20 15:12:37 192.168.56.1:39800 peer info: IV_NCP=2
2026-11-20 15:12:37 192.168.56.1:39800 peer info: IV_CIPHERS=AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305
2026-11-20 15:12:37 192.168.56.1:39800 peer info: IV_PROTO=990
2026-11-20 15:12:37 192.168.56.1:39800 peer info: IV_LZ4=1
2026-11-20 15:12:37 192.168.56.1:39800 peer info: IV_LZ4v2=1
2026-11-20 15:12:37 192.168.56.1:39800 peer info: IV_LZO=1
2026-11-20 15:12:37 192.168.56.1:39800 peer info: IV_COMP_STUB=1
2026-11-20 15:12:37 192.168.56.1:39800 peer info: IV_COMP_STUBv2=1
2026-11-20 15:12:37 192.168.56.1:39800 Control Channel: TLSv1.3, cipher TLSv1.3 TLS_AES_256_GCM_SHA384, peer certificate: 2048 bit RSA, signature: RSA-SHA256
2026-11-20 15:12:37 192.168.56.1:39800 [client] Peer Connection Initiated with [AF_INET]192.168.56.1:39800
2026-11-20 15:12:37 MULTI: new connection by client 'client' will cause previous active sessions by this client to be dropped.  Remember to use the --duplicate-cn option if you want multiple clients using the same certificate or username to concurrently connect.
2026-11-20 15:12:37 MULTI_sva: pool returned IPv4=10.10.10.6, IPv6=(Not enabled)
2026-11-20 15:12:37 OPTIONS IMPORT: reading client specific options from: /etc/openvpn/client/client
2026-11-20 15:12:37 MULTI: Learn: 10.10.10.6 -> client/192.168.56.1:39800
2026-11-20 15:12:37 MULTI: primary virtual IP for client/192.168.56.1:39800: 10.10.10.6
2026-11-20 15:12:37 MULTI: internal route 10.10.10.0/24 -> client/192.168.56.1:39800
2026-11-20 15:12:37 MULTI: Learn: 10.10.10.0/24 -> client/192.168.56.1:39800
2026-11-20 15:12:37 REMOVE PUSH ROUTE: 'route 10.10.10.0 255.255.255.0'
2026-11-20 15:12:37 Data Channel: using negotiated cipher 'AES-256-GCM'
2026-11-20 15:12:37 Outgoing Data Channel: Cipher 'AES-256-GCM' initialized with 256 bit key
2026-11-20 15:12:37 Incoming Data Channel: Cipher 'AES-256-GCM' initialized with 256 bit key
2026-11-20 15:12:37 SENT CONTROL [client]: 'PUSH_REPLY,topology net30,ping 10,ping-restart 120,ifconfig 10.10.10.6 10.10.10.5,peer-id 1,cipher AES-256-GCM' (status=1)
```

А дальше сработало правило из документации: **OpenVPN не пушит клиенту маршрут в сеть, которая уже закреплена за этим же клиентом через iroute** — ведь это «собственная» подсеть клиента, и маршрут до неё ему не нужен. Вот эта процедура вычёркивания и логируется как REMOVE PUSH ROUTE. Обратите внимание: в PUSH_REPLY маршрута действительно нет — только ifconfig, ping и cipher. Поэтому сервер не стал пушить этот маршрут клиенту — точнее было бы сказать: «сервер пушил, но сам же вычеркнул».

Из-за этого на клиенте после установления туннеля в таблице маршрутизации отсутствовал маршрут 10.10.10.0/24 via 10.10.10.5 dev tun0 , 
и поэтому пинги с сервера приходили на клиент из интерфейса tun0, но ответы клиента уходили в сторону маршрута по умолчанию.

Это можно исправить следующими способами:

1) На клиенте:

Добавить в файл конфигурации client.conf строку

```
route 10.10.10.0 255.255.255.0
```

Данная строка просто объявляет на клиенте нужный маршрут в сторону туннеля.

2) Как сделать, чтобы нужный маршрут пушил сам сервер:

2.1) Удалить из CCD-файла /etc/openvpn/client/client директиву iroute 10.10.10.0 255.255.255.0 (и push той же сети, если он там есть): iroute нужен для сетей, находящихся за клиентом, а не для самой туннельной сети — здесь он был лишним.

и добавить в server.conf:

```
push "route 10.10.10.0 255.255.255.0"
```

Заодно это правильная архитектура: маршрутизацией управляет сервер, а конфиг клиента остаётся минимальным — сервера рассылают маршруты, а не клиенты прописывают их вручную. 

**Примечание:** оказалось, что при добавлении в данном варианте дополнительной директивы push "route 10.10.10.0 255.255.255.0" маршрут стал пушиться на клиент дважды - эти видно в логах клиента при подключении:

```
<...>
2026-11-22 08:28:43 net_addr_ptp_v4_add: 10.10.10.6 peer 10.10.10.5 dev tun0
2026-11-22 08:28:43 net_route_v4_add: 10.10.10.0/24 via 10.10.10.5 dev [NULL] table 0 metric -1
2026-11-22 08:28:43 net_route_v4_add: 10.10.10.0/24 via 10.10.10.5 dev [NULL] table 0 metric -1
2026-11-22 08:28:43 sitnl_send: rtnl: generic error (-17): File exists
2026-11-22 08:28:43 NOTE: Linux route add command failed because route exists
2026-11-22 08:28:43 Initialization Sequence Completed
```

Это происходит оттого, что в файле server,conf сервера openvpn уже есть директива server 10.10.10.0 255.255.255.0  ， которая является helper-маркосом и при имеющейся конфигурации (по умолчанию dev tun, topology net30) макрос эквивалентен примерно этому:

```
mode server                          # режим мультипользовательского сервера
tls-server                           # серверная сторона TLS-рукопожатия
ifconfig 10.10.10.1 10.10.10.2   # адрес сервера и его фантомный пир
ifconfig-pool 10.10.10.4 10.10.10.251 255.255.255.0   # пул адресов для клиентов
route 10.10.10.0 255.255.255.0       # системный маршрут на сервере (через tun0)
push "route 10.10.10.0 255.255.255.0"   # ← вот ваш автоматический push
```

Отсюда и раскладка адресов, которую мы разбирали по .5/.6: первый блок /30 (.0–.3) — серверу (.1 и .2), следующие блоки раздаются клиентам из пула (.4–.7 → .5 и .6 первому клиенту, .8–.11 → второму и так далее). Пул заканчивается на .251 — OpenVPN резервирует хвост подсети на служебные нужды.


##### Сводка по механике пушей в итоговом конфиге

    push маршрута в туннельную сеть — делает макрос server автоматически (единственный источник, ручных пушей не осталось);
    REMOVE PUSH ROUTE в старых логах — это OpenVPN вычёркивал именно этот автоматический пуш из-за конфликта с iroute;
    маршруты в сети за клиентами — по-прежнему только вручную: push "route X" в конфиге/CCD + route + iroute.

То есть правило простое: всё, что касается туннельной подсети — забота макроса server (отдельный push маршрута туннельной подсети добавлять не нужно); всё, что дальше неё — ручная настройка.

##### Полезное следствие

Раз server делает push сам, в server.conf теперь ничего вручную пушить не нужно — конфиг можно было бы даже упростить. А если вы когда-нибудь перейдёте на topology subnet (см. далее), макрос сам изменит развёртку: ifconfig 10.10.10.1 255.255.255.0 и пул .2–.254 — без фантомных пиров и с нормальной маской у клиентов.

Есть и «брат» макроса для данных поверх TLS — server-bridge (режим bridge/TAP), который разворачивается в набор директив для L2-моста. В вашей лабе не нужен, но на защите спросят про отличие tun от tap — там как раз упомянуть.


2.2) Вариант ещё чище: topology subnet

Если хотите вообще без ручных маршрутов и без push, добавьте в server.conf:

```
topology subnet
```

В этой топологии клиент получает не точечный /30-пир (как у вас сейчас: 10.10.10.6 peer 10.10.10.5), а адрес с маской всей подсети — и маршрут 10.10.10.0/24 dev tun0 ядро устанавливает само, как для обычного Ethernet-интерфейса. Это современный рекомендуемый режим, и в нём ваша проблема «маршрут до 10.10.10.1» исчезает в принципе.



### Два этапа маршрутизации, две таблицы

route — системная таблица ядра, iroute — внутренняя таблица OpenVPN, которая решает, какому клиенту переслать пакет.

Разница в том, что эти две таблицы решают две разные задачи на двух разных этапах пути пакета.

Представьте, что туннель — это как локальная сеть: у сервера один интерфейс tun0, а за ним несколько клиентов. Пакет, летящий в сторону «сети за клиентом», проходит два этапа:

Этап 1 — системная таблица маршрутизации (ядро). Решает: «в какой интерфейс отправить пакет?» Скажем, приходит пакет на 192.168.100.5 (сеть за клиентом client). Системная таблица говорит: «шли пакет в tun0». Всё — на этом её компетенция заканчивается. Ядро понятия не имеет, что внутри tun0 есть несколько клиентов.

Этап 2 — внутренняя таблица OpenVPN (iroute). Пакет попал в процесс OpenVPN, тот его зашифровал и должен отправить какому-то конкретному клиенту через UDP-сокет. Какому? Вот тут и работает iroute: «сеть 192.168.100.0/24 → клиент client». OpenVPN инкапсулирует пакет и отправляет UDP-датаграмму именно этому клиенту.

Без iroute OpenVPN, получив пакет для 192.168.100.5, просто не знал бы, кому из подключённых клиентов его переслать, и выкинул бы его (а при client-to-client ещё и проверял, не принадлежит ли сеть другому клиенту — тоже по iroute).

##### Отсюда и правило пары

Так и объясняется связка, о которой мы говорили:

    route 192.168.100.0 255.255.255.0 в server.conf → этап 1: ядро знает, что сеть за tun0;
    iroute 192.168.100.0 255.255.255.0 в CCD → этап 2: OpenVPN знает, какой клиент за tun0 владеет этой сетью.

Нет первого — пакет вообще не попадёт в tun0 (ядро отправит его в default). Нет второго — пакет попадёт в tun0 и умрёт внутри процесса OpenVPN: адресат-клиент не определён.

##### Почему нельзя было обойтись одной системной таблицей

Собственно, ваш вопрос по сути: «почему бы ядру самому не выбирать клиента?» Ответ — потому что ядро не знает о клиентах вообще. С точки зрения ядра tun0 — одна точка-точка с одним пиром (10.10.10.2). Вся топология «многие клиенты за одним tun0» существует только внутри процесса OpenVPN: у него своя таблица «виртуальный IP клиента ↔ его реальный UDP-адрес (192.168.56.1:39800)»

**Важное уточнение:** у клиента внутренней таблицы openvpn нет и не должно быть. Клиент в OpenVPN — точка-точка: всё, что попало в tun0, уходит к серверу, разбираться там нечему. Его «знание» целиком состоит из конфига и push-опций. Вся внутренняя маршрутизация openvpn живёт на сервере.

### Про обратное направление: с клиента на сервер

Штатного механизма «клиент пушит маршруты серверу» нет — pull работает только в одну сторону: клиент тянет конфиг с сервера. Если нужно, чтобы сервер знал о сети за клиентом, это делается тремя путями:

- iroute в CCD — админ сервера заранее прописывает, какая сеть за каким клиентом. Это центральное управление, а не автоматика: клиент ничего не анонсирует сам.
  
- Скрипты client-connect / learn-address — например, скрипт при подключении клиента добавляет маршрут в систему.
  
- Динамический роутинг (OSPF/BGP через туннель) — единственный способ, когда маршруты реально анонсируются автоматически обеими сторонами.

### Полезные мелочи для лабы

- route-nopull в client.conf — клиент игнорирует все push-маршруты (удобно показать, что push можно «не принять»).

- pull-filter ignore "route 10.10.10.0" — выборочно отфильтровать конкретный push.

- push "route 10.10.10.0 255.255.255.0" можно класть и в CCD — если хотите, чтобы разные клиенты видели разные части сети.


#### Как посмотреть таблицу маршрутизации openvpn на сервере ?

Можно — частично напрямую, частично хитростью. Но сначала важное уточнение: у клиента внутренней таблицы нет и не должно быть. Клиент в OpenVPN — точка-точка: всё, что попало в tun0, уходит к серверу, разбираться там нечему. Его «знание» целиком состоит из конфига и push-опций. Вся внутренняя маршрутизация живёт на сервере. Вот как её посмотреть.

##### Способ 1: status-файл с форматом version 3

У вас уже есть status /var/log/openvpn-status.log, но по умолчанию формат вывода скудный. Добавьте в server.conf:

```
status-version 3
```

перезапустите сервер, и в файле появятся две таблицы — список клиентов и таблица изученных виртуальных адресов (это как раз та самая «таблица соответствия», о которой мы говорили в прошлый раз):

```
HEADER,CLIENT_LIST,Common Name,Real Address,Virtual Address,...
CLIENT_LIST,client,192.168.56.1:39800,10.10.10.6,...
HEADER,ROUTING_TABLE,Virtual Address,Common Name,Real Address,Last Ref
ROUTING_TABLE,10.10.10.6/32,client,192.168.56.1:39800,...
```

##### Способ 2: management-интерфейс

Добавьте в server.conf:

```
management 127.0.0.1 7505
```

(и для лабы management-client не нужен — это локальный сокет). После перезапуска:

```
telnet 127.0.0.1 7505
> status 3
```

Тот же вывод, что и в status-файле, но по запросу и в реальном времени. Команда help покажет весь набор команд интерфейса — полезно покрутить для отчёта.

##### Способ 3: SIGUSR2 без перенастройки

Если лень менять конфиг и перезапускать сервер:

```
kill -USR2 $(pidof openvpn)
tail -40 /var/log/openvpn.log
```

OpenVPN по сигналу USR2 вывалит в лог текущие CLIENT LIST и ROUTING TABLE. Удобно, когда туннель уже работает и хочется сохранить состояние «как есть».

##### А где же увидеть сами iroute?

Вот тут честная оговорка: отдельной команды «показать таблицу iroute» нет — ни в management-интерфейсе, ни в status-файле. Записи iroute видны косвенно:

- в логе при подключении клиента — строки MULTI: internal route 10.10.10.0/24 -> client/... (у вас они уже были в выводе при verb 3);

- косвенно в behavior: если отправить пакет на адрес из iroute-сети, лог покажет, какому клиенту он ушёл.

При этом ROUTING TABLE в status показывает не iroute'ы, а learned addresses — виртуальные адреса клиентов, выученные из их трафика (механизм learn-address). Это разные вещи: learned = «где физически сидит виртуальный IP», iroute = «какая сеть закреплена за клиентом в CCD».

##### На клиенте

Внутренней таблицы нет, но посмотреть информацию о сессии можно тем же management-интерфейсом (management 127.0.0.1 7506 в client.conf) — там будут status, время сессии, байты туда-обратно. А «маршрутизацию» клиента полностью описывают ip route плюс то, что сервер запушил — видно в логе клиента в строке PUSH: Received control message.

Для лабы красивая связка: показать ROUTING_TABLE из status-файла рядом со строками MULTI: internal route из лога и объяснить в выводах, что первая — выученные адреса, вторая — статические iroute из CCD. Демонстрирует понимание обоих уровней внутренней маршрутизации OpenVPN.


### Как организовать выход трафика из туннеля в сеть за сервером (10.0.2.0/24): ip_forward, NAT или без него. 

Задача: клиент с адресом 10.10.10.6 должен достучаться до машин в сети 10.0.2.0/24, в которой живёт сам сервер. Разберём, что нужно и почему.

##### Что мешает трафику пройти прямо сейчас

Два независимых препятствия, и оба надо устранить:

- Клиент не знает, куда идти. В его таблице маршрутов сети 10.0.2.0/24 нет — пакет уйдёт в default через eth0, то есть мимо туннеля. Лечится push'ом.

- Сервер не пересылает чужие пакеты. По умолчанию Linux-роутером не является: получив пакет «из tun0 в eth0», ядро его молча выбросит — это не его адресат. Лечится включением ip_forward. Плюс обратный трафик из сети 10.0.2.0/24 должен знать дорогу назад к 10.10.10.0/24 — а она знает только через NAT.

###### Шаг 1. Push маршрута клиентам

В server.conf (макрос server тут не поможет — он пушит только свою туннельную сеть):

```
push "route 10.0.2.0 255.255.255.0"
```

После переподключения клиента на нём появится:

```
10.0.2.0/24 via 10.10.10.5 dev tun0
```

###### Шаг 2. Включаем пересылку на сервере

```
# проверить текущее состояние
sysctl net.ipv4.ip_forward        # 0 = пересылка выключена

# включить сразу и навсегда
echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-forward.conf
sysctl -p /etc/sysctl.d/99-forward.conf
```

ip_forward=1 — это разрешение ядру работать маршрутизатором: принимать пакет на одном интерфейсе и отправлять в другой. Теперь сервер готов пересылать, но маршрутизации в обратную сторону ещё нет — переходим к выбору.

###### Шаг 3. Обратный путь: NAT или симметричная маршрутизация

Пакет дойдёт до цели, но ответ полетит с адресом источника 10.10.10.6 — а машины в 10.0.2.0/24 этого адреса не знают и пошлют ответ в свой default-шлюз, мимо сервера. Два классических решения:

Вариант А — NAT (проще и обычно для лабы достаточно):

```
iptables -t nat -A POSTROUTING -s 10.10.10.0/24 -o eth0 -j MASQUERADE
```

Все пакеты из туннельной сети при выходе через eth0 получают адрес сервера — для сети 10.0.2.0/24 это выглядит как трафик от самого сервера, и ответ гарантированно вернётся. Чтобы правило пережило перезагрузку: apt install iptables-persistent (Debian/Ubuntu) и сохранить.

Вариант Б — симметричная маршрутизация (без NAT, «честнее»):

Добавить на шлюз сети 10.0.2.0/24 маршрут:


```
10.10.10.0/24 via <адрес сервера в этой сети>
```

Тогда ответы знают дорогу назад. Минусы: нужен доступ к конфигурации шлюза, и пакет должен пройти через него — в VirtualBox NAT-сети (а судя по 10.0.2.15) шлюз нам не подконтролен. Плюсы: реальные адреса видны на конечных хостах, нет двойного NAT.

В лабе вариант А — рабочий выбор, потому что сеть 10.0.2.0/24 у VirtualBox NAT-ная и её шлюз — не ваш.

###### Шаг 4. Проверка

```
# на клиенте
ping 10.0.2.15          # сам сервер в той сети
ping 10.0.2.3           # соседний хост, если есть
traceroute 10.0.2.3     # должно быть: 10.10.10.5 → 10.10.10.1 → цель (1-2 хопа)
```

Для диагностики по пути на сервере:

```
tcpdump -ni tun0 icmp     # пакеты дошли до туннеля сервера?
tcpdump -ni eth0 icmp     # уходят в сеть с подменённым адресом?
```

Если пинг сервера работает, а хостов за ним нет — почти всегда это FORWARD-цепочка (проверьте iptables -L FORWARD, не DROP ли policy) либоSelinux/фаервол на хосте-цели.

Полная картина пути пакета:

```
КЛИЕНТ (10.10.10.6)                СЕРВЕР (10.10.10.1 / 10.0.2.15)          ЦЕЛЬ (10.0.2.3)
     │  ping 10.0.2.3                     │                                    │
     │  маршрут: via 10.10.10.5           │                                    │
     │ ─────── шифрованный туннель ──────►│ расшифровка                        │
     │                                    │ 1. ip_forward разрешает пересылку  │
     │                                    │ 2. FORWARD-цепочка пропускает      │
     │                                    │ 3. POSTROUTING: MASQUERADE         │
     │                                    │    src 10.10.10.6 → 10.0.2.15      │
     │                                    │ ──────── eth0 ────────────────────►│
     │                                    │◄──────────────── ответ ────────────│
     │◄──── туннель, расшифровка ─────────│ NAT восстанавливает адрес          │
     │  ← ICMP Echo Reply                 │                                    │
```

Выводы:

- Выход из туннеля в чужую сеть требует трёх независимых настроек: маршрут на клиенте (push), пересылка на сервере (ip_forward), обратный путь (NAT или маршрут на шлюзе).

- NAT скрывает топологию: адрес источника 10.10.10.6 не виден за сервером — это плюс для безопасности и минус для трассировки.

- Три уровня, где пакет может «застрять»: клиентская таблица маршрутов → ip_forward/iptables на сервере → обратный маршрут. Диагностика — по цепочке tcpdump'ом.



## 2. Генерация сертификатов на сервере с помощью easy-rsa


Всё идёт по плану, но есть нюанс: перед подписью серверного сертификата в вашей PKI должен уже существовать CA — а судя по выводу, вы его ещё не создавали. Без него sign-req упадёт с ошибкой «missing CA key» или попросит несуществующий ключ. Плюс трюк с echo 'yes' сработает только для подтверждения (Type the word 'yes' to continue), но не для ввода пароля CA — поэтому на лабе удобнее делать CA без пароля.

Полная последовательность генерации сертификатов для сервера выглядит так:

```
# 1. Создаём CA (один раз)
/usr/share/easy-rsa/easyrsa build-ca nopass

# 2. Запрос + ключ сервера
echo 'rasvpn' | /usr/share/easy-rsa/easyrsa gen-req server nopass

# 3. Подписываем сертификат сервера
echo 'yes' | /usr/share/easy-rsa/easyrsa sign-req server server

# 4. Параметры Диффи-Хеллмана
/usr/share/easy-rsa/easyrsa gen-dh

# 5. Список отзыва сертификатов (нужен для server.conf: crl-verify)
/usr/share/easy-rsa/easyrsa gen-crl
```

Пара деталей, которые обычно всплывают на этом этапе:

- Common Name. На запрос «Common Name [server]:» можно просто нажать Enter — имя уже подставлено из аргумента команды. Если вводите что-то своё, оно не должно совпадать с именем клиента.

- nopass. У серверного ключа пароль стоять не должен — иначе OpenVPN при перезапуске будет ожидать его ввода вручную, что удобно не очень.

- После sign-req сертификат ляжет в /etc/openvpn/pki/issued/server.crt, а ключ уже есть в /etc/openvpn/pki/private/server.key — именно эти пути пойдёт в server.conf (строки cert и key).

Дальше по классике: генерируете клиентские сертификаты той же парой gen-req + sign-req client client1, копируете файлы, пишете server.conf с port 1194, proto udp, dev tun, указываете пути к ca.crt, server.crt, server.key, dh.pem, crl.pem, добавляете tls-crypt (или ta.key при tls-auth), включаете net.ipv4.ip_forward=1 и NAT в iptables/firewall.

Кстати, ваш init-pki создал директорию /etc/openvpn/pki — а в стандартном гайде она обычно находится там же, где выполняются команды easy-rsa. Убедитесь, что все команды запускаете из одного каталога, чтобы easy-rsa не пересоздал PKI в другом месте.


Общее описание
==============


PKI как раз тот случай, когда «магия методички» распадается на понятные вещи за один разбор. И заодно я нашёл в вашем выводе занятную ловушку, которую методичка сама себе заложила (про ca.key — ниже).

Ключевая идея PKI: асимметричная криптография и доверие

Вся система держится на трёх фактах:

- У каждого участника — пара ключей: приватный (секрет, никогда не покидает владельца) и публичный (можно показывать всем).

- Сертификат — это не ключ, а «паспорт»: публичный ключ + имя владельца + срок действия + подпись издателя.

- Подпись CA — криптографическая гарантия: «я, центр сертификации, проверил, что этому публичному ключу действительно принадлежит это имя».

Цепочка доверия выглядит так:

```
ca.crt (самоподписанный, корень доверия)
 ├── server.crt  ← подписан CA, EKU: TLS Web Server Authentication
 └── client.crt  ← подписан CA, EKU: TLS Web Client Authentication
```

При рукопожатии TLS каждый проверяет сертификат другого: 

- подпись восходит к ca.crt (который известен обеим сторонам заранее),
  
- имя совпадает с ожидаемым (remote-cert-tls server проверяет ещё и EKU — вы это видели в логе клиента),

- срок не истёк.

Всё это и сработало в вашем логе: 

- VERIFY OK: depth=1, CN=rasvpn — это проверка самого CA (depth=1 — уровень в цепочке), 
- VERIFY OK: depth=0, CN=rasvpn — сертификат сервера.

Что сделал каждый шаг — по вашим командам:

1. init-pki создал каркас /etc/openvpn/pki — по сути, «бумажный архив» мини-CA: каталоги для запросов, подписанных сертификатов, ключей и — важная деталь — базу данных выданных сертификатов.

2. build-ca сгенерировал пару ключей CA (pki/private/ca.key + pki/ca.crt) и самоподписал корневой сертификат. Самоподписанный — потому что у CA нет «вышестоящего» издателя: он сам себе корень доверия. CN у него rasvpn (то самое echo 'rasvpn' | — Easy-RSA взял первую строку stdin как ответ на вопрос про Common Name, приём методички против интерактивных вопросов). nopass — приватный ключ CA без пароля: для лабы удобно, в реальной жизни CA-ключ хранят под паролем, потому что кто владеет им — тот может выпускать сертификаты на любое имя.

3. gen-req server сгенерировал пару ключей сервера: pki/private/server.key и запрос на подпись (CSR, pki/reqs/server.req). CSR — это по сути «заявление»: «вот мой публичный ключ, вот моё имя, подпишите, пожалуйста». **Важно:** приватный ключ в CSR не передаётся — только публичная часть и идентичность.

4. sign-req server server — CA изучил запрос и выпустил сертификат: pki/issued/server.crt. Тут произошли три вещи, которых не видно в выводе:

- Подпись сертификата — математически связывает публичный ключ из CSR с его именем и сертификатом CA;

- В сертификат вписан EKU — назначение «TLS Web Server Authentication» (для client-запросов было бы «Client Authentication»). Именно поэтому серверный и клиентский сертификаты не взаимозаменяемы;

- CA записал выдачу в свою базу — pki/index.txt и pki/serial. Отсюда и строчка Write out database with 1 new entries, и предупреждение unique_subject — невредный шум от OpenSSL про настройки этой базы.

5. Для клиента всё то же самое вторым заходом: gen-req client + sign-req client client → issued/client.crt.

6. gen-dh сгенерировал параметры Диффи–Хеллмана (dh.pem) — это не про иерархию сертификатов, а про выработку сеансовых ключей. Заметьте: в вашем логе видно peer temporary key: 253 bits X25519 — реальное рукопожатие уже идёт по современным эллиптическим кривым, а классический DH-файл нужен OpenVPN как поддержка для старых наборов шифров (DHE). Артефакт совместимости, обязательный в конфиге, но в TLS 1.3 не участвующий.

7. openvpn --genkey secret ca.key — и вот тут методичка вводит в заблуждение именем файла. Эта команда генерирует не ключ CA и вообще не сертификат, а симметричный статический ключ OpenVPN для директив tls-auth/tls-crypt — общий секрет, которым трафик контрольного канала дополнительно аутентифицируется/шифруется (защита от DoS и сканеров). Имя ca.key выбрано неудачно: настоящий приватный ключ CA лежит в pki/private/ca.key, а этот файл — отдельная сущность, к PKI отношения не имеющая (впрочем, в вашем server.conf ни tls-auth, ни tls-crypt не указаны — так что этот файл сейчас просто валяется неиспользуемым).
   
Карта каталога pki

|Файл	|Что это	|Секретность |
|!----------------------|!---------------------|!--------------------------------|
|pki/ca.crt	|Корневой сертификат CA	|Публичный, раздаётся всем |
|pki/private/ca.key	|Приватный ключ CA	|Высшая секретность — кто им владеет, выпускает сертификаты на любые имена |
|pki/private/server.key	|Ключ сервера	|Только сервер |
|pki/private/client.key	|Ключ клиента	|Только клиент (у вас он уезжает на хост) |
|pki/reqs/*.req	|CSR, запросы на подпись	|После подписания не нужны |
|pki/issued/*.crt	|Подписанные сертификаты	|Публичные |
|pki/index.txt, pki/serial	|База выданных: имена, серийники, даты	|Внутреннее хозяйство CA |
|pki/certs_by_serial/	|Сертификаты по серийным номерам	|Дубликат issued/ |

Обратите внимание на pki/index.txt — откройте его, там видно оба выданных сертификата с валидностью. Это ровно та база, из которой работают easyrsa revoke и CRL: отозвать сертификат = пометить запись в этой базе и сгенерировать список отзыва (easyrsa gen-crl + crl-verify в конфиге сервера).

Как это работает в сессии OpenVPN

- Обе стороны знают ca.crt заранее (вам его скопировали на хост) — это и есть доверенная точка, «корень».

- TLS-рукопожатие: сервер показывает server.crt, клиент — client.crt.

- Каждая сторона проверяет подпись чужого сертификата своим ca.crt, срок, EKU (remote-cert-tls server на клиенте) и владение ключом — сервер должен доказать, что владеет приватным server.key, соответствующим предъявленному сертификату.

- Дальше стороны по обмену по DH/X25519 вырабатывают сеансовые ключи (Outgoing Data Channel: Cipher 'AES-256-GCM' initialized with 256 bit key) — сертификаты после этого уже не участвуют, они нужны только для аутентификации рукопожатия.

Отсюда практический вывод: компрометация server.key не раскрывает прошлый трафик (прямая секретность), но позволяет представляться этим сервером — а компрометация ca.key подрывает всю PKI: злоумышленник может подписать себе сертификат на любое имя, и клиенты примут его. Поэтому CA-ключ живёт на сервере под паролем и отдельными правами.

Что стоит проверить руками (вместо слепого копирования)

```
# посмотреть содержимое сертификата: срок, EKU, подпись, серийник
openssl x509 -in /etc/openvpn/pki/issued/server.crt -noout -text

# проверить цепочку: подписан ли client.crt именно вашим CA
openssl verify -CAfile /etc/openvpn/pki/ca.crt /etc/openvpn/pki/issued/client.crt

# сопоставить публичные ключи сертификата и приватного ключа (совпадают хэши — пара согласована)
openssl x509 -in /etc/openvpn/pki/issued/client.crt -pubkey -noout | md5sum
openssl pkey -in /etc/openvpn/pki/private/client.key -pubout | md5sum

# а это тот самый «не-CA» файл:
openssl rsa -in ca.key -check        # сообщит: ключи не RSA, это OpenVPN static key
```

Таким образом: подпись сертификата = «аттестация связи публичный ключ ↔ имя», EKU = разделение ролей сервер/клиент.


Краткий список аббревиатур

|Аббревиатура	|Расшифровка	|Смысл |
|!----------|!----------------------------|!---------------------------------------------------|
|PKI	|Public Key Infrastructure	Инфраструктура открытых ключей. |Это не один файл, а целая система: центры сертификации, каталоги сертификатов, процедуры выпуска и отзыва (CRL и т.д.) |
|CA	|Certificate Authority	Удостоверяющий центр. |Выпускает и подписывает сертификаты. Корневой CA — самоподписанный («корень доверия»). Кто владеет его приватным ключом (pki/private/ca.key), тот может выпускать сертификаты на любые имена.|
|CN	|Common Name	«Общее имя». |Элемент Distinguished Name (DN) в сертификате. У вас: CN=rasvpn, CN=client. Это то, что попадает в поле subject. (Для современных публичных сертификатов главное — SAN, Subject Alternative Name; CN сейчас часто игнорируется.) |
|EKU	|Extended Key Usage	Расширенное использование ключа.|Это расширение X.509: оно уточняет не просто «это сертификат», а «этот сертификат для чего именно». Примеры: TLS Web Server Authentication (серверный сертификат), TLS Web Client Authentication (клиентский). Именно это проверяет опция remote-cert-tls server / remote-cert-tls client — чтобы клиентский сертификат не превратился в сервер |

Связка для картины

Это иерархия: PKI → содержит CA → CA подписывает сертификаты → в сертификате есть CN (часть DN) и EKU (назначение).

Пример из лабы: корень доверия — pki/ca.crt (самоподписанный CA, CN=rasvpn). Он подписал pki/issued/server.crt (CN=rasvpn, EKU = TLS Web Server Authentication). Клиент проверяет цепочку («подпись восходит к ca.crt»), смотрит на CN и EKU (remote-cert-tls server) — и только тогда принимает соединение.

Подсказать, как это красиво свернуть в одну схему для раздела «PKI в OpenVPN» в отчёте?


Разложу на три слоя: иерархия доверия, потоки файлов и проверка при рукопожатии. 

Схема 1. Иерархия PKI в вашем лабораторном стенде

```
                    ┌─────────────────────────────┐
                    │        CA (CN=rasvpn)       │
                    │  ca.crt      ca.key         │
                    │  (публичный) (СЕКРЕТ!)      │
                    │  самоподписанный корень     │
                    └──────────┬──────────────────┘
                               │ подписывает запросы (CSR)
              ┌────────────────┴────────────────┐
              ▼                                 ▼
   ┌─────────────────────┐          ┌─────────────────────┐
   │      Сервер          │          │      Клиент         │
   │  CN=rasvpn           │          │  CN=client          │
   │  EKU: Server Auth    │          │  EKU: Client Auth   │
   │  server.crt          │          │  client.crt         │
   │  server.key (секрет) │          │  client.key (секрет)│
   └─────────────────────┘          └─────────────────────┘
```

Схема 2. Поток данных при выпуске сертификатов

```
ГЕНЕРАЦИЯ ПАРИРОВАННЫХ КЛЮЧЕЙ + ЗАПРОСА          ПОДПИСАНИЕ CA

easyrsa gen-req server                easyrsa sign-req server server
   │                                        │
   ├── pki/private/server.key  ──► сервер   │  CA читает запрос,
   │                            (никогда    │  проверяет, подписывает:
   │                             не покидал)│
   └── pki/reqs/server.req    ──► CA  ──────┴──► pki/issued/server.crt
        (содержит ТОЛЬКО                          (публичный, копируется
         публичный ключ + имя)                      на все стороны)
```

То же самое для клиента: gen-req client → sign-req client client

Ключевая мысль схемы: приватный ключ появляется на месте генерации и оттуда не уезжает — CA получает только запрос. В лабе, правда, всё генерировалось на одном сервере, так что «уезд» ключа условный — в реальной инфраструктуре запросы генерируют на самих машинах, а CA видит только .req.

Схема 3. Проверка при TLS-рукопожатии (то, что видно в логах)

```
КЛИЕНТ                                  СЕРВЕР
   │                                       │
   │ ── TLS ClientHello ──────────────────►│
   │◄──────────────── TLS ServerHello ─────│  + server.crt
   │                                       │
   │ ПРОВЕРКИ СЕРВЕРА:                     │
   │  1. server.crt подписан моим ca.crt   │  → VERIFY OK depth=1 CN=rasvpn
   │  2. EKU = Server Auth                 │  → VERIFY EKU OK
   │  3. срок действия не истёк            │
   │  4. сервер докажет владение           │
   │     server.key                        │
   │                                       │
   │ ◄── запрос клиентского серта ─────────│
   │ ── client.crt ───────────────────────►│
   │                                       │ ПРОВЕРКИ НА СЕРВЕРЕ:
   │                                       │  1. client.crt подписан CA
   │                                       │  2. EKU = Client Auth
   │                                       │  3. CN есть в базе (index.txt)
   │                                       │  4. владение client.key
   │                                       │
   │ ◄════ обмен по X25519/DH ═════════════│
   │      выработка сеансового ключа       │
   │      (AES-256-GCM для данных)         │
   │                                       │
   │ ═══ шифрованный туннель ═════════════►│
```

Сопоставьте с реальными строками ваших логов — они ложатся в схему один в один:

- клиентский лог: VERIFY OK: depth=1, CN=rasvpn → VERIFY OK: depth=0, CN=rasvpn → VERIFY EKU OK → Peer temporary key: 253 bits X25519 → Data Channel: cipher 'AES-256-GCM';

- серверный лог: VERIFY OK: depth=0, CN=client → MULTI: Learn: 10.10.10.6 -> client/....

Схема 4. Кто какие файлы использует и хранит


```
                    ┌──────────────┐        ┌──────────────┐
   НА СЕРВЕРЕ       │ server.conf  │        │ client.conf  │  НА КЛИЕНТЕ
                    │              │        │              │
  ca.crt   ◄────────┼── ca    ─────┼───────►┼── ca    ─────┼──► ca.crt
  server.crt◄───────┼── cert  ─────┤        │              │
  server.key◄───────┼── key   ─────┤        │              │
  dh.pem   ◄────────┼── dh    ─────┤        │              │
                    │              │        │              │
                    │              │        │  cert  ──────┼──► client.crt
                    │              │        │  key   ──────┼──► client.key
                    │              │        │  ca    ──────┼──► ca.crt
                    └──────────────┘        └──────────────┘
```

Обратите внимание: ca.crt нужен обеим сторонам — это общая точка доверия. Серверу не нужен client.crt (он проверяет клиента по цепочке от ca.crt и по своей базе), клиенту не нужен server.key — приватные ключи не копируются никогда.

Выводы:

- PKI построена на асимметричной криптографии: сертификат — публичный «паспорт», приватный ключ — доказательство владения им.

- Цепочка доверия начинается с самоподписанного CA; проверка сертификата = проверка подписи, срока, EKU и принадлежности имени.

- EKU разделяет роли: серверный сертификат нельзя использовать как клиентский — защита от «подмены ролей».

- Сертификаты участвуют только в рукопожатии; сеансовые ключи вырабатываются заново (X25519/DH) — обеспечивается прямая секретность.

- Самое ценное — pki/private/ca.key; его компрометация разрушает всю PKI, поэтому в реальной практике CA-ключ хранят под паролем и часто вообще на отдельной машине.


### А как построена иерархия с промежуточными центрами сертификации и разграничением их влияния ? Как они ложатся в эту схему, где находятся ?

Отличное продолжение — и как раз тот случай, когда ваша лаба даёт точку опоры: то, что вы видели в логе как VERIFY OK: depth=1 и depth=0, — это и есть глубина цепочки сертификации. Сейчас станет ясно, что эти цифры значат.

##### Зачем вообще промежуточные CA

В вашей лабе всё подписано одним корневым CA — так делают в лабораториях. В реальной инфраструктуре корневой ключ держат офлайн: в безопаснике, на отключённой машине, он включается только для выпуска новых промежуточных CA или ротации. А ежедневная работа — подпись серверных и клиентских сертификатов, отзыв, продление — идёт через промежуточные центры. Логика такая:

- компрометация промежуточного CA лечится его отзывом — корень цел;

- у каждого промежуточного CA — своя зона ответственности (отдел компании, регион, класс сертификатов);

- корень почти не рискует, потому что почти никогда не онлайн.

##### Схема цепочки

```
        ┌──────────────────────────┐
        │  Root CA (офлайн)        │  ← единственная точка доверия,
        │  самоподписанный         │    хранится отдельно, почти не используется
        │  ca.key под паролем      │
        └────────────┬─────────────┘
                     │ подписывает (редко!)
        ┌────────────▼─────────────────────────┐
        │  Intermediate CA «Отдел А»           │  ← промежуточный:
        │  подписан корнем                     │    живёт на рабочем сервере,
        │  CA:TRUE, pathlen:0                  │    подписывает концевые серты
        └───────┬───────────────┬──────────────┘
                │               │
        ┌───────▼──────┐ ┌──────▼───────┐
        │ server.crt   │ │ client.crt   │  ← концевые сертификаты
        │ EKU: Server  │ │ EKU: Client  │    (листья, дальше ничего не подписывают)
        └──────────────┘ └──────────────┘
```

Где «находятся» промежуточные CA — вопрос с подвохом, потому что у них нет «места» в том смысле, как у файлов на конкретной машине. Промежуточный сертификат — это просто ещё один сертификат в цепочке. Он физически существует как файл (обычно у издателя — промежуточного CA), а при TLS-рукопожатии сервер предъявляет клиенту всю цепочку: свой сертификат + промежуточный(-е). Клиент получает её целиком и строит путь до корня, которого он знает заранее.

##### Как верификация видит эту цепочку

Клиент проверяет каждый уровень: корневой подписан сам собой, промежуточный подписан корнем, концевой — промежуточным. В логах OpenVPN параметр depth — это номер уровня цепочки, считая от концевого сертификата:

|Лаба (1 уровень)	|С промежуточным (2 уровня) |
|!---------------------------|!-------------------------|
|VERIFY OK: depth=1, CN=rasvpn — корень	|depth=2 — корень |
|VERIFY OK: depth=0, CN=rasvpn — серт сервера	|depth=1 — промежуточный |
|                 |                           |depth=0 — серт сервера  |

Клиенту по-прежнему нужен только корень (ca /etc/openvpn/pki/ca.crt) — промежуточные сертификаты сервер должен передать сам в рукопожатии (в OpenVPN это делается либо склейкой в один файл cert, либо директивой extra-certs). Если промежуточный серт не передан, клиент не сможет достроить цепочку — типичная ошибка «certificate verify failed» в реальном мире.

##### Разграничение влияния: чем ограничивают промежуточные CA

Иерархия держится не на «уставе», а на расширениях сертификата — они вшиваются в промежуточный серт при подписании и становятся его «паспортными ограничениями»:

|Ограничение	|Расширение X.509	|Что запрещает |
|!---------------|!-------------------|!----------------------------------------------------------|
|Глубина подчинения	|BasicConstraints: CA:TRUE, pathlen:0	|Промежуточному нельзя выдавать свои промежуточные — только концевые серты. Ваша схема «корень → промежуточный → листья» не может разрастись вглубь |
|Тип подписываемого	|KeyUsage / EKU	|Промежуточный может быть ограничен, например, выпуском только клиентских сертификатов — серверный уже не подпишет |
|Пространство имён	|NameConstraints	|Подписывать сертификаты только с CN/DNS в заданной зоне (например, только *.office.example.org) |
|Политики	|CertificatePolicies	|Формальное закрепление регламента выпуска (для аудит-проверок) |
|Отзыв	CRL |Distribution Points / OCSP	|Где проверять, не отозван ли сертификат |

pathlen — самое наглядное: корень подписывает промежуточный с pathlen:0, и если тот попытается выдать свой промежуточный, цепочка от него не пройдёт проверку. Так «влияние» режется не административно, а криптографически.


##### Как это ложится в схему лабы

Хорошая новость: почти ничего не меняется в архитектуре OpenVPN — добавляется ещё один этаж и один файл.

- Выпуск: easyrsa build-ca → затем build-ca subca (в Easy-RSA есть отдельный режим подпCenter — ./easyrsa build-ca subca nopass), потом sign-req промежуточного корневым, а клиентские/серверные запросы подписываются уже промежуточным.

- Конфиг: в ca у всех сторон остаётся только корневой ca.crt; серверу добавляется cert-файл вида fullchain (серверный серт + промежуточный) либо extra-ca.

- Лог: вместо одной пары depth=1/depth=0 вы увидите три строки VERIFY — и это прямое доказательство цепочки из двух уровней для отчёта.
    Отзыв: у каждого CA своя база и свой CRL — сервер проверяет отзыв концевого серта по crl-verify промежуточного.

Для отчёта эта тема разворачивается в красивое сравнение: «в лабе — плоская иерархия (один CA), в продакшене — дерево с офлайн-корнем, pathlen ограничивает глубину, NameConstraints — пространство имён, CRL — отзыв».

##### Как в Easy-RSA поднять промежуточный CA поверх rasvpn в лабе, а глубину в логе увидеть сразу ?

Всё ниже заточено под текущую инсталляцию: корневой PKI уже лежит в /etc/openvpn/pki (CN=rasvpn), Easy-RSA вызывается как /usr/share/easy-rsa/easyrsa, а ваш трюк с echo ... | для неинтерактивных ответов сохраняем. Итог — цепочка «rasvpn → rasvpn-inter → концевые серты» и depth=2 в логах. План рабочий процесс из четырёх этапов: строим промежуточный CA, подписываем корнем, выпускаем от него концевые серты, подключаем к OpenVPN.

##### Этап 1. Отдельный PKI для промежуточного CA

Промежуточному CA положено жить в своём каталоге — это не «ещё один файл», а полноценный центр с собственной базой выданных сертификатов:

```
/usr/share/easy-rsa/easyrsa --pki-dir=/etc/openvpn/pki-intermediate init-pki

# строим subca: генерируется пара ключей и ЗАПРОС (не самоподписанный сертификат!)
echo 'rasvpn-inter' | /usr/share/easy-rsa/easyrsa --pki-dir=/etc/openvpn/pki-intermediate build-ca subca nopass
```

Обратите внимание на ключевое отличие от build-ca без параметра: обычный CA сам себя подписывает, а subca создаёт только ключ и запрос на подпись — он появится в pki-intermediate/reqs/ca.req. Промежуточный CA не имеет права подписать сам себя — его должен удостоверить корень. Это и есть иерархия в действии.


##### Этап 2. Корень подписывает промежуточный

Переключаемся в PKI корня и работаем как обычный CA, только тип запроса теперь ca:

```
# импортируем запрос промежуточного в PKI корня
/usr/share/easy-rsa/easyrsa --pki-dir=/etc/openvpn/pki import-req \
  /etc/openvpn/pki-intermediate/reqs/ca.req rasvpn-inter

# подписываем его как CA-сертификат
echo 'yes' | /usr/share/easy-rsa/easyrsa --pki-dir=/etc/openvpn/pki sign-req ca rasvpn-inter
```

Теперь возвращаем подписанный сертификат промежуточному — он становится его «корнем доверия»:

```
cp /etc/openvpn/pki/issued/rasvpn-inter.crt /etc/openvpn/pki-intermediate/ca.crt
```

Сразу посмотрим, что внутри — там и должны быть те самые ограничения влияния:

```
openssl x509 -in /etc/openvpn/pki-intermediate/ca.crt -noout -text | grep -A2 'Basic Constraints'
# X509v3 Basic Constraints: critical
#     CA:TRUE, pathlen:0      ← можно подписывать только концевые серты
```

##### Этап 3. Выпуск концевых сертификатов от промежуточного

Теперь все рабочие серты подписывает уже промежуточный CA — именно так корень «отходит от дел». Сгенерируем новую пару для сервера (старую оставим нетронутой, чтобы не сломать работающий туннель):

```
echo 'server2' | /usr/share/easy-rsa/easyrsa --pki-dir=/etc/openvpn/pki-intermediate gen-req server2 nopass
echo 'yes'     | /usr/share/easy-rsa/easyrsa --pki-dir=/etc/openvpn/pki-intermediate sign-req server server2

echo 'client2' | /usr/share/easy-rsa/easyrsa --pki-dir=/etc/openvpn/pki-intermediate gen-req client2 nopass
echo 'yes'     | /usr/share/easy-rsa/easyrsa --pki-dir=/etc/openvpn/pki-intermediate sign-req client client2
```

Проверим, что цепочка математически сходится — трёхуровневая верификация openssl:

```
openssl verify -CAfile /etc/openvpn/pki/ca.crt \
               -untrusted /etc/openvpn/pki-intermediate/ca.crt \
               /etc/openvpn/pki-intermediate/issued/server2.crt
```

Флаг -untrusted — это буквально «промежуточные звенья, переданные сервером»: их сертификаты не доверенные сами по себе, они лишь мосты к корню. Ровно так их и рассматривает TLS-клиент.


##### Этап 4. Подключение к OpenVPN

Конфигурация почти не меняется — добавляется один файл. На сервере:

```
ca           /etc/openvpn/pki/ca.crt                      # корень — как и был
cert         /etc/openvpn/pki-intermediate/issued/server2.crt
key          /etc/openvpn/pki-intermediate/private/server2.key
extra-certs  /etc/openvpn/pki-intermediate/ca.crt         # ← цепочка для клиентов
```

extra-certs — это директива «прикладывай эти сертификаты к своему в рукопожатии». Без неё клиент, знающий только корень, не достроит цепочку и откажет в соединении — как раз та типичная ошибка, о которой я говорил: промежуточный серт должен передать сервер.


На клиенте (для client2):

```
ca   /etc/openvpn/pki/ca.crt        # всё тот же корень — больше ничего не нужно!
cert /etc/openvpn/pki-intermediate/issued/client2.crt
key  /etc/openvpn/pki-intermediate/private/client2.key
```

После перезапуска смотрите в лог клиента — там будет праздник из трёх строк VERIFY:

```
VERIFY OK: depth=2, CN=rasvpn          ← корень (известен заранее)
VERIFY OK: depth=1, CN=rasvpn-inter    ← промежуточный (передан сервером)
VERIFY OK: depth=0, CN=server2         ← концевой серт сервера
```

Сравните с вашим старым логом (depth=1 / depth=0) — глубина цепочки выросла на единицу, и это наглядное доказательство иерархии для отчёта.


##### Бонус-эксперименты: посмотреть разграничение влияния вживую

Эксперимент А — pathlen работает. Попробуйте от промежуточного выпустить его собственного промежуточного:

```
/usr/share/easy-rsa/easyrsa --pki-dir=/etc/openvpn/pki-intermediate2 init-pki
echo 'rasvpn-inter2' | /usr/share/easy-rsa/easyrsa --pki-dir=/etc/openvpn/pki-intermediate2 build-ca subca nopass
/usr/share/easy-rsa/easyrsa --pki-dir=/etc/openvpn/pki-intermediate import-req \
  /etc/openvpn/pki-intermediate2/reqs/ca.req rasvpn-inter2
echo 'yes' | /usr/share/easy-rsa/easyrsa --pki-dir=/etc/openvpn/pki-intermediate sign-req ca rasvpn-inter2
```

Сертификат выпустится (OpenSSL не откажет — ограничение проверяется не при выпуске, а при верификации). Но цепочка сломается: openssl verify с корнем выдаст path length constraint exceeded — два уровня подчинения запрещены pathlen:0 корня. Красивая демонстрация: «подписать-то можно, но доверять не будут».


Эксперимент Б — роль корня исчезает. Закомментируйте extra-certs на сервере и перезапустите — клиент откажет, хотя серт валиден. Восстановите — работает. Наглядно показывает, кто и что должен передавать в рукопожатии.

Эксперимент В — «офлайн» корня. После выпуска промежуточного корневой ключ в реальной жизни уводят в безопасник. В лабе можно хотя бы сменить права: chmod 400 /etc/openvpn/pki/private/ca.key — и с этого момента повседневные операции (отзыв, продление, новые клиенты) физически не трогают корень. Это и есть смысл всей конструкции.

Один нюанс напоследок

После перевода на промежуточный CA старые серты (client, подписанные корнем) продолжат работать — они всё ещё валидны в той же PKI. В отчёте это можно сформулировать так: «корень остаётся точкой доверия для всех выданных ранее сертификатов; новые выпускаются через промежуточный уровень». Сроки у обоих уровней разные — можно показать на openssl x509 -noout -enddate, что корень живёт дольше промежуточного, а тот — дольше концевых: срок наследуется убывающим каскадом.


### Отзыв сертификатов и CRL

Cледующая логичная ступень — это отзыв сертификатов (CRL) и проверка «отзови client2 — туннель должен отвергнуть». 

Отзыв — самое наглядное продолжение: раз база выданных сертификатов у CA уже есть (pki/index.txt), остаётся только добавить в неё пометку «отозван» и научить сервер её читать. Разберём полный цикл.

##### Как устроен механизм

Отзыв делается не «по нажатию кнопки в туннеле», а через список отзыва — CRL (Certificate Revocation List). Схема такая:

```
1. Администратор:    easyrsa revoke client2
                     → CA помечает запись в pki/index.txt как «R» (revoked)

2. Администратор:    easyrsa gen-crl
                     → CA публикует CRL: pki/crl.pem
                       (подписанный CA список серийных номеров отозванных сертов)

3. Администратор:    кладёт crl.pem туда, где его ждёт сервер,
                     и прописывает в server.conf: crl-verify <путь>

4. Сервер при каждом TLS-рукопожатии клиента:
                     смотрит серийный номер его сертификата
                     → есть в CRL?  → отказ: «CRL CHECK FAILED»
```

Важный момент, который часто ставит в тупик: сертификат нельзя «удалить» — он уже выдан и его копии гуляют по миру. Отзыв — это не стирание, а публичное заявление CA: «этот серийный номер больше не доверяю». Клиентский серт у пользователя остаётся на руках и остаётся криптографически валидным — просто сервер его отвергнет.

##### Пошагово в лабе

Допустим, отзываем client2 (вышедшему сотруднику забрали ноутбук):

1. Отзываем в PKI того уровня, где серт выпущен — у нас это промежуточный CA:

```
echo 'yes' | /usr/share/easy-rsa/easyrsa --pki-dir=/etc/openvpn/pki-intermediate revoke client2
```

Легко проверить по базе — строка сменит статус:

```
grep client2 /etc/openvpn/pki-intermediate/index.txt
# было:  V   <срок>        ... /CN=client2     (V = valid)
# станет: R   <срок>  <дата отзыва> ... /CN=client2, serial=XXXX  (R = revoked)
```

2. Генерируем CRL (опять же — на уровне промежуточного, там его база):

```
/usr/share/easy-rsa/easyrsa --pki-dir=/etc/openvpn/pki-intermediate gen-crl
# создан: /etc/openvpn/pki-intermediate/crl.pem
```

CRL подписан тем же CA — сервер проверяет подпись, поэтому подменить список нельзя. Посмотреть его содержимое можно так:

```
openssl crl -in /etc/openvpn/pki-intermediate/crl.pem -noout -text
# ищите Serial Number — серийник отозванного client2
```

3. Подключаем к серверу:

```
crl-verify /etc/openvpn/pki-intermediate/crl.pem
```

и перезапускаем OpenVPN (CRL читается один раз при старте, не на каждый handshake).


4. Проверяем. Раньше подключавшийся client2 теперь получит отказ — в логе сервера:

```
client2/192.168.56.1:xxxxx VERIFY ERROR: CRL: certificate revoked
```

Три нюанса, на которых ловятся

1. Отзыв не рвёт уже установленный сеанс. Проверка CRL выполняется при TLS-рукопожатии. Если client2 уже подключён, его туннель продолжит жить до пересогласования ключа или переподключения. Для мгновенного отключения используют перезапуск сервера или firewall. То есть, отзыв не мгновенный — эффект наступает при следующем рукопожатии.

2. CRL нужно обновлять на сервере после каждого отзыва. Файл crl.pem — снимок на момент генерации. Отозвали нового клиента → перегенерировали → перезакинули на сервер. В проде это автоматизируют, а nextUpdate в CRL подсказывает, когда пора.

3. Срок действия CRL. По умолчанию Easy-RSA ставит валидность списка 180 дней (crl_days), но осторожнее с нулем: если серверу подсунуть просроченный CRL, OpenVPN ругнётся при старте, а некоторые сборки вообще отказываются запускаться — следите за датой Next Update в выводе openssl crl.


##### Как это связано с иерархией

У каждого CA — своя база и свой CRL: корень отзывает то, что выпустил сам, промежуточный — свои концевые. Серверу можно дать несколько списков (в новых версиях — crl-verify с каталогом, либо склейка: CRL подписывается каждым CA цепочки). В реальном мире к этому добавляется OCSP — «спросить CA онлайн про конкретный серт» вместо периодически раскидываемого файла, — но для лабы CRL нагляднее: весь список лежит в файле, который можно открыть и почитать глазами.

Для отчёта сюжет в одну строку: выпуск — CA фиксирует серийник в index.txt; отзыв — тот же файл, но статус R + публикация подписанного CRL; проверка — сервер сверяет серийник входящего серта с CRL при каждом handshake. Все три операции — на стороне CA, сервер лишь читает готовый список. Это и есть распределение ролей в PKI: центр решает, OpenVPN исполняет.

