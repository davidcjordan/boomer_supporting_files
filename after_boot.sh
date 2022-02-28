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
sudo apt update && sudo apt upgrade

# enable i2c (creates /dev/i2c-0 -1)
sudo modprobe i2c-dev

# build & install the wifi-driver
sudo apt --yes install dkms
cd ~/repos/88x2bu-20210702
sudo ./install-driver.sh NoPrompt

# use vi as an editor for crontab
update-alternatives --auto vi --quiet

# install and configure incron
sudo apt --yes install incron
if [ $? -eq 0 ]; then
   printf "Failed: sudo apt install incron\n"
fi

# allow pi to use setcap
echo "${USER} ALL=(ALL:ALL) NOPASSWD: /usr/sbin/setcap" | sudo tee -a /etc/sudoers

#add pi as a user
echo "${USER}" | sudo tee -a /etc/incron.allow 

# configure incron table entries:
if ${is_camera}; then
   incrontab ${source_dir}/incrontab_cam.txt
else
  incrontab ${source_dir}/incrontab_base.txt
fi

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
   sudo systemctl stop systemd-timesyncd.service
   sudo systemctl disable systemd-timesyncd.service
fi

# need to transfer in executables and set up
systemctl --user enable boomer.service

# fix locale warning
sudo locale-gen
sudo update-locale en_US.UTF-8
# sudo locale-gen --purge --no-archive 
# sudo update-initramfs -u

sudo apt --yes install git
sudo apt --yes install i2c-dev

# load arducam shared library (.so), which requires opencv shared libraries installed first
if ${is_camera}; then
   sudo apt --yes install libzbar-dev libopencv-dev
   cd ~/repos
   git clone https://github.com/ArduCAM/MIPI_Camera.git
   cd MIPI_Camera/RPI/; make install
fi

GITHUB_USER=davidcjordan
if [ $(hostname) == 'base' ]; then
   sudo apt --yes install hostapd; sudo systemctl stop hostapd
   sudo apt --yes install dnsmasq; sudo systemctl stop dnsmasq
   sudo mv /etc/hostapd/hostapd.conf /etc/hostapd/hostapd.conf.orig
   sudo cp ${source_dir}/hostapd.conf /etc/hostapd
   sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig
   sudo cp ${source_dir}/dnsmasq.conf /etc/dnsmasq.conf
   # install stuff for python web-server
   python3 -m pip install flask-socketio
   python3 -m pip install eventlet

   cd ~/boomer
   git clone https://github.com/${GITHUB_USER}/drills

   cd ~/repos
   git clone https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com/${GITHUB_USER}/control_ipc_utils
   git clone https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com/${GITHUB_USER}/ui-webserver
   ./ui-webserver/make-links.sh
fi

printf "\n  Success - the sd-card has been configured.\n"
printf "    HOWEVER: bcam or bbase.out and the cam_params have to be loaded.\n"
