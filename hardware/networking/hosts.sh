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

if [ "$2" == "$(hostname -s)" ]
then
  sed -i "/$2/ s/.*/$1\t$(hostname -f)\t$(hostname -s) #static/g" /etc/hosts
else
  if [ -z "$(cat /etc/hosts | grep $2)" ]
  then
    echo "$1\t$2" | tee --append /etc/hosts
  else
    sed -i "/$2/ s/.*/$1\t$2 #static/g" /etc/hosts
  fi
fi
