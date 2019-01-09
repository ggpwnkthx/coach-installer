#!/bin/bash
# Install firmware burning tools
sudo apt-get -y install gcc make dkms *-headers-$(uname -r)
cd /tmp
#wget http://www.mellanox.com/downloads/MFT/mft-4.5.0-31-x86_64-deb.tgz
#tar -xvzf mft-4.5.0-31-x86_64-deb.tgz
#cd mft-4.5.0-31-x86_64-deb
wget http://www.mellanox.com/downloads/MFT/mft-4.11.0-103-x86_64-deb.tgz
tar mft-4.11.0-103-x86_64-deb.tgz
cd mft-4.11.0-103-x86_64-deb.tgz
sudo ./install.sh
# Get firmware source
cd /tmp
wget http://www.mellanox.com/downloads/firmware/fw-ConnectX2-rel-2_9_1200.tgz
tar -xvzf fw-ConnectX2-rel-2_9_1200.tgz
# Compile then burn firmware
sudo mst start
DEVICE=$(sudo mst status | grep -m 1 /dev/mst/ | awk '{print $1}')
MODEL=$(sudo flint -d $DEVICE dc | grep "Name" | awk '{print $3}')
sudo flint -d $DEVICE dc > /tmp/ConnectX2-rel-2_9_1200/$MODEL.ini
sudo mlxburn -fw /tmp/ConnectX2-rel-2_9_1200/fw-ConnectX2-rel.mlx -conf /tmp/ConnectX2-rel-2_9_1200/$MODEL.ini -wrimage $MODEL.bin
sudo flint -d $DEVICE -i $MODEL.bin -y b
# Get and install FlexBoot rom
wget http://www.mellanox.com/downloads/Drivers/PXE/FlexBoot-3.4.306_VPI.tar
tar -xvf FlexBoot-3.4.306_VPI.tar
sudo flint -d $DEVICE brom FlexBoot-3.4.306_VPI_26428.mrom
