#!/bin/bash
#printf "process_staged_files.sh: started\n" >&2

#the script requires /etc/hostnames to have the address for the left and right cams
# this script runs when files are put into the boomer/staged directory on the base
# this script only runs on the base; refer to the incrontab_base
# on the cam, the .out files are copied from the staged dir to the exec dir
#  after the mv, the change_version.sh script runs to do the setcap

cfg_data_dest_dir="${HOME}/boomer/this_boomers_data"
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

# handle cam parameter files
elif [[ $2 == *"cam_param"* ]]; then
   if [[ $2 != *"new" ]]; then
      printf "Skipping cam_param filename: ${2}\n" >&2
      exit 1
   fi
   if [[ $2 == *"left"* ]]; then
      cam="left"
   elif [[ $2 == *"right"* ]]; then
      cam="right"
   else
      printf "Unrecognized cam_param filename: ${2}\n" >&2
      exit 1
   fi
   # make a backup, then copy in new file
   cam_param_basename=$(basename -- "$2" .new)
   mv -v "${cfg_data_dest_dir}/${cam_param_basename}.txt" "${cfg_data_dest_dir}/${cam_param_basename}.before_$(date +%Y_%m_%d)"
   mv -v "$1/$2" "${cfg_data_dest_dir}/${cam_param_basename}.txt"

   scp -pq ${cfg_data_dest_dir}/${cam_param_basename}.txt ${cam}:${cfg_data_dest_dir}
   if [ $? -eq 0 ]; then
      printf "Success: scp of ${cam_param_basename}.txt to the ${cam} camera.\n"
   else
      printf "Failed: scp of ${cam_param_basename}.txt to the ${cam} camera.\n" >&2
   fi
# handle cam executable 
elif [[ $2 == *"cam"* ]] || [[ $2 == *"dat2png"* ]]; then
   scp -pq $1/$2 left:${cam_staged_dest_dir}
   if [ $? -eq 0 ]
   then
      printf "Success: scp of ${2} to the left camera.\n"
   else
      printf "Failed: scp of ${2} to the left camera.\n" >&2
   fi
   scp -pq $1/$2 right:${cam_staged_dest_dir}
   if [ $? -eq 0 ]
   then
      printf "Success: scp of ${2} to the right camera.\n"
   else
      printf "Failed: scp of ${2} to the right camera.\n" >&2
   fi
# copy other executables (bbase, gen_cam_params)
elif [[ $2 == *"out"* ]]; then
   cp -v $1/$2 /home/${USER}/boomer/execs/
   if [ $? -eq 0 ]
   then
      printf "Success: cp of %s to /home/pi/boomer/execs.\n" $1
   else
      printf "Failed: cp of %s to /home/pi/boomer/execs.\n" $1 >&2
   fi
else
   printf "Skipping file: ${2}\n"
fi
