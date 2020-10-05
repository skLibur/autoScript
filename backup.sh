#!/bin/bash

# Разбор конфига config.json
siteName=$(cat config.json | jq -r '.sitename')
siterootDir=$(cat config.json | jq -r '.siteroot_dir')
#DB_userName=$(cat config.json | jq -r '.db.username')
#DB_password=$(cat config.json | jq -r '.db.password')
DB_name=$(cat config.json | jq -r '.db.name')


#backupEnable=$(cat config.json | jq -r '.backup_enable')
#cronMin=$(cat config.json | jq -r '.cron.min')
#cronHour=$(cat config.json | jq -r '.cron.hour')
#cronDay_m=$(cat config.json | jq -r '.cron.day_m')
#cronMonth=$(cat config.json | jq -r '.cron.month')
#cronDay_w=$(cat config.json | jq -r '.cron.day_w')

copynum=$(cat config.json | jq -r '.copynum')



# Создадим папки для резервных копий
# проверяем количество копий (уже созданных папок) и лишнее удаляем

if [ -d "/root/backups/$siteName" ] 
  then
        # Смотрим количество копий
        realnum=$(find /root/backups/$siteName -maxdepth 1 -type f | wc -l)
        echo "Количество копий в папке бэкапа:$realnum" 
        if [ "$realnum" -gt "$copynum" ]
          then

                ((copynum++)) # удаляем все, что больше $copynum 
                echo "Удаляем лишнее!"
                find /root/backups/$siteName -maxdepth 1 -type f | sort -r | tail -n +$copynum | xargs rm
        fi  
  else
        # создаем папку
        mkdir -p /root/backups/$siteName
        echo "Создали папку: $siteName"
fi


backupPath=/root/backups/$siteName

date=$(date +"%y-%m-%d.%H-%M")

mkdir -p $backupPath/$date/configs
mkdir -p $backupPath/$date/logs


# Делаем дамп БД WordPress из MySQL в корень
#sudo mysqldump $DB_name > $siterootDir/$DB_name.dump.sql


# Записываем туда конфиги (Apache, WordPress) и дамп БД
cp $siterootDir/wp-config.php $backupPath/$date/configs
cp /etc/apache2/sites-available/* $backupPath/$date/configs
cp $siterootDir/$DB_name.dump.sql $backupPath/$date




#Записываем туда логи:

[ -e "$siterootDir/error.log" ] && cp $siterootDir/error.log $backupPath/$date/logs 
[ -e "$siterootDir/access.log" ] && cp $siterootDir/access.log $backupPath/$date/logs


# Создаем архивчик archive
cd $backupPath
tar -czf $date.tar.gz $date
#Удаляем папку
rm -r $backupPath/$date

