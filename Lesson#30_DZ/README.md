# Занятие 19.10.2026 "30. Фильтрация трафика - iptables"

Сценарии iptables

## Цель:

Написать сценарии iptables.

## Описание/Пошаговая инструкция выполнения домашнего задания:

Что нужно сделать?

1. Реализовать knocking port. centralRouter может попасть на ssh inetrRouter через knock скрипт. Пример в материалах.

2. Добавить inetRouter2, который виден(маршрутизируется (host-only тип сети для виртуалки)) с хоста или форвардится порт через локалхост.
    
3. запустить nginx на centralServer. Пробросить 80й порт на inetRouter2 8080. Дефолт в инет оставить через inetRouter.



Формат сдачи ДЗ - vagrant + ansible


Задача со звёздочкой. Реализовать проход на 80й порт без маскарадинга*

# Решение

## 1. Создание сети ВМ

За основу лабораторной сети взята лабораторная сеть из занятия "28. Архитектура сетей", из которой для облегчения удалены ненужные хосты office1Router, office1Server, office2Router и office2Server. А также добавлени дополнительный маршрутизатор inetRouter2:

<img width="382" height="373" alt="изображение" src="https://github.com/user-attachments/assets/074258fc-3b49-445c-8a07-3a048d228a6c" />

Таблица IP-адресации интерфейсов хостов:





Схема создаваемой лабораторной сети из методички:


## 2. запустить nginx на centralServer. Пробросить 80й порт на inetRouter2 8080. Дефолт в инет оставить через inetRouter.

#### 2.1 Запуск и проверка nginx на centralServer

Устанавливаем, запускаем и проверяем сервер nginx на centralServer:

```
[admin_insta11@mv334 iptables_lab]$ vagrant ssh centralServer
vagrant@centralServer:~$
vagrant@centralServer:~$ sudo apt-get update
Hit:1 http://us.archive.ubuntu.com/ubuntu jammy InRelease
Get:2 http://security.ubuntu.com/ubuntu jammy-security InRelease [129 kB]
Get:3 http://us.archive.ubuntu.com/ubuntu jammy-updates InRelease [128 kB]
<...>
Fetched 28.3 MB in 13s (2,188 kB/s)                                                                                         
Reading package lists... Done
vagrant@centralServer:~$ 
vagrant@centralServer:~$ sudo apt install nginx
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
The following additional packages will be installed:
  fontconfig-config fonts-dejavu-core libdeflate0 libfontconfig1 libgd3 libjbig0 libjpeg-turbo8 libjpeg8
  libnginx-mod-http-geoip2 libnginx-mod-http-image-filter libnginx-mod-http-xslt-filter libnginx-mod-mail
  libnginx-mod-stream libnginx-mod-stream-geoip2 libtiff5 libwebp7 libx11-6 libx11-data libxau6 libxcb1 libxdmcp6 libxpm4
  nginx-common nginx-core
Suggested packages:
  libgd-tools fcgiwrap nginx-doc ssl-cert
The following NEW packages will be installed:
  fontconfig-config fonts-dejavu-core libdeflate0 libfontconfig1 libgd3 libjbig0 libjpeg-turbo8 libjpeg8
  libnginx-mod-http-geoip2 libnginx-mod-http-image-filter libnginx-mod-http-xslt-filter libnginx-mod-mail
  libnginx-mod-stream libnginx-mod-stream-geoip2 libtiff5 libwebp7 libx11-6 libx11-data libxau6 libxcb1 libxdmcp6 libxpm4
  nginx nginx-common nginx-core
0 upgraded, 25 newly installed, 0 to remove and 199 not upgraded.
Need to get 1,710 kB/3,552 kB of archives.
After this operation, 11.5 MB of additional disk space will be used.
Do you want to continue? [Y/n] y
Get:1 http://us.archive.ubuntu.com/ubuntu jammy-updates/main amd64 libx11-data all 2:1.7.5-1ubuntu0.4 [120 kB]
Get:2 http://us.archive.ubuntu.com/ubuntu jammy-updates/main amd64 libx11-6 amd64 2:1.7.5-1ubuntu0.4 [668 kB]
<...>
vagrant@centralServer:~$ 
vagrant@centralServer:~$ sudo systemctl status nginx
● nginx.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/lib/systemd/system/nginx.service; enabled; vendor preset: enabled)
     Active: active (running) since Sat 2026-11-07 13:18:27 UTC; 33s ago
       Docs: man:nginx(8)
    Process: 2157 ExecStartPre=/usr/sbin/nginx -t -q -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
    Process: 2158 ExecStart=/usr/sbin/nginx -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
   Main PID: 2258 (nginx)
      Tasks: 2 (limit: 709)
     Memory: 4.0M
        CPU: 45ms
     CGroup: /system.slice/nginx.service
             ├─2258 "nginx: master process /usr/sbin/nginx -g daemon on; master_process on;"
             └─2262 "nginx: worker process" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" ""

Nov 07 13:18:27 centralServer systemd[1]: Starting A high performance web server and a reverse proxy server...
Nov 07 13:18:27 centralServer systemd[1]: Started A high performance web server and a reverse proxy server.
vagrant@centralServer:~$ 
vagrant@centralServer:~$ sudo vi /var/www/html/index.nginx-debian.html 
vagrant@centralServer:~$ 
vagrant@centralServer:~$ curl http://localhost/
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
<h1>Welcome to nginx - it's running on centralServer !</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
vagrant@centralServer:~$ 
```

