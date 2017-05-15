# Add IB modules to /etc/modules and start them
mods=(mlx4_core mlx4_ib ib_umad ib_uverbs ib_ipoib)
for i in ${mods[@]}
do
  mod=$(cat /etc/modules | grep $i)
  if [ -z $mod ]
  then
    echo $i | sudo tee --append /etc/modules
  fi
  mod=$(lsmod | grep $i)
  if [ -z $mod ]
  then
    modprobe $i
  fi
done

# Install IB Subnet Manager
apt-get update
apt-get -y install opensm
update-rc.d -f opensm remove
update-rc.d opensm defaults
update-rc.d opensm enable
service opensm restart
