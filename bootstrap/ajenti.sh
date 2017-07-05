#!/bin/bash

apt-get -y install build-essential python-pip python-dev python-lxml libffi-dev libssl-dev libjpeg-dev libpng-dev uuid-dev python-dbus
pip install 'setuptools>=0.6rc11' 'pip>=6' wheel
pip install ajenti-panel ajenti.plugin.dashboard ajenti.plugin.settings ajenti.plugin.plugins ajenti.plugin.terminal

if [ -z "$(cat /etc/ajenti/config.yml | grep 'restricted_user: $(whoami)')" ]
then
  echo "restricted_user: $(whoami)" | sudo tee --append /etc/ajenti/config.yml
fi