Также проверяем доступ к странице nginx на centralServer с хоста через адрес 192.168.50.12 прямого доступа к centralServer:

<img width="787" height="587" alt="изображение" src="https://github.com/user-attachments/assets/eef00db8-5f95-4831-a3f4-5c5782fd2e85" />


#### 2.1 Проброс порта сервера nginx на порт 8080 на inetRouter2

Сервер nginx на centralServer работает на стандартном порту 80. Задача состоит в том, чтобы пробросить 80й порт centralServer на порт 8080 на inetRouter2.

Для этого на inetRouter2 делаем следующую конфигурацию iptables:

```
vagrant@inetRouter2:~$ sudo iptables -L -n -v
Chain INPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain FORWARD (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain OUTPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         
vagrant@inetRouter2:~$ 
vagrant@inetRouter2:~$ sudo iptables -t nat -A PREROUTING -p tcp --dport 8080 -j DNAT --to-destination 192.168.0.2:80
vagrant@inetRouter2:~$
vagrant@inetRouter2:~$ sudo iptables -t nat -A POSTROUTING -o eth1 -p tcp -d 192.168.0.2 --dport 80 -j MASQUERADE
vagrant@inetRouter2:~$ 
vagrant@inetRouter2:~$ 
vagrant@inetRouter2:~$ sudo iptables -t nat -L -n -v
Chain PREROUTING (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         
    7   308 DNAT       tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            tcp dpt:8080 to:192.168.0.2:80

Chain INPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain OUTPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain POSTROUTING (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         
    1    44 MASQUERADE  tcp  --  *      eth1    0.0.0.0/0            192.168.0.2          tcp dpt:80
vagrant@inetRouter2:~$
```

Доступ к серверу nginx на centralServer проверяем с хоста. Для этой цели:

1. В Vagrantfile при создании ВМ сконфигурирован проброс порта localhost 8082 на порт inetRouter2 8080 :

```

```


# КОНЕЦ


# Примечания и дополнительная информация

## Q1: 

Почему у inetRouter и inetRouter2 на внешних интерфейсах выдаются одинаковые адреса 10.0.2.15 ? Как это изменить, чтобы virtualbox dhcp выдавал разные адреса ?

## A1:

Короткий ответ: это не баг и не «один общий DHCP». У каждой ВМ в VirtualBox свой изолированный NAT-движок, и у него дефолтная подсеть — всегда 10.0.2.0/24 с шлюзом 10.0.2.2 и DHCP, раздающим первый адрес 10.0.2.15. Эти два роутера физически не видят друг друга через eth0 — у них просто совпадают адреса в двух разных частных NAT-сетках. Поэтому и в SSH вы заходите не через них, а через вашу отдельную management-сеть 192.168.50.0/24.

### Менять ли что-то вообще

Для лабы по iptables менять ничего не нужно: eth0 — это «выход в интернет» через хост, а вся топология у вас на внутренних сетях. Но если хочется, чтобы внешние интерфейсы имели разные подсети (например, для отработки dual-uplink и выбора маршрута), вот варианты.

### Вариант 1: своя NAT-подсеть на каждую ВМ

VirtualBox позволяет менять подсеть дефолтного NAT через modifyvm --natnet1. В Vagrantfile это делается так:

```
box.vm.provider "virtualbox" do |v|
  v.memory = 768
  v.cpus = 1
  if boxconfig[:nat_net]
    v.customize ["modifyvm", :id, "--natnet1", boxconfig[:nat_net]]
  end
end
```

и в описании машин:

```
:inetRouter => {
  ...
  :nat_net => "10.11.0.0/24",
},
:inetRouter2 => {
  ...
  :nat_net => "10.12.0.0/24",
},
```

После vagrant reload у inetRouter eth0 получит адрес из 10.11.0.0/24, у inetRouter2 — из 10.12.0.0/24 (встроенный DHCP подстроится под новую сетку автоматически). Доступ по vagrant ssh не сломается: Vagrant пробрасывает SSH-порты через тот же NAT-адаптер.


