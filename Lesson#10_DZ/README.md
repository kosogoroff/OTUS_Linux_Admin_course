# Занятие 03.08.2026 "Bash"

Пишем скрипт

## Цель:

написать bash-скрипт, который ежечасно формирует и отправляет на email отчёт о работе веб-сервера;

## Описание/Пошаговая инструкция выполнения домашнего задания:

## 🎯Что нужно сделать?

Написать скрипт для CRON, который раз в час формирует отчёт и отправляет его на заданную почту.


Отчёт должен содержать:

    IP-адреса с наибольшим числом запросов (с момента последнего запуска);
    Запрашиваемые URL с наибольшим числом запросов (с момента последнего запуска);
    Ошибки веб-сервера/приложения (с момента последнего запуска);
    HTTP-коды ответов с указанием их количества (с момента последнего запуска).


Скрипт должен предотвращать одновременный запуск нескольких копий, до его завершения.

В письме должен быть прописан обрабатываемый временной диапазон.

# Решение

## 0. Исходная конфигурация:
- сервер с ОС REDOS 7.3.5;
- прилагаемый к заданию лог ‘access_4560_644067-586145-be5697.log’.

## 1. Предотвращение повторного одновременного запуска нескольких копий скрипта до его завершения

Предотвращение повторного одновременного запуска нескольких копий скрипта до его завершения реализовано путём
блокировки файла. Если попытка эксклюзивной блокировки файла успешна, значит другие экземпляры этого же скрипта
ещё не были запущены - блокируем файл сами. Если попытка эксклюзивной блокировки файла неудачна, значит уже
запущен другой экземпляр скрипта, поэтому выполнения текущего скрипта завершаем:

```
#!/usr/bin/bash
set -euo pipefail

# 1. Не разрешаем запускать скрипт повторно, если другой экземпляр этого же уже выполняется
# При запуске блокируем файл <lockfile>

lockfile="/tmp/scan_log_${HOSTNAME}.lock"
exec 9>"$lockfile"

# Trap: при любом выходе сначала закрываем дескриптор — блокировка снимется.
# Удаление файла делаем только если можем (без ошибок).
trap 'exec 9>&-; exit 0' EXIT INT TERM

# Пытаемся взять эксклюзивную блокировку файла <lockfile> на 0 секунд (не ждать)
if ! flock -n 9; then
    echo "Скрипт уже выполняется, дождитесь окончания выполнения!" >&2
    exit 1
fi

echo "Script run"

sleep 100

exit 0
```

## 2. Отправка писем скриптом с сервера на почту Яндекс

