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

if [ $(hostname) == 'base' ]; then
   is_base=1
else
   is_base=0
fi
printf "set is_base to %d.\n" $is_base

#rsync creates temporary dot (.) files unless the -T=/run/shm is used
if [[ $2 == "."* ]]
then
   printf "Skipping file: %s.\n" $1/$2
   exit 0
fi

# handle cam parameter files
if [[ $2 == *"cam_param"* ]]; then
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
   exit 0
fi

# scp cam executables
if ${is_base}; then
   if [[ $2 == *"cam"* ]] || [[ $2 == *"dat2png"* ]]; then
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
         exit 0
      else
         printf "Failed: scp of ${2} to the right camera.\n" >&2
         exit 1
      fi
   fi
   exit 0
fi

# copy other executables (bbase, cam, dat2png, gen_cam_params)
if [[ $2 == *"out"* ]]; then
   if [[ $2 == *"dat2png"* ]] || [[ $2 == *"gen_cam_params"* ]]; then
      cp -v $1/$2 /home/${USER}/boomer/execs/
   else
      # the following is necessary for systectl to be called when the script is from from incron
      export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/1000/bus"

      systemctl --user stop boomer.service
      if [ $? -eq 0 ]
      then
         printf "boomer service stopped.\n"
      else
         printf "process_staged_files.sh: Failure on boomer.service stop.\n"  >&2
         exit 1
      fi

      boomer_pid=$(pgrep bbase)
      if [ $boomer_pid != '' ]; then
         printf "killing pid=%s\n" $boomer_pid
         sudo kill -9 $boomer_pid
      fi

      sudo -u root -g sudo setcap 'cap_sys_nice=eip' $1/$2
      #/usr/sbin/setcap 'cap_sys_nice=eip' $1
      if [ $? -eq 0 ]
      then
         printf "priority capabilities set on: %s\n" $1/$2
      else
         printf "change_versions.sh: Failure on setcap 'cap_sys_nice=eip for: %s\n" $1/$2 >&2
         exit 1
      fi

      # chmod should be unnecessary with scp -p or rsync -E
      chmod +x $1/$2
      if [ $? -eq 0 ]
      then
         printf "+x set on: %s\n" $1/$2
      else
         printf "change_versions.sh: Failure on chmod +x for: %s\n" $1/$2 >&2
         exit 1
      fi
      mv $1/$2 /home/${USER}/boomer/execs/
      if [ $? -eq 0 ]
      then
         printf "Success: mv of %s to /home/pi/boomer/execs.\n" $1
         # uncomment the following when running interactively (vs by systemd)
         # exit 0
      else
         printf "Failed: mv of %s to /home/pi/boomer/execs.\n" $1 >&2
         exit 1
      fi
      systemctl --user start boomer.service
      if [ $? -eq 0 ]
      then
         printf "boomer service started.\n"
         exit 0
      else
         printf "process_staged_files.sh: Failure on boomer.service start.\n"  >&2
         exit 1
      fi
   fi
fi

#should have exited by now...
printf "Skipping file: ${2}\n"
