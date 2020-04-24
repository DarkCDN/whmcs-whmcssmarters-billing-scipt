#!/bin/bash

###################################################################
#         Author: Daily Updates
#    Description: Installs WHMCS and Wordpress IPTV Billing Site.
#            Run: bash wordpressiptv.sh
#          Notes: In case of any errors just re-run the script.
#                 Nothing will be re-installed except for the packages with errors.
###################################################################

# Color Reset
Color_Off='\033[0m'       # Reset

# Regular Colors
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow
Blue='\033[0;34m'         # Blue
Purple='\033[0;35m'       # Purple
Cyan='\033[0;36m'         # Cyan

# GENERATE PASSOWRDS
# sudo apt -qy install openssl # openssl used for generating a truly random password
PASS_MYSQL_ROOT=`openssl rand -base64 12 | tr -d "=+/" | cut -c1-16` # this you need to save 
PASS_PHPMYADMIN_APP=`openssl rand -base64 12 | tr -d "=+/" | cut -c1-16` # can be random, won't be used again
PASS_PHPMYADMIN_ROOT="${PASS_MYSQL_ROOT}" # Your MySQL root pass
USER_WORDPRESS=`openssl rand -base64 12 | tr -d "=+/" | cut -c1-16` # can be random, won't be used again
PASS_WORDPRESS=`openssl rand -base64 12 | tr -d "=+/" | cut -c1-16` # can be random, won't be used again
USER_WHMCS=`openssl rand -base64 12 | tr -d "=+/" | cut -c1-16` # can be random, won't be used again
PASS_WHMCS=`openssl rand -base64 12 | tr -d "=+/" | cut -c1-16` # can be random, won't be used again

# Get IP Address
default_iface=$(awk '$2 == 00000000 { print $1 }' /proc/net/route)
ip=$(ip addr show dev "$default_iface" | awk '$1 == "inet" { sub("/.*", "", $2); print $2 }')

update() {
	# Update system repos
	echo -e "\n ${Cyan} Updating package repositories.. ${Color_Off}"
	sudo apt -qq update 
}

installApache() {
	# Apache
	echo -e "\n ${Cyan} Installing Apache.. ${Color_Off}"
	sudo apt -qy install apache2 apache2-doc libexpat1 ssl-cert unzip
	# check Apache configuration: apachectl configtest
}

installLetsEncryptCertbot() {
  # Let's Encrypt SSL 
  echo -e "\n ${Cyan} Installing Let's Encrypt SSL.. ${Color_Off}"

  sudo apt update # update repo sources
  sudo apt install -y software-properties-common # required in order to add a repo
  sudo add-apt-repository ppa:certbot/certbot -y # add Certbot repo
  sudo apt update # update repo sources
  sudo apt install -y python-certbot-apache # install Certbot
}


installPHP() {
	# PHP and Modules
	echo -e "\n ${Cyan} Installing PHP and common Modules.. ${Color_Off}"

	# PHP5 on Ubuntu 14.04 LTS
	# apt install php5 libapache2-mod-php5 php5-cli php5-common php5-curl php5-dev php5-gd php5-intl php5-mcrypt php5-mysql php5-recode php5-xml php5-pspell php5-ps php5-imagick php-pear php-gettext -y

	# PHP5 on Ubuntu 17.04 Zesty
	# Add repository and update local cache of available packages
	sudo add-apt-repository ppa:ondrej/php -y
	sudo apt update
	apt install php5.6 libapache2-mod-php5.6 php5.6-cli php5.6-common php-curl php5.6-curl php5.6-dev php5.6-gd php5.6-intl php5.6-mcrypt php5.6-mbstring php5.6-mysql php5.6-recode php5.6-xml php5.6-pspell php5.6-ps php5.6-imagick php-pear php-gettext -y

	# PHP7 (latest)
	#sudo apt -qy install php php-common libapache2-mod-php php-curl php-dev php-gd php-gettext php-imagick php-intl php-mbstring php-mysql php-pear php-pspell php-recode php-xml php-zip
}

installMySQL() {
	# MySQL
	echo -e "\n ${Cyan} Installing MySQL.. ${Color_Off}"
	
	# set password with `debconf-set-selections` so you don't have to enter it in prompt and the script continues
	sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password ${PASS_MYSQL_ROOT}" # new password for the MySQL root user
	sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password ${PASS_MYSQL_ROOT}" # repeat password for the MySQL root user
	
	# DEBIAN_FRONTEND=noninteractive # by setting this to non-interactive, no questions will be asked
	DEBIAN_FRONTEND=noninteractive sudo apt -qy install mysql-server mysql-client
}

