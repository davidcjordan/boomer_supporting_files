#!/bin/bash
# checks for bluetooth paired device, connects to it and write to file

if [[ $1 ]]; then
 sleep_duration=$1
else
 sleep_duration=2
fi

printf "bt_audio_enable.sh started: sleep_duration=$sleep_duration arg2=$2\n" >&2

filepath="/run/shm/bt_speaker.fifo"
while true; do
  bt_device_id=$(bluetoothctl devices | awk ' { print $2 } ')
  # test if string is not empty
  if [[ $bt_device_id ]]; then
    # printf "paired with '$bt_device_id'\n"
    bluetoothctl trust $bt_device_id > /dev/null
    if [ $? -eq 0 ]; then
      # printf "trusted '$bt_device_id'\n"
      bluetoothctl connect $bt_device_id > /dev/null
      if [ $? -eq 0 ]; then
        # printf "connected '$bt_device_id'\n"
        rssi=$(hcitool rssi $bt_device_id | awk ' { print $4 } ')
        # printf "rssi= $rssi\n"
        if [ $? -eq 0 ]; then
          printf "$bt_device_id $rssi" > $filepath
        else
          printf "$bt_device_id 0" > $filepath
        fi
      fi
    fi
  else
    rm -f $filepath
  fi
  sleep $sleep_duration
done