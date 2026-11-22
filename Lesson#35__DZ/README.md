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

### 2. Организация туннеля openvpn

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

2.1.2 Генерация ключей на сервере

```
root@server:~# 
root@server:~# cd /etc/openvpn
root@server:/etc/openvpn#
root@server:/etc/openvpn# /usr/share/easy-rsa/easyrsa init-pki

init-pki complete; you may now create a CA or requests.
Your newly created PKI dir is: /etc/openvpn/pki

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

root@server:/etc/openvpn# 
root@server:/etc/openvpn# echo 'rasvpn' | /usr/share/easy-rsa/easyrsa gen-req server nopass
Using SSL: openssl OpenSSL 3.0.2 15 Mar 2022 (Library: OpenSSL 3.0.2 15 Mar 2022)
.+....+...+...........+.+......+..............+.+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*.+...+......+.+...........+....+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*.............+...+.........+..............+..........+.........+...+........+....+..+.........+....+...+...+.........+....................+.+..+...+.+.......................+......+.+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
.....+..+...+............+.+.....+.........+.+..+.......+...+......+............+..+.+.....+..........+......+......+...+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*............+..........+..+....+..+...+...................+..+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*....+......+..+.+......+......+..+......+....+.................+......+.........+...+.......+...+...+..+......+..........+.....+......+.+........+....+...+..+..........+...........+.......+.....+.........+...+.+..+....+.......................................+..+.........+.............+...........+...................+..+....+.........+...+..+.+..+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
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

2.2 Конфигурируем openvpn client на хосте

```

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
