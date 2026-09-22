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


На Dockerhub помещён для проверки результирующий кастомный образ Docker на основе alpine с установленным пакетом nginx и кастомной страницей.

1) Ссылка на образ в Dockerhub:

```
   https://hub.docker.com/r/kosogoroff/my-nginx-alpine
```
   
Команды для запуска:
   
   ```bash
   docker pull kosogoroff/my-nginx-alpine:1.0
   docker run -d -p 8081:80 --name test-nginx kosogoroff/my-nginx-alpine:1.0

3) Ссылка на репозиторий в Git с файлами для создания кастомного образа:

```
https://github.com/kosogoroff/nginx-alpine-custom.git
```

Команды для скачивания и сборки образа:

```
git clone https://github.com/kosogoroff/nginx-alpine-custom.git
cd nginx-alpine-custom
docker run -d -p 8081:80 --name test-nginx my-nginx-alpine:1.0
```

Команды для проверки:

```
docker ps
curl http://localhost:8081
```

Ожидается вывод кастомной WEB-страницы.


Ниже приведены более подробно результаты выполнения лабораторной работы:

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


На этом основное задание лабораторной работы выполнено.

# КОНЕЦ

Далее представлена собранная и полученная с помощью ИИ раcширенная информация по работе с Docker и Docker compose.

## **Примечание:**
Можно использовать и переносить локально собранные образы Docker и без Dockerhub, например:

### Использование локальных образов

Например, образ собран локально с помощью команды 'docker build -t my-php:1.0 .' — образ появляется в локальном хранилище (local image store).
Для использования его в docker-compose.yml:

```yaml
php:
  image: my-php:1.0
  # без registry prefix — значит, берётся локально
```

Никакого Docker Hub не нужно. Docker сначала смотрит локальные образы, и только если не находит — пытается тянуть из реестра.

Версионирование. Для Ansible/Vagrant-стендов удобно хранить несколько версий образов локально: my-php:1.0, my-php:1.1. Тогда плейбук или Vagrantfile могут явно указывать, какую версию поднимать.

### Перенос на другую машину. 

Локальный образ не «путешествует» сам по себе. Если нужно перенести его на другой сервер (или на виртуалку в Vagrant), есть два пути:

- Через реестр (Docker Hub или свой). Это самый простой способ.

- Экспорт/импорт. Можно сохранить образ в файл и перетащить его как обычный файл:
```bash
# Экспорт
docker save -o my-php-1.0.tar my-php:1.0

# На другой машине: импорт
docker load -i my-php-1.0.tar

Это как архив Vagrant-бокса: можно положить его в Git LFS, на флешку, в S3 — и развернуть где угодно.
```

**Важно:** Сборка по Dockerfile обеспечивает воспроизводимость имиджей. То же самое и здесь: вместо «сохранить текущий контейнер как образ» (docker commit) лучше всегда собирать образ по Dockerfile. Тогда ты точно знаешь, из чего он состоит, и можешь повторить сборку на любой машине.


# Тренировочная задача с созданием нескольких контейнеров, взаимодействующих через локальную сеть Docker между собой

Хотелось бы потренироваться и создать (с участием ИИ) в docker несколько контейнеров, организовать между ними взаимодействие. Один из контейнеров должег быть nginx на базе alpine, доступ с хоста через проброшенный порт. Второй, например, бд msql, в который через форму на странице nginx вносятся/удаляются записи (запись, например, Фамилия, Имя, возраст, ID).

## Решение

Самый чистый и понятный вариант для тренировки — использовать Docker Compose и такую связку:

- Nginx (на базе Alpine) — как фронтенд/прокси и раздача статики (HTML‑форма).

- PHP‑FPM (можно тоже Alpine) — для обработки формы, работы с MySQL и логики вставки/удаления записей.

- MySQL/MariaDB — база данных.

## Структура проекта

```
docker-alpine-mysql/
├── docker-compose.yml
├── nginx/
│   └── default.conf
├── php/
│   ├── index.php
│   └── db.php
└── data/                  # сюда будут сохраняться данные MySQL (опционально)
```

docker-compose.yml

```
services:
  nginx:
    image: nginx:alpine
    container_name: nginx-alpine
    ports:
      - "8080:80"
    volumes:
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
      - ./php:/var/www/html:ro
    depends_on:
      php:
        condition: service_started
      db:
        condition: service_started
    networks:
      - app-net

  php:
    build:
      context: ./php
      dockerfile: Dockerfile
    container_name: php-alpine
    volumes:
      - ./php:/var/www/html:ro
    environment:
      MYSQL_HOST: db
      MYSQL_USER: appuser
      MYSQL_PASSWORD: secret
      MYSQL_DB: people_db
    depends_on:
      db:
        condition: service_healthy
    networks:
      - app-net

  db:
    image: mariadb:10.6
    container_name: mysql-alpine
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: rootsecret
      MYSQL_DATABASE: people_db
      MYSQL_USER: appuser
      MYSQL_PASSWORD: secret
    volumes:
      - ./data:/var/lib/mysql
    networks:
      - app-net
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "appuser", "-psecret"]
      interval: 5s
      timeout: 5s
      retries: 10
      start_period: 10s

