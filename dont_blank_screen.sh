#!/bin/sh
printf "Running xset to turn off blanking..."
# refer to: https://superuser.com/questions/644804/disable-screensaver-screen-blank-via-command-line#644829
#xset -version
export DISPLAY=:0.0
sleep 10
xset s off
xset s noblank
xset -dpms

# add this to crontab: @reboot sh /home/pi/boomer/dont_blank_screen.sh > /home/pi/boomer/script_logs/dont_blank_screen.log 2>&1