alias bstart='systemctl --user start boomer.service'
alias bstop='systemctl --user stop boomer.service'
alias bstat='systemctl --user status boomer.service'
alias blog='tail -f /run/shm/boomer.log'
alias clog='rm /run/shm/boomer.log'
alias scap='function _scap(){ sudo setcap "cap_sys_nice=eip" $1; };_scap'
alias bps='ps -e | grep -E --color=none cam\|base'
alias temp='/usr/bin/vcgencmd measure_temp'

#alias basesync='scp /home/pi/boomer/staged/base*.out pi@base:/home/pi/boomer/staged'
#alias bcamsync='scp /home/pi/boomer/staged/bcam*.out pi@base:/home/pi/boomer/staged'
alias basesync='~/repos/boomer_supporting_files/basesync.sh'
alias bcamsync='~/repos/boomer_supporting_files/basesync.sh'

alias drillsync='rsync -avhe ssh --del --exclude=.git --exclude=__pycache__ ~/repos/drills base:repos'
alias bclean='rm -v /home/pi/repos/launcher/build/CMakeFiles/*/*.o; rm -v /home/pi/repos/boomer_cam/build/CMakeFiles/*/*.o'

alias uistop='systemctl --user stop base_gui.service'
alias uistart='systemctl --user start base_gui.service'
alias uistat='systemctl --user status base_gui.service'

alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias grep='grep --color=auto'
alias ls='ls --color=auto'
alias pulse16='sudo sh -c '\''cd /sys/class/pwm/pwmchip0; echo 0 > export; cd pwm0; echo 16688200 > period; echo 8000000 > duty_cycle; echo 1 > enable'\'''
alias pulse21='sudo sh -c '\''cd /sys/class/pwm/pwmchip0; echo 0 > export; cd pwm0; echo 21000000 > period; echo 8000000 > duty_cycle; echo 1 > enable'\'''

#alias getpngs='scp left:/run/shm/frame_even.png /home/pi/boomer/logs/left_frame_even.png; scp left:/run/shm/frame_odd.png /home/pi/boomer/logs/left_frame_odd.png;scp right:/run/shm/frame_even.png /home/pi/boomer/logs/right_frame_even.png;scp right:/run/shm/frame_odd.png /home/pi/boomer/logs/right_frame_odd.png'
#alias getdats='scp left:/run/shm/frame_even.dat /home/pi/boomer/logs/left_frame_even.dat; scp left:/run/shm/frame_odd.dat /home/pi/boomer/logs/left_frame_odd.dat;scp right:/run/shm/frame_even.dat /home/pi/boomer/logs/right_frame_even.dat;scp right:/run/shm/frame_odd.dat /home/pi/boomer/logs/right_frame_odd.dat'

alias pic2="ssh pi@base-2 'cd /tmp; scp left:/run/shm/frame_even.png frame.png; convert -resize 75% frame.png frame.jpeg'; scp pi@base-2:/tmp/frame.jpeg .; gpicview frame.jpeg"
alias pic1="ssh pi@base-1 'cd /tmp; scp left:/run/shm/frame_even.png frame.png; convert -resize 75% frame.png frame.jpeg'; scp pi@base-1:/tmp/frame.jpeg .; gpicview frame.jpeg"

alias stopall='ssh left systemctl --user stop boomer.service; ssh right systemctl --user stop boomer.service; ssh spkr systemctl --user stop boomer.service; systemctl --user stop boomer.service; pkill -o chromium; systemctl --user stop base_gui.service'
alias haltall='ssh left sudo halt; ssh right sudo halt; ssh spkr sudo halt; sudo halt'

alias uiv='cd ~/repos/ui-webserver; . venv/bin/activate'
#alias uig='gunicorn -k eventlet -b 0.0.0.0:1111 "app:create_app()"'
alias uig='gunicorn --config gunicorn.conf.py --log-config gunicorn_log.conf "app:create_app()"'

alias swap-lines-12='sed -i '\''1{h;d};2{x;H;x}'\'''

alias ttab='lxterminal --tabs=daves,base,left --geometry=128x80 --title=BOOMER_TERMINALS'

tstat() { tailscale status --self=false | awk -v OFS="\t" '$1=$1' | cut -f 2,5; }