Для отправки писем скриптом с сервера на почту Яндекс делаем следующие настройки
(настройки выполнены по инструкции "Отправка email из консоли linux через Yandex"
по ссылке https://sysadminium.ru/email-from-linux-console-via-yandex/  )
(для простоты используем аутентификацию в почтовом ящике Яндекс по логину/паролю) :

### 2.1 Настраиваем почтовый сервер Яндекс по инструкции:
- Создаём пароль приложений Yandex;
- включаем разрешение подключаться в почтовому ящику Яндекс по IMAP.

### 2.2 На Linux устанавливаем и настраиваем сервер postfix и mailutils. 

```
[root@mv334 admin_insta11]# vi /etc/postfix/main.cf
[root@mv334 admin_insta11]# vi /etc/postfix/sasl_passwd
[root@mv334 admin_insta11]# vi /etc/postfix/generic
[root@mv334 admin_insta11]# 
[root@mv334 admin_insta11]# cat /etc/postfix/main.cf | grep -v '#' | grep -v '^$'
compatibility_level = 3.10
queue_directory = /var/spool/postfix
command_directory = /usr/sbin
daemon_directory = /usr/libexec/postfix
data_directory = /var/lib/postfix
mail_owner = postfix
inet_interfaces = localhost
inet_protocols = ipv4
mydestination = $myhostname, localhost.$mydomain, localhost
unknown_local_recipient_reject_code = 550
relayhost = smtp.yandex.ru:465
alias_maps = hash:/etc/aliases
alias_database = hash:/etc/aliases
 
  
debug_peer_level = 2
debugger_command =
	 PATH=/bin:/usr/bin:/usr/local/bin:/usr/X11R6/bin
	 ddd $daemon_directory/$process_name $process_id & sleep 5
sendmail_path = /usr/sbin/sendmail.postfix
newaliases_path = /usr/bin/newaliases.postfix
mailq_path = /usr/bin/mailq.postfix
setgid_group = postdrop
html_directory = no
manpage_directory = /usr/share/man
sample_directory = /usr/share/doc/postfix/samples
readme_directory = /usr/share/doc/postfix/README_FILES
shlib_directory = /usr/lib64/postfix
meta_directory = /etc/postfix
smtpd_tls_cert_file = /etc/pki/tls/certs/postfix.pem
smtpd_tls_key_file = /etc/pki/tls/private/postfix.key
smtpd_tls_security_level = may
smtp_tls_CApath = /etc/pki/tls/certs
smtp_tls_CAfile = /etc/pki/tls/certs/ca-bundle.crt


smtp_tls_session_cache_timeout = 600s
smtp_tls_wrappermode = yes
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_generic_maps = hash:/etc/postfix/generic
smtp_sasl_security_options = noanonymous
smtp_tls_security_level = encrypt
smtp_tls_loglevel = 1
[root@mv334 admin_insta11]#
[root@mv334 admin_insta11]#
[root@mv334 admin_insta11]# cat /etc/postfix/sasl_passwd
smtp.yandex.ru eugeny.kosogorov@yandex.ru:**************************
[root@mv334 admin_insta11]#
[root@mv334 admin_insta11]# cat /etc/postfix/generic | grep -v '#' | grep -v '^$'
root        eugeny.kosogorov@yandex.ru
mv334       eugeny.kosogorov@yandex.ru
*@mv334     eugeny.kosogorov@yandex.ru
[root@mv334 admin_insta11]# 
```

Перегружаем и проверяем работоспособность сконфигурированного сервера postfix:

```
[root@mv334 admin_insta11]# 
[root@mv334 admin_insta11]# systemctl restart postfix
[root@mv334 admin_insta11]# systemctl status postfix
● postfix.service - Postfix Mail Transport Agent
     Loaded: loaded (/usr/lib/systemd/system/postfix.service; disabled; vendor preset: disabled)
     Active: active (running) since Sun 2026-08-09 04:48:59 MSK; 4s ago
    Process: 246656 ExecStartPre=/usr/sbin/restorecon -R /var/spool/postfix/pid (code=exited, status=0/SUCCESS)
    Process: 246658 ExecStartPre=/usr/libexec/postfix/aliasesdb (code=exited, status=0/SUCCESS)
    Process: 246660 ExecStartPre=/usr/libexec/postfix/chroot-update (code=exited, status=0/SUCCESS)
    Process: 246661 ExecStart=/usr/sbin/postfix start (code=exited, status=0/SUCCESS)
   Main PID: 246729 (master)
      Tasks: 3 (limit: 9211)
     Memory: 3.5M
        CPU: 499ms
     CGroup: /system.slice/postfix.service
             ├─ 246729 /usr/libexec/postfix/master -w
             ├─ 246730 pickup -l -t unix -u
             └─ 246731 qmgr -l -t unix -u

авг 09 04:48:59 mv334 systemd[1]: Starting Postfix Mail Transport Agent...
авг 09 04:48:59 mv334 postfix[246727]: postfix/postlog: starting the Postfix mail system
авг 09 04:48:59 mv334 postfix/postfix-script[246727]: starting the Postfix mail system
авг 09 04:48:59 mv334 postfix/master[246729]: daemon started -- version 3.10.9, configuration /etc/postfix
авг 09 04:48:59 mv334 systemd[1]: Started Postfix Mail Transport Agent.
[root@mv334 admin_insta11]#
```

А также проверяем отправку писем:

```
[root@mv334 admin_insta11]# echo "Текст письма." | mail -s "Тема письма" eugeny.kosogorov@yandex.ru
[root@mv334 admin_insta11]#
[root@mv334 admin_insta11]# echo "Текст письма." | mail -s "Тема письма" eugeny.kosogorov@yandex.ru
[root@mv334 admin_insta11]#
```

При этом в логе сервера видно успешное (без ошибок) отправление письма:

```
[root@mv334 admin_insta11]# journalctl -u  postfix.service -f
авг 09 04:48:59 mv334 systemd[1]: Stopping Postfix Mail Transport Agent...
авг 09 04:48:59 mv334 postfix[246651]: postfix/postlog: stopping the Postfix mail system
авг 09 04:48:59 mv334 postfix/postfix-script[246651]: stopping the Postfix mail system
авг 09 04:48:59 mv334 systemd[1]: postfix.service: Deactivated successfully.
авг 09 04:48:59 mv334 systemd[1]: Stopped Postfix Mail Transport Agent.
авг 09 04:48:59 mv334 systemd[1]: Starting Postfix Mail Transport Agent...
авг 09 04:48:59 mv334 postfix[246727]: postfix/postlog: starting the Postfix mail system
авг 09 04:48:59 mv334 postfix/postfix-script[246727]: starting the Postfix mail system
авг 09 04:48:59 mv334 postfix/master[246729]: daemon started -- version 3.10.9, configuration /etc/postfix
авг 09 04:48:59 mv334 systemd[1]: Started Postfix Mail Transport Agent.
авг 09 04:49:15 mv334 postfix/pickup[246730]: 0A25740199: uid=0 from=<root>
авг 09 04:49:15 mv334 postfix/cleanup[246739]: 0A25740199: message-id=<20260809014915.0A25740199@mv334.localdomain>
авг 09 04:49:15 mv334 postfix/qmgr[246731]: 0A25740199: from=<root@mv334.localdomain>, size=491, nrcpt=1 (queue active)
авг 09 04:49:15 mv334 postfix/smtp[246741]: Trusted TLS connection established to smtp.yandex.ru[77.88.21.158]:465: TLSv1.3 with cipher TLS_AES_256_GCM_SHA384 (256/256 bits) key-exchange ECDHE (P-256) server-signature RSA-PSS (2048 bits) server-digest SHA256
авг 09 04:49:16 mv334 postfix/smtp[246741]: 0A25740199: to=<eugeny.kosogorov@yandex.ru>, relay=smtp.yandex.ru[77.88.21.158]:465, delay=1.6, delays=0.06/0.03/1/0.44, dsn=2.0.0, status=sent (250 2.0.0 Ok: queued on mail-nwsmtp-smtp-production-main-72.klg.yp-c.yandex.net 1786240156-FnAdABeg4W20-XHPOHTrr)
авг 09 04:49:16 mv334 postfix/qmgr[246731]: 0A25740199: removed
авг 09 04:53:59 mv334 postfix/qmgr[246731]: 2548F40196: from=<root@mv334.localdomain>, size=491, nrcpt=1 (queue active)
авг 09 04:54:00 mv334 postfix/smtp[246765]: Trusted TLS connection established to smtp.yandex.ru[77.88.21.158]:465: TLSv1.3 with cipher TLS_AES_256_GCM_SHA384 (256/256 bits) key-exchange ECDHE (P-256) server-signature RSA-PSS (2048 bits) server-digest SHA256
авг 09 04:54:01 mv334 postfix/smtp[246765]: 2548F40196: to=<eugeny.kosogorov@yandex.ru>, relay=smtp.yandex.ru[77.88.21.158]:465, delay=394, delays=393/0.05/1.1/0.49, dsn=2.0.0, status=sent (250 2.0.0 Ok: queued on mail-nwsmtp-smtp-production-main-98.sas.yp-c.yandex.net 1786240441-xrA081beGSw0-3YoBvmUa)
авг 09 04:54:01 mv334 postfix/qmgr[246731]: 2548F40196: removed
^C
[root@mv334 admin_insta11]#
```

А в почтовый ящик Яндекс пришло письмо:

<img width="1230" height="426" alt="изображение" src="https://github.com/user-attachments/assets/6d58c143-a65e-42d3-9b64-93df90787b8a" />

<img width="1211" height="481" alt="изображение" src="https://github.com/user-attachments/assets/5a638296-718b-42af-a5f9-e3d509564294" />


## 3. Скрипты для парсинга лога

Для парсинга строк лога были разработаны следующие скрипты:

### 3.1  Парсер полей строк лога log_parser.sh

Для облегчения и унификации первоначального парсинга лога был разработан основной парсер полей строк лога (оформлен в виде отдельного файла log_parser.sh). Строки лога содержат разделённые пробелами простые (состоящие из НЕпробельных символов) и сложные (поля в кавычках и скобках, которые могут содержать внутри пробельные символы) поля. Парсер рассчитан на парсинг полей следующих следующих типов:

- поля в двойных кавычках, содержащие пробелы, например "a bc def" - считается одним полем
- поля в одинарных кавычках, содержащие пробелы, например 'a bc def' - считается одним полем
- поля в квадратных скобках, содержащие пробелы, например [a bc def] - считается одним полем
- поля в круглых скобках, содержащие пробелы, например (a bc def) - считается одним полем
- поля в фигурных скобках, содержащие пробелы, например {a bc def} - считается одним полем
- поля в угловых скобках, содержащие пробелы, например <a bc def> - считается одним полем
- поля без кавычек и скобок, не содержащие пробелов, например HTTP1.1/OK - считается одним полем

Данный основной парсер разбивает строки на указанные простые и сложные поля, считает их количество, а также возвращает поля по их номерам. Вложенность и экранирование скобок и кавычек внутри полей не поддерживаются !!!

Парсер использует два метода парсинга:

1. Более быстрый с использованием gawk (GNU awk) и его параметра FPAT, в котором задаются regex для возможных форматов полей (работает в системах с установленным GNU awk)
   
2. Более медленный, с посимвольным разбором строки, если в системе не содержится gawk (обычный awk не поддерживает FPAT) (должен работать в любой системе)

```
[admin_insta11@mv334 ~]$ cat log_parser.sh
#!/usr/bin/env bash

# Основной парсер полей строк лога.
# Функции парсера работают со строкой, содержащей следующие типы полей:
# - поля в двойных кавычках, содержащие пробелы, например "a bc def" - считается одним полем
# - поля в одинарных кавычках, содержащие пробелы, например 'a bc def' - считается одним полем
# - поля в квадратных скобках, содержащие пробелы, например [a bc def] - считается одним полем
# - поля в круглых скобках, содержащие пробелы, например (a bc def) - считается одним полем
# - поля в фигурных скобках, содержащие пробелы, например {a bc def} - считается одним полем
# - поля в угловых скобках, содержащие пробелы, например <a bc def> - считается одним полем
# - поля без кавычек и скобок, не содержащие пробелов, например HTTP1.1/OK - считается одним полем
#
# Вложенность и экранирование скобок и кавычек не поддерживаются !!!

# Парсер использует два метода парсинга:
# 1. Более быстрый с использованием gawk (GNU awk) и его параметра FPAT, в котором задаются regex для возможных форматов полей
# 2. Более медленный, с посимвольным разбором строки, если в системе не содержится gawk (обычный awk не поддерживает FPAT),
# должен работать везде
#
# Объявление нужного варианта функции parse_fields() производится условным оператором if в зависимости
# от наличия/отсутствия в системе GNU awk по результату команды command -v

# Имеющиеся функции:
#
# parse_fields() - принимает один параметр: текстовую строку ; возвращает текстовые поля из строки
# get_field() - принимает два параметра: текстовую строку и номер поля N в строке ; возвращает N-е текстовое поле из строки (если оно существует)
# count_fields() - принимает один параметр: текстовую строку ; возвращает количество текстовых полей в строке

# Примечания для FPAT:
#
# 1. Важен порядок следования масок regex: маски regex для более сложных полей со скобками/кавычками должны идти вначале, а
# маски regex для более простых полей без кавычек и пробелов должны идти в конце, так как парсер полей FPAT в gawk идёт
# по порядку следования масок в FPAT до первого срабатывания и дальше не идёт. Если первой будет срабатывать маска [^[:space:]]+ ,
# то она будет разбивать более сложные поля с пробелами на более простые поля без пробелов, например, вместо 'a bc def' 
# будет три поля "'a", "bc" и  "def'"
#
# 2. В bash/shell/awk нет способа вставить одинарную кавычку в строку внутри одинарных кавычек типа 'it's OK' ,
# даже через экранирование 'it\'s OK'.
# Поэтому при создании необходимой маски '([^']*) для поля в одинарных кавычках с пробелами применён приём разрыва строки,
# общая маска формируется как '"([^"]*)"|'"'"'([^'"'"']*)'"'"'|\\[([^]]*)\\]|\\(([^)]*)\\)|\\{([^{}]*)\\}|[^[:space:]]+' ,
# при этом делится на следующие части:
# 1. '"([^"]*)"|'  2. "'"  3. '([^'  4. "'"  5. ]*)'  6. "'"  7. '|\\[([^]]*)\\]|\\(([^)]*)\\)|\\{([^{}]*)\\}|[^[:space:]]+'
# В частях 2, 4, 6 вставляется одинарная кавычка как символ внутри строки в двойных кавычках 
#
# 3. В awk угловые скобки имеют специальное значение, поэтому легче из заменить на другие (например, на квадратные)
# перед обработкой в awk
#

# --- Автовыбор движка ---
# command -v выдаёт путь к исполняемому файлу, если команда существует или код ошибки - если не существует
if command -v gawk >/dev/null 2>&1; then  
    # Версия на gawk (быстрая)
    parse_fields() {
        local input="$1"
        # Нормализуем угловые скобки
        input=$(echo "$input" | sed 's/<\([^>]*\)>/[\1]/g')    #  заменяем угловые скобки в строке на квадратные, чтобы обрабатывать одинаково
        gawk -v FPAT='"([^"]*)"|'"'"'([^'"'"']*)'"'"'|\\[([^]]*)\\]|\\(([^)]*)\\)|\\{([^{}]*)\\}|[^[:space:]]+' '{
            for (i = 1; i <= NF; i++) {
              f = $i
            # Убираем ограничители
            gsub(/^"/, "", f); gsub(/"$/, "", f)
            gsub(/^'"'"'/, "", f); gsub(/'"'"'$/, "", f)
            gsub(/^\[/, "", f); gsub(/\]$/, "", f)
            gsub(/^\(/, "", f); gsub(/\)$/, "", f)
            gsub(/^\{/, "", f); gsub(/\}$/, "", f)
            print f
            }
        }' <<< "$input"
    }
else
    # Версия на чистом Bash (переносимая)
    parse_fields() {
        local input="$1"
        input=$(echo "$input" | sed 's/<\([^>]*\)>/[\1]/g')

        local -a fields=()
        local i=0 len current state="normal" open_char
        len=${#input}

        while (( i < len )); do
            local ch="${input:i:1}"
            case "$state" in
                normal)
                    if [[ "$ch" == " " || "$ch" == $'\t' ]]; then
                        [[ -n "$current" ]] && { fields+=("$current"); current=""; }
                        ((i++)); continue
                    fi
                    [[ "$ch" == '"' ]] && { state="double"; ((i++)); continue; }
                    [[ "$ch" == "'" ]] && { state="single"; ((i++)); continue; }
                    [[ "$ch" == '[' ]] && { state="square"; ((i++)); continue; }
                    [[ "$ch" == '(' ]] && { state="paren"; ((i++)); continue; }
                    [[ "$ch" == '{' ]] && { state="brace"; ((i++)); continue; }
                    current+="$ch"; ((i++)); continue
                    ;;
                double|single|square|paren|brace)
                    local end_char
                    case "$state" in
                      double) end_char='"';;
                      single) end_char="'";;
                      square) end_char=']';;
                      paren)  end_char=')';;
                      brace)  end_char='}';;
                    esac

                    if [[ "$ch" == "$end_char" ]]; then
                        fields+=("$current")
                        current=""
                        state="normal"
                    else
                        current+="$ch";
                    fi
                    ((i++))
                    continue
                    ;;
            esac
        done
        [[ -n "$current" ]] && fields+=("$current")
        printf '%s\n' "${fields[@]}"
    }
fi

# Обертка: получить N-е поле (1-based)
get_field() {
    local input="$1" n="$2"
    [[ -z "$input" || ! "$n" =~ ^[0-9]+$ || "$n" -lt 1 ]] && return 1
    local -a f; mapfile -t f < <(parse_fields "$input")
    (( n <= ${#f[@]} )) && echo "${f[n-1]}" || return 1
}

# Посчитать поля
count_fields() {
    local input="$1"; [[ -z "$input" ]] && { echo 0; return; }
    local -a f; mapfile -t f < <(parse_fields "$input"); echo "${#f[@]}"
}
```

Тест парсера:

```
[admin_insta11@mv334 ~]$ cat test_parser.sh
#!/usr/bin/bash

source log_parser.sh

line='107.179.102.58 - - [14/Aug/2019:05:22:10 +0300] "GET /wp-content/plugins/uploadify/readme.txt HTTP/1.1" 404 200 "http://dbadmins.ru/wp-content/plugins/uploadify/readme.txt" "Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/42.0.2311.152 Safari/537.36"rt=0.000 uct="-" uht="-" urt="-'

total=$(count_fields "$line")
echo "Всего полей: $total"

for ((i = 1; i <= total; i++)); do
    echo "Поле $i: $(get_field "$line" "$i")"
done
[admin_insta11@mv334 ~]$ 
[admin_insta11@mv334 ~]$ ./test_parser.sh
Всего полей: 13
Поле 1: 107.179.102.58
Поле 2: -
Поле 3: -
Поле 4: 14/Aug/2019:05:22:10 +0300
Поле 5: GET /wp-content/plugins/uploadify/readme.txt HTTP/1.1
Поле 6: 404
Поле 7: 200
Поле 8: http://dbadmins.ru/wp-content/plugins/uploadify/readme.txt
Поле 9: Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/42.0.2311.152 Safari/537.36
Поле 10: rt=0.000
Поле 11: uct=-
Поле 12: uht=-
Поле 13: urt=-
[admin_insta11@mv334 ~]$ 
```

Примечание: для тестирования парсера без GNU awk можно добавить в строке

```
if command -v gawk >/dev/null 2>&1; then
<...>
```

отрицание "!" , тогда будет выбираться второй вариант функции parse_fields() :

```
if ! command -v gawk >/dev/null 2>&1; then
<...>
```

Вывод теста в обоих при обоих вариантах выбранной функции parse_fields() одинаковый.


### 3.2 Основной скрипт scan_log2.sh:

Основной скрипт scan_log2.sh, использующий вышеприведённый парсер log_parser.sh и выполняющий поставленные задачи, может запускаться либо без параметров (тогда для обработки лога берётся текущая дата системы), либо с явным заданием времени в параметре -t (с параметром -t для обработки лога берётся введённая дата):


```
[admin_insta11@mv334 ~]$ cat scan_log2.sh
#!/usr/bin/bash
# set -euo pipefail

top_n=20  #  количество выводимых строк в отчётах о самых-самых (частых адресах, URL-ах и проч.)

source log_parser.sh  # включаем код основного парсера полей для использования его функций

usage_help() {
  # Вывод подсказки по использованию скрипта
  cat >&2 << EOF1

Примеры использования скрипта:

$0                            # без параметра для обработки лога берётся текущая дата системы

$0 -t "2019-08-14 04:00:00"   # с параметром -t для обработки лога берётся введённая дата


EOF1

  exit 1
}

urldecode() {
  # В закодированном Base64 URL заменяем все символы % на \x , получаем строку Hex символов и перекодируем в UTF-8
  printf '%b' "${1//%/\\x}"  
}

# 1. Не разрешаем запускать скрипт повторно, если другой экземпляр этого же уже выполняется
# При запуске блокируем файл <lockfile>

lockfile="/tmp/scan_log_${HOSTNAME}.lock"
exec 9>"$lockfile"

# Trap: при любом выходе сначала закрываем дескриптор — блокировка снимется.
# Удаление файла делаем только если можем (без ошибок).
trap 'exec 9>&-; exit 0' EXIT INT TERM 

# Пытаемся взять эксклюзивную блокировку файла <lockfile> на 0 секунд (не ждать)
if ! flock -n 9; then
    echo "Скрипт уже выполняется, дождитесь окончания выполнения!" >&2
    exit 1
fi

# Получить дату в нужном формате, используемом в логе, вывод месяцев на английском:
#LC_TIME=C date +'%d/%b/%Y'
# или
#LC_TIME=en_US.UTF-8 date +'%d/%b/%Y'
# LC_TIME=C — самый простой и переносимый вариант: короткие названия месяцев будут на английском (Jan, Feb, …, Dec).
# en_US.UTF-8 тоже сработает, но требует, чтобы эта локаль была установлена в системе (в Ubuntu обычно есть,
# в минималистичных образах может не быть). C есть всегда.
# Проверить наличие локалей:  locale -a | grep -i 'en_us\|C'


# При запуске скрипта будет анализироваться 1 час из него в период от previous_date до base_date

case $1 in
  "")
    # Если параметр отсутствует, то в качестве базовой даты для анализа лога берём текущее время
    base_date=`LC_TIME=C date +'%Y-%m-%d %H:%M:%S'`
  ;;
  "-t")
    # А если параметр -t , то то в качестве базовой даты для анализа лога берём введённое время
    base_date=$2
  ;;
  *)
    usage_help
    exit 1
  ;;
esac

# Валидация базовой даты
if ! LC_TIME=C date -d "$base_date" >/dev/null 2>&1; then
  echo "Некорректная базовая дата: $base_date" >&2
  usage_help
  exit 1
fi

# previous_date = base_date - 1 hour
previous_date=`LC_TIME=C date -d "$base_date 1 hour ago" +'%Y-%m-%d %H:%M:%S'`

#echo "$base_date"
#echo "$previous_date"

# Получаем время (без минут и секунд) в нужном формате, соответствующем формату времени в логе 
current_hour=`LC_TIME=C date -d "$base_date" +'%d/%b/%Y:%H'`
previous_hour=`LC_TIME=C date -d "$base_date 1 hour ago" +'%d/%b/%Y:%H'`

# Выбирать нужный период в логе будем в помощью  grep "${previous_hour}"

#echo "current_hour=$current_hour"
#echo "previous_hour=$previous_hour"

echo "Результаты обработки лога за период ${previous_hour}:00:00 - ${current_hour}:00:00"

log_file="access_4560_644067-586145-be5697.log"

echo "log_file=$log_file"


# 1. IP-адреса с наибольшим числом запросов (с момента последнего запуска)
#
# REGEX для IP-адресов:
#   ip a | grep -P "((25[0-5]|2[0-4][0-9]|1[0-9]{1,2}|[1-9][0-9]|[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{1,2}|[1-9][0-9]|[0-9])"

echo "1. IP-адреса с наибольшим числом запросов (TOP $top_n IP-адресов)"
cat $log_file | grep "$previous_hour" | \
grep -P "((25[0-5]|2[0-4][0-9]|1[0-9]{1,2}|[1-9][0-9]|[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{1,2}|[1-9][0-9]|[0-9])" | \
awk '{print $1}' | uniq -c | sort -r -n | grep -v -P "[ ]*1 " | head -n "$top_n"


# Далее используем функции разработанного парсера полей в файле log_parser.sh

# 2. Запрашиваемые URL с наибольшим числом запросов (с момента последнего запуска)

echo
echo "2. Запрашиваемые URL с наибольшим числом запросов (TOP $top_n URL-ов)"


declare -A counts          # Ассоциативный массив для хранения количества строк URL: ключ - строка URL, значение - количество её вызовов
declare -A sample_decoded  # храним один пример декодированной строки для каждого пути: ключ - строка URL, значение - декодированная строка URL

while IFS= read -r line; do

    # Пропускаем пустые строки
    [[ -z "$line" ]] && continue

    # Поле 5: "GET /path?query=1 HTTP/1.1" (кавычки уже сняты парсером)
    request=$(get_field "$line" 5)
    [[ -z "$request" ]] && continue

    # Разбиваем на метод, путь, версию
    read -r method path version <<< "$request"

    # Если вдруг path пустой (странный лог) — пропускаем
    [[ -z "$path" ]] && continue
    
    # Убираем query‑параметры: /page?a=1 → /page  , чтобы страницы URL /page?a=1 и /page?b=150 были одинаковыми
    path_no_query=${path%%\?*}

    # увеличиваем счётчик значений для данного URL в массиве, если такого элемента ещё нет, он создаётся
    ((counts["$path_no_query"]++))

  # Сохраняем декодированный вариант URL (один раз достаточно)
  if [[ -z "${sample_decoded[$path_no_query]:-}" ]]; then
    sample_decoded["$path_no_query"]=$(urldecode "$path_no_query")
  fi

done < <(cat "$log_file" | grep "$previous_hour")

# Выводим топ‑N
for path in "${!counts[@]}"; do
    decoded="${sample_decoded[$path]}"
    printf '%d %s\n' "${counts[$path]}" "$decoded"
done | sort -rn | head -n "$top_n"


# 3. Ошибки веб-сервера/приложения (с момента последнего запуска)

echo
echo "3. Ошибки веб-сервера/приложения"

while IFS= read -r line; do

    # Пропускаем пустые строки
    [[ -z "$line" ]] && continue

    # Поле 4: время
    time=$(get_field "$line" 4)
    time=`echo $time | awk '{print $1}'`
    # Поле 6: статус 
    status=$(get_field "$line" 6)

#    echo "$time - $status"

    [[ -z "$status" ]] && continue

    # Выводим ошибку и время её возникновения: 4xx - Client errors, 5xx - Server error
    if [[ "$status" =~ 4[0-9]{2} ]]; then
      echo "$time - Client error: $status"
    fi 
    if [[ "$status" =~ 5[0-9]{2} ]]; then
      echo "$time - Server error: $status"
    fi

done < <(cat "$log_file" | grep "$previous_hour")

# 4. HTTP-коды ответов с указанием их количества (с момента последнего запуска)

echo
echo "4. HTTP-коды ответов с указанием их количества"

declare -A codes_counts      # Ассоциативный массив для хранения количества HTTP-кодов : ключ - HTTP-код статуса, значение - количество

while IFS= read -r line; do

    # Пропускаем пустые строки
    [[ -z "$line" ]] && continue

    # Поле 6: статус 
    status=$(get_field "$line" 6)

    [[ -z "$status" ]] && continue

    ((codes_counts["$status"]++))

done < <(cat "$log_file" | grep "$previous_hour")

# Выводим коды и их количество
    echo "Код HTTP ответа   -   Количество"
for code in "${!codes_counts[@]}"; do
    echo "     $code          -     ${codes_counts[$code]}"
done | sort
```

Пример получения отчёта из лога с помощью скриптов с заданием времени:

```
[admin_insta11@mv334 ~]$ ./scan_log2.sh -t "2019-08-14 23:00:00"
Результаты обработки лога за период 14/Aug/2019:22:00:00 - 14/Aug/2019:23:00:00
log_file=access_4560_644067-586145-be5697.log
1. IP-адреса с наибольшим числом запросов (TOP 20 IP-адресов)
      3 89.32.248.234
      3 167.71.136.40
      3 139.180.174.55
      2 93.158.167.130

2. Запрашиваемые URL с наибольшим числом запросов (TOP 20 URL-ов)
8 /
6 /wp-login.php
3 /xmlrpc.php
1 /wp-content/uploads/2018/08/seo_script.php
1 /2017/06/

3. Ошибки веб-сервера/приложения
14/Aug/2019:22:04:04 - Server error: 500
14/Aug/2019:22:05:00 - Client error: 404
14/Aug/2019:22:56:43 - Client error: 404

4. HTTP-коды ответов с указанием их количества
Код HTTP ответа   -   Количество
     200          -     14
     301          -     2
     404          -     2
     500          -     1
[admin_insta11@mv334 ~]$ 
```

### 4. Отправка писем полученных отчётов в почту Яндекс

Наконец, отправляем получаемые скриптами отчёты по логу в почту Яндекс:

```
[root@mv334 admin_insta11]# cur_date=`date -d "2019-08-14 19:00:00" +'%Y-%m-%d %H:00:00'`; prev_date=`date -d "$cur_date 1 hour ago" +'%Y-%m-%d %H:%M:%S'`; /home/admin_insta11/scan_log2.sh -t "$cur_date" | mail -s "Результаты проверки лога за период $prev_date - $cur_date" eugeny.kosogorov@yandex.ru
[root@mv334 admin_insta11]# 
[root@mv334 admin_insta11]# cur_date=`date -d "2019-08-14 20:00:00" +'%Y-%m-%d %H:00:00'`; prev_date=`date -d "$cur_date 1 hour ago" +'%Y-%m-%d %H:%M:%S'`; /home/admin_insta11/scan_log2.sh -t "$cur_date" | mail -s "Результаты проверки лога за период $prev_date - $cur_date" eugeny.kosogorov@yandex.ru
[root@mv334 admin_insta11]# 
[root@mv334 admin_insta11]# cur_date=`date -d "2019-08-14 21:00:00" +'%Y-%m-%d %H:00:00'`; prev_date=`date -d "$cur_date 1 hour ago" +'%Y-%m-%d %H:%M:%S'`; /home/admin_insta11/scan_log2.sh -t "$cur_date" | mail -s "Результаты проверки лога за период $prev_date - $cur_date" eugeny.kosogorov@yandex.ru
[root@mv334 admin_insta11]# 
[root@mv334 admin_insta11]# cur_date=`date -d "2019-08-14 22:00:00" +'%Y-%m-%d %H:00:00'`; prev_date=`date -d "$cur_date 1 hour ago" +'%Y-%m-%d %H:%M:%S'`; /home/admin_insta11/scan_log2.sh -t "$cur_date" | mail -s "Результаты проверки лога за период $prev_date - $cur_date" eugeny.kosogorov@yandex.ru
[root@mv334 admin_insta11]# 
[root@mv334 admin_insta11]# cur_date=`date -d "2019-08-14 23:00:00" +'%Y-%m-%d %H:00:00'`; prev_date=`date -d "$cur_date 1 hour ago" +'%Y-%m-%d %H:%M:%S'`; /home/admin_insta11/scan_log2.sh -t "$cur_date" | mail -s "Результаты проверки лога за период $prev_date - $cur_date" eugeny.kosogorov@yandex.ru
[root@mv334 admin_insta11]# 
```

При этом в почтовый ящик Яндекс приходят письма с отчётами:

<img width="1130" height="655" alt="изображение" src="https://github.com/user-attachments/assets/2a3dd74b-83e3-43a7-ad58-bcff60291ef2" />

Письма имеют следующее соодержимое:

<img width="1654" height="973" alt="изображение" src="https://github.com/user-attachments/assets/dedffe30-45da-4914-89e8-74f887ea875a" />


<img width="1159" height="657" alt="изображение" src="https://github.com/user-attachments/assets/82e632a3-9908-45c9-9e3f-dc831dfbb84b" />


<img width="1161" height="659" alt="изображение" src="https://github.com/user-attachments/assets/4e9f9b1e-8513-412c-b9ea-21ec52f25aa6" />


### 5. Конфигурирование CRON для запуска скрипта один раз в час для отправки писем полученных отчётов в почту Яндекс:

Для запуска скрипта один раз в час можно использовать crontab:

```
[root@mv334 admin_insta11]# crontab -e
no crontab for root - using an empty one
No protocol specified

crontab: installing new crontab
[root@mv334 admin_insta11]# 
[root@mv334 admin_insta11]# crontab -l
0 * * * * cur_date=`date +'%Y-%m-%d %H:00:00'`; prev_date=`date -d "$cur_date 1 hour ago" +'%Y-%m-%d %H:%M:%S'`; /home/admin_insta11/scan_log2.sh -t "$cur_date" | mail -s "Результаты проверки лога за период $prev_date - $cur_date" eugeny.kosogorov@yandex.ru
[root@mv334 admin_insta11]# 
```
