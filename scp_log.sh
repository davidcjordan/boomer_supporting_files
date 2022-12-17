#!/bin/bash

# this script assumes that 'base' and 'daves' IP addresses are setup in hostnames;
#   and that the ssh keys have been copied to base and daves

printf "scp_logs.sh started: arg1=$1 arg2=$2\n" >&2
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

extension="${2##*.}"
# printf "file extension: $extension\n"
if [[ $2 == *"boomer.log"* ]] || [ $extension == "fifo" ] || [ $extension == "png" ] || [[ $2 == *"intensity.log"* ]]; then
 printf "skipping handling of file: $2\n"
 exit 0
fi

# on camera: convert frame data to PNG files
if [ "$2" == "frame_even.dat" ] || [ "$2" == "frame_odd.dat" ]; then
  cd $1
  ~/boomer/execs/dat2png.out $2
  if [ $? -eq 0 ]; then
    printf "OK: dat2png.out $1/$2\n"
  else
    printf "Failed: dat2png.out $1/$2\n" >&2
    exit 1
  fi
  exit 0
fi

user_id="pi"
log_dir="/home/${user_id}/boomer/logs/"
shm_dir="/run/shm"

eth_state=$(cat /sys/class/net/eth0/operstate)

if [[ $(hostname) == "base"* ]]; then
  if [ $eth_state == "up" ]; then
    dest_ip="daves"
    dest="${user_id}@${dest_ip}:${log_dir}"
    scp "$1/$2" $dest
    if [ $? -eq 0 ]; then
      printf "OK: scp $1/$2 $dest\n"
      rm -v "$1/$2"
    else
      printf "Failed: scp $1/$2 $dest\n" >&2
      exit 1
    fi
  else
    # if enet not up, then move shm files to the log directory
    if [ $1 == $shm_dir ]; then
      mv -v "$1/$2" $log_dir
      if [ $? -eq 0 ]; then
        printf "OK: mv $1/$2 $log_dir\n"
      else
        printf "Failed: mv $1/$2 $log_dir\n" >&2
        exit 1
      fi
    fi
  fi
else
  # camera or speaker files:
  dest_ip="base"
  dest="${user_id}@${dest_ip}:${shm_dir}"
  # the following delays didn't seem to work - so adding the delays in the cam code instead
  # if [ "$1" == "/run/shm" ] && [ $extension == "dat" ]; then
  #   printf "Adding sleep before sending video file."
  #   if [ $(hostname) == "right" ]; then
  #     printf "Adding sleep for right camera."
  #     # wait for left to transfer the video
  #     sleep 49
  #   else
  #     printf "Adding sleep for left camera."
  #     sleep 3 # wait for .log files to be transferred
  #   fi
  # fi
  scp "$1/$2" $dest
  if [ $? -eq 0 ]; then
    printf "OK: scp $1/$2 $dest\n"
    rm -v "$1/$2"
  else
    printf "Failed: scp $1/$2 $dest\n" >&2
    exit 1
  fi
fi