secureMySQL() {
	# secure MySQL install
	echo -e "\n ${Cyan} Securing MySQL.. ${Color_Off}"
	
	mysql --user=root --password=${PASS_MYSQL_ROOT} << EOFMYSQLSECURE
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.db WHERE Db='test' OR Db='test_%';
FLUSH PRIVILEGES;
EOFMYSQLSECURE

# NOTE: Skipped validate_password because it'll cause issues with the generated password in this script
}

installPHPMyAdmin() {
	# PHPMyAdmin
	echo -e "\n ${Cyan} Installing PHPMyAdmin.. ${Color_Off}"
	
	# set answers with `debconf-set-selections` so you don't have to enter it in prompt and the script continues
	sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" # Select Web Server
	sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/dbconfig-install boolean true" # Configure database for phpmyadmin with dbconfig-common
	sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/app-pass password ${PASS_PHPMYADMIN_APP}" # Set MySQL application password for phpmyadmin
	sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/app-password-confirm password ${PASS_PHPMYADMIN_APP}" # Confirm application password
	sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/admin-pass password ${PASS_MYSQL_ROOT}" # MySQL Root Password
	sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/internal/skip-preseed boolean true"

	DEBIAN_FRONTEND=noninteractive sudo apt -qy install phpmyadmin
}


enableMods() {
	# Enable mod_rewrite, required for WordPress permalinks and .htaccess files
	echo -e "\n ${Cyan} Enabling Modules.. ${Color_Off}"

	sudo a2enmod rewrite
	# php5enmod mcrypt # PHP5 on Ubuntu 14.04 LTS
	# phpenmod -v 5.6 mcrypt mbstring # PHP5 on Ubuntu 17.04
	sudo phpenmod mbstring # PHP7
}

setPermissions() {
	# Permissions
	echo -e "\n ${Cyan} Setting Ownership for /var/www.. ${Color_Off}"
	sudo chown -R www-data:www-data /var/www
}

restartApache() {
	# Restart Apache
	echo -e "\n ${Cyan} Restarting Apache.. ${Color_Off}"
	sudo service apache2 restart
}

