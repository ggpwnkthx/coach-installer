#!/bin/bash
am_i_root()
{
  i_am_root=$(whoami | grep "root")
  if [ ! -z "$i_am_root" ]
  then
    echo ""
  else
    echo "This script makes changes to your system. It must be run with root privileges."
    echo ""
    exit
  fi
}
no_root()
{
  i_am_root=$(whoami | grep "root")
  if [ ! -z "$i_am_root" ]
  then
    echo ''
    echo "You can't be root for this part."
    exit
  else
    echo ''
  fi
}
return_to_base()
{
  dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
  cd $dirs
}
restart_script()
{
  return_to_base
  script_name=$(basename $0)
  ./$script_name
  exit
}

# Install Dell OpenManage Server Administrator
install_dell_omsa()
{
  echo 'deb http://linux.dell.com/repo/community/ubuntu trusty openmanage' | sudo tee -a /etc/apt/sources.list.d/linux.dell.com.sources.list
  gpg --keyserver pool.sks-keyservers.net --recv-key 1285491434D8786F ; gpg -a --export 1285491434D8786F | sudo apt-key add -
  # add openjdk-7-jdk repository to meet dependencies
  sudo add-apt-repository ppa:openjdk-r/ppa
  sudo apt-get update
  sudo apt-get -y install srvadmin-all
  sudo apt-get -y install srvadmin-omcommon srvadmin-storage srvadmin-base srvadmin-storageservices srvadmin-deng srvadmin-omacs srvadmin-omilcore srvadmin-storelib srvadmin-ominst srvadmin-smcommon srvadmin-storelib-sysfs srvadmin-isvc srvadmin-rnasoap srvadmin-xmlsup srvadmin-realssd srvadmin-nvme srvadmin-storageservices-snmp srvadmin-storageservices-cli srvadmin-storage-snmp srvadmin-deng-snmp srvadmin-isvc-snmp srvadmin-idrac-snmp srvadmin-storage-cli srvadmin-omacore
  sudo service dsm_om_connsvc start
  sudo update-rc.d dsm_om_connsvc defaults
  sudo service dataeng start

  restart_script
}
ask_dell_omsa()
{
  is_dell=$(service dataeng status | grep "No such file or directory")
  if [ ! -z "$is_dell" ]
  then
    echo ''
    echo 'Vendor has been identified as Dell.'
    read -n1 -p "Would you like to install the Dell Open Manage Server Adminstrator? [y,n]" doit
    case $doit in
      y|Y) echo '' && install_dell_omsa && echo '' ;;
      n|N) echo '' && echo 'Dell OMSA will not be installed.' ;;
      *) ask_dell_omsa ;;
    esac
  else
    echo "Dell OMSA already installed."
  fi
}

# Vendor specific system adminstration software
ask_system_admin()
{
  system_vendor=$(sudo dmidecode | grep "Vendor: " | sed 's/^.*: //')
  case $system_vendor in
    "Dell Inc.") ask_dell_omsa ;;
  esac
}

# Get Infiniband card up-to-date
update_mellanox_firmware()
{
  # Install firmware burning tools
  cd /tmp
  wget http://www.mellanox.com/downloads/MFT/mft-4.5.0-31-x86_64-deb.tgz
  tar -xvzf mft-4.5.0-31-x86_64-deb.tgz
  cd mft-4.5.0-31-x86_64-deb
  sudo ./install.sh
  # Get firmware source
  cd /tmp
  wget http://www.mellanox.com/downloads/firmware/fw-ConnectX2-rel-2_9_1200.tgz
  tar -xvzf fw-ConnectX2-rel-2_9_1200.tgz
  # Compile then burn firmware
  sudo mst start
  DEVICE=$(mst status | grep -m 1 /dev/mst/ | awk '{print $1}')
  MODEL=$(flint -d $DEVICE dc | grep "Name" | awk '{print $3}')
  sudo flint -d $DEVICE dc > /tmp/ConnectX2-rel-2_9_1200/$MODEL.ini
  sudo mlxburn -fw /tmp/ConnectX2-rel-2_9_1200/fw-ConnectX2-rel.mlx -conf /tmp/ConnectX2-rel-2_9_1200/$MODEL.ini -wrimage $MODEL.bin
  sudo flint -d $DEVICE -i $MODEL.bin -y b
  # Get and install FlexBoot rom
  wget http://www.mellanox.com/downloads/Drivers/PXE/FlexBoot-3.4.306_VPI.tar
  tar -xvf FlexBoot-3.4.306_VPI.tar
  sudo flint -d $DEVICE brom FlexBoot-3.4.306_VPI_26428.mrom

  restart_script
}
ask_mellanox_firmware()
{
  read -n1 -p "Update Mellanox adapter firmware using source code? [y,n]" doit
  case $doit in
    y|Y) echo '' && update_mellanox_firmware ;;
    n|N) echo '' && echo 'Mellanox Infiniband drivers will not be installed.' ;;
    *) ask_mellanox_firmware ;;
  esac
}

# Set up IP addresses
set_infiniband_ip()
{
  ip_added=$(sudo cat /etc/network/interfaces | grep ib0)
  if [ -z "$ip_added" ]
  then
    echo "Making sure OpenFabric services are running..."
    sudo service opensm stop
    sudo service openibd stop
    sudo service openibd start
    sudo service openibd restart
    sudo service opensm start

    host_type=$(hostname | grep -o '[^0-9]*')
    host_number=$(hostname | grep -o '[0-9]*')
    case $host_type in
      ceph) ip=$((host_number * 2 - 1)) ;;
      blade) ip=$((host_number * 2 + 15)) ;;
	  *) return ;;
    esac

    x=0
    interfaces=($(ip -o link show | awk -F': ' '{print $2}' | grep ib))
    for i in "${interfaces[@]}"
    do
      ip=$(($ip + $x))
      echo "auto $i" | sudo tee --append /etc/network/interfaces
      echo "iface $i inet static" | sudo tee --append /etc/network/interfaces
      echo "    address 192.168.0.$ip" | sudo tee --append /etc/network/interfaces
      echo "    netmask 255.255.255.0" | sudo tee --append /etc/network/interfaces
      if [ $x = 0 ]
      then
        sudo cp /etc/hosts /etc/hosts.old
        sed -e '/'$HOSTNAME'/s=^[0-9\.]*='"192.168.0.$ip"'=' /etc/hosts.old | sudo tee /etc/hosts
      fi
      x=$(($x + 1))
    done

    echo "Resetting OpenFabric services..."
    sudo service opensm stop
    sudo service openibd stop
    sudo service openibd start
    sudo service openibd restart
    sudo service opensm start
  fi
  restart_script
}
ask_infiniband_ip()
{
  ip_added=$(sudo cat /etc/network/interfaces | grep ib0)
  if [ ! -z "$ip_added" ]
  then
    echo "IP addresses for Infiniband adpaters detected. New IPs were not added."
  else
    read -n1 -p "Set InfiniBand IP addresses? [y,n]" doit
    case $doit in
      y|Y) echo '' && set_infiniband_ip ;;
      n|N) echo '' && echo 'IP addresses for InfiniBand devices were not set.' ;;
      *) ask_infiniband_ip ;;
    esac
  fi
}

# Install Mellanox drivers installed
install_mellanox_drivers()
{
  release=$(lsb_release -si)$(lsb_release -sr)
  cd /tmp
  rm MLNX_OFED_LINUX-*.iso
  wget http://content.mellanox.com/ofed/MLNX_OFED-4.0-1.0.1.0/MLNX_OFED_LINUX-4.0-1.0.1.0-${release,}-x86_64.iso
  mkdir iso
  sudo mount -o loop MLNX_OFED_LINUX-*.iso iso
  sudo apt-get -y install perl
  sudo /tmp/iso/mlnxofedinstall
  sudo umount /tmp/iso
  # Enable Ethernet IPoIB
  #sed -i '/^E_IPOIB_LOAD=/s/=.*/=yes/' /etc/infiniband/openib.conf
  # Fix opensm service
  sudo update-rc.d -f opensm remove
  sudo update-rc.d -f opensmd remove
  sudo sed -i 's/# Default-Start: null/# Default-Start: 2 3 4 5/g' /etc/init.d/opensmd
  sudo mv /etc/init.d/opensmd /etc/init.d/opensm
  sudo update-rc.d opensm defaults
  sudo update-rc.d opensm enable

  return_to_base
  ask_mellanox_firmware

  restart_script
}
use_infiniband=0
ask_mellanox_install()
{
  is_mellanox=$(service openibd status | grep "No such file or directory")
  if [ ! -z "$is_mellanox" ]
  then
    read -n1 -p "Install Mellanox Infiniband drivers? [y,n]" doit
    case $doit in
      y|Y) echo '' && install_mellanox_drivers && use_infiniband=1 ;;
      n|N) echo '' && echo 'Mellanox Infiniband drivers will not be installed.' ;;
      *) ask_mellanox_install ;;
    esac
  else
    echo "Infiniband drivers detected. Ignoring Mellanox installation."
    use_infiniband=1
  fi
}

