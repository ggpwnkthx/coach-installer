#!/bin/bash
if [ -z $1 ]
then
  echo "No IP specified."
  exit
fi
if [ -z $2 ]
then
  echo "No hostname specified."
  exit
fi

if [ -z "$(cat /etc/hosts | grep $2)" ]
then
  echo "$1\t$2" | sudo tee --append /etc/hosts
else
  sudo sed -i "/$2/ s/.*/$1\t$2 #static/g" /etc/hosts
fi
