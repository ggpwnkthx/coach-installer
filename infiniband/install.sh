#!/bin/sh
# Add IB modules to /etc/modules and start them
mods=(mlx4_core mlx4_ib ib_umad ib_uverbs ib_ipoib)
for i in ${mods[@]}
do
  mod=$(cat /etc/modules | grep $i)
  if [ -z "$mod" ]
  then
    echo $i | sudo tee --append /etc/modules
  fi
  mod=$(lsmod | grep $i)
  if [ -z "$mod" ]
  then
    sudo modprobe $i
  fi
done

# Install IB Subnet Manager
sudo apt-get update
sudo apt-get -y install opensm
sudo update-rc.d -f opensm remove
sudo update-rc.d opensm defaults
sudo update-rc.d opensm enable
sudo service opensm restart
