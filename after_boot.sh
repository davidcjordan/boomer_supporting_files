#!/bin/bash
# ssh keys:
# cam: key copied to base, daves
# base: key copied to cams, daves, speaker
# daves: key copied base, cams, speaker

if [ -z "${GITHUB_TOKEN}" ]; then 
   echo "type: 'export GITHUB_TOKEN=something' before running script"; 
   exit 1
fi

if [ $(hostname) == 'left' ] || [ $(hostname) == 'right' ]; then
   is_camera=1
else
   is_camera=0
fi

#NOTE: if you name id_rsa something else then make a ln -s to id_rsa;
#   ssh defaults to the filename id_rsa
ssh-keygen -t rsa -f ${HOME}/.ssh/id_rsa -q -N ""
if [ $? -eq 0 ]; then
   printf "OK: ssh-copy-id pi@192.168.27.2\n"
else
   printf "Failed: ssh-keygen\n" >&2
   exit 1
fi
# add base rpi to transfer log fils over wifi
#ssh-copy-id base
printf "!!Skipping ssh-copy-id base"
if [ $? -eq 0 ]; then
   printf "OK: ssh-copy-id pi@192.168.27.2\n"
else
   printf "Failed: ssh-copy-id pi@192.168.27.2\n" >&2
   #exit 1
fi
# add daves rpi to transfer log fils over enet
#ssh-copy-id daves
printf "!!Skipping ssh-copy-id daves"
if [ $? -eq 0 ]; then
   printf "OK: ssh-copy-id pi@192.168.0.40\n"
else
   printf "Failed: ssh-copy-id pi@192.168.0.40\n" >&2
   #exit 1
fi

source_dir="/home/${USER}/repos/boomer_supporting_files"

#enable wifi:
sudo raspi-config nonint do_wifi_country US
rfkill unblock wifi

# without update, then install libopencv will fail
sudo apt update && sudo apt --yes upgrade

# enable i2c (creates /dev/i2c-0 -1)
sudo modprobe i2c-dev

# build & install the wifi-driver
sudo apt --yes install dkms
cd ~/repos/88x2bu-20210702
sudo ./install-driver.sh NoPrompt

# use vi as an editor for crontab
# for more info: https://askubuntu.com/questions/891928/how-can-i-add-my-desired-editor-to-the-update-alternatives-interactive-menu
sudo update-alternatives --set editor /usr/bin/vim.tiny

# install and configure incron
sudo apt --yes install incron
if [ $? -eq 0 ]; then
   printf "Failed: sudo apt install incron\n"
fi

# allow pi to use setcap and to set the date
# for more info: https://www.digitalocean.com/community/tutorials/how-to-edit-the-sudoers-file
#  and https://linux.die.net/man/5/sudoers
scap_rule_filename="/etc/sudoers.d/011_pi-setcap"
sudo touch ${scap_rule_filename}
echo "${USER} ALL=(ALL:ALL) NOPASSWD: /usr/sbin/setcap" | sudo tee -a ${scap_rule_filename}
# wasn't able to have the following rule allow pi to set the date
# so setting the date is done using the root crontab
# refer to: https://unix.stackexchange.com/questions/78299/allow-a-specific-user-or-group-root-access-without-password-to-bin-date
#echo "${USER} ALL=(ALL:ALL) NOPASSWD: /bin/date" | sudo tee -a /etc/sudoers

#add pi as a user
echo "${USER}" | sudo tee -a /etc/incron.allow 

# configure incron table entries:
incrontab ${source_dir}/incrontab.txt

# disable unused services
sudo systemctl stop bluetooth.service
sudo systemctl disable bluetooth.service
sudo systemctl stop avahi-daemon.service
sudo systemctl disable avahi-daemon.service
sudo systemctl stop dphys-swapfile.service
sudo systemctl disable dphys-swapfile.service
sudo systemctl stop triggerhappy.service
sudo systemctl disable triggerhappy.service
sudo systemctl stop hciuart.service
sudo systemctl disable hciuart.service
sudo systemctl stop alsa-state.service
sudo systemctl disable alsa-state.service
if ${is_camera}; then
   printf "disabling systemd-timesyncd.service\n"
   sudo systemctl stop systemd-timesyncd.service
   sudo systemctl disable systemd-timesyncd.service
fi

# fix locale warning
sudo locale-gen
sudo update-locale en_US.UTF-8
# sudo locale-gen --purge --no-archive 
# sudo update-initramfs -u

sudo apt --yes install git
#sudo apt --yes install i2c-dev
sudo apt --yes install i2c-tools

# load arducam shared library (.so), which requires opencv shared libraries installed first
if [ $is_camera -eq 1 ]; then
   sudo apt --yes install libzbar-dev libopencv-dev
   cd ~/repos
   git clone https://github.com/ArduCAM/MIPI_Camera.git
   cd MIPI_Camera/RPI/; make install
fi

#the following is required to have the base/cam service start when not logged in
loginctl enable-linger pi
if [ $? -ne 0 ]; then
   printf "enable-linger failed.\n"
   exit 1
fi

GITHUB_USER=davidcjordan
if [ $(hostname) == 'base' ]; then
   sudo apt --yes install hostapd; sudo systemctl stop hostapd
   sudo apt --yes install dnsmasq; sudo systemctl stop dnsmasq
   sudo mv /etc/hostapd/hostapd.conf /etc/hostapd/hostapd.conf.orig
   sudo cp ${source_dir}/hostapd.conf /etc/hostapd
   sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig
   sudo cp ${source_dir}/dnsmasq.conf /etc/dnsmasq.conf
   sudo systemctl unmask hostapd.service 
   sudo apt-get install gpiod
   # install stuff for python web-server
   python3 -m pip install flask-socketio
   python3 -m pip install eventlet
   python3 -m pip install waitress
   #have chromium autostart; refer to: https://forums.raspberrypi.com/viewtopic.php?t=294014
   #  could use --kiosk mode which doesn't allow F11 to get out of full screen mode
   # need to disable the 'Restore Chromium' refer to: https://raspberrypi.stackexchange.com/questions/68734/how-do-i-disable-restore-pages-chromium-didnt-shut-down-correctly-prompt#85827
   sudo chattr +i /home/pi/.config/chromium/Default/Preferences
   echo "@chromium --start-fullscreen --disable-infobars http://localhost:1111" | sudo tee -a /etc/xdg/lxsession/LXDE-pi/autostart

   cd ~/boomer
   git clone https://github.com/${GITHUB_USER}/drills

   cd ~/repos
   git clone https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com/${GITHUB_USER}/control_ipc_utils
   git clone https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com/${GITHUB_USER}/ui-webserver
   ./ui-webserver/make-links.sh

  systemctl --user enable base_gui.service
fi

# need to transfer in executables
systemctl --user enable boomer.service

# load crontab with a command to set the date on reboot or daily: @daily date --set="$(ssh base date)
if [ $is_camera -eq 1 ]; then
   sudo crontab ${source_dir}/crontab_cam.txt
fi

printf "\n  Success - the sd-card has been configured.\n"
printf "    HOWEVER: bcam or bbase.out and the cam_params have to be loaded.\n"
