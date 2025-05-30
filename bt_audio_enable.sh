#!/bin/bash
# checks for bluetooth paired device, connects to it and writes the blue_toothid & signal strength to a file
# if there are no paired devices, then it deletes the file to indicate that condition
# once a device is paired, as indicated by a non-zero rssi, then it stops doing bluetoothctl
# if bbase gets a bluetooth error, then it deletes the file to restart the process.

#states: 
#  1) file doesn't exist: not paired -> look for paired device and connect
#  2) file exists, but has 0 as second field: not connected, poll to try to connect
#  3) file exists, has non-zero for second field: connected, so do nothing

if [[ $1 ]]; then
	sleep_duration=$1
	# printf "setting sleep_duration=$sleep_duration\n"
else
	sleep_duration=2
fi

printf "bt_audio_enable.sh started: sleep_duration=$sleep_duration\n" >&2

filepath="/run/shm/bt_speaker.fifo"

# poll for paired bluetooth and connect
while true; do

	if [ -f "$filepath" ]; then
		# check if status is non-zero then it's connected
		line=$(<$filepath)
		if [[ ${line: -1} != 0 ]]; then
			sleep $sleep_duration
			# printf "bluetooth connected: file={$line}\n"
			continue
		fi
	fi

	bt_device_id=$(bluetoothctl paired-devices | awk ' { print $2 } ')
	if [ $? -ne 0 ]; then
		printf "bluetoothctl paired-devices command failed; returned {$?}\n"
		sleep 10
		rm -f $filepath
		continue
	fi

	# test if string is not empty
	if [[ $bt_device_id ]]; then
		# printf "paired with '$bt_device_id'\n"
		if [[ ! -f $filepath ]]; then
			printf "$bt_device_id 0" > $filepath #create file if it doesn't exist, which happens on boot
		fi

		# as the system boots, then bluetooth will return 'default' as the device ID, so handle a change in device_id
		line=$(<$filepath)
		if [[ ${line:0:7} != ${bt_device_id:0:7} ]]; then
			rm -f $filepath
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
				status="0"
			else
				status="3"
			fi

			if [ ! -f "$filepath" ]; then
					printf "$bt_device_id $status" > $filepath
			else
				# only write file if connection status has changed
				line=$(<$filepath)
				if [[ ${line: -1} != $status ]]; then
					printf "$bt_device_id $status" > $filepath
				fi

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