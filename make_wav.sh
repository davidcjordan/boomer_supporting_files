#!/bin/bash

printf "make_wav.sh started on  $(date): arg1=$1 arg2=$2\n"
if [ -z $1 ]
then
 printf "arg 1 (path to file) is empty\n"
 exit 1
fi

if [ -z $2 ]
then
 printf "arg 2 (filename to file) is empty\n"
 exit 1
fi

extension="${2##*.}"
if [ $extension != "mp3" ] && [ $extension != "MP3" ]; then
 printf "skipping handling of file: $2\n"
 exit 0
fi

mpg123 -vm2 -w "/home/pi/boomer/audio/${2%.mp3}.WAV" $1/$2
if [ $? -ne 0 ]
then
  printf "wav to mp3 conversion failed for: $1/$2\n" >&2
  exit 1
fi
