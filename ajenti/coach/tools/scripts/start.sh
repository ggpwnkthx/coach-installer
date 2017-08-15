#!/bin/bash
PID=$(sudo ss -lptn 'sport = :8000' | grep pid | sed -n -e 's/^.*pid=//p' | awk -F, '{print $1}')
if [ ! -z $PID ]
then
  kill $PID
fi
ajenti-dev-multitool --build
ajenti-dev-multitool --run-dev