# Update local hostname resoltion
update_hostnames()
{
  echo "192.168.0.1    ceph01" | sudo tee --append /etc/hosts
  echo "192.168.0.3    ceph02" | sudo tee --append /etc/hosts
  echo "192.168.0.5    ceph03" | sudo tee --append /etc/hosts
  echo "192.168.0.7    ceph04" | sudo tee --append /etc/hosts
  echo "192.168.0.9    ceph05" | sudo tee --append /etc/hosts
  echo "192.168.0.11   ceph06" | sudo tee --append /etc/hosts
  echo "192.168.0.13   ceph07" | sudo tee --append /etc/hosts
  echo "192.168.0.15   ceph08" | sudo tee --append /etc/hosts
  echo "192.168.0.17   blade01" | sudo tee --append /etc/hosts
  echo "192.168.0.19   blade02" | sudo tee --append /etc/hosts
  echo "192.168.0.21   blade03" | sudo tee --append /etc/hosts
  echo "192.168.0.23   blade04" | sudo tee --append /etc/hosts
  echo "192.168.0.25   blade05" | sudo tee --append /etc/hosts
  echo "192.168.0.27   blade06" | sudo tee --append /etc/hosts
  echo "192.168.0.29   blade07" | sudo tee --append /etc/hosts
  echo "192.168.0.31   blade08" | sudo tee --append /etc/hosts
  echo "192.168.0.33   blade09" | sudo tee --append /etc/hosts
  echo "192.168.0.35   blade10" | sudo tee --append /etc/hosts
  echo "192.168.0.37   blade11" | sudo tee --append /etc/hosts
  echo "192.168.0.39   blade12" | sudo tee --append /etc/hosts
  echo "192.168.0.41   blade13" | sudo tee --append /etc/hosts
  echo "192.168.0.43   blade14" | sudo tee --append /etc/hosts
  echo "192.168.0.45   blade15" | sudo tee --append /etc/hosts
  echo "192.168.0.47   blade16" | sudo tee --append /etc/hosts
  echo "#AutoUpdated" | sudo tee --append /etc/hosts

  sudo service opensm stop
  sudo service openibd stop
  sudo service openibd start
  sudo service openibd restart
  sudo service opensm start

  restart_script
}
ask_hostnames()
{
  hosts_added=$(cat /etc/hosts | grep "#AutoUpdated")
  if [ ! -z "$hosts_added" ]
  then
    echo "Preconfigured hostnames detected detected. New hostnames were not added."
  else
    read -n1 -p "Update hostname resolution? [y,n]" doit
    case $doit in
      y|Y) echo '' && update_hostnames ;;
      n|N) echo '' && echo 'Hostnames were not updated.' ;;
      *) ask_hostnames ;;
    esac
  fi
}
# Install networking
ask_networking()
{
  mellanox=$(lspci | grep Mellanox)
  if [ ! -z "$mellanox" ]
  then
    ask_mellanox_install
    if [ $use_infiniband = 1 ]
    then
      ask_infiniband_ip
    fi
  fi
  ask_hostnames
}

# Build out MegaRAID devices
preflight_megaraid()
{
  # Clear foreign states
  sudo MegaCli -CfgForeign -Clear -aALL
}
build_megaraid()
{
  preflight_megaraid
  sudo megaclisas-status | grep Unconfigured | grep "HDD\|SSD" | while read -r line ;
  do
    adapter=$(echo $line | awk '{print $1}' | grep -o '[0-9]\+')
    device=$(echo $line | awk 'NR>1{print $1}' RS=[ FS=] | sed -e 's/N\/A//g')
    sudo MegaCli -CfgLdAdd -r0[$device] -a$adapter
  done
}
use_megaraid=0
ask_megaraid_ceph()
{
  no_it_mode=$(sudo megaclisas-status | grep "PERC H700\|NonJBODCard")
  if [ ! -z "$no_it_mode" ]
  then
    use_megaraid=1
  fi

  if [ $use_megaraid = 1 ]
  then
    if [ "$(megaclisas-status | grep -c Unconfigured)" -ge 1 ]
    then
      echo ''
      echo "Ceph works best with individual disk, but your controller does not support this."
      read -n1 -p "Do you want to prepare your unconfigured disks into individual RAID0 devices? [y,n]" doit
      case $doit in
        y|Y) echo '' && build_megaraid ;;
        n|N) echo '' && echo 'Disk were not prepared.' ;;
        *) ask_megaraid ;;
      esac
    else
      echo "MegaRAID is enabled, but there are no disks to configure."
    fi
  fi
}

# Install MegaCLI for LSI MegaRAID cards
install_megacli()
{
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

  restart_script
}
ask_megacli()
{
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
    read -n1 -p "Install MegaCLI? [y,n]" doit
    case $doit in
      y|Y) echo '' && install_megacli ;;
      n|N) echo '' && echo 'MegaCLI will not be installed.' ;;
      *) ask_megacli ;;
    esac
  fi
}

ask_drives()
{
  megacli=$(lspci | grep MegaRAID)
  if [ ! -z "$megacli" ]
  then
    ask_megacli
  fi
}
preflight_network_local()
{
  return_to_base
  if [ ! -f "changeInterface.awk" ]
  then
    wget https://raw.githubusercontent.com/JoeKuan/Network-Interfaces-Script/master/changeInterface.awk
  fi
  if [ ! -f "readInterfaces.awk" ]
  then
    wget https://raw.githubusercontent.com/JoeKuan/Network-Interfaces-Script/master/readInterfaces.awk
  fi
}
get_network_local()
{
  preflight_network_local
  awk -f readInterfaces.awk /etc/network/interfaces "device=$1"
}
get_network_local_mode()
{
  echo "???"
}
get_network_local_address()
{
  echo $(get_network_local $1 | awk '{print $1}')
}
get_network_local_netmask()
{
  echo $(get_network_local $1 | awk '{print $2}')
}
get_network_local_gateway()
{
  echo $(get_network_local $1 | awk '{print $3}')
}
set_network_local()
{
  if [ -z "$2" ]
  then
    case $(sudo cat /sys/class/net/$1/operstate) in
	  up) sudo ifdown $1 ;;
	  down) sudo ifup $1 ;;
	esac
  else
    preflight_network_local
    sudo cp /etc/network/interfaces /etc/network/interfaces.bak
	if [ -z $(cat /etc/network/interfaces | grep $1) ]
	then
      net_exists="action=add"
    else
	  net_exists=""
	fi
    if [ "$2" == "mode" ]
    then
      awk -f changeInterface.awk /etc/network/interfaces.bak "dev=$1" $net_exists "$2=$3" | sudo tee /etc/network/interfaces
    else
      awk -f changeInterface.awk /etc/network/interfaces.bak "dev=$1" $net_exists "mode=static" "$2=$3" | sudo tee /etc/network/interfaces
    fi
	if [ $(sudo cat /sys/class/net/$1/operstate) == "up" ]
	then
      sudo ifdown $1
      if [ $(ip link | awk "/$1/{getline; print}" | awk '{print $1}' | awk -F "/" '{print $2}') == "infiniband" ]
      then
        sudo service openibd restart
      fi
      sudo ifup $1
	fi
  fi
  sudo service networking restart
  exit
}
ask_network_local_mode()
{
  clear
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "COACH - Cluster Of Arbitrary, Cheap, Hardware"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "$1 - Network Manager || $HOSTNAME"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  fmt="%-8s%-12s\n"
  printf "$fmt" "[D]" "DHCP"
  printf "$fmt" "[S]" "Static"
  printf "$fmt" "[M]" "Manual"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo ''
  read -p "Which mode? " doit
  case $doit in
	d|D) echo '' && set_network_local $1 mode dhcp ;;
	s|S) echo '' && set_network_local $1 mode static ;;
	m|M) echo '' && set_network_local $1 mode manual ;;
	*) ask_network_local_mode $1 ;;
  esac
  network_local_details $1
}
ask_network_local_address()
{
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo ''
  read -p "IP Address: " doit
  set_network_local $1 address $doit
  network_local_details $1
}
ask_network_local_netmask()
{
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo ''
  read -p "Netmask: " doit
  set_network_local $1 netmask $doit
  network_local_details $1
}
ask_network_local_broadcast()
{
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo ''
  read -p "Broadcast: " doit
  set_network_local $1 broadcast $doit
  network_local_details $1
}
ask_network_local_gateway()
{
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo ''
  read -p "Gateway: " doit
  set_network_local $1 gateway $doit
  network_local_details $1
}
add_network_local()
{
  preflight_network_local
  sudo cp /etc/network/interfaces /etc/network/interfaces.bak
  awk -f changeInterface.awk /etc/network/interfaces.bak "device=$1" "action=add" "mode=static" "address=$2" "netmask=$3" "gateway=$4" | sudo tee /etc/network/interfaces
  sudo service networking restart
}
ask_network_local_child()
{
  max=${net_links[0]}
  if [ -z $max ]
  then
    max=0
  fi
  for n in "${net_links[@]}" ; do
    ((n > max)) && max=$n
  done
  child=$[$max +1]
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo ''
  read -p "Address: " address
  read -p "Netmask: " netmask
  read -p "Gateway: " gateway
  add_network_local $1:$child $address $netmask $gateway
}
menu_network_local_child() {
  net_links=($(cat /etc/network/interfaces | grep "iface $1:" | awk '{print $2}' | awk -F ":" '{print $2}'))
  counter=0
  clear
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "COACH - Cluster Of Arbitrary, Cheap, Hardware"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "Network Manager || $HOSTNAME"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  fmt="%-8s%-12s%-18s%-18s%-18s\n"
  printf "$fmt" "" "NAME" "ADDRESS" "NETMASK" "GATEWAY"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  for i in ${net_links[@]}
  do
    printf "$fmt" "[$[$counter +1]]" "$1:$i" "$(get_network_local_address $1:$i)" "$(get_network_local_netmask $1:$i)" "$(get_network_local_gateway $1:$i)"
    counter=$[$counter +1]
  done
  echo ''
  printf "$fmt" "[C]" "Create Child Interface"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  printf "$fmt" "[0]" "BACK"
  echo ''
  read -p "What would you like to do? " doit
  if [ "$doit" == "0" ]
  then
    echo '' && network_local_details $1
  else
    if [ "$doit" == "C" ]
    then
      ask_network_local_child $1 && menu_network_local_child $1
    else
      if [ "$doit" == "c" ]
      then
        ask_network_local_child $1 && menu_network_local_child $1
      else
        network_local_details $1:${net_links[$doit - 1]}
      fi
    fi
  fi
}
network_local_delete() 
{
  sudo cp /etc/network/interfaces /etc/network/interfaces.bak
  awk -f changeInterface.awk /etc/network/interfaces.bak "device=$1" "action=remove" | sudo tee /etc/network/interfaces
  sudo service networking restart
}
ask_network_local_child_delete() {
  read -p "Are you absolutely sure you want to delete this child interface? [y,n]" doit
  case $doit in
    y|Y) echo '' && network_local_delete $1 ;;
    n|N) network_local_details $1 ;;
    *) ask_network_local_child_delete $1 ;;
  esac
}
network_local_details()
{
  net_inet=$(cat /etc/network/interfaces | grep "$1 inet" | awk '{print $4}')
  net_state=$(sudo cat /sys/class/net/$1/operstate)
  clear
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "COACH - Cluster Of Arbitrary, Cheap, Hardware"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "$1 - Network Manager || $HOSTNAME"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  fmt="%-8s%-12s%-18s%-8s%-12s\n"
  printf "$fmt" " " "PROPERTY" "VALUE"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  printf "$fmt" "[M]" "Mode" $net_inet
  if [ "$net_inet" == "static" ]
  then
    printf "$fmt" "[A]" "Address" $(get_network_local_address $1)
    printf "$fmt" "[N]" "Netmask" $(get_network_local_netmask $1)
    printf "$fmt" "[G]" "Gateway" $(get_network_local_gateway $1)
    printf "$fmt" "[B]" "Broadcast" $(ifconfig | awk "/$1/{getline; print}" | awk '{print $3}' | awk -F ":" '{print $2}' | xargs | awk '{print $1}')
  else
    printf "$fmt" " " "Address" $(get_network_local_address $1)
    printf "$fmt" " " "Netmask" $(get_network_local_netmask $1)
    printf "$fmt" " " "Gateway" $(get_network_local_gateway $1)
    printf "$fmt" " " "Broadcast" $(ifconfig | awk "/$1/{getline; print}" | awk '{print $3}' | awk -F ":" '{print $2}' | xargs | awk '{print $1}')
  fi
  if [ ! -z $net_state ]
  then
    printf "$fmt" "[S]" "State" $net_state
    echo ''
    printf "$fmt" "[C]" "Manage Child Interfaces"
  else
    echo ''
	printf "$fmt" "[D]" "Delete Interfaces"
  fi
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo "[0]	BACK"
  echo ''
  read -p "What would you like to do? " doit
  case $doit in
    0) menu_network_local ;;
	m|M) echo '' && ask_network_local_mode $1 && network_local_details $1 ;;
	a|A) echo '' && ask_network_local_address $1 && network_local_details $1 ;;
	n|N) echo '' && ask_network_local_netmask $1 && network_local_details $1 ;;
	b|B) echo '' && ask_network_local_broadcast $1 && network_local_details $1 ;;
	g|G) echo '' && ask_network_local_gateway $1 && network_local_details $1 ;;
	c|C) echo '' && menu_network_local_child $1 ;;
	d|D) echo '' && ask_network_local_child_delete $1 && menu_network_local ;;
	*) network_local_details $1 ;;
  esac
}
menu_network_local()
{
  net_links=($(ip link | grep mtu | awk '{print $2}' | sed 's/://' | grep -v lo))
  counter=0
  clear
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "COACH - Cluster Of Arbitrary, Cheap, Hardware"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "Network Manager || $HOSTNAME"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  fmt="%-8s%-12s%-18s%-8s%-12s\n"
  printf "$fmt" " " "NAME" "ADDRESS" "STATE" "TYPE"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  for i in ${net_links[@]}
  do
    net_state=$(sudo cat /sys/class/net/$i/operstate)
    net_type=$(ip link | awk "/$i/{getline; print}" | awk '{print $1}' | awk -F "/" '{print $2}')
    printf "$fmt" "[$[$counter +1]]" "$i" "$(get_network_local_address $i)" "$net_state" "$net_type"
    counter=$[$counter +1]
  done
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo "[0]	BACK"
  echo ''
  read -p "What would you like to do? " doit
  if [ "$doit" == "0" ]
  then
    echo '' && menu_network
  else
    if [ "$doit" == "C" ]
    then
      menu_network_local
    else
      if [ "$doit" == "c" ]
      then
        menu_network_local
      else
        network_local_details  ${net_links[$doit - 1]}
      fi
    fi
  fi
}

