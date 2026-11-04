# Занятие 14.08.2026 "Механизмы изоляции и аккаунтинга Linux (namespaces и cgroups)"

Компетенции

    Администрирование, установка, настройка, отладка серверов Linux
        - понимать работу с механизмов namespaces и cgroups


В приложенном архиве пример создания виртуальной сети из трёх хостов на одной ВМ на основе использования namespaces

```
# СТЕНД (повторяет домашку HW21, но в ОДНОЙ VM — через network namespaces):
#
#   ┌─────────────┐  veth   ┌────────────────────────┐  veth   ┌──────────────┐
#   │ ns client   │─────────│ ns router (inetRouter2)│─────────│ ns server    │
#   │ eth0        │         │ eth-c          eth-s   │         │ eth0         │
#   │ 10.0.1.2/24 │         │ 10.0.1.1   10.0.2.1    │         │ 10.0.2.2/24  │
#   └─────────────┘         └────────────────────────┘         │ http.server  │
#                                                              │ :80 (≈nginx) │
#                                                              └──────────────┘
#
# У каждого namespace СВОЙ стек: свои интерфейсы, маршруты, свой iptables,
# свой conntrack, свои ipset'ы. iptables хоста на стенд не влияет и наоборот.
```

В числе прочего там есть скрипты для создания виртуальной и удаления сети:

1. Общие переменные и процедуры
```
#!/usr/bin/env bash
#
# lab-env.sh
# ==========
# Общие переменные и хелперы для всех демо урока. Подключается так:
#
#     source "$(dirname "$0")/lab-env.sh"
#
# Сам по себе ничего не создаёт и не ломает.
#
# СТЕНД (повторяет домашку HW21, но в ОДНОЙ VM — через network namespaces):
#
#   ┌─────────────┐  veth   ┌────────────────────────┐  veth   ┌──────────────┐
#   │ ns client   │─────────│ ns router (inetRouter2)│─────────│ ns server    │
#   │ eth0        │         │ eth-c          eth-s   │         │ eth0         │
#   │ 10.0.1.2/24 │         │ 10.0.1.1   10.0.2.1    │         │ 10.0.2.2/24  │
#   └─────────────┘         └────────────────────────┘         │ http.server  │
#                                                              │ :80 (≈nginx) │
#                                                              └──────────────┘
#
# У каждого namespace СВОЙ стек: свои интерфейсы, маршруты, свой iptables,
# свой conntrack, свои ipset'ы. iptables хоста на стенд не влияет и наоборот.

NS_C=client
NS_R=router
NS_S=server

C_IP=10.0.1.2        # клиент
R_IP_C=10.0.1.1      # роутер, нога в сторону клиента («внешняя»)
R_IP_S=10.0.2.1      # роутер, нога в сторону сервера («внутренняя»)
S_IP=10.0.2.2        # сервер (nginx в ДЗ)
FAKE_GW=10.0.2.254   # «другой роутер» (centralRouter в ДЗ) — в 02 сюда уводим default сервера

LAB_DIR=/tmp/iptables-lab           # логи и pid-ы стенда
HTTP_LOG=$LAB_DIR/http-server.log   # здесь http.server пишет, КТО к нему пришёл

# Короткие обёртки: «выполнить команду внутри namespace».
# Под капотом это просто `sudo ip netns exec <ns> <команда>`.
inc() { sudo ip netns exec "$NS_C" "$@"; }
inr() { sudo ip netns exec "$NS_R" "$@"; }
ins() { sudo ip netns exec "$NS_S" "$@"; }

# Пауза между шагами. AUTO=1 bash 0X-....sh — прогон без остановок.
pause() {
    echo
    if [[ -n "${AUTO:-}" ]]; then echo ">>> $*"; return 0; fi
    read -r -p ">>> $* [Enter] " _ || true
}

# Заголовок шага — чтобы на проекторе было видно, где мы.
step() { echo; echo "=== $* ==="; }

# Заголовок команды: печатаем её перед выполнением — зал видит, ЧТО мы набрали.
run() { echo "\$ $*"; "$@"; }

# Проверка «стенд поднят».
require_lab() {
    if [[ ! -e /run/netns/$NS_R ]]; then
        echo "✗ Стенд не поднят. Сначала: bash 00-lab-up.sh"
        exit 1
    fi
}

# Привести роутер в «чистое» состояние: пустые таблицы, policy ACCEPT,
# нулевые счётчики, ни одного ipset, пустой conntrack.
# Каждое демо начинает с этого — порядок запуска 01..04 не важен.
reset_router() {
    local t
    for t in filter nat mangle raw; do
        inr iptables -t "$t" -F
        inr iptables -t "$t" -X
        inr iptables -t "$t" -Z
    done
    for c in INPUT FORWARD OUTPUT; do inr iptables -P "$c" ACCEPT; done
    if inr sh -c 'command -v ipset' >/dev/null 2>&1; then
        inr ipset destroy 2>/dev/null || true
    fi
    if inr sh -c 'command -v conntrack' >/dev/null 2>&1; then
        inr conntrack -F >/dev/null 2>&1 || true
    fi
    # Сервер по умолчанию знает дорогу домой через роутер (02 это ломает и чинит).
    ins ip route replace default via "$R_IP_S"
}

# HTTP-запрос с клиента: печатает код ответа или «тишина (таймаут)».
# -m 3 : ждать не больше 3 секунд — не висим на проекторе.
http_from_client() {
    local url=$1
    local code
    if code=$(inc curl -s -o /dev/null -w '%{http_code}' -m 3 "$url"); then
        echo "✓ $url → HTTP $code"
    else
        echo "✗ $url → тишина (таймаут 3с)"
    fi
}
```


