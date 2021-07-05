#!/bin/bash
#printf "scp_cam_executables.sh: started\n" >&2
net_addr="192.168.27."
sub_addr_left="3"
sub_addr_right="4"
dest_dir="/home/pi/boomer/staged"

if [ -z $1 ]
then
 printf "arg 1 (path of software version) is empty\n"
 exit 1
fi

if [ -z $2 ]
then
 printf "arg 2 (filename of software version) is empty\n"
 exit 1
fi

#rsync creates temporary dot (.) files unless the -T=/run/shm is used
if [[ $2 == "."* ]]
then
   printf "Skipping file: %s.\n" $1/$2

elif [[ $2 == *"base"* ]]
then
   cp $1/$2 /home/pi/boomer/execs/
   if [ $? -eq 0 ]
   then
      printf "Success: cp of %s to /home/pi/boomer/execs.\n" $1
   else
      printf "Failed: cp of %s to /home/pi/boomer/execs.\n" $1 >&2
   fi
elif [[ $2 == *"cam"* ]]
then
   scp $1/$2 pi@${net_addr}${sub_addr_left}:${dest_dir}
   if [ $? -eq 0 ]
   then
      printf "Success: scp of %sto the left camera.\n" $1
   else
      printf "Failed: scp of %s to the left camera.\n" $1 >&2
   fi
   scp $1/$2 pi@${net_addr}${sub_addr_right}:${dest_dir}
   if [ $? -eq 0 ]
   then
      printf "Success: scp of %s to the right camera.\n" $1
   else
      printf "Failed: scp of %s to the right camera.\n" $1 >&2
   fi
else
   printf "Skipping file: %s.\n" $1
fi