### Вариант 2: общая NAT Network на обе ВМ

Если нужно, чтобы роутеры жили в одной внешней сетке и получали от DHCP разные адреса — это «NAT Network» VirtualBox, а не дефолтный NAT. Создаётся на хосте:

```
VBoxManage natnetwork add --netname labnat --network "10.9.9.0/24" --dhcp on --enable
```

и подключается к ВМ дополнительным адаптером:

```
v.customize ["modifyvm", :id, "--nic3", "natnetwork"]
v.customize ["modifyvm", :id, "--nat-network3", "labnat"]
```

**Важно:** adapter 1 оставьте обычным NAT — именно через него Vagrant делает проброс SSH-портов, и переключение его на natnetwork ломает vagrant ssh.


### Вариант 3: bridged (real LAN)

Раскомментировать :public => ... — тогда адреса придут от DHCP вашего реального роутера и будут заведомо разными. Но тут вас подстерегает настоящая проблема: у обеих машин eth0 имеет один и тот же MAC — 08:00:27:16:dd:ef (видно и в IPv6 link-local, который из MAC и собирается). В NAT-режиме это безразлично, а вот в bridged две ВМ с одним MAC на одном свитче будут грызться за аренду. Лечится заданием уникального MAC:

```
v.customize ["modifyvm", :id, "--macaddress1", "0800270000XY"]
```

## Q2: 

А почему одинаковые MAC-адреса у двух разных ВМ? Это как исправить ?

## A2:

Причина простая: MAC 08:00:27:16:dd:ef «приехал» из самого бокса. Когда bento собирает образ bento/ubuntu-22.04, первая сетевая карта в экспортированной виртуалке получает какой-то конкретный MAC, и он сохраняется в метаданных бокса. При vagrant up Vagrant не генерирует новый MAC для адаптера 1, а берёт настройки ВМ из бокса как есть — поэтому у всех машин, поднятых из одного бокса, eth0 выходит с одним и тем же адресом. А вот eth1 и eth2 Vagrant добавляет сам, и для них MAC-и генерируются случайно — потому они у вас разные. То же самое с IPv6 link-local: fe80::a00:27ff:fe16:ddef построен из этого самого MAC.

Пока все сетевушки в режиме дефолтного NAT, это безвредно — ВМ не встречаются в одном L2-сегменте. Но как только появится bridged или общая NAT Network, начнутся конфликты.

### Как исправить

**Способ 1:** Самый надёжный способ — задать уникальные MAC прямо в Vagrantfile. Удобно завести их в конфиг машины:

```
MACHINES = {
  :inetRouter => {
    ...
    :mac1 => "0800270000A1",   # адаптер 1 (NAT)
  },
  :inetRouter2 => {
    ...
    :mac1 => "0800270000A2",
  },
}
```

и в блоке провайдера:

```
box.vm.provider "virtualbox" do |v|
  v.memory = 768
  v.cpus = 1
  v.customize ["modifyvm", :id, "--macaddress1", boxconfig[:mac1]] if boxconfig[:mac1]
end
```

Формат MAC: 12 hex-символов без разделителей, первая шестнадцатеричная цифра должна быть чётной (unicast), а 08:00:27 — префикс VirtualBox, его лучше сохранить.


**Способ 2:** Вариант попроще, без ручных адресов — попросить VirtualBox сгенерировать MAC автоматически:

```
v.customize ["modifyvm", :id, "--macaddress1", "auto"]
```

Тогда при каждом пересоздании ВМ получит случайный MAC. Для лабы оба варианта равнозначны; статические удобнее, если захотите позже привязать правила iptables к MAC-адресам (-m mac --mac-source).
Как применить

vagrant reload недостаточно, если MAC «запечён» в существующую ВМ — надёжнее пересоздать машины:

```
vagrant destroy -f
vagrant up
```

После этого ip a на каждой машине покажет разные MAC на eth0.

Нюанс: в Ubuntu 22.04 имена интерфейсов (enp0s3 и т.п.) строятся по слотам PCI, а не по MAC, так что переименования интерфейсов после смены адреса не будет — eth0 останется eth0. А вот если у вас где-то в netplan прописана привязка к MAC — там её придётся обновить, но у дефолтного бокса такого нет.


## Q3: 

Нужно сделать, чтобы inetRouter2 был доступен через форвард порта через локалхост. Так что надо разные IP выданные по DHCP

## A3:

Тут важный момент: форвард портов в Vagrant/VirtualBox не зависит от IP гостя вообще. Механика такая: VirtualBox слушает порт на хосте (например, 127.0.0.1:2222) и заворачивает соединение в NAT-движок конкретной ВМ — а у каждой машины он свой, со своей внутренней сеткой. Поэтому одинаковые 10.0.2.15 у двух ВМ форварду не мешают: каждый форвард «прибит» к конкретной ВМ, а не к адресу.

