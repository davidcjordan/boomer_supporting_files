#!/bin/bash

# takes a path to an exacutable, makes it runnable,, changes the symbolic link to the version
# and stop/starts the boomer service (which starts boomer_base/cam)
printf "change_versions.sh: started\n" >&2

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
if [[ $2 == "."* ]];
then
   printf "Skipping file: %s.\n" $1/$2
else
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

   #remove link that points to previous version and create new link
   rm /home/pi/boomer/bbase.out
   if [ $? -eq 0 ]
   then
     printf "bbase.out link removed\n"
   else
     printf "no bbase.out link not found.\n"
   fi


   ln -s $1/$2 /home/pi/boomer/bbase.out
   if [ $? -eq 0 ]
   then
     printf "bbase.out link to %s created.\n" $1
   else
     printf "change_versions.sh: Failure to create bbase.out link.\n"
   fi

   # the following is necessary for systectl to be called when the script is frin from incron
   export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/1000/bus"

   systemctl --user stop boomer.service
   if [ $? -eq 0 ]
   then
     printf "boomer service stopped.\n"
   else
     printf "change_versions.sh: Failure on boomer.service stop.\n"  >&2
     exit 1
   fi

   systemctl --user start boomer.service
   if [ $? -eq 0 ]
   then
     printf "boomer service started.\n"
   else
     printf "change_versions.sh: Failure on boomer.service start.\n"  >&2
     exit 1
   fi
fi