network_cluster_install()
{
  sudo mkdir /mnt/ceph/fs/networking
  sudo mkdir /mnt/ceph/fs/networking/dhcp
  sudo apt-get -y install dnsmasq
  sudo sed -i '/^#dhcp-leasefile/s/^#//' /etc/dnsmasq.conf
  sudo sed -i '/^dhcp-leasefile/s/=.*/=\/mnt\/ceph\/fs\/networking\/dhcp\/leases/' /etc/dnsmasq.conf
  sudo sed -i '/^#conf-file=\etc\dnsmasq.more.conf/s/^#//' /etc/dnsmasq.conf
  sudo sed -i '/^conf-file/s/=.*/=\/mnt\/ceph\/fs\/networking\/dhcp\/cluster.conf/' /etc/dnsmasq.conf
}
ask_network_cluster_install()
{
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo ''
  is_ceph_mon="$(sudo ceph mon dump | grep $HOSTNAME)"
  is_ceph_mds="$(sudo ceph mds stat | grep $HOSTNAME)"
  if [ -z "$is_ceph_mon" ]
  then
    echo "This node must have be an active Ceph Monitor before installing the DHCP role."
    read -n1 -p "Would you like to install it now? [y,n]" doit
    case $doit in
      y|Y) echo '' && install_ceph_mon && ask_network_cluster_install ;;
      n|N) echo '' && echo 'Returning to previous menu.' ;;
      *) ask_network_cluster_install ;;
    esac
  else
    if [ -z "$is_ceph_mds" ]
	then
      echo "This node must have be an active Ceph Metadata Server before installing the DHCP role."
      read -n 1 -s -p "Press any key to return to the previous menu..."
	else
      if [ -f /mnt/ceph/fs ]
      then
        echo network_cluster_install
      else
        echo "You must have CephFS mounted to start the installation process."
        read -n 1 -s -p "Press any key to return to the previous menu..."
      fi
	
	fi
  fi
}
network_cluster_dhcp_interface()
{
  if [ -z $(cat /etc/dnsmasq.conf | grep "interface=$1") ]
  then
    echo "interface=$1" | sudo tee --append /etc/dnsmasq.conf
  else
    sudo sed -i "/interface=$1/d" /etc/dnsmasq.conf
  fi
  sudo service dnsmasq restart
}
menu_network_cluster_dhcp_interface()
{
  net_links=($(ip link | grep mtu | awk '{print $2}' | sed 's/://' | grep -v lo))
  counter=0
  clear
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "COACH - Cluster Of Arbitrary, Cheap, Hardware"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "DHCP - Network Manager || $HOSTNAME"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  fmt="%-8s%-12s%-18s%-8s%-12s\n"
  for i in ${net_links[@]}
  do
	if [ -z $(cat /etc/dnsmasq.conf | grep "interface=$i") ]
	then
	  enabled=""
	else
	  enabled="Enabled"
	fi
    printf "$fmt" "[$[$counter +1]]" "$i" $enabled
    counter=$[$counter +1]
  done
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  printf "$fmt" "[0]" "BACK"
  echo ''
  read -p "What would you like to do? " doit
  if [ "$doit" == "0" ]
  then
    echo '' && menu_network_dhcp
  else
    echo '' && network_cluster_dhcp_interface ${net_links[$doit-1]} && menu_network_cluster_dhcp_interface
  fi
}
network_cluster_dhcp_scope()
{
  echo "dhcp-range=$1,$2,$3h" | sudo tee --append /mnt/ceph/fs/networking/dhcp/cluster.conf
  sudo service dnsmasq restart
}
ask_network_cluster_dhcp_scope()
{
  read -p "Starting IP: " start
  read -p "Ending IP: " end
  read -p "Lease Hours: " lease
  network_cluster_dhcp_scope $start $end $lease
}
menu_network_cluster_dhcp_scope()
{
  scopes=($(cat /mnt/ceph/fs/networking/dhcp/cluster.conf | grep "dhcp-range" | awk '{split($0,a,"="); print a[2]}'))
  counter=0
  clear
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "COACH - Cluster Of Arbitrary, Cheap, Hardware"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "DHCP - Network Manager || $HOSTNAME"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  fmt="%-8s%-18s%-18s%-8s%-12s\n"
  printf "$fmt" "" "START" "END" "LEASE"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  for i in ${scopes[@]}
  do
    counter=$[$counter +1]
	start=$(echo $i | awk '{split($0,a,","); print a[1]}')
	end=$(echo $i | awk '{split($0,a,","); print a[2]}')
	lease=$(echo $i | awk '{split($0,a,","); print a[3]}')
    printf "$fmt" "[$counter]" $start $end $lease
  done
  echo ''
  printf "$fmt" "[C]" "Create New Scope"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  printf "$fmt" "[0]" "BACK"
  echo ''
  read -p "What would you like to do? " doit
  if [ "$doit" == "0" ]
  then
    echo '' && menu_network_dhcp
  else
    if [ "$doit" == "C" ]
    then
      ask_network_cluster_dhcp_scope
    else
      if [ "$doit" == "c" ]
      then
        ask_network_cluster_dhcp_scope
      else
        details_network_cluster_dhcp_scope ${net_links[$doit - 1]}
      fi
    fi
  fi
}
menu_network_dhcp()
{
  clear
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "COACH - Cluster Of Arbitrary, Cheap, Hardware"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "DHCP - Network Manager || $HOSTNAME"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  fmt="%-8s%-12s%-18s%-8s%-12s\n"
  printf "$fmt" "[I]" "Interfaces"
  printf "$fmt" "[S]" "Scopes"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  printf "$fmt" "[0]" "BACK"
  echo ''
  read -p "What would you like to do? " doit
  case $doit in
    0) menu_network_cluster ;;
	i|I) echo '' && menu_network_cluster_dhcp_interface && menu_network_cluster ;;
	s|S) echo '' && menu_network_cluster_dhcp_scope && menu_network_cluster ;;
	*) menu_network_dhcp ;;
  esac
}
menu_network_dns()
{
  clear
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "COACH - Cluster Of Arbitrary, Cheap, Hardware"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "DNS - Network Manager || $HOSTNAME"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  fmt="%-8s%-12s%-18s%-8s%-12s\n"
  printf "$fmt" "[I]" "Interfaces"
  printf "$fmt" "[S]" "Scopes"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo "[0]	BACK"
  echo ''
  read -p "What would you like to do? " doit
  case $doit in
    0) menu_network ;;
	i|I) echo '' && ask_network_cluster_install && menu_network_cluster ;;
	h|H) echo '' && menu_network_dhcp ;;
	n|N) echo '' && menu_network_dns ;;
	*) menu_network_cluster ;;
  esac
}
menu_network_cluster()
{
  clear
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "COACH - Cluster Of Arbitrary, Cheap, Hardware"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "Network Manager || $HOSTNAME"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  fmt="%-8s%-12s%-18s%-8s%-12s\n"
  if [ -z $(command -v dnsmasq) ]
  then
    printf "$fmt" "[I]" "Install DHCP and DNS Service"
  else
    printf "$fmt" "[H]" "DHCP"
    printf "$fmt" "[N]" "DNS"
    printf "$fmt" "[P]" "PXE"
  fi
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo "[0]	BACK"
  echo ''
  read -p "What would you like to do? " doit
  case $doit in
    0) menu_network ;;
	i|I) echo '' && ask_network_cluster_install && menu_network_cluster ;;
	h|H) echo '' && menu_network_dhcp ;;
	n|N) echo '' && menu_network_dns ;;
	*) menu_network_cluster ;;
  esac
}
menu_network()
{
  clear
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "COACH - Cluster Of Arbitrary, Cheap, Hardware"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "Network Manager || $HOSTNAME"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo "[L]	Local Network Settings"
  echo "[C]	Cluster Network Manager"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo "[0]	BACK"
  echo ''
  read -p "What would you like to do? " doit
  case $doit in
    0) menu_main ;;
    l|L) echo '' && menu_network_local ;;
	c|C) echo '' && menu_network_cluster ;;
	*) menu_network ;;
  esac
}

