#!/bin/bash

echo "Запускаем настройку резервного копирования..."
cronMin=$(cat /root/config.json | jq -r '.cron.min')
cronHour=$(cat /root/config.json | jq -r '.cron.hour')
cronDay_m=$(cat /root/config.json | jq -r '.cron.day_m')
cronMonth=$(cat /root/config.json | jq -r '.cron.month')
cronDay_w=$(cat /root/config.json | jq -r '.cron.day_w')

#Добавляем задание по резервному копированию в планировщик
crontab -l > current_cron
cat >> current_cron << EOF
$cronMin $cronHour $cronDay_m $cronMonth $cronDay_w /root/backup.sh
EOF
crontab < current_cron
rm -f current_cron

echo "Планировщик заданий настроен! Посмотреть: crontab -e"
echo "Очистить планировщик: crontab -r"
