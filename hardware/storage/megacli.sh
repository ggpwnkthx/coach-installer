#!/bin/bash
# Install MegaCli and megaclisas-status
sudo apt-get -y install unzip alien dpkg-dev debhelper build-essential lshw python
cd /tmp
wget https://docs.broadcom.com/docs-and-downloads/raid-controllers/raid-controllers-common-files/8-07-14_MegaCLI.zip
unzip 8-07-14_MegaCLI.zip
cd Linux
sudo alien MegaCli*.rpm
sudo dpkg -i megacli*.deb
sudo ln -s /opt/MegaRAID/MegaCli/MegaCli64 /bin/MegaCli
cd /opt/MegaRAID/MegaCli
sudo wget http://step.polymtl.ca/~coyote/dist/megaclisas-status/megaclisas-status
sudo chmod +x megaclisas-status
sudo ln -s /opt/MegaRAID/MegaCli/megaclisas-status /bin/megaclisas-status
