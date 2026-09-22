# Занятия 02.09.2026, 07.09.2026 "Docker"

Домашнее задание

### Цель:

освоить базовые принципы работы с Docker, научиться создавать, настраивать и управлять контейнерами;

Описание/Пошаговая инструкция выполнения домашнего задания:


### 🎯 Задание

- Установите Docker на хост машину https://docs.docker.com/engine/install/ubuntu/

- Установите Docker Compose - как плагин, или как отдельное приложение

- Создайте свой кастомный образ nginx на базе alpine. После запуска nginx должен отдавать кастомную страницу (достаточно изменить дефолтную страницу nginx)

- Определите разницу между контейнером и образом

- Вывод опишите в домашнем задании.

- Ответьте на вопрос: Можно ли в контейнере собрать ядро?


### 🗂Формат сдачи

Собранный образ необходимо запушить в docker hub и дать ссылку на ваш репозиторий.

В чат ДЗ отправьте ссылку на ваш git-репозиторий. Обычно мы проверяем ДЗ в течение 48 часов.

# Решение

0. Пакеты установлены:

```
[admin_insta11@mv334 ~]$ docker --version
Docker version 29.5.1, build 2518b52
[admin_insta11@mv334 ~]$ docker compose version
Docker Compose version 5.0.2
[admin_insta11@mv334 ~]$
```

Ниже приведены результаты выполнения лабораторной работы:

1. Создаём рабочую директорию проекта, создаём в ней три файла :

```
[admin_insta11@mv334 ~]$ mkdir nginx-alpine-custom
[admin_insta11@mv334 ~]$ cd nginx-alpine-custom
[admin_insta11@mv334 nginx-alpine-custom]$
```

1.1 Сам Dockerfile собираемого кастомного образа Docker :

```
[admin_insta11@mv334 nginx-alpine-custom]$ cat > Dockerfile
FROM alpine:latest

# Ставим nginx через apk (пакетный менеджер Alpine)
RUN apk add --no-cache nginx

# Создаём папку для сайта, если её нет
RUN mkdir -p /usr/share/nginx/html

# Копируем нашу кастомную страницу в корень сайта
COPY index.html /usr/share/nginx/html/index.html

# Удаляем дефолтный конфиг, который отдаёт 404
RUN rm -f /etc/nginx/http.d/default.conf

# Кладём наш конфиг. 
# Кладём в http.d/, потому что в nginx.conf есть include /etc/nginx/http.d/*.conf
COPY default.conf /etc/nginx/http.d/default.conf

# Открываем порт 80
EXPOSE 80

# Запускаем nginx на переднем плане (без демона, так нужно для Docker - иначе при запуске сервиса
# с 'deamon on' в качестве демона контейнер может сразу же завершиться)
CMD ["nginx", "-g", "daemon off;"]
```

1.2 Файл index.html начальной страницы nginx:

```
[admin_insta11@mv334 nginx-alpine-custom]$ cat > index.html
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <title>Мой кастомный Nginx</title>
  </head>
  <body>
    <h1>Привет! Это Nginx из моего собственного образа.</h1>
    <p>Образ собран на Alpine, страница изменена вручную.</p>
  </body>
</html>
[admin_insta11@mv334 nginx-alpine-custom]$
```

1.3 Файл конфигурации default.conf для замещения дефолтного файла, содержащегося в пакете nginx.

Дефолтный файл /etc/nginx/http.d/default.conf конфигурации nginx в alpine имеет следующее содержание (извлечён из работающего контейнера alpine с установленным пакетом nginx):

```
[admin_insta11@mv334 nginx-alpine-custom]$ docker exec -it test-nginx sh
/ # cat /etc/nginx/http.d/default.conf 
# This is a default site configuration which will simply return 404, preventing
# chance access to any other virtualhost.

server {
	listen 80 default_server;
	listen [::]:80 default_server;

	# Everything is a 404
	location / {
		return 404;
	}

	# You may need this to prevent return 404 recursion.
	location = /404.html {
		internal;
	}
}
```

Заменяем его на файл default.conf следующего содержания:

```
[admin_insta11@mv334 nginx-alpine-custom]$ cat > default.conf
server {
    listen 80;
    server_name localhost;

    location / {
        root /usr/share/nginx/html;
        index index.html;
    }
}
```

2. Собираем образ:

