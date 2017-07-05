#!/bin/bash

if [ -z "$(command -v curl)" ]
then
  apt-get -y install curl
fi

curl https://raw.githubusercontent.com/ajenti/ajenti/master/scripts/install.sh | bash -s -

if [ -z "$(cat /etc/ajenti/config.yml | grep 'restricted_user: $(whoami)')" ]
then
  echo "restricted_user: $(whoami)" | sudo tee --append /etc/ajenti/config.yml
fi

systemctl restart ajenti.service
