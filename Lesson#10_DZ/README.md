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

0. Исходная конфигурация:
- сервер с ОС REDOS 7.3.5;
- прилагаемый к заданию лог ‘access_4560_644067-586145-be5697.log’.

### 1. Предотвращение повторного одновременного запуска нескольких копий скрипта до его завершения

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

### 2. Отправка писем скриптом с сервера на почту Яндекс

Для отправки писем скриптом с сервера на почту Яндекс делаем следующие настройки
(настройки выполнены по инструкции "Отправка email из консоли linux через Yandex"
по ссылке https://sysadminium.ru/email-from-linux-console-via-yandex/  )
(для простоты используем аутентификацию в почтовом ящике Яндекс по логину/паролю) :

2.1 Настраиваем почтовый сервер Яндекс по инструкции:
- Создаём пароль приложений Yandex;
- включаем разрешение подключаться в почтовому ящику Яндекс по IMAP.

2.2 На Linux устанавливаем и настраиваем сервер postfix и mailutils. 

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

