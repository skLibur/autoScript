#!/bin/bash

#DZ-6  Проверки!

# Проверка дистрибутива Linux
cat /etc/os-release | grep -w "Ubuntu" 1> /dev/null
if [ $? != 0 ]
  then
        echo "It's not Ubuntu! Run script only on Ubuntu!!!"
        exit
# Проверка, запущен ли скрипт от имени root
  else if [ "$(id -u)" != "0" ] 
  then
        echo "Запустите скрипт от имени root!"
	exit
  fi
fi

# Проверка присутвует доступ к файлу /root/config.json
if [ -e /root/config.json ]
  then 
	# Проверка: устновлен ли пакет jq; устанавливаем, если нету.
	dpkg -s "jq" &> /dev/null
	if [ $? != 0 ] 
	  then
		apt -y install jq
	fi
	# Разбор конфига /root/config.json
	siteName=$(cat /root/config.json | jq -r '.sitename')
	siterootDir=$(cat /root/config.json |jq -r '.siteroot_dir')
	DB_userName=$(cat /root/config.json | jq -r '.db.username')
	DB_password=$(cat /root/config.json | jq -r '.db.password')
	DB_name=$(cat /root/config.json | jq -r '.db.name')

	echo "siteName: $siteName"
	echo "siterootDir: $siterootDir"
	echo "DB_userName: $DB_userName"
	echo "DB_password: $DB_password"

  else
	echo "Файла '/root/config.json' не существует!"
	exit
fi


# Проверка установленного пакета apache2
dpkg -s "apache2" &> /dev/null 
 
if  [ $? != 0 ]
  then
	# Установка Apache2
	apt update && sudo apt -y install apache2
fi

# Проверка установленного пакета mysql-server
dpkg -s "mysql-server" &> /dev/null
if [ $? != 0 ]
  then
	# Установка MySQL Server
	apt -y install mysql-server
fi

dpkg -s "php7.2" &> /dev/null
# Проверка установленного PHP
if [ $? != 0 ]
  then
	# Установка PHP
	apt -y install php7.2
	apt -y install php7.2-mysql # модуль для MySQL
fi 


# Перезагружаем веб-сервер
systemctl reload apache2.service

# Очищаем каталок перед копированием туда WordPress
rm -rf $siterootDir/*

# Установка WordPress
wget https://ru.wordpress.org/latest-ru_RU.tar.gz -P $siterootDir 
# Распаковка WordPress
tar -xzvf $siterootDir/latest-ru_RU.tar.gz -C $siterootDir


# Перемещаем все файлы из папки WordPress прямо в корень папки $siterootDir
mv $siterootDir/wordpress/* $siterootDir

# Удаляем пустую папку WordPress
rmdir $siterootDir/wordpress

##DZ-3

# Удаление БД
#mysql -e "DROP DATABASE $DB_name;"

# Удаление пользователя 
#mysql -e "DROP USER '$DB_userName'@'localhost';"

# Создание БД в MySQL
mysql -e "CREATE DATABASE $DB_name"

# Создание нового пользователя БД MySQL
mysql -e "CREATE USER '$DB_userName'@'localhost' IDENTIFIED BY '$DB_password';"
# Предоставить права для этого пользователя БД
mysql -e "GRANT ALL PRIVILEGES ON $DB_name.* TO '$DB_userName'@'localhost' WITH GRANT OPTION;"


##DZ-4
# Настройка Wordpress.

# Создаем конфиг WordPress
# Переходим в корневую папку. Там у нас уже конфиги WordPress 
cd $siterootDir 
cp wp-config-sample.php wp-config.php

# Правим конфиг (wp-config.php) Wordpress. Замена строк в конфиге

# /** Имя базы данных для WordPress */
sed -i "s/.*database_name_here.*/define( 'DB_NAME', '$DB_name' );/" wp-config.php

# /** Имя пользователя MySQL */
sed -i "s/.*username_here.*/define( 'DB_USER', '$DB_userName' );/" wp-config.php

# /** Пароль (пользователя) к базе данных MySQL */
sed -i "s/.*password_here.*/define( 'DB_PASSWORD', '$DB_password' );/" wp-config.php

# /** Имя сервера MySQL */
sed -i "s/.*localhost.*/define( 'DB_HOST', '$siteName' );/" wp-config.php

#############################################################################
## Настройка конфигов Apache2
# Формирование vhost.conf
ServerAdmin="$DB_userName@$siteName" 
sed -i "s!ServerAdmin!ServerAdmin $ServerAdmin!" /root/vhost.conf
DocumentRoot="DocumentRoot $siterootDir"
sed -i "s!DocumentRoot!$DocumentRoot!" /root/vhost.conf
ServerName="ServerName $siteName" 
sed -i "s!ServerName!$ServerName!" /root/vhost.conf
ServerAlias="ServerAlias www.$siteName" 
sed -i "s!ServerAlias!$ServerAlias!" /root/vhost.conf
Directory="<Directory $siterootDir>"
sed -i "s!<Directory>!$Directory!" /root/vhost.conf
ErrorLog="$siterootDir/error.log"
sed -i "s!ErrorLog!ErrorLog $ErrorLog!" /root/vhost.conf
CustomLog="$siterootDir/access.log combined"
sed -i "s!CustomLog!CustomLog $CustomLog!" /root/vhost.conf



# Закидываем сформированный vhost.conf в /etc/apache2/sites-available
cp /root/vhost.conf /etc/apache2/sites-available

# Активируем vhost.conf
a2ensite vhost.conf
# Деактивируем старый конфиг
a2dissite 000-default.conf 

systemctl is-active apache2.service --quiet
if [ $? = 0 ]
  then 
	# Перезапускаем apache2.service
	systemctl reload apache2.service
  else
	# Запускаем Apache2
	systemctl start apache2.service
fi


#############################################################################

##DZ-5
# Резервные копии
# Разбор конфига /root/config.json
backupEnable=$(cat /root/config.json | jq -r '.backup_enable')

# Нужно ли делать резервные копии?
if [ "$backupEnable" == "1" ]
  then
	#Запускаем скрипт по добавлению резервного копирования в планировщик
	/root/cron.sh
  else
	echo "Резервное копирование отключено."
fi
