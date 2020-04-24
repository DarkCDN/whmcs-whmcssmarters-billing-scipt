#!/bin/bash

##################
# Bash script to install IonCube Loader
##################

# Color Reset
Color_Off='\033[0m'       # Text Reset

# Regular Colors
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Cyan='\033[0;36m'         # Cyan

# PHP Modules folder
MODULES=$(php -i | grep extension_dir)

# PHP Version
PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")

# System Architecture
ARCH=$(getconf LONG_BIT)

getFiles() {
  # if machine type is 64-bit, download and extract 64-bit files
  if [ $ARCH == 64 ]; then
    echo -e "${Cyan} \n Downloading.. ${Color_Off}"
    wget http://downloads3.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.tar.gz

    echo -e "${Cyan} Extracting files.. ${Color_Off}"
    tar xvfz ioncube_loaders_lin_x86-64.tar.gz

  # else, get 32-bit files
  else
    echo -e "${Cyan} \n Downloading.. ${Color_Off}"
    wget http://downloads3.ioncube.com/loader_downloads/ioncube_loaders_lin_x86.tar.gz

    echo -e "${Cyan} Extracting files.. ${Color_Off}"
    tar xvfz ioncube_loaders_lin_x86.tar.gz
  fi

  echo -e "${Cyan} \n Copying files to PHP Modules folder.. ${Color_Off}"
  # Copy files to modules folder
  sudo cp "ioncube/ioncube_loader_lin_${PHP_VERSION}.so" $MODULES
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
getFiles
success
restart