2. Скрипт для создания виртуальной сети:

```
#!/usr/bin/env bash
#
# 00-lab-up.sh
# ============
# Что делаем: поднимаем стенд «client — router — server» из трёх network
# namespaces внутри ОДНОЙ VM. Это та же топология, что в ДЗ (HW21):
# клиент снаружи, inetRouter2 посередине, nginx за ним.
#
# Целевой ага-эффект: «три машины» за 2 секунды без Vagrant. Namespace —
# это отдельный сетевой стек: свои интерфейсы, маршруты И СВОЙ iptables.
# Всё, что мы дальше делаем с iptables роутера, делается ВНУТРИ ns router
# и не трогает iptables самой VM (ssh до VM не отвалится).
#
# Идемпотентен: если стенд уже есть — сносит и строит заново.
# Время: ~2 минуты с объяснением.

set -euo pipefail
source "$(dirname "$0")/lab-env.sh"

# Зависимости: iproute2, iptables, python3, curl — есть в Ubuntu из коробки.
# ipset и conntrack — нет. Ставим заранее (нужны в 02 и 04):
#     sudo apt install -y ipset conntrack
for b in ip iptables python3 curl nc; do
    command -v "$b" >/dev/null || { echo "✗ нет $b"; exit 1; }
done
for b in ipset conntrack; do
    command -v "$b" >/dev/null || echo "⚠ нет $b — sudo apt install -y ipset conntrack"
done

# Снести старый стенд, если был (молча).
bash "$(dirname "$0")/99-lab-down.sh" >/dev/null 2>&1 || true
mkdir -p "$LAB_DIR"

step "1. Три namespace"
# ip netns add <имя> — создаёт файл /run/netns/<имя>, за ним живёт сетевой стек.
for ns in "$NS_C" "$NS_R" "$NS_S"; do
    run sudo ip netns add "$ns"
    sudo ip netns exec "$ns" ip link set lo up
done
run sudo ip netns list

step "2. Два «провода» (veth-пары) и раскладка концов по namespace"
# veth — виртуальный кабель с двумя концами. Что вошло в один — вышло из другого.
run sudo ip link add c-eth0 type veth peer name r-eth-c
run sudo ip link add s-eth0 type veth peer name r-eth-s
# Переносим концы в нужные ns и сразу даём им «человеческие» имена.
sudo ip link set c-eth0  netns "$NS_C" name eth0
sudo ip link set r-eth-c netns "$NS_R" name eth-c
sudo ip link set r-eth-s netns "$NS_R" name eth-s
sudo ip link set s-eth0  netns "$NS_S" name eth0

step "3. Адреса и маршруты"
inc ip addr add "$C_IP/24"   dev eth0
inr ip addr add "$R_IP_C/24" dev eth-c
inr ip addr add "$R_IP_S/24" dev eth-s
ins ip addr add "$S_IP/24"   dev eth0
inc ip link set eth0 up
inr ip link set eth-c up
inr ip link set eth-s up
ins ip link set eth0 up
# Клиент и сервер ходят «в мир» через роутер.
inc ip route add default via "$R_IP_C"
ins ip route add default via "$R_IP_S"

step "4. Роутер становится роутером"
# Без ip_forward=1 ядро НЕ пересылает пакеты между интерфейсами —
# транзит просто дропается, ещё до iptables FORWARD.
# Это ключ ДЗ: на inetRouter2 тоже нужен net.ipv4.ip_forward=1.
run inr sysctl -w net.ipv4.ip_forward=1

step "5. «nginx» на сервере"
# python3 -m http.server — пишет в лог IP каждого клиента. Это нам и нужно:
# в 02 будем смотреть, КТО пришёл к серверу — клиент или роутер.
# -u — без буферизации, чтобы строки лога появлялись сразу.
mkdir -p "$LAB_DIR/www"
echo "hello from server ($S_IP)" > "$LAB_DIR/www/index.html"
: > "$HTTP_LOG"
ins sh -c "nohup python3 -u -m http.server 80 --bind $S_IP --directory $LAB_DIR/www \
    >>$HTTP_LOG 2>&1 </dev/null &"
sleep 1

step "Проверка"
inc ip -br addr show eth0
inr ip -br addr
ins ip -br addr show eth0
echo
inc ping -c 1 -W 1 "$S_IP" | grep -E 'bytes from|loss'
http_from_client "http://$S_IP/"
echo
echo "✓ Стенд поднят. Лог сервера: tail -f $HTTP_LOG"
```

3. Скрипт для удаления виртуальной сети
```
#!/usr/bin/env bash
#
# 99-lab-down.sh
# ==============
# Что делаем: сносим стенд целиком. Идемпотентен — можно звать сколько угодно.
#
# Удаление namespace удаляет и всё, что в нём жило: veth-концы (вторые концы
# пропадают автоматически), адреса, маршруты, iptables, ipset, conntrack.
# Процессы сами не умирают — их убиваем явно через `ip netns pids`.

set -uo pipefail
source "$(dirname "$0")/lab-env.sh"

for ns in "$NS_C" "$NS_R" "$NS_S"; do
    if [[ -e /run/netns/$ns ]]; then
        # ip netns pids <ns> — PID-ы всех процессов, живущих в этом ns.
        pids=$(sudo ip netns pids "$ns" 2>/dev/null || true)
        [[ -n "$pids" ]] && sudo kill $pids 2>/dev/null
        sudo ip netns del "$ns" && echo "✓ удалён ns $ns"
    fi
done
rm -rf "$LAB_DIR"
echo "✓ Стенд снесён. iptables самой VM мы не трогали."
```
