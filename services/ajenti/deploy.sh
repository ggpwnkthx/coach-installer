#!/bin/bash

if [ -z "$(command -v curl)" ]
then
  apt-get -y install curl
fi

curl https://raw.githubusercontent.com/ajenti/ajenti/master/scripts/install.sh | bash -s -

systemctl stop ajenti.service

if [ -z "$(cat /etc/ajenti/config.yml | grep 'restricted_user: $(whoami)')" ]
then
  echo "restricted_user: $(whoami)" | sudo tee --append /etc/ajenti/config.yml
fi

pip uninstall ajenti.plugin.notepad
pip install ajenti.plugin.network ajenti.plugin.datetime ajenti.plugin.power ajenti.plugin.traffic

systemctl start ajenti.service
