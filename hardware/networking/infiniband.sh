#!/bin/bash
# Add IB modules to /etc/modules and start them
mods=(mlx4_core mlx4_ib ib_umad ib_uverbs ib_ipoib)
for i in ${mods[@]}
do
  mod=$(cat /etc/modules | grep $i)
  if [ -z "$mod" ]
  then
    echo $i | tee --append /etc/modules
  fi
  mod=$(lsmod | grep $i)
  if [ -z "$mod" ]
  then
    modprobe $i
  fi
done

# Install IB Subnet Manager
if [ -z "$(command -v opensm)" ]
then
  apt-get update
  apt-get -y install ifenslave-2.6 opensm
  update-rc.d -f opensm remove
  update-rc.d opensm defaults
  update-rc.d opensm enable
  service opensm restart
fi
