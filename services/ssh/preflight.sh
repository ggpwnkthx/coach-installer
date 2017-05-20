#/bin/bash

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
