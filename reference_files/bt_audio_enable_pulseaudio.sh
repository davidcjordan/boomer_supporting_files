#!/bin/bash

# checks for bluetooth device and enables it

# pulseaudio --start
# if [ $? -ne 0 ]; then
#   printf "Failed: pulse audio command --start'\n"
#   exit 1
# fi
# pactl load-module module-bluetooth-discover

bluez_sink_status=$(pacmd list-sinks | grep -e 'name:') > /dev/null
if [ $? -ne 0 ]; then
  printf "Failed: pulse audio command (pacmd) list-sinks'\n"
  # exit 1
fi
# printf "bluez_sink_status=${bluez_sink_status}\n"
if [[ $bluez_sink_status == *"bluez_sink"* ]]; then
  printf "bluetooth sink exists\n"
  exit 0
fi

# sink doesn't exist, so do the initialization sequence

bt_device_id=$(bluetoothctl devices | awk ' { print $2 } ')
if [ $? -ne 0 ]; then
  printf "no paired devices\n"
  exit 1
fi
printf "paired with '${bt_device_id}'\n"

bluetoothctl trust ${bt_device_id} > /dev/null
if [ $? -ne 0 ]; then
  printf "Failed: Setting trust for '${bt_device_id}'\n"
  exit 1
fi

bluetoothctl connect ${bt_device_id} > /dev/null
if [ $? -ne 0 ]; then
  printf "Failed: Couldn't connect to '${bt_device_id}'\n"
  exit 1
fi
# printf "connected with '${bt_device_id}'\n"

sleep 2
bluetoothctl disconnect > /dev/null
if [ $? -ne 0 ]; then
  printf "Couldn't disconnect to '${bt_device_id}'\n"
  exit 1
fi
sleep 20
bluetoothctl connect ${bt_device_id} > /dev/null
if [ $? -ne 0 ]; then
  printf "Failed: Couldn't connect to '${bt_device_id}' the second time\n"
  exit 1
fi

# sleep 2
# bluetoothctl disconnect > /dev/null
# if [ $? -ne 0 ]; then
#   printf "Couldn't disconnect to '${bt_device_id}'\n"
#   exit 1
# fi
# sleep 12
# bluetoothctl connect ${bt_device_id} > /dev/null
# if [ $? -ne 0 ]; then
#   printf "Failed: Couldn't connect to '${bt_device_id}' the third time\n"
#   exit 1
# fi
sleep 8

# need to fix d-bus policies per: https://stackoverflow.com/questions/24580155/pulseaudio-not-detecting-bluetooth-headset
#pactl list cards short #returns: 2       bluez_card.C4_F6_C6_3D_10_DB    module-bluez5-device.c
bluez_card_id=$(pactl list cards short | awk ' { print $2 } ')
if [ $? -ne 0 ]; then
  printf "Failed: pactl list cards short'\n"
  exit 1
fi

if [[ ! $bluez_card_id ]]; then # var is not set or it is set to an empty string
  printf "bluez card id missing for '${bt_device_id} on first attempt'\n"
fi

bluez_card_id=$(pactl list cards short | awk ' { print $2 } ')
if [ $? -ne 0 ]; then
  printf "Failed: pactl list cards short'\n"
  exit 1
fi

if [[ ! $bluez_card_id ]]; then # var is not set or it is set to an empty string
  printf "bluez card id missing for '${bt_device_id}'\n"
  exit 1
fi

printf "bluez_card_id: '${bluez_card_id}'\n"

pactl set-card-profile ${bluez_card_id} off
if [ $? -ne 0 ]; then
  printf "Failed: pulse audio control (pactl) set-card-profile off ${bluez_card_id}\n"
  exit 1
fi

# disconnect and reconnect here?

pactl set-card-profile ${bluez_card_id} a2dp_sink
if [ $? -ne 0 ]; then
  printf "Failed: pulse audio control (pactl) set-card-profile ${bluez_card_id} a2dp_sink\n"
  exit 1
fi

bluez_sink_id=${bluez_card_id/card/sink}
# printf "bluez_sink_id: '${bluez_sink_id}'\n"

pacmd set-default-sink ${bluez_sink_id}.a2dp_sink
if [ $? -ne 0 ]; then
  printf "Failed: pulse audio command (pacmd) set-default-sink ${bluez_card_id}.a2dp_sink\n"
  exit 1
fi


# bluetoothctl info <device> #verify trusted & connected (or not)
# for i in {0..1}
# do
#   bluetoothctl connect ${bt_device_id} > /dev/null
#   if [ $? -ne 0 ]; then
#     printf "Couldn't connect to '${bt_device_id}'\n"
#     exit 1
#   fi
#   # printf "connected with '${bt_device_id}'\n"
#   sleep 5
# done
