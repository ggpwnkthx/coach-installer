#!/bin/bash
deploy()
{
  clear
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "COACH - Cluster Of Arbitrary, Cheap, Hardware"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
  echo "Ceph Monitor - $HOSTNAME"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  read -p "Is this the first node? [y,N] " first
  case $first in
    y|Y)
      ./download_and_run services/ceph/init.sh
      ;;
    n|N)
      if [ -z $1 ]
      then
        ifconfig | awk -v RS="\n\n" '{ for (i=1; i<=NF; i++) if ($i == "inet" && $(i+1) ~ /^addr:/) address = substr($(i+1), 6); if (address != "127.0.0.1") printf "%s\t%s\n", $1, address }'
        read -p "Which adapter should be used for the ceph cluster? " nic
      else
        nic=$1
      fi
      chaddr=$(ifconfig $nic | grep HWaddr | awk '{print $5}')
      mask=$(ifconfig $nic | grep Mask | awk '{print $4}' | awk '{split($0,a,":"); print a[2]}')
      net=$(ipcalc -n $addr $mask | grep Network | awk '{print $2}')
      if [ -z $2 ]
      then
        read -p "What is the hostname or IP of an active node? " node
      else
        node=$2
      fi
      ssh -t $node "ssh-keygen -R $HOSTNAME && ssh-copy-id $(whoami)@$HOSTNAME"
      ssh -t $node "cd ~/ceph && ceph-deploy mon create $HOSTNAME"
      ;;
  esac
}

if [ -z "$(command -v ceph)" ]
then
  deploy $@
else
  if [ -z "$(ceph mon dump | grep mon.$(hostname -s))" ]
  then
    deploy $@
  fi
fi
