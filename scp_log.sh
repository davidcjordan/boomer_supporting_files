#!/bin/bash

if [ -z $1 ]
then
 echo "arg 1 (file to scp) is empty"
 exit 1
fi

extension="${1##*.}"
dest_prefix="pi@"
dest_dir=":/home/pi/boomer/logs/"
dest=${dest_prefix}${dest_ip}${dest_dir}

daves_enet="192.168.0.40"
# daves_enet="10.0.1.102"
base_wifi="192.168.27.2"

my_ip_addresses=$(hostname -I)
if [[ $my_ip_addresses == *"27.2"* ]]; then
  is_base="true"
else
  is_base="false"
fi
# printf "is_base: $is_base\n"

eth_state=$(cat /sys/class/net/eth0/operstate)
if [[ $eth_state == "up" ]]; then
  is_eth_up="true"
else
  is_eth_up="false"
fi
# is_eth_up="false"
# printf "is_eth_up: $is_eth_up\n"

dest_ip="false"
if "$is_eth_up"; then
  dest_ip=${daves_enet}
else
  if "$is_base"; then
    printf "Not sending logs because enet is not plugged into base\n"
  elif [[ $extension == "dat" ]]; then
    printf "Not sending video because enet is not plugged into the cam\n"
  else
    dest_ip=${base_wifi}
  fi
fi

if [ "$dest_ip" != "false" ] ; then
  dest=${dest_prefix}${dest_ip}${dest_dir}
  scp $1 $dest
  if [ $? -eq 0 ]
  then
    printf "OK: scp $1 $dest\n"
    # rm "$1"
  else
    echo "Failed: scp $1 $dest\n" >&2
    exit 1
  fi
fi