installIPTV() {
# If /root/.my.cnf exists then it won't ask for root password
if [ -f /root/.my.cnf ]; then
	echo "Create Wordpress database."
	echo "Please enter the NAME of the new MySQL database! ${USER_WORDPRESS}"
	read dbname
	echo "Please enter the MySQL database CHARACTER SET! (example: latin1, utf8, ...)"
	echo "Enter utf8 if you don't know what you are doing"
	read charset
	echo "Creating new MySQL database..."
	mysql -e "CREATE DATABASE ${dbname} /*\!40100 DEFAULT CHARACTER SET ${charset} */;"
	echo "Database successfully created!"
	echo "Showing existing databases..."
	mysql -e "show databases;"
	echo ""
	echo "Please enter the NAME of the new MySQL database user! ${USER_WORDPRESS}"
	read username
	echo "Please enter the PASSWORD for the new MySQL database user! ${PASS_WORDPRESS}"
	echo "Note: password will be hidden when typing"
	read -e userpass
	echo "Creating new user..."
	mysql -e "CREATE USER ${username}@localhost IDENTIFIED BY '${userpass}';"
	echo "User successfully created!"
	echo ""
	echo "Granting ALL privileges on ${dbname} to ${username}!"
	mysql -e "GRANT ALL PRIVILEGES ON ${dbname}.* TO '${username}'@'localhost';"
	mysql -e "FLUSH PRIVILEGES;"
	echo "You're good now :)"
	
# If /root/.my.cnf doesn't exist then it'll ask for root password	
else
	echo "Create Wordpress database."
	echo "Please enter root user MySQL password! ${PASS_MYSQL_ROOT}"
	echo "Note: password will be hidden when typing"
	read -e rootpasswd
	echo "Please enter the NAME of the new MySQL database! ${USER_WORDPRESS}"
	read dbname
	echo "Please enter the MySQL database CHARACTER SET! (example: latin1, utf8, ...)"
	echo "Enter utf8 if you don't know what you are doing"
	read charset
	echo "Creating new MySQL database..."
	mysql -uroot -p${rootpasswd} -e "CREATE DATABASE ${dbname} /*\!40100 DEFAULT CHARACTER SET ${charset} */;"
	echo "Database successfully created!"
	echo "Showing existing databases..."
	mysql -uroot -p${rootpasswd} -e "show databases;"
	echo ""
	echo "Please enter the NAME of the new MySQL database user! ${USER_WORDPRESS}"
	read username
	echo "Please enter the PASSWORD for the new MySQL database user! ${PASS_WORDPRESS}"
	echo "Note: password will be hidden when typing"
	read -e userpass
	echo "Creating new user..."
	mysql -uroot -p${rootpasswd} -e "CREATE USER ${username}@localhost IDENTIFIED BY '${userpass}';"
	echo "User successfully created!"
	echo ""
	echo "Granting ALL privileges on ${dbname} to ${username}!"
	mysql -uroot -p${rootpasswd} -e "GRANT ALL PRIVILEGES ON ${dbname}.* TO '${username}'@'localhost';"
	mysql -uroot -p${rootpasswd} -e "FLUSH PRIVILEGES;"
	echo "You're good now :)"
fi

	# install wordpress and iptv billing
    clear
    echo "============================================"
    echo "WordPress Install Script root password ${PASS_MYSQL_ROOT}"
    echo "============================================"
#	echo "Create a Database, User, Password and enter them in the next prompts"
    echo "TYPE YOUR AUTOCREATED DATABASE NAME ${USER_WORDPRESS}: "
    read -e dbname
    echo "TYPE YOUR AUTOCREATED DATABASE USER ${USER_WORDPRESS}: "
    read -e dbuser
    echo "TYPE YOUR AUTOCREATED DATABASE PASSWORD ${PASS_WORDPRESS}: "
    read -e dbpass
    echo "Enter your ip address ($ip) or domain name:(Example:https://yoursite)"
    read -e wpurl
    echo "Enter your site name:(Example:Best Iptv)"
    read -e wpblogname
    echo "Enter your description:(Example:The Best Streams All The Time)"
    read -e wpblogdescription
    echo "run install? (y/n)"
    read -e run
    if [ "$run" == n ] ; then
    exit
    else
    echo "============================================"
    echo "A robot is now installing WordPress for you."
    echo "============================================"
    #download wordpress
    cd /var/www/html && wget https://raw.githubusercontent.com/circulosmeos/gdown.pl/master/gdown.pl
	cd /var/www/html && chmod +x gdown.pl 
	cd /var/www/html && ./gdown.pl https://drive.google.com/file/d/1_I13uDK-pWMCZrGi7U-a8grL77czAfBr/ install.zip
    #unzip wordpress
    cd /var/www/html && unzip install.zip
	#create wp config
    cp wp-config-sample.php wp-config.php
    #set database details with perl find and replace 
	wget https://raw.githubusercontent.com/ProTechEx/whmcs-whmcssmarters-billing-scipt/master/databasewp.sql -O /var/www/html/databasewp.sql
	sed -i "s|https://yoursite|$wpurl|g" /var/www/html/databasewp.sql
	sed -i "s|blognamehere|$wpblogname|g" /var/www/html/databasewp.sql
	sed -i "s|blogdescriptionhere|$wpblogdescription|g" /var/www/html/databasewp.sql
	mysql -uroot -p${PASS_MYSQL_ROOT} $dbname< /var/www/html/databasewp.sql
    perl -pi -e "s/database_name_here/$dbname/g" /var/www/html/wp-config.php
    perl -pi -e "s/username_here/$dbuser/g" /var/www/html/wp-config.php
    perl -pi -e "s/password_here/$dbpass/g" /var/www/html/wp-config.php

    #set WP salts
    perl -i -pe'
      BEGIN {
        @chars = ("a" .. "z", "A" .. "Z", 0 .. 9);
        push @chars, split //, "!@#$%^&*()-_ []{}<>~\`+=,.;:/?|";
        sub salt { join "", map $chars[ rand @chars ], 1 .. 64 }
      }
      s/put your unique phrase here/salt()/ge
    ' wp-config.php

    #create uploads folder and set permissions
    cd /var/www/html && mkdir /var/www/html/wp-content/uploads
    chmod 775 /var/www/html/wp-content/uploads
	chmod 777 /var/www/html/billing/configuration.php
	chmod 777 /var/www/html/billing/attachments/
	chmod 777 /var/www/html/billing/downloads/
	chmod 777 /var/www/html/billing/templates_c/
	rm -r /var/www/html/billing/install/ 
    echo "========================="
    echo "Installation is complete."
    echo "========================="
fi

# If /root/.my.cnf exists then it won't ask for root password
if [ -f /root/.my.cnf ]; then
	echo "Create WHMCS database."
	echo "Please enter the NAME of the new MySQL database! ${USER_WHMCS}"
	read dbname
	echo "Please enter the MySQL database CHARACTER SET! (example: latin1, utf8, ...)"
	echo "Enter utf8 if you don't know what you are doing"
	read charset
	echo "Creating new MySQL database..."
	mysql -e "CREATE DATABASE ${dbname} /*\!40100 DEFAULT CHARACTER SET ${charset} */;"
	echo "Database successfully created!"
	echo "Showing existing databases..."
	mysql -e "show databases;"
	echo ""
	echo "Please enter the NAME of the new MySQL database user! ${USER_WHMCS}"
	read username
	echo "Please enter the PASSWORD for the new MySQL database user! ${PASS_WHMCS}"
	echo "Note: password will be hidden when typing"
	read -e userpass
	echo "Creating new user..."
	mysql -e "CREATE USER ${username}@localhost IDENTIFIED BY '${userpass}';"
	echo "User successfully created!"
	echo ""
	echo "Granting ALL privileges on ${dbname} to ${username}!"
	mysql -e "GRANT ALL PRIVILEGES ON ${dbname}.* TO '${username}'@'localhost';"
	mysql -e "FLUSH PRIVILEGES;"
	echo "You're good now :)"
	
# If /root/.my.cnf doesn't exist then it'll ask for root password	
else
	echo "Create WHMCS database."
	echo "Please enter root user MySQL password! ${PASS_MYSQL_ROOT}"
	echo "Note: password will be hidden when typing"
	read -e rootpasswd
	echo "Please enter the NAME of the new MySQL database! ${USER_WHMCS}"
	read dbname
	echo "Please enter the MySQL database CHARACTER SET! (example: latin1, utf8, ...)"
	echo "Enter utf8 if you don't know what you are doing"
	read charset
	echo "Creating new MySQL database..."
	mysql -uroot -p${rootpasswd} -e "CREATE DATABASE ${dbname} /*\!40100 DEFAULT CHARACTER SET ${charset} */;"
	echo "Database successfully created!"
	echo "Showing existing databases..."
	mysql -uroot -p${rootpasswd} -e "show databases;"
	echo ""
	echo "Please enter the NAME of the new MySQL database user! ${USER_WHMCS}"
	read username
	echo "Please enter the PASSWORD for the new MySQL database user! ${PASS_WHMCS}"
	echo "Note: password will be hidden when typing"
	read -e userpass
	echo "Creating new user..."
	mysql -uroot -p${rootpasswd} -e "CREATE USER ${username}@localhost IDENTIFIED BY '${userpass}';"
	echo "User successfully created!"
	echo ""
	echo "Granting ALL privileges on ${dbname} to ${username}!"
	mysql -uroot -p${rootpasswd} -e "GRANT ALL PRIVILEGES ON ${dbname}.* TO '${username}'@'localhost';"
	mysql -uroot -p${rootpasswd} -e "FLUSH PRIVILEGES;"
	echo "You're good now :)"
fi

	# install wordpress and iptv billing
    clear
    echo "============================================"
    echo "Billing Install Script root password ${PASS_MYSQL_ROOT}"
    echo "============================================"
    echo "TYPE YOUR AUTOCREATED DATABASE NAME ${USER_WHMCS}:"
    read -e dbname2
    echo "TYPE YOUR AUTOCREATED DATABASE USER ${USER_WHMCS}:"
    read -e dbuser2
    echo "TYPE YOUR AUTOCREATED DATABASE PASSWORD ${PASS_WHMCS}:"
    read -e dbpass2
    echo "Enter your XCUI domain and port number:(Example:http://domain:port)"
    read -e xcuidomain
    echo "Enter your XCUI ip and port number:(Example:ip:port)"
    read -e xcuiip
    echo "Enter your XCUI database user"
    read -e xcuiserveruser
    echo "Enter your admin first name:(Example:John)"
    read -e whmcsfirstname
    echo "Enter your admin last name:(Example:Doe)"
    read -e whmcslastname
    echo "Enter your admin email:(Example:admin@domain.com)"
    read -e whmcsemail
    echo "Enter your Company Name:(Example:Best IPTV)"
    read -e whmcscompany
    echo "Enter your ip address ($ip) or domain name:(Example:http://yoursite)"
    read -e whmcsdomain
    echo "Enter random characters for credit card hash:(Example:dkdfijidjsfidjsoifjsoa)"
    read -e cchash
    echo "run install? (y/n)"
    read -e run
    if [ "$run" == n ] ; then
    exit
    else
    echo "============================================"
    echo "A robot is now installing billing for you."
    echo "============================================"
    #set database details with perl find and replace 
	wget https://raw.githubusercontent.com/ProTechEx/whmcs-whmcssmarters-billing-scipt/master/whmcsdb.sql -O /var/www/html/whmcsdb.sql
	sed -i "s|http://domain:port|$xcuidomain|g" /var/www/html/whmcsdb.sql
	sed -i "s|ip:port|$xcuiip|g" /var/www/html/whmcsdb.sql
	sed -i "s|xtreamcodesdbuser|$xcuiserveruser|g" /var/www/html/whmcsdb.sql
	sed -i "s|yourfirstnamehere|$whmcsfirstname|g" /var/www/html/whmcsdb.sql
	sed -i "s|yourlastnamehere|$whmcslastname|g" /var/www/html/whmcsdb.sql
	sed -i "s|youremailhere|$whmcsemail|g" /var/www/html/whmcsdb.sql
	sed -i "s|http://www.yourdomain.com|$whmcsdomain|g" /var/www/html/whmcsdb.sql
	sed -i "s|changeme@changeme.com|$whmcsemail|g" /var/www/html/whmcsdb.sql
	sed -i "s|Company Name|$whmcscompany|g" /var/www/html/whmcsdb.sql
    mysql -u${USER_WHMCS} -p${PASS_WHMCS} ${USER_WHMCS}< /var/www/html/whmcsdb.sql
    perl -pi -e "s/database_name_here/$dbname2/g" /var/www/html/billing/configuration.php
    perl -pi -e "s/username_here/$dbuser2/g" /var/www/html/billing/configuration.php
    perl -pi -e "s/password_here/$dbpass2/g" /var/www/html/billing/configuration.php
    perl -pi -e "s/''/'$cchash'/g" /var/www/html/billing/configuration.php

    echo "========================="
    echo "Installation is complete."
    echo "========================="
fi
}