networks:
  app-net:
    driver: bridge
[admin_insta11@mv334 docker-alpine-mysql]$ 
[admin_insta11@mv334 docker-alpine-mysql]$ cat nginx/default.conf
server {
    listen 80;
    server_name localhost;
    root /var/www/html;
    index index.php index.html;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass php:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }
}
[admin_insta11@mv334 docker-alpine-mysql]$ cat php/db.php
<?php
$host = getenv('MYSQL_HOST') ?: 'db';
$user = getenv('MYSQL_USER') ?: 'appuser';
$pass = getenv('MYSQL_PASSWORD') ?: 'secret';
$db   = getenv('MYSQL_DB') ?: 'people_db';

$dsn = "mysql:host=$host;dbname=$db;charset=utf8mb4";
$options = [
    PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
];

try {
    $pdo = new PDO($dsn, $user, $pass, $options);
} catch (PDOException $e) {
    die("Ошибка подключения к БД: " . $e->getMessage());
}

// Создаём таблицу, если её нет
$sql = "CREATE TABLE IF NOT EXISTS people (
    id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name  VARCHAR(50) NOT NULL,
    age        INT NOT NULL
)";
$pdo->exec($sql);
[admin_insta11@mv334 docker-alpine-mysql]$ 
[admin_insta11@mv334 docker-alpine-mysql]$ cat php/index.php
<?php
require_once 'db.php';

// Обработка действий
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (isset($_POST['action']) && $_POST['action'] === 'add') {
        $first = trim($_POST['first_name'] ?? '');
        $last  = trim($_POST['last_name'] ?? '');
        $age   = (int)($_POST['age'] ?? 0);
        if ($first && $last && $age > 0) {
            $stmt = $pdo->prepare("INSERT INTO people (first_name, last_name, age) VALUES (?, ?, ?)");
            $stmt->execute([$first, $last, $age]);
        }
    } elseif (isset($_POST['action']) && $_POST['action'] === 'delete' && isset($_POST['id'])) {
        $id = (int)$_POST['id'];
        if ($id > 0) {
            $stmt = $pdo->prepare("DELETE FROM people WHERE id = ?");
            $stmt->execute([$id]);
        }
    }
    header('Location: /');
    exit;
}

// Получаем список
$people = $pdo->query("SELECT * FROM people ORDER BY id")->fetchAll();
?>
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Люди — MySQL + PHP + Nginx</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 2rem; }
        form { margin-bottom: 2rem; border: 1px solid #ccc; padding: 1rem; }
        label { display: block; margin-top: 0.5rem; }
        input { padding: 0.4rem; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 0.4rem; text-align: left; }
        .delete-btn { color: red; cursor: pointer; }
    </style>
</head>
<body>
    <h1>Список людей</h1>

    <form method="post">
        <input type="hidden" name="action" value="add">
        <label>Фамилия: <input type="text" name="last_name" required></label>
        <label>Имя: <input type="text" name="first_name" required></label>
        <label>Возраст: <input type="number" name="age" required></label>
        <button type="submit">Добавить</button>
    </form>

    <?php if (count($people) > 0): ?>
    <table>
        <thead>
            <tr><th>ID</th><th>Фамилия</th><th>Имя</th><th>Возраст</th><th></th></tr>
        </thead>
        <tbody>
            <?php foreach ($people as $row): ?>
            <tr>
                <td><?= htmlspecialchars($row['id']) ?></td>
                <td><?= htmlspecialchars($row['last_name']) ?></td>
                <td><?= htmlspecialchars($row['first_name']) ?></td>
                <td><?= htmlspecialchars($row['age']) ?></td>
                <td>
                    <form method="post" style="display:inline;">
                        <input type="hidden" name="action" value="delete">
                        <input type="hidden" name="id" value="<?= $row['id'] ?>">
                        <button type="submit" class="delete-btn">Удалить</button>
                    </form>
                </td>
            </tr>
            <?php endforeach; ?>
        </tbody>
    </table>
    <?php else: ?>
    <p>Пока нет записей.</p>
    <?php endif; ?>
</body>
</html>
[admin_insta11@mv334 docker-alpine-mysql]$ 
```

Все сервисы в одной сети app-net — они видят друг друга по именам (db, php, nginx).

Nginx пробрасывает запросы на PHP‑FPM через fastcgi_pass php:9000.

База данных хранит данные на хосте в папке data, чтобы они не пропали при docker compose down.

