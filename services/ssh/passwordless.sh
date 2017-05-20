#/bin/bash
if [ -z $1 ]
then
  read -p "Hostname: " hostname
else
  hostname=$1
fi
if [ -z "$(cat /etc/hosts | grep "$hostname #static") ]
then
  ping=$(ping $hostname -c 1 | grep -w PING | awk '{print $3}' | tr -d '()')
  if [ "$ping" != "ping: unknown host $hostname" ]
  then
    ip=$ping
  else
    echo "Hostname not found."
    read -p "IP of host: " ip
    ping=$(ping $ip -c 1 | grep "Destination Host Unreachable")
    if [ ! -z "$ping" ]
    then
      echo "Cannot reach host."
      exit
    fi
  fi
  echo "Hostname $hostname resolves to $ip."
  read -p "Is this expected? [Y,n] " resolve
  case $resolve in
    n|N)
      read -p "What should the IP for $hostname be? " ip
      ;;
  esac
  
  wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/hardware/networking/hosts.sh -O hardware_networking_hosts.sh
  chmod +x hardware_networking_hosts.sh
  ./hardware_networking_hosts.sh $hostname $ip
fi

scp_user=$(cat ~/.ssh/config | grep -A 2 $hostname | grep User | awk '{print $2}')
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
  ssh-keygen
fi
if [ -z "$(ssh-keygen -F $hostname)" ]
then
  echo "Copying new public key from $hostname..."
  ssh-copy-id $scp_user@$hostname
  if [ $scp_found == 0 ]
  then
    echo "Host $hostname" >> ~/.ssh/config
    echo "	Hostname $hostname" >> ~/.ssh/config
    echo "	User $scp_user" >> ~/.ssh/config
  fi
fi

ssh -t $hostname wget https://raw.githubusercontent.com/ggpwnkthx/coach/master/hardware/networking/hosts.sh -O hardware_network_hosts.sh
ssh -t $hostname chmod +x hardware_network_hosts.sh
ssh -t $hostname ./hardware_network_hosts.sh $(who am i | awk '{print $5}' | tr -d '()') $HOSTNAME
