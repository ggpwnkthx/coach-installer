# Add IB modules to /etc/modules
mod=$(cat /etc/modules | grep "mlx4_core")
if [ -z $mod ]
then
  echo "mlx4_core" >> /etc/modules
fi
mod=$(cat /etc/modules | grep "mlx4_ib")
if [ -z $mod ]
then
  echo "mlx4_ib" >> /etc/modules
fi
mod=$(cat /etc/modules | grep "ib_umad")
if [ -z $mod ]
then
  echo "ib_umad" >> /etc/modules
fi
mod=$(cat /etc/modules | grep "ib_uverbs")
if [ -z $mod ]
then
  echo "ib_uverbs" >> /etc/modules
fi
mod=$(cat /etc/modules | grep "ib_ipoib")
if [ -z $mod ]
then
  echo "ib_ipoib" >> /etc/modules
fi

# Start modules if they are not already
mod=$(lsmod | grep "mlx4_core")
if [ -z $mod ]
then
  modprobe mlx4_core
fi
mod=$(lsmod | grep "mlx4_ib")
if [ -z $mod ]
then
  modprobe mlx4_ib
fi
mod=$(lsmod | grep "ib_umad")
if [ -z $mod ]
then
  modprobe ib_umad
fi
mod=$(lsmod | grep "mlx4ib_uverbs_core")
if [ -z $mod ]
then
  modprobe ib_uverbs
fi
mod=$(lsmod | grep "ib_ipoib")
if [ -z $mod ]
then
  modprobe ib_ipoib
fi

# Install IB Subnet Manager
apt-get update
apt-get -y install opensm
update-rc.d -f opensm remove
update-rc.d opensm defaults
update-rc.d opensm enable
service opensm restart
