#/bin/bash
if [ -z $1 ]
then
  read -p "Hostname: " hostname
else
  hostname=$1
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
