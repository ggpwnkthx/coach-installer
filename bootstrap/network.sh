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
    dhcp_search=$(sudo nmap --script broadcast-dhcp-discover -e $1 | grep "Server Identifier" | awk '{print $4}')
    if [ -z "$dhcp_search" ]
    then
      read -p "CIDR [192.168.0.0/24] : " cidr
      netmin="$(ipcalc -n $cidr | grep HostMin | awk '{print $2}')"
      netmax="$(ipcalc -n $cidr | grep HostMax | awk '{print $2}')"
      netmask="$(ipcalc -n $cidr | grep Netmask | awk '{print $2}')"
      
    else
      echo "not sure what to do yet"
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
  for iface in $ifaces
  do
    echo "[$i] $iface"
  done
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo "[B] Back"
  echo
  read -p "Choose an interface for your storage fabric: " iface
  case i in $iface
    b|B) return ;;
    *) 
      if [ -z "${ifaces[iface+1]}" ]
      then
        iface_menu
      else
        bootstrap ${ifaces[iface+1]}
      fi
  esac
}
iface_menu
