#!/bin/bash

apt update && apt upgrade -y
apt install nginx php-fpm php-mysql php-dom php-simplexml php-curl php-intl php-zip php-xml php-gd php-imagick php-cli php-dev php-imap php-soap php-mbstring unzip -y
systemctl start nginx
systemctl enable nginx

# Download and prepare PrestaShop
cd /var/www/html
wget https://download.prestashop.com/download/releases/prestashop_1.7.8.0.zip
unzip prestashop_1.7.8.0.zip
rm prestashop_1.7.8.0.zip
mv prestashop/* .
rm -rf prestashop
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html