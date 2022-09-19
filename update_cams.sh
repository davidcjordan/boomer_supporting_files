#!/bin/bash

printf "If successful, the script will print: '1 OK; 2 OK; 3 OK; 4 OK' on the following line:\n"

scp -pq /home/pi/repos/boomer_supporting_files/scp_log.sh left:/home/pi/repos/boomer_supporting_files
if [ $? -eq 0 ]; then
   printf "1 OK; "
else
   printf "\n1 FAILED (scp of scp_log.sh to left).\n"
fi

scp -pq /home/pi/repos/boomer_supporting_files/scp_log.sh right:/home/pi/repos/boomer_supporting_files
if [ $? -eq 0 ]; then
   printf "2 OK; "
else
   printf "\n2 FAILED (scp of scp_log.sh to right).\n"
fi

scp -pq /home/pi/repos/boomer_supporting_files/ssh_config.txt left:/home/pi/.ssh/config
if [ $? -eq 0 ]; then
   printf "3 OK; "
else
   printf "\n3 FAILED (scp of ssh_config.txt to left).\n"
fi

scp -pq /home/pi/repos/boomer_supporting_files/ssh_config.txt right:/home/pi/.ssh/config
if [ $? -eq 0 ]; then
   printf "4 OK\n"
else
   printf "\n4 FAILED (scp of ssh_config.txt to right).\n"
fi