```
[admin_insta11@mv334 nginx-alpine-custom]$ docker build -t my-nginx-alpine:1.0 .
[+] Building 2.4s (11/11) FINISHED                                                                                                                                docker:default
 => [internal] load build definition from Dockerfile                                                                                                                        0.0s
 => => transferring dockerfile: 956B                                                                                                                                        0.0s
 => [internal] load metadata for docker.io/library/alpine:latest                                                                                                            1.9s
 => [internal] load .dockerignore                                                                                                                                           0.0s
 => => transferring context: 2B                                                                                                                                             0.0s
 => [1/6] FROM docker.io/library/alpine:latest@sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6                                                      0.0s
 => [internal] load build context                                                                                                                                           0.0s
 => => transferring context: 210B                                                                                                                                           0.0s
 => CACHED [2/6] RUN apk add --no-cache nginx                                                                                                                               0.0s
 => CACHED [3/6] RUN mkdir -p /usr/share/nginx/html                                                                                                                         0.0s
 => CACHED [4/6] COPY index.html /usr/share/nginx/html/index.html                                                                                                           0.0s
 => [5/6] RUN rm -f /etc/nginx/http.d/default.conf                                                                                                                          0.2s
 => [6/6] COPY default.conf /etc/nginx/http.d/default.conf                                                                                                                  0.1s
 => exporting to image                                                                                                                                                      0.1s
 => => exporting layers                                                                                                                                                     0.0s
 => => writing image sha256:cf61db952b67dbf522d616768a6736cc0774c9e54ee1cc224dd413f6c75346c8                                                                                0.0s
 => => naming to docker.io/library/my-nginx-alpine:1.0                                                                                                                      0.0s
[admin_insta11@mv334 nginx-alpine-custom]$
[admin_insta11@mv334 nginx-alpine-custom]$ docker images
                                                                                                i Info →   U  In Use
IMAGE                            ID             DISK USAGE   CONTENT SIZE   EXTRA
docker-alpine-mysql-php:latest   7d9665027b20       81.6MB             0B    U   
local:latest                     8fbc9e255078       8.42MB             0B        
mariadb:10.6                     663725b505fb        316MB             0B    U   
my-nginx-alpine:1.0              cf61db952b67       10.5MB             0B    U   
nginx:alpine                     55fcc661c2cd       62.9MB             0B    U   
php:8.2-fpm-alpine               5e2898ac99a1       81.3MB             0B        
[admin_insta11@mv334 nginx-alpine-custom]$
```

3.  запускаем контейнер из собранного образа. Контейнер - это запущенный экземпляр образа. Из одного образа можно создать несколько контейнеров.
После запуска контейнера проверяем, что выводится кастомная страница:

```
[admin_insta11@mv334 nginx-alpine-custom]$ docker run -d -p 8081:80 --name test-nginx my-nginx-alpine:1.0
f8929b8a6ab158aba9eee7f494cc7d9452c4037d6640a88ae5d2e719a6e6528b
[admin_insta11@mv334 nginx-alpine-custom]$
[admin_insta11@mv334 nginx-alpine-custom]$ docker ps
CONTAINER ID   IMAGE                 COMMAND                  CREATED        STATUS          PORTS                                     NAMES
f8929b8a6ab1   my-nginx-alpine:1.0   "nginx -g 'daemon of…"   23 hours ago   Up 13 seconds   0.0.0.0:8081->80/tcp, [::]:8081->80/tcp   test-nginx
[admin_insta11@mv334 nginx-alpine-custom]$ 
[admin_insta11@mv334 nginx-alpine-custom]$ curl http://localhost:8081
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <title>Мой кастомный Nginx</title>
  </head>
  <body>
    <h1>Привет! Это Nginx из моего собственного образа.</h1>
    <p>Образ собран на Alpine, страница изменена вручную.</p>
  </body>
</html>
[admin_insta11@mv334 nginx-alpine-custom]$
```

В WEB-броузере на хосте открывается страница:

<img width="949" height="485" alt="изображение" src="https://github.com/user-attachments/assets/c150f13a-7410-479a-81f2-a4c55edee5bf" />


В данном случае файл кастомной страницы index.html помещён прямо в собранный образ Docker.


### 4. Результирующий кастомный образ помещённый на Dockerhub:

1. Ссылка на образ:

```
   https://hub.docker.com/r/kosogoroff/my-nginx-alpine
```
   
2. Команды для запуска:
   
   ```bash
   docker pull kosogoroff/my-nginx-alpine:1.0
   docker run -d -p 8081:80 --name test-nginx kosogoroff/my-nginx-alpine:1.0
