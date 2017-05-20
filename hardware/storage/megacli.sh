#!/bin/bash
if [ -f /opt/MegaRAID/MegaCli/MegaCli64 ]
then
  echo "MegaCLI detected. Ignoring installation."
  if [ -f /bin/MegaCli ]
  then
    echo "MegaCLI alias found in /bin. No changes made."
  else
    sudo ln -s /opt/MegaRAID/MegaCli/MegaCli64 /bin/MegaCli
    echo "MegaCLI alias was not found, so it was added."
  fi
else
  # Install MegaCli and megaclisas-status
  sudo apt-get -y install unzip alien dpkg-dev debhelper build-essential lshw python
  cd /tmp
  wget https://docs.broadcom.com/docs-and-downloads/raid-controllers/raid-controllers-common-files/8-07-14_MegaCLI.zip
  unzip 8-07-14_MegaCLI.zip
  cd Linux
  sudo alien MegaCli*.rpm
  sudo dpkg -i megacli*.deb
  sudo ln -s /opt/MegaRAID/MegaCli/MegaCli64 /bin/MegaCli
fi

if [ -f /opt/MegaRAID/MegaCli/megaclisas-status ]
then
  echo "megaclisas-status detected. Ignoring installation."
  if [ -f /bin/megaclisas-status ]
  then
    echo "megaclisas-status alias found in /bin. No changes made."
  else
    sudo ln -s /opt/MegaRAID/MegaCli/megaclisas-status /bin/megaclisas-status
    echo "megaclisas-status alias was not found, so it was added."
  fi
else
  cd /opt/MegaRAID/MegaCli
  sudo wget http://step.polymtl.ca/~coyote/dist/megaclisas-status/megaclisas-status
  sudo chmod +x megaclisas-status
  sudo ln -s /opt/MegaRAID/MegaCli/megaclisas-status /bin/megaclisas-status
fi
