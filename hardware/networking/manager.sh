#!/bin/bash

preflight_network_local()
{
  return_to_base
  sudo apt-get -y install ipcalc nmap dhcping
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
	  up) sudo ifconfig $1 down ;;
	  down) sudo ifconfig $1 up;;
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
      awk -f changeInterface.awk /etc/network/interfaces.bak "dev=$1" $net_exists "$2=$3" | sudo tee /etc/network/interfaces >/dev/null 2>/dev/null
    else
      awk -f changeInterface.awk /etc/network/interfaces.bak "dev=$1" $net_exists "mode=static" "$2=$3" | sudo tee /etc/network/interfaces >/dev/null 2>/dev/null
    fi
	if [ $(sudo cat /sys/class/net/$1/operstate) == "up" ]
	then
	  sudo ifdown $1
      if [ $(ip link | awk "/$1/{getline; print}" | awk '{print $1}' | awk -F "/" '{print $2}') == "infiniband" ]
      then
	    echo "Clearing OpenFabric Settings"
        reset_infiniband
      fi
	  sudo ifup $1
	fi
  fi
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
}
ask_network_local_address()
{
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo ''
  read -p "IP Address: " doit
  set_network_local $1 address $doit
}
ask_network_local_netmask()
{
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo ''
  read -p "Netmask: " doit
  set_network_local $1 netmask $doit
}
ask_network_local_broadcast()
{
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo ''
  read -p "Broadcast: " doit
  set_network_local $1 broadcast $doit
}
ask_network_local_gateway()
{
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo ''
  read -p "Gateway: " doit
  set_network_local $1 gateway $doit
}
add_network_local()
{
  preflight_network_local
  sudo cp /etc/network/interfaces /etc/network/interfaces.bak
  awk -f changeInterface.awk /etc/network/interfaces.bak "dev=$1" "action=add" "mode=static" "address=$2" "netmask=$3" "gateway=$4" | sudo tee /etc/network/interfaces >/dev/null 2>/dev/null
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
  awk -f changeInterface.awk /etc/network/interfaces.bak "dev=$1" "action=remove" | sudo tee /etc/network/interfaces >/dev/null 2>/dev/null
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
    echo '' && menu_main
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
  if [ ! -f "/mnt/ceph/fs/networking" ]
  then
    sudo mkdir /mnt/ceph/fs/networking
  fi
  if [ ! -f "/mnt/ceph/fs/networking/dhcp" ]
  then
    sudo mkdir /mnt/ceph/fs/networking/dhcp
  fi
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
  if [ -z "$(command -v dnsmasq)" ]
  then
    menu_network_local
  else
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
      0) exit ;;
      l|L) echo '' && menu_network_local ;;
      c|C) echo '' && menu_network_cluster ;;
      *) menu_network ;;
    esac
  fi
}

menu_network
