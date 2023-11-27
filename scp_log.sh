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

if [[ $2 == *"chromium"* ]]; then
 printf "skipping handling of file: $2\n"
 exit 0
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

# on base: write_sheet with score
if [ "$2" == "score_update.json" ]; then
  printf "updating google score sheet\n"
  cd ~/repos/boomer_supporting_files
  source venv/bin/activate
  python3 score_update.py $1 $2
  if [ $? -eq 0 ]; then
    printf "OK: score sheet updated\n"
  else
    printf "Failed: score sheet updated\n" >&2
    exit 1
  fi
  exit 0
fi

# on base: email workout analytics
analytics_file="workout_analytics.csv"
subject="$(hostname) workout analytics"
if [ "$2" == $analytics_file ]; then
  printf "emailing $analytics_file\n"
  cd /run/shm
  cat $analytics_file | mutt -s "$subject" -- roi.co.4444@gmail.com
  if [ $? -eq 0 ]; then
    printf "OK: emailed $analytics_file\n"
  else
    printf "Failed: emailed $analytics_file\n" >&2
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
  scp "$1/$2" $dest
  if [ $? -eq 0 ]; then
    printf "OK: scp $1/$2 $dest\n"
    rm -v "$1/$2"
  else
    printf "Failed: scp $1/$2 $dest\n" >&2
    exit 1
  fi
fi