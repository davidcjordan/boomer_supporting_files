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

scp /home/pi/boomer/staged/${filename}.out pi@base-$id:/home/pi/boomer/staged
if [ $? -ne 0 ]; then
   printf "Failed: scp of ${filename}.out to base-$id\n"
fi
