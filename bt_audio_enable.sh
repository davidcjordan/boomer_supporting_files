#!/bin/bash
# checks for bluetooth paired device, connects to it and write to file
# if there are no paired devices, then it deletes the file to indicate that condition

if [[ $1 ]]; then
 sleep_duration=$1
else
 sleep_duration=2
fi

printf "bt_audio_enable.sh started: sleep_duration=$sleep_duration arg2=$2\n" >&2

filepath="/run/shm/bt_speaker.fifo"
while true; do
  bt_device_id=$(bluetoothctl paired-devices | awk ' { print $2 } ')
  # test if string is not empty
  if [[ $bt_device_id ]]; then
    # printf "paired with '$bt_device_id'\n"
    if [[ ! -f $filepath ]]; then
      printf "$bt_device_id 0" > $filepath #create file if it doesn't exist, which happens on boot
    fi
    bluetoothctl trust $bt_device_id > /dev/null
    if [ $? -eq 0 ]; then
      # printf "trusted '$bt_device_id'\n"
      conn_status=$(bluetoothctl info $bt_device_id | grep Connected | awk ' { print $2 } ')
      if [[ -z $conn_status ]]; then
        printf "bogus return from get info for '$bt_device_id'\n"
      elif [[ "$conn_status" == "no" ]]; then
        bluetoothctl connect $bt_device_id > /dev/null
        conn_status=$(bluetoothctl info $bt_device_id | grep Connected | awk ' { print $2 } ')
      fi
      # at this point, should either be connected or not
      if [[ "$conn_status" == "no" ]]; then
        printf "$bt_device_id 0" > $filepath
      else
        printf "$bt_device_id 33" > $filepath
      # NOT checking signal strength because it interferes with the audio stream
      #   rssi_string=$(hcitool rssi $bt_device_id)
      #   # hcitool has an exit code of 1 if the device is not connected
      #   if [ $? -eq 0 ]; then
      #     # printf "rssi_string= '$rssi_string'\n"
      #     rssi=$(echo $rssi_string | awk ' { print $4 } ')
      #     # printf "rssi= $rssi\n"
      #     printf "$bt_device_id $rssi" > $filepath
      #   else
      #     printf "$bt_device_id 0" > $filepath
      #   fi
      fi
    fi
  else
    rm -f $filepath
  fi
  sleep $sleep_duration
done