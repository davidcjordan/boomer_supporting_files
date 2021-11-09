#!/bin/bash

if [ -z $1 ]
then
 echo "arg 1 (file to scp) is empty"
 exit 1
fi

extension="${1##*.}"
dest_prefix="pi@"
dest_dir=":/home/pi/boomer/logs/"
daves_enet="192.168.0.40"
# daves_enet="10.0.1.102"
base_wifi="192.168.27.2"
dest_ip=${base_enet}

eth_state=$(cat /sys/class/net/eth0/operstate)

# if [[ -z ${eth_state} ]]; then
if [[ $eth_state == "up" ]]; then
  dest_ip=${daves_enet}
else
  dest_ip=${base_wifi}
fi

dest=${dest_prefix}${dest_ip}${dest_dir}

if [[ $extension == "dat" ]]; then
  if [[ $eth_state == "up" ]]; then
    # scp over enet for the video files
    scp $1 $dest
  else
    printf "Skipping transfer of video since enet is not up"
  fi
else
  scp $1 $dest
fi

if [ $? -eq 0 ]
then
  printf "OK: scp $1 $dest\n"
  # rm "$1"
else
  echo "Failed: scp $1 $dest\n" >&2
  exit 1
fi