# System Preparation
sys_prep()
{
  apt-get -y install parted gdisk ntp apt-transport-https
  echo "$(whoami) ALL = (root) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$(whoami)
  sudo chmod 0440 /etc/sudoers.d/$(whoami)
}

# Install Ceph
set_ceph_journal_size()
{
  ssh -t $ceph_admin "sudo sed -i 's/^.*osd journal size = .*$/osd journal size = '$1'/' /etc/ceph/ceph.conf && sed -i 's/^.*osd journal size = .*$/osd journal size = '$1'/' ~/ceph/ceph.conf"
}
set_ceph_journal_size_MB()
{
  read -p "Set Journal Size in MB: " osd_journal_size
  set_ceph_journal_size $osd_journal_size
}
set_ceph_journal_size_auto()
{
  read -p "What is the expected average throughput (in MBps) for each OSD? " osd_throughput
  osd_journal_size=$[ 2 * ( $osd_throughput * 5 ) ]
  set_ceph_journal_size $osd_journal_size
}
change_ceph_journal_size()
{
  read -n1 -p "Would you like the set the ceph journal size Manually or Automatically? [m,a]" doit
  case $doit in
    m|M) echo '' && set_ceph_journal_size_MB ;;
    a|A) echo '' && set_ceph_journal_size_auto ;;
    *) change_ceph_journal_size ;;
  esac
  osd_journal_size=$(cat /etc/ceph/ceph.conf | sed -n -e 's/^.*osd journal size = //p')
  echo "The ceph journal size has been changed in /etc/ceph/ceph.conf to $osd_journal_size MB."
}
ask_ceph_journal_size()
{
  osd_journal_size=$(cat /etc/ceph/ceph.conf | sed -n -e 's/^.*osd journal size = //p')
  if [ -z "$osd_journal_size" ]
  then
    set_ceph_journal_size $ceph_default_journal_size
    echo "osd journal size = $ceph_default_journal_size" | sudo tee --append /etc/ceph/ceph.conf
    osd_journal_size=$(cat /etc/ceph/ceph.conf | sed -n -e 's/^.*osd journal size = //p')
  fi
  echo "According to /etc/ceph/ceph.conf, your ceph journal size is set to $osd_journal_size MB."
  read -n1 -p "Would you like to change the ceph journal size? [y,n]" doit
  case $doit in
    y|Y) echo '' && change_ceph_journal_size ;;
    n|N) echo '' && echo 'The ceph journal size has not been altered.' ;;
    *) ask_ceph_journal_size ;;
  esac
}
ignore_dev=()
dev="$(lsblk -p -l -o kname | grep -v 'KNAME' | grep -v [0-9])"
dev_available=()
dev_spin=()
dev_ssd=()
preflight_ceph_osd()
{
  clear
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "COACH - Cluster Of Arbitrary, Cheap, Hardware"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "Device Scanner || $HOSTNAME"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo "Scanning for storage devices..."

  ignore_dev=()
  dev="$(lsblk -p -l -o kname | grep -v 'KNAME' | grep -v [0-9])"
  dev_available=()
  dev_spin=()
  dev_ssd=()

  spin_count=0
  ssd_count=0
  if [ ! -z $(command -v megaclisas-status) ]
  then
    echo "MegaRAID controller found. "
    echo "Cleaning and preparing disks..."
    build_megaraid

    echo "Scanning for any RAID spans with more than 1 device. These will be ignored."
    raid_ignore=($(sudo megaclisas-status | grep Online | grep HDD | awk '{print $1}' | grep p1))
    raid_ignore=(${raid_ignore[@]} $(sudo megaclisas-status | grep Online | grep SSD | awk '{print $1}' | grep p1))
    raid_ignore=("${raid_ignore[@]}" "$(megaclisas-status | grep Online | grep SSD | awk '{print $1}' | grep p1)")
    ignore_count=0
    echo ""
    echo "Ignoring the following MegaRAID devices:"
    for line in "${raid_ignore}"
    do
      raid_id=$(echo $line | sed -r 's/(c[0-9]+u[0-9]+)(p1)/\1/')
      dev_id=$(sudo megaclisas-status | grep $raid_id | grep "/dev" | awk '{print $16}')
      ignore_dev=("${ignore_dev[@]}" "$dev_id")
      dev=$(echo "$dev" | grep -v "$dev_id")
      echo "  $raid_id		$dev_id"
    done
    echo ""
    echo "Scanning for MegaRAID hard disks..."
    found_spin=$(sudo megaclisas-status | grep Online | grep HDD)
    if [ ! -z "$found_spin" ]
    then
      raid_spin=($(echo "${found_spin[@]}" | awk '{print $1}' | grep p0))
      for line in "${raid_spin[@]}"
      do
        raid_id=$(echo $line | sed -r 's/(c[0-9]+u[0-9]+)(p0)/\1/')
        dev_id=$(sudo megaclisas-status | grep -w $raid_id | grep "/dev" | awk '{print $16}')
        should_ignore=$((for e in "${ignore_dev[@]}"; do [[ "$e" == "$dev_id" ]] && exit 0; done) && echo 1 || echo 0)
        if [ "$should_ignore" -lt 1 ]
        then
          dev_spin=("${dev_spin[@]}" "$dev_id")
          dev_available=("${dev_available[@]}" "$dev_id")
          dev=$(echo "$dev" | grep -v "$dev_id")
          echo "  $raid_id		$dev_id"
          spin_count=$[$spin_count + 1]
        fi

      done
    fi
    echo ""
    echo "Scanning for MegaRAID solid state disks..."
    found_ssd=$(sudo megaclisas-status | grep Online | grep SSD)
    if [ ! -z "$found_ssd" ]
    then
      raid_ssd=($(echo "${found_ssd[@]}" | awk '{print $1}' | grep p0))
      for line in "${raid_ssd[@]}"
      do
        raid_id=$(echo $line | sed -r 's/(c[0-9]+u[0-9]+)(p0)/\1/')
        dev_id=$(sudo megaclisas-status | grep -w $raid_id | grep "/dev" | awk '{print $16}')
        should_ignore=$((for e in "${ignore_dev[@]}"; do [[ "$e" == "$dev_id" ]] && exit 0; done) && echo 1 || echo 0)
        if [ "$should_ignore" -lt 1 ]
        then
          dev_ssd=("${dev_ssd[@]}" "$dev_id")
          dev_available=("${dev_available[@]}" "$dev_id")
          dev=$(echo "$dev" | grep -v "$dev_id")
          echo "  $raid_id		$dev_id"
          ssd_count=$[$ssd_count + 1]
        fi
      done
    fi
    echo ""
  fi
  if [ ! -z "$dev" ]
  then
    while read line
    do
      id=$(echo "$line" | awk '{split($0,a,"/"); print a[3]}')
      if [ -z "$(sudo cat /proc/mdstat | grep $id)" ]
      then
        if [ -z  $(lsblk -p -l -o kname | grep -e $line"[0-9]") ]
        then
          if [ $(lsblk -p -l -o kname,rota | grep -e $line | awk '{print $2}') -gt 0 ]
          then
            dev_spin=("${dev_spin[@]}" "$line")
            spin_count=$[$spin_count + 1]
          else
            dev_ssd=("${dev_ssd[@]}" "$line")
            ssd_count=$[$ssd_count + 1]
          fi
        else
          if [ $(lsblk -p -l -o kname,rota | grep -e $line | grep -v -e $line"[0-9]" | awk '{print $2}') -gt 0 ]
          then
            dev_spin=("${dev_spin[@]}" "$line")
            spin_count=$[$spin_count + 1]
          else
            dev_ssd=("${dev_ssd[@]}" "$line")
            ssd_count=$[$ssd_count + 1]
          fi
        fi
        dev_available=("${dev_available[@]}" "$line")
      fi
    done <<EOT
$(echo "$dev")
EOT
  fi
}
diff(){
  awk 'BEGIN{RS=ORS=" "}
       {NR==FNR?a[$0]++:a[$0]--}
  END{for(k in a)if(a[k])print k}' <(echo -n "${!1}") <(echo -n "${!2}")
}
create_ceph_osd()
{
  parts=($(lsblk -p -l -o kname | grep -e $1"[0-9]"))
  if [ ${#parts[@]} -eq 0 ]
  then
    echo "No partitions found on the selected storage device."
    echo "Zaping device to assure proper installation."
    sudo sgdisk -z $1
  else
    echo "Partitions were found on the selected storage device."
    read -n1 -p "Do you want to zap it to assure proper installation? [y,n]" doit
    case $doit in
      y|Y) echo '' && sudo sgdisk -z $1 ;;
      *) echo '' && echo 'Partitions will not be changed.' ;;
    esac
  fi
  if [ ! -z "$2" ]
  then
    parts=($(lsblk -p -l -o kname | grep -e $2"[0-9]"))
    if [ ${#parts[@]} -eq 0 ]
    then
      echo "No partitions found on the selected journal device."
      echo "Zapping device to assure proper installation."
      sudo sgdisk -z $2
    else
      if [ ! -z "$(sudo sgdisk $2 -p | grep 'ceph journal')" ]
      then
        echo "There are existing, active, journals on the seleced journalling device."
        echo "No changes will be made to the partitioning."
      else
        echo ''
        echo 'There are existing partitions on the journal device,'
        echo "but there are no active journals set up on it."
        read -n1 -p "Do you want to zap it to assure proper installation? [y,n]" doit
        case $doit in
          y|Y) echo '' && sudo sgdisk -z $2 ;;
          *) echo '' && echo 'Partitions will not be changed.' ;;
        esac
      fi
    fi
    echo "Creating OSD with separate Journal device..."
    ssh -t $ceph_admin "cd ~/ceph && ceph-deploy --overwrite-conf osd prepare $HOSTNAME:$1:$2"
  else
    echo "Creating OSD..."
    ssh -t $ceph_admin "cd ~/ceph && ceph-deploy --overwrite-conf osd prepare $HOSTNAME:$1"
  fi
  echo "OSD has been created for device $1"
}
menu_ceph_osd()
{
  RED='\033[1;31m'
  BLUE='\033[0;34m'
  YELLOW='\033[1;33m'
  GREEN='\033[0;32m'
  NC='\033[0m' # No Color
  counter=0
  add_selections=()
  remove_selections=()
  fix_selections=()
  clear
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "COACH - Cluster Of Arbitrary, Cheap, Hardware"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "Available Devices || $HOSTNAME"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo "	PATH		TYPE	ACTIVITY"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  for dev_id in ${dev_available[@]}
  do
    counter=$[$counter +1]
    if [ $((for e in "${dev_available[@]}"; do [[ "$e" == "$dev_id" ]] && exit 0; done) && echo 1 || echo 0) -eq 1 ]
    then
      if [ ${#dev_spin[@]} -gt 0 ]
      then
        if [ $((for e in "${dev_spin[@]}"; do [[ "$e" == "$dev_id" ]] && exit 0; done) && echo 1 || echo 0) -eq 1 ]
        then
          if [ ! -z "$(sudo sgdisk $dev_id -p | grep 'ceph data')" ]
          then
            osd_id=$(mount | grep $dev_id | grep ceph | awk '{print $3}' | grep -Eo '[0-9]{1,4}')
            if [ -z "$osd_id" ]
            then
              in_use=$(sudo sgdisk $dev_id -p | sed -n -e '/Number/,$p' | grep -v Number | grep -v ceph)
              if [ -z "$in_use" ]
              then
                printf  "${BLUE}[$counter]${NC}	$dev_id	HDD	${BLUE}ORPHANED${NC}\n"
                add_selections=("${add_selections[@]}" "$counter")
              else
                printf "${YELLOW}[$counter]${NC}	$dev_id	HDD	${YELLOW}IN USE${NC}\n"
                add_selections=("${add_selections[@]}" "$counter")
              fi
            else
              printf  "${RED}[$counter]${NC}	$dev_id	HDD	${RED}(osd.$osd_id)${NC}\n"
              remove_selections=("${remove_selections[@]}" "$counter")
            fi
          else
            if [ -z $(lsblk -p -l -o kname | grep -e $dev_id"[0-9]") ]
            then
              printf "${GREEN}[$counter]${NC}	$dev_id	HDD\n"
              add_selections=("${add_selections[@]}" "$counter")
            fi
          fi

        fi
      fi
      if [ ${#dev_ssd[@]} -gt 0 ]
      then
        if [ $((for e in "${dev_ssd[@]}"; do [[ "$e" == "$dev_id" ]] && exit 0; done) && echo 1 || echo 0) -eq 1 ]
        then
          if [ ! -z "$(sudo sgdisk $dev_id -p | grep 'ceph data')" ]
          then
            osd_id=$(mount | grep $dev_id | grep ceph | awk '{print $3}' | grep -Eo '[0-9]{1,4}')
            if [ -z "$osd_id" ]
            then
              in_use=$(sudo sgdisk $dev_id -p | sed -n -e '/Number/,$p' | grep -v Number | grep -v ceph)
              if [ -z "$in_use" ]
              then
                printf  "${BLUE}[$counter]${NC}	$dev_id	SSD	${BLUE}ORPHANED${NC}\n"
                add_selections=("${add_selections[@]}" "$counter")
              else
                printf "${YELLOW}[$counter]${NC}	$dev_id	SSD	${YELLOW}IN USE${NC}\n"
                add_selections=("${add_selections[@]}" "$counter")
              fi
            else
              printf  "${RED}[$counter]${NC}	$dev_id	SSD	${RED}(osd.$osd_id)${NC}\n"
              remove_selections=("${remove_selections[@]}" "$counter")
            fi
          else
            if [ ! -z "$(sudo sgdisk $dev_id -p | grep 'ceph journal')" ]
            then
              parts=($(lsblk -p -l -o kname | grep -e $dev_id"[0-9]"))
              echo "	$dev_id	SSD	(${#parts[@]} Journals)"
            else
              if [ -z $(lsblk -p -l -o kname | grep -e $dev_id"[0-9]") ]
              then
                printf  "${GREEN}[$counter]${NC}	$dev_id	SSD\n"
                add_selections=("${add_selections[@]}" "$counter")
              fi
            fi
          fi
        fi
      fi
    fi
  done
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo "[0]	BACK"
  echo ''
}
install_ceph_osd()
{
  menu_ceph_osd
  if [ $counter -gt 0 ]
  then
    read -p "Which device would you like to use for an OSD? " to_be_osd
    if [ "$to_be_osd" != "0" ]
    then
      if [ $((for e in "${add_selections[@]}"; do [[ "$e" == "$to_be_osd" ]] && exit 0; done) && echo 1 || echo 0) -eq 1 ]
      then
        if [ $((for e in "${dev_spin[@]}"; do [[ "$e" == "${dev_available[to_be_osd-1]}" ]] && exit 0; done) && echo 1 || echo 0) -eq 1 ]
        then
          if [ ${#dev_ssd[@]} -gt 0 ]
          then
            counter=0
            journal_selections=()
            echo ''
            echo "Ceph journaling can be used for the following SSDs (may take a moment to load):"
            for i in ${dev_ssd[@]}
            do
              counter=$[$counter +1]
              parts=($(lsblk -p -l -o kname | grep -e $i"[0-9]"))
              if [ "${#parts[@]}" -gt 0 ]
              then
                if [ ! -z "$(sudo sgdisk $i -p | grep 'ceph journal')" ]
                then
                  journal_free_space=$(sudo parted $i unit MB print free | grep 'Free Space' | tail -n1 | awk '{print $3}' | sed 's/MB//g')
                  if [ $journal_free_space -gt $osd_journal_size ]
                  then
                    echo "[$counter]	$i	(Space Available)"
                    journal_selections=("${journal_selections[@]}" "$counter")
                  else
                    echo "	$i	(Full)"
                  fi
                fi
              else
                echo "[$counter]	$i	(Empty)"
                journal_selections=("${journal_selections[@]}" "$counter")
              fi
            done
            read -p "Which device would you like to use for the ceph journal? " to_be_journal
            if [ $((for e in "${journal_selections[@]}"; do [[ "$e" == "$to_be_journal" ]] && exit 0; done) && echo 1 || echo 0) -eq 1 ]
            then
              create_ceph_osd ${dev_available[to_be_osd-1]} ${dev_ssd[to_be_journal-1]}
            else
              echo "Your selection was not in the list of available devices."
              install_ceph_osd
            fi
          fi
          create_ceph_osd ${dev_available[to_be_osd-1]}
        else
          echo "You chose an SSD."
        fi
        install_ceph_osd
      else
        echo "Your selection was not in the list of available devices."
        install_ceph_osd
      fi
    else
      menu_ceph_osd
    fi
  else
    echo "No devices available."
    read -n 1 -s -p "Press any key to return to the previous menu..."
    menu_ceph
  fi
}
ask_ceph_osd_add()
{
  if [ ${#dev_ssd[@]} -gt 0 ]
  then
    ask_ceph_journal_size
  fi
  install_ceph_osd
  menu_ceph
}
delete_ceph_osd()
{
  if [ ! -z $1 ]
  then
    sudo systemctl stop ceph-osd@$1
    sudo umount /var/lib/ceph/osd/ceph-$1
    ssh -t $ceph_admin "cd ~/ceph && ceph osd out $1 && ceph osd crush remove osd.$1 && ceph auth del osd.$1 && ceph osd rm $1"
    sudo sgdisk -z $2
  else
    echo "You need to provide a valid OSD #"
  fi
  remove_ceph_osd
}
remove_ceph_osd()
{
  menu_ceph_osd
  if [ $counter -gt 0 ]
  then
    read -p "Which OSD would you like to remove from the cluster? " to_be_osd
    if [ "$to_be_osd" != "0" ]
    then
      if [ $((for e in "${remove_selections[@]}"; do [[ "$e" == "$to_be_osd" ]] && exit 0; done) && echo 1 || echo 0) -eq 1 ]
      then
        menu="$(menu_ceph_osd)"
        osd_id=$(echo "$menu" | grep '\['$to_be_osd'\]' | awk '{print $4}' | grep -Eo '[0-9]{1,4}' )
        read -p "Are you absolutely sure you want to delete this OSD? [y,n]" doit
        case $doit in
          y|Y) echo '' && delete_ceph_osd $osd_id ${dev_available[to_be_osd-1]};;
          n|N) remove_ceph_osd ;;
          *) remove_ceph_osd ;;
        esac
      else
        echo "Your selection was not in the list of available devices."
        remove_ceph_osd
      fi
    fi
  else
    echo "No devices available."
  fi
}
ask_ceph_osd_remove()
{
  remove_ceph_osd
  menu_ceph
}
ceph_default_journal_size=2000
ceph_seed_osd_size=3000
ceph_admin=""
install_ceph_mon()
{
  no_root
  if [ "$HOSTNAME" == "$ceph_admin" ]
  then
    if [ ! -z "$1" ]
    then
      iface=$1
    else
      if [ $use_infiniband = 1 ]
      then
        iface="ib0"
      else
        iface="eno1"
      fi
    fi
    ip_ceph_mon=$(ifconfig $iface | grep "inet addr:" | awk '/inet addr/{print substr($2,6)}')
    ceph_pub_net=$( ip route | grep $iface | awk '{print $1}' )

    if [ -z "$ceph_pub_net" ]
    then
      read -p "Ceph Public Network [192.168.0.0/24]: " ceph_pub_net
    fi
    if [ -z "$ceph_pub_net" ]
    then
      ceph_pub_net="192.168.0.0/24"
    fi

    cd ~/ceph
    ceph-deploy new $HOSTNAME
    echo "osd pool default size = 2" >> ceph.conf
    echo "public network = $ceph_pub_net" >> ceph.conf
    echo "osd journal size = $ceph_default_journal_size" >> ceph.conf
    ceph-deploy mon create-initial
    ceph-deploy admin $HOSTNAME
    sudo chmod +r /etc/ceph/ceph.client.admin.keyring
  else
    ssh -t $ceph_admin "ssh-keygen -R $HOSTNAME && ssh-copy-id $(whoami)@$HOSTNAME"
    ssh -t $ceph_admin "cd ~/ceph && ceph-deploy mon create $HOSTNAME"
  fi
}
# Install Ceph
install_ceph_deploy()
{
  if [ "$ceph_admin" == "$HOSTNAME" ]
  then
    wget -q -O- 'https://download.ceph.com/keys/release.asc' | sudo apt-key add -
    echo deb https://download.ceph.com/debian-kraken/ $(lsb_release -sc) main | sudo tee /etc/apt/sources.list.d/ceph.list
    sudo apt-get update
    sudo apt-get -y install ceph-deploy
  fi
}
is_ceph_mon=""
is_ceph_mds=""
default_ceph_pg_num=512
preflight_ceph()
{
  if [ -z "$(command -v ceph-deploy)" ]
  then
    ceph_admin_ip=$(who -m | awk '{print $5}' | tr -d '()')
    ceph_admin=$(cat /etc/hosts | grep $ceph_admin_ip | awk '{print $2}')
    if [ -z "$ceph_admin" ]
    then
      echo "You need to either run this script locally, or connect using a qualified hostname."
      echo ''
      exit
    fi

    ceph_admin_user=$(cat ~/.ssh/config | grep -A 2 $ceph_admin | grep User | awk '{print $2}')
    if [ -z "$ceph_admin_user" ]
    then
      ceph_admin_user=$(who -m | awk '{print $1}')
    fi
    if [ "$ceph_admin" != "$HOSTNAME" ]
    then
      if [ -f ~/.ssh/id_rsa ]
      then
        echo ''
        echo "SSH keys are already created."
      else
        echo "Creating SSH keys..."
        echo -e "\n\n\n" | ssh-keygen
      fi
      if [ -z "$(ssh-keygen -F $ceph_admin)" ]
      then
        echo "Copying new public key from $ceph_admin..."
        ssh-copy-id $ceph_admin_user@$ceph_admin
        echo "Host $ceph_admin" >> ~/.ssh/config
        echo "	Hostname $ceph_admin" >> ~/.ssh/config
        echo "	User $ceph_admin_user" >> ~/.ssh/config
      fi
    fi
  else
    ceph_admin=$HOSTNAME
  fi
  if [ ! -z "$(command -v ceph)" ]
  then
    is_ceph_mon="$(sudo ceph mon dump | grep $HOSTNAME)"
    is_ceph_mds="$(sudo ls /var/lib/ceph/mds | grep $HOSTNAME)"
    ceph_fs_ls=$(sudo ceph fs ls)
    if [ $ceph_fs_ls == "No filesystems enabled" ]
    then
      is_ceph_fs=0
    else
      ceph_fs_ls=$(sudo ceph fs ls | awk '{print $2}' | sed 's/,//')
      is_ceph_fs=1
    fi
  fi
}
install_ceph()
{
  if [ -z "$(command -v ceph-deploy)" ]
  then
    install_ceph_deploy
  fi
  if [ "$ceph_admin" == "$HOSTNAME" ]
  then
    mkdir ~/ceph
    cd ~/ceph
    ceph-deploy install $HOSTNAME
  else
    ssh -t $ceph_admin "ssh-keygen -R $HOSTNAME && ssh-copy-id $ceph_admin_user@$HOSTNAME"
    ssh -t $ceph_admin "cd ~/ceph && ceph-deploy install $HOSTNAME && ceph-deploy admin $HOSTNAME"
  fi
}

ceph_authenticate()
{
  if [ -z $2 ]
  then
    sudo ceph auth get-or-create client.$1 osd 'allow rwx' mon 'allow r' -o /etc/ceph/ceph.client.$1.keyring
  else
    sudo ceph auth get-or-create client.$1.$2 osd 'allow rwx pool=$1' mon 'allow r' -o /etc/ceph/ceph.client.$1.$2.keyring
  fi
}
ask_ceph_authenticate()
{
  read -p "Client Hostname [$HOSTNAME]: " client
  if [ -z $client ]
  then
    client=$HOSTNAME
  fi
  ceph_authenticate $client
}

scanned=0
menu_ceph_osd()
{
  if [ $scanned -eq 0 ]
  then
    preflight_ceph_osd
    scanned=1
  fi
  clear
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "COACH - Cluster Of Arbitrary, Cheap, Hardware"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "Ceph OSD - Manager || $HOSTNAME"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo "[A]	Add OSD"
  echo "[R]	Remove OSD"
  echo "[S]	Rescan Devices"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo "[0]	BACK"
  echo ''
  read -p "What would you like to do? " doit
  case $doit in
    0) echo '' && menu_ceph ;;
    a|A) echo '' && ask_ceph_osd_add ;;
    r|R) echo '' && ask_ceph_osd_remove ;;
    s|S) echo '' && preflight_ceph_osd && menu_ceph_osd ;;
    *) menu_ceph_osd ;;
  esac
}
ceph_pool_remove()
{
  sudo ceph osd pool rm $1 $1 --yes-i-really-really-mean-it
}
ask_ceph_pool_remove()
{
  read -p "Are you sure? [y,n]" doit
  case $doit in
    y|Y) echo '' && ceph_pool_remove $1 && menu_ceph_pool ;;
    *) ceph_pool_details $1 ;;
  esac
}
ceph_pool_rename()
{
  sudo ceph osd pool rename $1 $2
}
ask_ceph_pool_rename()
{
  read -p "New name: " doit
  ceph_pool_rename $1 $doit
  ceph_pool_details $doit
}
ceph_pool_set()
{
  sudo ceph osd pool set $1 $2 $3
}
ask_ceph_pool_set()
{
  read -p "Property: " prop
  read -p "Value: " value
  ceph_pool_set $1 $prop $value
}
ceph_pool_details()
{
  clear
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "COACH - Cluster Of Arbitrary, Cheap, Hardware"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "Pool - Ceph - Manager || $HOSTNAME"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  sudo ceph osd pool get $1 all
  #sudo ceph osd pool get-quota $1
  #sudo ceph osd pool stats $1
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo "[D]	Delete"
  echo "[R]	Rename"
  echo ""
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo "[0]	BACK"
  echo ''
  read -p "What would you like to do? " doit
  case $doit in
    0) echo '' && menu_ceph_pool ;;
    d|D) echo '' && ask_ceph_pool_remove $1 ;;
    r|r) echo '' && ask_ceph_pool_rename $1 ;;
    s|S) echo '' && ask_ceph_pool_set $1 && ceph_pool_details $1 ;;
    *) ceph_pool_details $1 ;;
  esac
}
ceph_pool_create()
{
  sudo ceph osd pool create $1 $2
}
ask_ceph_pool_create()
{
  read -p "Pool name: " pool_name
  read -p "Placement Group size [$default_ceph_pg_num]: " pgs
  if [ -z $pgs ]
  then
    pgs=$default_ceph_pg_num
  fi
  ceph_pool_create $pool_name $pgs
  menu_ceph_pool
}
menu_ceph_pool()
{
  ceph_pools=($(sudo ceph osd pool ls))
  clear
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "COACH - Cluster Of Arbitrary, Cheap, Hardware"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "Ceph OSD - Manager || $HOSTNAME"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  count=0
  for i in ${ceph_pools[@]}
  do
    ((count++))
    echo "[$count]	$i"
  done
  echo ""
  echo "[C]	Create New Pool"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo "[0]	BACK"
  echo ''
  read -p "What would you like to do? " doit
  if [ "$doit" == "0" ]
  then
    echo '' && menu_ceph
  else
    if [ "$doit" == "C" ]
    then
      ask_ceph_pool_create
    else
      if [ "$doit" == "c" ]
      then
        ask_ceph_pool_create
      else
        ceph_pool_details ${ceph_pools[($doit - 1)]}
      fi
    fi
  fi
  menu_ceph_pool
}
install_ceph_mds()
{
  no_root
  if [ "$HOSTNAME" == "$ceph_admin" ]
  then
    ceph-deploy mds create $HOSTNAME
  else
    ssh -t $ceph_admin "cd ~/ceph && ceph-deploy mds create $HOSTNAME"
  fi
}
ceph_fs_create()
{
  if [ -z "$(sudo ceph fs ls | grep -w $1)" ]
  then
    ceph_pool_create $1_data $default_ceph_pg_num
    ceph_pool_create $1_meta $default_ceph_pg_num
    sudo ceph fs new $1 $1_meta $1_data
  fi
}
ask_ceph_fs_create()
{
  read -p "Name: " doit
  ceph_fs_create $doit
}
ceph_fs_delete()
{
  sudo ceph mds cluster_down
  sudo ceph mds fail 0
  sudo ceph fs rm $1 --yes-i-really-mean-it
  ceph_pool_remove $1_data
  ceph_pool_remove $1_meta
}
ask_ceph_fs_delete()
{
  read -p "Are you sure? [y,n]" doit
  case $doit in
    y|Y) echo '' && ceph_fs_delete $1 && menu_ceph_fs;;
    *) ceph_fs_details $1 ;;
  esac
}
ceph_fs_mount()
{
  ceph_mon_ls=($(sudo ceph mon dump | grep mon | awk '{print $3}' | awk '{split($0,a,"."); print a[2]}'))
  ceph_mons=""
  for i in ${ceph_mon_ls[@]}
  do
	ping=$(ping $i -c 1 | grep -w PING | awk '{print $3}' | tr -d '()')
	if [ "$ping" != "ping: unknown host $i" ]
	then
      if [ -z $ceph_mons ]
      then
        ceph_mons="$ping"
      else
        ceph_mons="$ceph_mons,$ping"
      fi
    fi
  done

  sudo mkdir /mnt
  sudo mkdir /mnt/ceph
  sudo mkdir /mnt/ceph/fs
  ceph_authenticate $HOSTNAME
  secret=$(sudo ceph-authtool -p /etc/ceph/ceph.client.admin.keyring)
  sudo mount -t ceph $ceph_mons:/ /mnt/ceph/fs -o name=admin,secret=$secret	
  echo "$ceph_mons:/  ceph name=admin,secret=$secret,noatime,_netdev,x-systemd.automount 0 2" | sudo tee --append /etc/fstab
}
ceph_fs_unmount()
{
  sudo umount /mnt/ceph/fs
  sudo rm -r /mnt/ceph/fs
  sudo cp /etc/fstab /etc/fstab.bak
  sudo sed -i '/\/mnt\/ceph\/fs/d' /etc/fstab
}
ceph_fs_details()
{
  clear
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "COACH - Cluster Of Arbitrary, Cheap, Hardware"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "FileSystem - Ceph - Manager || $HOSTNAME"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo $1
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo "[D]	Delete"
  if [ -z "$(df -h | grep '/mnt/ceph/fs')" ]
  then
    echo "[M]	Mount"
  else
    echo "[U]	Unmount"
  fi
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo "[0]	BACK"
  echo ''
  read -p "What would you like to do? " doit
  case $doit in
    0) echo '' && menu_ceph_fs ;;
    d|D) echo '' && ask_ceph_fs_delete $1 && menu_ceph_fs ;;
    m|M) echo '' && ceph_fs_mount $1 && ceph_fs_details $1 ;;
    u|u) echo '' && ceph_fs_unmount $1 && ceph_fs_details $1 ;;
    *) ceph_fs_details $1 ;;
  esac
}
menu_ceph_fs()
{
  ceph_fs_ls=$(sudo ceph fs ls)
  if [ "$ceph_fs_ls" == "No filesystems enabled" ]
  then
    is_ceph_fs=0
  else
    ceph_fs_ls=$(sudo ceph fs ls | awk '{print $2}' | sed 's/,//')
    is_ceph_fs=1
  fi
  count=0
  clear
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "COACH - Cluster Of Arbitrary, Cheap, Hardware"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "FileSystem - Ceph - Manager || $HOSTNAME"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  if [ $is_ceph_fs -eq 1 ]
  then
    for i in ${ceph_fs_ls[@]}
    do
      ((count++))
      echo "[$count]	$i"
    done
  else
    echo "[C]	Create CephFS"
  fi

  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo "[0]	BACK"
  echo ''
  read -p "What would you like to do? " doit
  if [ "$doit" == "0" ]
  then
    echo '' && menu_ceph
  else
    if [ "$doit" == "C" ]
    then
      ask_ceph_fs_create "ceph_fs" && menu_ceph_fs
    else
      if [ "$doit" == "c" ]
      then
        ceph_fs_create "ceph_fs" && menu_ceph_fs
      else
        ceph_fs_details ${ceph_fs_ls[($doit - 1)]}
      fi
    fi
  fi
}