getFiles() {
  echo -e "${Cyan} \n Downloading IONCUBE Files.. ${Color_Off}"
  # Copy files to modules folder
  wget https://raw.githubusercontent.com/ProTechEx/whmcs-whmcssmarters-billing-scipt/master/ioncube.sh -O /root/ioncube.sh
  chmod +x /root/ioncube.sh
  sed -i 's/\r//' /root/ioncube.sh
  bash /root/ioncube.sh
  echo -e "${Cyan} \n Copying files to ini files folder.. ${Color_Off}"
  # Copy files to modules folder
  wget https://raw.githubusercontent.com/ProTechEx/whmcs-whmcssmarters-billing-scipt/master/00-ioncube.ini -O /var/www/html/00-ioncube.ini 
  sudo cp "/var/www/html/00-ioncube.ini" /etc/php/5.6/apache2/conf.d
  echo "Cleaning..."
  #remove zip file
  rm /var/www/html/gdown.cookie.temp
  rm /var/www/html/gdown.pl
  rm /var/www/html/install.zip
  rm /var/www/html/wordpress.sh
  #remove bash script
  rm /root/install.sh
  rm /var/www/html/00-ioncube.ini
  rm /var/www/html/ioncube_loaders_lin_x86-64.tar.gz
  rm /var/www/html/ioncube_loaders_lin_x86.tar.gz
  rm -r /var/www/html/ioncube
  rm /var/www/html/databasewp.sql
  rm /var/www/html/databasewhmcs.sql
  rm /var/www/html/whmcsdb.sql
  rm /var/www/html/index.html
  rm /root/ioncube.sh
}

success() {
  echo -e "${Green} \n IonCube has been installed. Restarting PHP and Apache.. ${Color_Off}"
}

restart() {
  service apache2 restart
  # if using Nginx
  # service php5-fpm restart
}

# RUN
update
installApache
installLetsEncryptCertbot
installPHP
installMySQL
secureMySQL
installPHPMyAdmin
enableMods
setPermissions
restartApache
installIPTV
getFiles
success
restart

echo "<?php phpinfo(); ?>" > /var/www/html/info.php
echo ""
echo "You can access http://${ip}/info.php to see more informations about PHP"
echo "You can start your Wordpress install here http://${ip}/ to see start setting up your site"
echo "You can access phpmyadmin install here http://${ip}/phpmyadmin and use your mysql generated password ${PASS_MYSQL_ROOT}"
echo -e "\n${Green} SUCCESS! MySQL root password is: ${PASS_MYSQL_ROOT} ${Color_Off}"
echo -e "\n${Green} SUCCESS! wordress database info User:$dbuser Pass:$dbpass Database:$dbname ${Color_Off}"
echo -e "\n${Green} SUCCESS! WHMCS database info User:$dbuser2 Pass:$dbpass2 Database:$dbname2 ${Color_Off}"
