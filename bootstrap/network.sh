#!/bin/bash

if [ -z "$(command -v nmap)" ]
then
  sudo apt-get -y install nmap
fi
if [ -z "$(command -v ipcalc)" ]
then
  sudo apt-get -y install ipcalc
fi

bootstrap()
{
  if [ -z $1 ]
  then
    echo "Something isn't right here..."
    return
  else
    echo "Searching for existing network..."
    dhcp_search=$(sudo nmap --script broadcast-dhcp-discover -e $1 | grep "Server Identifier" | awk '{print $4}')
    if [ -z "$dhcp_search" ]
    then
      echo "No network found."
      echo "Let's start a new one."
      read -p "CIDR for new network [192.168.0.0/24] : " cidr
      if [ -z "$cidr" ]
      then
        cidr="192.168.0.0/24"
      fi
      network="$(ipcalc -n $cidr | grep Network | awk '{print $2}')"
      if [ "$network" == $cidr]
      then
        netmin="$(ipcalc -n $cidr | grep HostMin | awk '{print $2}')"
        netmax="$(ipcalc -n $cidr | grep HostMax | awk '{print $2}')"
        netmask="$(ipcalc -n $cidr | grep Netmask | awk '{print $2}')"
        echo "auto $1 " | sudo tee /etc/network/interfaces.d/$1
        echo "iface $1 inet static" | sudo tee --append /etc/network/interfaces.d/$1
        echo "address $netmin" | sudo tee --append /etc/network/interfaces.d/$1
        echo "netmaks $netmask" | sudo tee --append /etc/network/interfaces.d/$1
        ifconfig $1 $netmin netmask $netmask
      else
        echo "Hmm... you CIDR doesn't look right."
        bootstrap $1
      fi
    else
      echo "auto $1 " | sudo tee /etc/network/interfaces.d/$1
      echo "iface $1 inet dhcp" | sudo tee --append /etc/network/interfaces.d/$1
    fi
  fi
}
iface_menu()
{
  ifaces=($(ifconfig -a | sed 's/[ \t].*//;/^\(lo\|\)$/d'))
  clear
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "COACH - Cluster Of Arbitrary, Cheap, Hardware"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "Bootstrapping this node's Network"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  i=1
  for iface in ${ifaces[@]}
  do
    echo "[$i] $iface"
    i=$[$i+1]
  done
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo "[B] Back"
  echo
  read -p "Choose an interface for your storage fabric: " iface
  case $iface in
    b|B) return ;;
    *) 
      if [ -z "${ifaces[$iface+1]}" ]
      then
        iface_menu
      else
        bootstrap ${ifaces[iface+1]}
      fi
  esac
}
iface_menu