install_ceph_rgw()
{
  no_root
  if [ "$HOSTNAME" == "$ceph_admin" ]
  then
    ceph-deploy rgw create $HOSTNAME
  else
    ssh -t $ceph_admin "cd ~/ceph && ceph-deploy rgw create $HOSTNAME"
  fi
}
ceph_rbd_create()
{
  sudo rbd create --size $1 $2
}
ask_ceph_rbd_create()
{
  ceph_pools=($(sudo ceph osd pool ls))
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  count=0
  for i in ${ceph_pools[@]}
  do
    ((count++))
    echo "[$count]	$i"
  done
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  read -p "Which pool should the RBD be in? " pool_selected
  pool=${ceph_pools[($pool_selected - 1)]}
  read -p "Name: " name
  read -p "Size [MB]: " size
  ceph_rbd_create $size $pool/$name
  echo ""
  read -n 1 -s -p "Press any key to return to the previous menu..."
}
ceph_rbd_resize()
{
  sudo rbd resize --size $1 $2 --allow-shrink
}
ask_ceph_rbd_resize()
{
  read -p "Size [MB]: " size
  ceph_rbd_resize $size $1
}
ceph_rbd_delete()
{
  sudo rbd rm $1
}
ask_ceph_rbd_delete()
{
  read -p "Are you sure? [y,n]" doit
  case $doit in
    y|Y) echo '' && ceph_rbd_delete $1 && menu_ceph_rbd;;
    *) ceph_rbd_details rbd/$1 ;;
  esac
}
ceph_rbd_map()
{
  ceph_authenticate $HOSTNAME
  sudo rbd feature disable $1 exclusive-lock object-map fast-diff deep-flatten
  dev=$(sudo rbd map $1)
  sudo mkdir /mnt
  sudo mkdir /mnt/ceph
  sudo mkdir /mnt/ceph/rbd
  pool=$(echo $1 | awk -F "/" '{print $1}')
  rbd=$(echo $1 | awk -F "/" '{print $2}')
  sudo mkdir "/mnt/ceph/rbd/$pool"
  sudo mkdir "/mnt/ceph/rbd/$pool/$rbd"
  sudo mount $dev "/mnt/ceph/rbd/$1"
  read -n 1 -s -p "Press any key to return to the previous menu..."
}
ceph_rbd_unmap()
{
  sudo umount /mnt/ceph/rbd/$1
  sudo rbd unmap $1
}
ceph_rbd_details()
{
  clear
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "COACH - Cluster Of Arbitrary, Cheap, Hardware"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "RBD - Ceph - Manager || $HOSTNAME"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  sudo rbd info $1
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo "[R]	Resize"
  echo "[D]	Delete"
  if [ -z "$(sudo rbd showmapped | grep $1)" ]
  then
    echo "[M]	Map & Mount"
  else
    echo "[U]	Unmount & Unmap"
  fi
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo "[0]	BACK"
  echo ''
  read -p "What would you like to do? " doit
  case $doit in
    0) echo '' && menu_ceph_rbd ;;
    r|R) echo '' && ask_ceph_rbd_resize $1 && ceph_rbd_details $1 ;;
    d|D) echo '' && ask_ceph_rbd_delete $1 && menu_ceph_rbd;;
    m|M) echo '' && ceph_rbd_map $1 ;;
    u|U) echo '' && ceph_rbd_unmap $1 ;;
    *) ceph_rbd_details $1 ;;
  esac
}
menu_ceph_rbd()
{
  ceph_rbds=()
  ceph_pools=($(sudo ceph osd pool ls))
  if [ ! -z "${#ceph_pools[@]}" ]
  then
    for i in ${ceph_pools[@]}
    do
      pool_rbds=($(sudo rbd ls $i))
      if [ ! -z "${#pool_rbds[@]}" ]
      then
        for j in ${pool_rbds[@]}
        do
          ceph_rbds="${ceph_rbds[@]} $i/$j"
        done
      fi
    done
  fi
  ceph_rbds=($(echo "${ceph_rbds[@]}" | xargs))
  clear
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "COACH - Cluster Of Arbitrary, Cheap, Hardware"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "RBD - Ceph - Manager || $HOSTNAME"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  count=0
  for i in ${ceph_rbds[@]}
  do
    ((count++))
    echo "[$count]	$i"
  done
  echo ""
  echo "[C]	Create New RADOS Block Device"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo "[0]	BACK"
  echo ''
  read -p "What would you like to do? " doit
  if [ "$doit" == "0" ]
  then
    echo '' && menu_ceph
  else
    if [ "$doit" == "C" ]
    then
      ask_ceph_rbd_create
    else
      if [ "$doit" == "c" ]
      then
        ask_ceph_rbd_create
      else
        ceph_rbd_details ${ceph_rbds[($doit - 1)]}
      fi
    fi
  fi
  menu_ceph_rbd
}
ceph_test()
{
  sudo ceph osd pool create test 512
  sudo rados -p test bench 30 write --no-cleanup
  sudo rados -p test bench 30 seq
  sudo ceph osd pool rm test test --yes-i-really-really-mean-it
  echo ''
  read -n 1 -s -p "Press any key to return to the previous menu..."
}
ask_repair_raid_ceph()
{
  ask_megaraid_ceph
}
ask_ceph_test()
{
  read -n1 -p "Would you like to benchmark your ceph cluster? [y,n]" doit
  case $doit in
    y|Y) echo '' && ceph_test ;;
    n|N) echo '' ;;
    *) ask_ceph_test ;;
  esac
  menu_ceph
}
scanned=0
menu_ceph()
{
  preflight_ceph
  clear
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "COACH - Cluster Of Arbitrary, Cheap, Hardware"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "Ceph - Manager || $HOSTNAME"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  if [ ! -z "$(command -v ceph)" ]
  then
    sudo ceph df
  fi
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  if [ -z "$(command -v ceph-deploy)" ]
  then
    if [ "$ceph_admin" == "$HOSTNAME" ]
    then
      echo "[C]	Install ceph-deploy"
    fi
  fi
  if [ -z "$(command -v ceph)" ]
  then
    echo "[C]	Install ceph"
  else
    if [ -z "$is_ceph_mon" ]
    then
      echo "[MO]	Install Monitor Service"
    else
      echo "[O]	Manage Local OSDs"
    fi
    echo "[P]	Manage Pools"
    if [ -z $is_ceph_mds ]
    then
      echo "[ME]	Install Metadata Service"
    fi
    is_mds_up=$(sudo ceph mds stat | grep up)
    if [ ! -z "$is_mds_up" ]
    then
      echo "[F]	Manage CephFS"
    fi
    echo "[G]	Setup RADOS Gateway"
    echo "[D]	Manage RADOS Block Devices"
	echo "[R]	Repair RAID Arrays"
    echo "[B]	Benchmark"
  fi
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo "[0]	BACK"
  echo ''
  read -p "What would you like to do? " doit
  case $doit in
    0) echo '' && menu_main ;;
    c|C) echo '' && install_ceph && menu_ceph;;
    mo|MO) echo '' && install_ceph_mon && menu_ceph ;;
    me|ME) echo '' && install_ceph_mds && menu_ceph ;;
    g|G) echo '' && install_ceph_rgw && menu_ceph ;;
    o|O) echo '' && menu_ceph_osd ;;
    p|P) echo '' && menu_ceph_pool ;;
    f|F) echo '' && menu_ceph_fs ;;
    d|D) echo '' && menu_ceph_rbd ;;
	r|R) echo '' && ask_repair_raid_ceph && menu_ceph ;;
    b|B) echo '' && ask_ceph_test && menu_ceph ;;
    *) menu_ceph ;;
  esac
}
auto_install()
{
  ask_system_admin
  ask_networking
  ask_drives
  sys_prep
}
menu_auto_installer()
{
  clear
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "COACH - Cluster Of Arbitrary, Cheap, Hardware"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "Auto Installers || $HOSTNAME"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo "[V]	System Vendor Specific Software"
  echo "[N]	Network Drivers"
  echo "[D]	Storage Drivers"
  echo "[P]	Prepare System for Remote Use"
  echo ""
  echo "[A]	All of the Above"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo "[0]	BACK"
  echo ''
  read -p "What would you like to do? " doit
  case $doit in
    0) echo '' && menu_main ;;
    v|V) echo '' && ask_system_admin && menu_main;;
    n|N) echo '' && ask_networking && menu_main;;
    d|D) echo '' && ask_drives && menu_main ;;
    p|P) echo '' && sys_prep && menu_main ;;
    a|A) echo '' && auto_install && menu_main ;;
    *) menu_auto_installer ;;
  esac
}

