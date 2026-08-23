#!/usr/bin/bash

source log_parser.sh

line='107.179.102.58 - - [14/Aug/2019:05:22:10 +0300] "GET /wp-content/plugins/uploadify/readme.txt HTTP/1.1" 404 200 "http://dbadmins.ru/wp-content/plugins/uploadify/readme.txt" "Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/42.0.2311.152 Safari/537.36"rt=0.000 uct="-" uht="-" urt="-'

total=$(count_fields "$line")
echo "Всего полей: $total"

for ((i = 1; i <= total; i++)); do
    echo "Поле $i: $(get_field "$line" "$i")"
done
