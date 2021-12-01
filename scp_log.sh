#!/bin/bash

# if enet is up:
  # if a rec_*dat || rec_*log file then transfer to daves
# else
  # if rec_log && !base then transfer to base
# endif -> i.e. do nothing if not a log file or video file

# this script assumes that 'base' and 'daves' IP addresses are setup in hostnames;
#   and that the ssh keys have been copied to base and daves

printf "scp_logs.sh: started\n" >&2
if [ -z $1 ]
then
 printf "arg 1 (path to file) is empty\n"
 exit 1
fi

if [ -z $2 ]
then
 printf "arg 2 (filename to file) is empty\n"
 exit 1
fi

extension="${1##*.}"
user_id="pi"
dest_dir=":/home/${user_id}/boomer/logs/"

if [[ $2 == "frame.dat" ]]; then
  cd $1
  ~/boomer/staged/dat2png.out $2
  if [ $? -eq 0 ]; then
    printf "OK: ./staged/dat2png.out $1/$2\n"
    # rm "$1"
  else
    echo "Failed: ./staged/dat2png.out $1/$2\n" >&2
    exit 1
  fi
  exit 0
fi

if [[ $2 != "rec_"* ]]; then
  printf "Skipping file: $1/$2\n"
  exit 0
fi

if [[ $(hostname) == "base" ]]; then
  is_base="true"
else
  is_base="false"
fi
#printf "is_base: $is_base\n"

eth_state=$(cat /sys/class/net/eth0/operstate)
if [[ $eth_state == "up" ]]; then
  is_eth_up="true"
else
  is_eth_up="false"
fi
# printf "is_eth_up: $is_eth_up\n"

dest_ip="false"
if "$is_eth_up"; then
  dest_ip="daves"
else
  if "$is_base"; then
    printf "Not sending logs because enet is not plugged into base\n"
  elif [[ $extension == "dat" ]]; then
    printf "Not sending video because enet is not plugged into the cam\n"
  else
    dest_ip="base"
  fi
fi

if [ "$dest_ip" != "false" ] ; then
  dest="${user_id}@${dest_ip}${dest_dir}"
  scp "$1/$2" $dest
  if [ $? -eq 0 ]; then
    printf "OK: scp $1/$2 $dest\n"
    # rm "$1"
  else
    echo "Failed: scp $1/$2 $dest\n" >&2
    exit 1
  fi
fi