coach_bootstrap()
{
  auto_install
  install_ceph
  install_ceph_mon
  
  if [ ! -f ~/ceph/coach_seed ]
  then
    cd ~/ceph
    fallocate -l 4G coach_seed
    mkfs.xfs coach_seed
  fi
  mkdir /mnt
  mkdir /mnt/ceph
  mkdir /mnt/ceph/seed
  sudo chmod 777 /mnt/ceph/seed
  echo "/home/$(whoami)/ceph/coach_seed /mnt/ceph/seed xfs loop" | sudo tee --append /etc/fstab
  sudo mount -o loop=$(losetup -f) coach_seed /mnt/ceph/seed
  sudo ceph-deploy osd prepare $HOSTNAME:/mnt/ceph/seed
  sudo ceph-deploy osd activate $HOSTNAME:/mnt/ceph/seed
  systemctl enable ceph.target
  
  install_ceph_mds
  ceph_fs_create "ceph_fs"
  ceph_fs_mount
  
  network_cluster_install
  menu_network_cluster_dhcp_interface
}

connect_to()
{
  clear
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "COACH - Cluster Of Arbitrary, Cheap, Hardware"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "Remote Operations Manager"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo "Connecting to $1"
  scp_user=$(cat ~/.ssh/config | grep -A 2 $1 | grep User | awk '{print $2}')
  scp_found=1
  if [ -z "$scp_user" ]
  then
    read -p "Username: " scp_user
    scp_found=0
  fi

  if [ -f ~/.ssh/id_rsa ]
  then
    echo ''
    echo "SSH keys are already created."
  else
    echo "Creating SSH keys..."
    echo -e "\n\n\n" | ssh-keygen
  fi
  if [ -z "$(ssh-keygen -F $1)" ]
  then
    echo "Copying new public key from $1..."
    ssh-copy-id $scp_user@$1
    if [ $scp_found == 0 ]
    then
      echo "Host $1" >> ~/.ssh/config
      echo "	Hostname $1" >> ~/.ssh/config
      echo "	User $scp_user" >> ~/.ssh/config
    fi
  fi

  script_name=$(basename $0)
  script_path=$(realpath $0)

  echo ''
  echo "Copying preflight installer..."
  scp $script_path $scp_user@$1:/home/$scp_user/$script_name
  echo ''
  echo "Running preflight installer..."
  ssh -t $scp_user@$1 ./$script_name
}
ask_connect_to()
{
  read -p "Hostname: " connect_to_host
  connect_to $connect_to_host
}
# Main Menu
menu_main()
{
  clear
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "COACH - Cluster Of Arbitrary, Cheap, Hardware"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "Main Menu || $HOSTNAME"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo "[A]	Auto-Installers"
  echo "[N]	Network Manager"
  echo "[C]	Ceph Manager"
  echo ""
  echo "[B]	Bootstrap (Setup as Seed Node)"
  echo ""
  echo "[R]	Connect to Remote System"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo "[0]	EXIT"
  echo ''
  read -p "What would you like to do? " doit
  case $doit in
    0) echo '' && exit ;;
    a|A) echo '' && menu_auto_installer ;;
    n|N) echo '' && menu_network ;;
    c|C) echo '' && menu_ceph ;;
	b|B) echo '' && coach_bootstrap ;;
    r|R) echo '' && ask_connect_to ;;
    *) menu_main ;;
  esac
}

# Installer
if [ -z $1 ]
then
  menu_main
else
  connect_to $1
fi
