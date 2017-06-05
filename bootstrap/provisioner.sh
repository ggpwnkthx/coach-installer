#!/bin/bash

if [ -z "$(command -v docker)" ]
then
  ./download_and_run "docker/deploy.sh"
fi

./download_and_run "docker/provisioner/deploy.sh"
