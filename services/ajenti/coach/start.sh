#!/bin/bash
PID=$(sudo ss -lptn 'sport = :8000' | grep pid | sed -n -e 's/^.*pid=//p' | awk -F, '{print $1}')
if [ ! -z $PID ]
then
  kill $PID
fi
dpkg --configure -a
apt-get -f -y install
ceph-deploy purge $(hostname -s)
ceph-deploy purgedata $(hostname -s)
apt -y autoremove
ajenti-dev-multitool --build
ajenti-dev-multitool --run-dev
