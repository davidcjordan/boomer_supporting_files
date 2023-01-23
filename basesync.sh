#!/bin/bash

if [ -z $1 ]; then
   read -p "Enter Boomer number: " id
else
   id=$1
fi

if [[ $0 == *"cam"* ]]; then 
   filename="bcam"
else
   filename="bbase"
fi

# printf "called with: $0, scp ${filename}.out to base-${id}\n"

if [ $id == 0 ]; then
   # use ethernet
   scp -o ConnectTimeout=10 /home/pi/boomer/staged/${filename}.out pi@192.168.0.42:/home/pi/boomer/staged
else
   scp -o ConnectTimeout=10 /home/pi/boomer/staged/${filename}.out pi@base-$id:/home/pi/boomer/staged
fi

if [ $? -ne 0 ]; then
   printf "Failed: scp of ${filename}.out to base-$id\n"
fi
