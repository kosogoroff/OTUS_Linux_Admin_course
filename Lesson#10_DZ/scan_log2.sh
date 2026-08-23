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
  printf '%b' "${1//%/\\x}"  # В закодированном Base64 URL заменяем все символы % на \x , получаем строку Hex символов и перекодируем в UTF-8
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
# en_US.UTF-8 тоже сработает, но требует, чтобы эта локаль была установлена в системе (в Ubuntu обычно есть, в минималистичных образах может не быть). C есть всегда.
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


