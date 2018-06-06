#!/bin/bash

LOGFILE=install.log

hostname=$1

if [[ $hostname == *'.'* ]]; then
	host $hostname > /dev/null 2>&1
	echo "is valid"
	else
		echo "hostname is not valid"
		exit
fi

if [[ -e /etc/debian_version ]]; then
	OS=debian
	GROUPNAME=nogroup
	RCLOCAL='/etc/rc.local'
elif [[ -e /etc/centos-release || -e /etc/redhat-release ]]; then
	OS=centos
	GROUPNAME=nobody
	RCLOCAL='/etc/rc.d/rc.local'
elif [[ `uname` == "Darwin" ]]; then
	OS=macos
	GROUPNAME=nogroup
else
	echo "Looks like you aren't running this installer on Debian, Ubuntu or CentOS"
	exit
fi

if [[ "$OS" = 'debian' ]]; then
  apt update
  apt -y install apache2 git-core expect curl git unzip
  git clone https://github.com/Subely/subely.com.git /var/www/$hostname
  git clone https://github.com/Subely/api.subely.com.git /var/www/api.$hostname
  sudo chown -R $USER:$USER /var/www/$hostname
  sudo chown -R $USER:$USER /var/www/api.$hostname
  sudo chmod -R 755 /var/www
  sed -e "s/\${host}/$hostname/" ./config/subely.com.conf |tee /etc/apache2/sites-available/$hostname.conf
  sed -e "s/\${host}/$hostname/" ./config/api.subely.com.conf |tee /etc/apache2/sites-available/api.$hostname.conf
  sudo a2ensite $hostname.conf
  sudo a2ensite api.$hostname.conf
  sudo service apache2 restart

  #
  #Installing MySQL 5.7 which is available in default repo for Ubuntu 16.06
  #
  MYSQLPASSWORD=$(LC_ALL=C tr -dc 'A-HJ-NPR-Za-km-z2-9' < /dev/urandom | head -c 16)

  echo "Installing MySQL 5.7 now...\n"

  echo "You mysql password is:" | echo $MYSQLPASSWORD
  echo "mysql-server-5.7 mysql-server/root_password password root" | sudo debconf-set-selections
  echo "mysql-server-5.7 mysql-server/root_password_again password root" | sudo debconf-set-selections
  apt -y install mysql-server-5.7 mysql-client >> $LOGFILE 2>&1

  mysql -u root -proot -e "use mysql; UPDATE user SET authentication_string=PASSWORD('$MYSQLPASSWORD') WHERE User='root'; flush privileges;" >> $LOGFILE 2>&1

  # checkerror $?

  # install php
  sudo apt -y install php libapache2-mod-php php-mysql php-cli php-mbstring php-curl php7.2-xml
  rm -rf /etc/apache2/mods-enabled/dir.conf
  sudo cp ./config/dir.conf /etc/apache2/mods-enabled/dir.conf

  # configure apache with the changes
  sudo systemctl restart apache2

  mysql -u root -proot -e "use mysql; UPDATE user SET authentication_string=PASSWORD('$MYSQLPASSWORD') WHERE User='root'; flush privileges;" >> $LOGFILE 2>&1

  mysql -u "root" "-p$MYSQLPASSWORD" <<MYSQL_SCRIPT
CREATE DATABASE restapi;
CREATE USER '$1'@'localhost' IDENTIFIED BY '$PASS';
GRANT ALL PRIVILEGES ON $1.* TO '$1'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT


  # configure .env file
  sed -e "s/\${db_name}/restapi/" -e "s/\${db_user}/root/" -e "s/\${db_passwd}/$MYSQLPASSWORD/" /var/www/api.$hostname/.env.example |tee /var/www/api.$hostname/.env

  # composer install
  curl -sS https://getcomposer.org/installer -o composer-setup.php
  php -r "if (hash_file('SHA384', 'composer-setup.php') === '544e09ee996cdf60ece3804abc52599c22b1f40f4323403c44d44fdfdd586475ca9813a858088ffbc1f233e9b180f061') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
  sudo php composer-setup.php --install-dir=/usr/local/bin --filename=composer

  cd /var/www/api.$hostname
  composer install
  php artisan migrate
  php artisan db:seed

fi
