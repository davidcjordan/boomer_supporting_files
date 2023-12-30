#!/bin/bash

#Thus script was largely written by the following chatGPT prompts:
#  - write a bash script that obtains bluetooth RSSI over several seconds and prints an average
#  - linux extract integer from string 'RSSI return value: -7'
#  - bash count colon in string
#  - bash -h help script
# I added printf's (chatGPT used echo) and changed the main loop which would infinite loop if RSSI didn't return correctly.

# Check for the help option
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    printf "With no arguments, this script will get the average RSSI of the connected bluetooth device over 10 seconds.\n"
    printf "Invoking with an integer argument will change the duration of the collection period.\n"
    exit 0
fi

count_colons() {
    local str="$1"
    local count=0

    while [[ $str =~ ":" ]]; do
        str="${str#*:}"  # Remove everything up to the first colon
        ((count++))
    done

    echo "$count"
}

DEVICE_ADDRESS=$(hcitool con | grep -oP '\b([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})\b')

if [ $(count_colons $DEVICE_ADDRESS) -ne 5 ]; then
   printf "hcitool did not return a MAC address\n"
   exit 1
fi
printf "Getting RSSI for ${DEVICE_ADDRESS}\n"

# Number of seconds to collect RSSI
if [ -z $1 ]; then
   DURATION=10
else
   DURATION=$1
fi

# Initialize variables
TOTAL_RSSI=0
COUNT=0

# Main loop
while [ "$COUNT" -lt "$DURATION" ]; do
   # Extract RSSI value (assuming the output is in the format "RSSI return value: -13")
   rssi=$(hcitool rssi $DEVICE_ADDRESS | grep -oP '[-+]?\d+')
   printf "Sample ${COUNT}: RSSI=${rssi}\n"

   if [[ -n "$rssi" ]]; then
      TOTAL_RSSI=$((TOTAL_RSSI + rssi))
   fi

   COUNT=$((COUNT + 1))
   sleep 1
done

# Calculate average RSSI
if [ "$TOTAL_RSSI" -ne 0 ]; then
    AVERAGE_RSSI=$((TOTAL_RSSI / COUNT))
    printf "Average RSSI over ${DURATION} seconds: ${AVERAGE_RSSI}\n"
else
    printf "No RSSI data collected.\n"
fi
