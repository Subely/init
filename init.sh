LOGFILE=install.log

hostname=$1

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
  git clone https://github.com/Subely/subely.com.git /var/www/$hostname.com
  git clone https://github.com/Subely/api.subely.com.git /var/www/api.$hostname.com
  sudo chown -R $USER:$USER /var/www/$hostname.com
  sudo chown -R $USER:$USER /var/www/api.$hostname.com
  sudo chmod -R 755 /var/www
  sudo cp ./config/$hostname.com.conf /etc/apache2/sites-available/$hostname.com.conf
  sudo cp ./config/api.$hostname.com.conf /etc/apache2/sites-available/api.$hostname.com.conf
  sudo a2ensite $hostname.com.conf
  sudo a2ensite api.$hostname.com.conf
  sudo service apache2 restart

  # Install MySQL Server in a Non-Interactive mode. Default root password will be "root"
  // Not required in actual script
  MYSQL_ROOT_PASSWORD=abcd1234

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

  checkerror $?

  # install php
  sudo apt -y install php libapache2-mod-php php-mysql php-cli php-mbstring
  rm -rf /etc/apache2/mods-enabled/dir.conf
  sudo cp ./config/dir.conf

  # configure apache with the changes
  sudo systemctl restart apache2

  # configure .env file
  sed -e "s/\${db_name}/restapi/" -e "s/\${db_user}/root/" -e "s/\${db_passwd}/$MYSQLPASSWORD/" .env.example |tee .env

  # composer install
  curl -sS https://getcomposer.org/installer -o composer-setup.php
  php -r "if (hash_file('SHA384', 'composer-setup.php') === '669656bab3166a7aff8a7506b8cb2d1c292f042046c5a994c43155c0be6190fa0355160742ab2e1c88d40d5be660b410') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
  sudo php composer-setup.php --install-dir=/usr/local/bin --filename=composer

  composer install
  php artisan migrate
  php artisan db:seed

fi