Так что для доступа к inetRouter2 через localhost достаточно просто добавить форварды с разными хостовыми портами:

```
:inetRouter => {
  ...
  :fwd => [
    [22, 2201],   # guest, host
    [8080, 8081],
  ],
},
:inetRouter2 => {
  ...
  :fwd => [
    [22, 2202],
    [8080, 8082],
  ],
},
```

и в конфигурации:

```
if boxconfig[:fwd]
  boxconfig[:fwd].each do |guest_port, host_port|
    box.vm.network "forwarded_port", guest: guest_port, host: host_port,
      host_ip: "127.0.0.1", auto_correct: true
  end
end
```

После vagrant reload:

```
ssh -p 2202 vagrant@127.0.0.1   # это inetRouter2
curl http://127.0.0.1:8082      # сервис на inetRouter2
```

Пара нюансов:

- auto_correct: true спасёт, если порт на хосте занят — Vagrant подберёт свободный и напишет какой. Для дефолтного SSH-форварда (2222) Vagrant сам разруливает коллизии между машинами.
  
- SSH-форвард для inetRouter2 лучше объявить с другим host: — иначе id: "ssh" совпадёт и порт 2222 достанется первой машине, а вторая уйдёт на 2223. С явными портами (2201/2202) вы контролируете всё сами.

### Если всё-таки нужны разные DHCP-адреса

Форварду они не нужны, но если хочется, чтобы eth0 у машин отличался — снова вариант с --natnet1:

```
:inetRouter  => { ..., :nat_net => "10.11.0.0/24" },
:inetRouter2 => { ..., :nat_net => "10.12.0.0/24" },
```

Встроенный DHCP каждой NAT-сетки выдаст адрес из своей подсети: 10.11.0.15 и 10.12.0.15. Форварды продолжат работать как раньше — они к адаптеру 1 и так привязаны, а не к адресу.

И маленькое наблюдение: у вас обе машины уже имеют разные адреса в management-сети 192.168.50.0/24 (.10 и .20) — вы ведь по ним и подключаетесь по SSH. Так что «доступ через localhost по форварду» и «доступ по 192.168.50.x» — это два независимых пути, можно пользоваться обоими. Что именно планируется пускать через форварды — SSH или какой-то сервис на роутере?

 
### Если с хоста нужно иметь доступ к внутренним сетям virtualbox за маршрутизатором inetRouter2

Если хост должен дотягиваться до внутренних сетей за inetRouter2 (например, до 192.168.255.20/30), нужно два шага:

1. Роутер должен пересылать пакеты. На inetRouter2 нужно включить форвардинг пакетов:

```
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward = 1" | sudo tee /etc/sysctl.d/99-forward.conf
sudo sysctl -p /etc/sysctl.d/99-forward.conf
```

2. На хосте добавить маршрут в внутренние сети через inetRouter2:

```
sudo ip route add 192.168.255.20/30 via 192.168.50.20
sudo ip route add 192.168.255.16/30 via 192.168.50.20   # линк inetRouter2—centralRouter
```

(обратный путь из внутренних сетей в хост-сеть 192.168.50.0/24 уже есть через центральные роутеры, если у них прописаны маршруты — проверьте).

Проверка с хоста:

bash

ping -c 2 192.168.255.21        # свой линк inetRouter2
ping -c 2 192.168.255.22        # линк к centralRouter (если тот отвечает и путь настроен)

Если ping до 192.168.255.22 не проходит, вернитесь с трассировкой — почти всегда это missing route в одну из сторон.

Вариант Б: форвард портов через localhost

Добавьте в описание машин:

```
:inetRouter => {
  ...
  :fwd => [ [22, 2201] ],
},
:inetRouter2 => {
  ...
  :fwd => [ [22, 2202] ],
},
```

и в общий блок:

```
if boxconfig[:fwd]
  boxconfig[:fwd].each do |guest, host|
    box.vm.network "forwarded_port",
      guest: guest, host: host, host_ip: "127.0.0.1", auto_correct: true
  end
end
```

После vagrant reload доступ с хоста:

```
ssh -p 2202 vagrant@127.0.0.1     # попадёте на inetRouter2
```

Два замечания:

- Vagrant по умолчанию и так пробрасывает SSH (порт 2222 и далее по номерам), но делает это «вслепую» — при большом числе машин легко запутаться, какой порт к какой ВМ. Явные порты дают предсказуемость.

- auto_correct: true подстрахует, если 2201/2202 на хосте кем-то заняты — Vagrant возьмёт следующий свободный и напишет об этом.
