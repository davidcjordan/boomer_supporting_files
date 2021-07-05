#!/bin/bash

pipe=/run/shm/audio_file_fifo
audio_path=/home/pi/boomer/audio

#trap "rm -f $pipe" EXIT

if [[ ! -p $pipe ]]; then
    mkfifo $pipe
fi

while true
do
    if read line <$pipe; then
        if [[ "$line" == 'quit' ]]; then
            break
        fi
        printf "playing: %s\n" $line
        aplay --quiet $audio_path/$line
    fi
done

echo "Reader exiting"
