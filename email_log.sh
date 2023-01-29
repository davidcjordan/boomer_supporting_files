#!/bin/bash

# emails the portion of boomer.log from the "==== Last opened"

log_file="/run/shm/boomer.log"

last_opened_line_number=$(grep -n "====" /run/shm/boomer.log | tail -1 | cut -d ":" -f1)
last_line_number=$(wc -l /run/shm/boomer.log | cut -f1 -d" ")
lines_to_tail=$(expr $last_line_number - $last_opened_line_number + 1)
# printf "last_line_opened=%d last_line=%d lines_to_tail=%d\n" $last_opened_line_number $last_line_number $lines_to_tail

# subject=$(grep -n "====" /run/shm/boomer.log | tail -1 | cut -d ":" -f2)
echo -n "Enter what went wrong (will be the subject): " 
read subject

tail -$lines_to_tail $log_file | mutt -s "$subject" -- roi.co.4444@gmail.com

if [ $? -ne 0 ]; then
  printf "failed to send log email\n"
fi
