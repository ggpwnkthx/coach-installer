#!/bin/bash

if [ -z "$(command -v curl)" ]
then
  apt-get -y install curl
fi

curl https://raw.githubusercontent.com/ajenti/ajenti/master/scripts/install.sh | bash -s -

systemctl stop ajenti.service

if [ -z "$(cat /etc/ajenti/config.yml | grep 'restricted_user: $(whoami)')" ]
then
  echo "restricted_user: $(who am i | awk '{print $1}')" | sudo tee --append /etc/ajenti/config.yml
fi

sed -i "s/{{customization.plugins.core.title || 'Ajenti'}}/{{customization.plugins.core.title || 'COACH'}}"/g /usr/local/lib/python2.7/dist-packages/ajenti_plugin_core/content/pages/index.html

cp -r services/ajenti/coach /usr/local/lib/python2.7/dist-packages/ajenti_plugin_coach
rm -r /usr/local/lib/python2.7/dist-packages/ajenti_plugin_core/resources/vendor/fontawesome
cwd=$(pwd)
cd /usr/local/lib/python2.7/dist-packages/ajenti_plugin_core/resources/vendor
git clone https://github.com/FortAwesome/Font-Awesome.git
cd $cwd
mv /usr/local/lib/python2.7/dist-packages/ajenti_plugin_core/resources/vendor/Font-Awesome /usr/local/lib/python2.7/dist-packages/ajenti_plugin_core/resources/vendor/fontawesome

systemctl start ajenti.service
