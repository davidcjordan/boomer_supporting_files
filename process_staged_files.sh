#!/bin/bash
#printf "process_staged_files.sh: started\n" >&2

#the script requires /etc/hostnames to have the address for the left and right cams
# this script runs when files are put into the boomer/staged directory on the base
# a incrontab config moves (mv) the executable from the staged to the execs directoty
#  after the mv, the change_version.sh script runs

cfg_data_dest_dir="${HOME}/this_boomers_data"
cam_staged_dest_dir="${HOME}/boomer/staged"
cam=""

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

elif [[ $2 == *"base"* ]]; then
   cp $1/$2 ${USER}/boomer/execs/
   if [ $? -eq 0 ]
   then
      printf "Success: cp of %s to /home/pi/boomer/execs.\n" $1
   else
      printf "Failed: cp of %s to /home/pi/boomer/execs.\n" $1 >&2
   fi
# handle cam parameter files
elif [[ $2 == *"cam_param"* ]]; then
   if [[ $2 == *"left"* ]]; then
      cam="left"
   elif [[ $2 == *"right"* ]]; then
      cam="right"
   else
      printf "Unrecognized cam_param filename: ${2}\n" >&2
      exit 1
   fi
   scp $1/$2 ${cam}:${cfg_data_dest_dir}/$2
   if [ $? -eq 0 ]; then
      printf "Success: scp of ${2} to the left camera.\n"
   else
      printf "Failed: scp of ${2} to the left camera.\n" >&2
   fi
   # make a params file backup and move the new params to the base config data directory
   mv ${cfg_data_dest_dir}/$2 ${cfg_data_dest_dir}/$2_before_$(date +%Y_%m_%d)
   mv $1/$2 ${cfg_data_dest_dir}
# handle cam executable
elif [[ $2 == *"cam"* ]]; then
   scp $1/$2 left:${cam_staged_dest_dir}
   if [ $? -eq 0 ]
   then
      printf "Success: scp of ${2} to the left camera.\n"
   else
      printf "Failed: scp of ${2} to the left camera.\n" >&2
   fi
   scp $1/$2 right:${cam_staged_dest_dir}
   if [ $? -eq 0 ]
   then
      printf "Success: scp of ${2} to the right camera.\n"
   else
      printf "Failed: scp of ${2} to the right camera.\n" >&2
   fi
else
   printf "Skipping file: ${2}\n"
fi
