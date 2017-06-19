#!/bin/bash

wget https://s3-us-west-2.amazonaws.com/core-releases/8314/8532/5573/concrete5-8.1.0.zip
if [ -z "$(command -v unzip)" ]
then
  sudo apt-get -y install unzip
fi
unzip concrete5-*
sudo mv concrete5-*/* /mnt/ceph/fs/containers/provisioner/www/
sudo chmod 777 /mnt/ceph/fs/containers/provisioner/www/packages
sudo chmod 777 /mnt/ceph/fs/containers/provisioner/www/application/config
sudo chmod 777 /mnt/ceph/fs/containers/provisioner/www/application/files
sudo sed -i 's/Install concrete5/Install COACH/g' /mnt/ceph/fs/containers/provisioner/www/concrete/views/frontend/install.php
sudo sed -i "s/<?php echo t('Site') ?>/<?php echo t('Cluster') ?>/g" /mnt/ceph/fs/containers/provisioner/www/concrete/views/frontend/install.php
sudo sed -i "s/pkgHandle == 'elemental_full'/pkgHandle == 'elemental_blank'/g" /mnt/ceph/fs/containers/provisioner/www/concrete/views/frontend/install.php
sudo sed -i "s/'DB_SERVER', \['required' => 'required'\]/'DB_SERVER', '127.0.0.1',  \['required' => 'required'\]/g" /mnt/ceph/fs/containers/provisioner/www/concrete/views/frontend/install.php
sudo sed -i "s/'DB_USERNAME'/'DB_USERNAME', 'root'/g" /mnt/ceph/fs/containers/provisioner/www/concrete/views/frontend/install.php
sudo sed -i "s/'DB_DATABASE'/'DB_DATABASE', 'db'/g" /mnt/ceph/fs/containers/provisioner/www/concrete/views/frontend/install.php
sudo sed -i "s/'Edit Your Site'/'Start'/g" /mnt/ceph/fs/containers/provisioner/www/concrete/views/frontend/install.php
sudo sed -i "s/'concrete.misc.login_redirect', 'DESKTOP'/'concrete.misc.login_redirect', 'HOMEPAGE'/g" /mnt/ceph/fs/containers/provisioner/www/concrete/src/Package/StartingPointPackage.php
