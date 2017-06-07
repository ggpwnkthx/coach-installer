#!/bin/bash

if [ -z "$(command -v nmap)" ]
then
  sudo apt-get -y install nmap
fi
if [ -z "$(command -v ipcalc)" ]
then
  sudo apt-get -y install ipcalc
fi
set_cloud()
{
  echo "auto $1 " | sudo tee /etc/network/interfaces.d/cloud
  echo "iface $1 inet static" | sudo tee --append /etc/network/interfaces.d/cloud
  echo "address 169.254.169.254" | sudo tee --append /etc/network/interfaces.d/cloud
  echo "netmask 255.0.0.0" | sudo tee --append /etc/network/interfaces.d/cloud
  sudo ifconfig $1 169.254.169.254 netmask 255.0.0.0
}
set_storage()
{
  netmin="$(ipcalc -n $2 | grep HostMin | awk '{print $2}')"
  netmax="$(ipcalc -n $2 | grep HostMax | awk '{print $2}')"
  netmask="$(ipcalc -n $2 | grep Netmask | awk '{print $2}')"
  echo "auto $1 " | sudo tee /etc/network/interfaces.d/storage
  echo "iface $1 inet static" | sudo tee --append /etc/network/interfaces.d/storage
  echo "address $netmin" | sudo tee --append /etc/network/interfaces.d/storage
  echo "netmask $netmask" | sudo tee --append /etc/network/interfaces.d/storage
  sudo ifconfig $1 $netmin netmask $netmask
}

bootstrap()
{
  if [ -z $1 ]
  then
    echo "Something isn't right here..."
    return
  else
    if [ -z "$(ifconfig ${ifaces[$iface-1]} | grep "inet ")" ]
    then
      echo "Searching for existing network..."
      if [ -z $2 ]
      then
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
          if [ "$network" == $cidr ]
          then
            set_storage $1 $cidr
          else
            echo "Hmm... you CIDR doesn't look right."
            bootstrap $1
          fi
        else
          echo "auto $1 " | sudo tee /etc/network/interfaces.d/storage
          echo "iface $1 inet dhcp" | sudo tee --append /etc/network/interfaces.d/storage
        fi
      else
        network="$(ipcalc -n $2 | grep Network | awk '{print $2}')"
        if [ "$network" == $2 ]
        then
          set_storage $1 $2
        fi
      fi
    else
      echo "${ifaces[$iface-1]} has already been configured."
      address=$(ifconfig ${ifaces[$iface-1]} | grep "inet " | awk '{print $2}' | awk '{split($0,a,":"); print a[2]}')
      netmaks=$(ifconfig ${ifaces[$iface-1]} | grep "inet " | awk '{print $4}' | awk '{split($0,a,":"); print a[2]}')
      cidr=$(ipcalc $address $netmaks)
      set_storage ${ifaces[$iface-1]} $cidr
      set_cloud ${ifaces[$iface-1]}
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
    i=$(($i+1))
  done
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo "[B] Back"
  echo
  read -p "Choose an interface for your storage fabric: " iface
  case $iface in
    b|B) return ;;
    *)
      if [ -z ${ifaces[$iface-1]} ]
      then
        iface_menu
      else
        bootstrap ${ifaces[$iface-1]}
      fi
  esac
}
if [ ! -f /etc/network/interfaces.d/storage ]
then
  if [ -z $1 ]
  then
    iface_menu
  else
    boostrap $1
  fi
fi
