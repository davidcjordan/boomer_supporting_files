#!/bin/bash

if [ -z $1 ]
then
 echo "arg 1 (file to scp) is empty"
 exit 1
fi

LineNum=0 
input_file=/home/pi/boomer/pswd
# read file line by line and store in $line
while IFS="" read -r line
do
  case $LineNum in
   0)
      #echo "pswd: $line" ;;
      pswd=$line ;;
   1)
      #echo "user: $line" ;;
      user=$line ;;
   2)
      #echo "IP: $line" ;;
      IP=$line ;;
   3)
      #echo "dest: $line" ;;
      dest=$line ;;
  esac
  ((LineNum++))
done < "$input_file"

#echo "sshpass -f ${input_file} scp $1 ${user}@${IP}:${dest}"
#exit 0

# the following is when enet is connected:
scp "$1" pi@192.168.28.40:/home/pi/boomer/logs/
# the following is to transfer to the base, which will relay them to dave
#scp "$1" pi@192.168.27.2:/home/pi/boomer/logs/
if [ $? -eq 0 ]
then
  echo "The script ran ok"
  #rm "$TARGET/$FILENAME"
else
  echo "The script failed" >&2
  exit 1
fi
