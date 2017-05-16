if [ -z $(sudo ceph osd pool ls | rbd) ]
then
  sudo ceph osd pool create rbd 256
fi
if [ -z $(sudo rbd ls | grep lamp) ]
then
  sudo rbd create rbd/lamp --size 1024
fi

# Apache
sudo apt-get -y install apache2
sudo a2enmod ssl
sudo a2ensite default-ssl.conf 
sudo systemctl restart apache2.service
sudo systemctl enable apache2

# PHP 7.0
sudo apt-get -y install php7.0 libapache2-mod-php7.0 php7.0-mysql php7.0-xml php7.0-gd

#MariaDB
sudo apt install php7.0-mysql mariadb-server mariadb-client
sudo mysql_secure_installation
