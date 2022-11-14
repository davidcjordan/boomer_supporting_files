#!/bin/bash
#timedatectl set-time "$(ssh pi@base date +%Y-%m-%d%t%H:%M:%S)"
sudo date --set="$(ssh pi@base date +%Y%m%d%t%H:%M:%S)"

   #*/1 * * * * timedatectl set-time "$(ssh base date '+%Y-%m-%d%t%H:%M:%S')"  > /home/pi/boomer/script_logs/set_date_daily.log 2>&1 | logger -t mycmd
#hour:min:seconds didn't get set with the following due to some delimiter problem:
#@daily date --set="$(ssh base date +%Y%m%d%t%H:%M:%S)" > /home/pi/boomer/script_logs/set_date_daily.log 2>&1 | logger -t mycmd

