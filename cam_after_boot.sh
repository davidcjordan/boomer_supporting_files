#!/bin/bash
# ssh keys:
# cam: keys goto base, daves
# base: keys goto cams, daves, speaker
# daves: keys toto base, cams, speaker

ssh-keygen -t rsa -f ${HOME}/.ssh/${HOSTNAME}_id_rsa -q -N ""
if [ $? -eq 0 ]; then
   printf "OK: ssh-copy-id pi@192.168.27.2\n"
else
   printf "Failed: ssh-keygen\n" >&2
   exit 1
fi
# add base rpi to transfer log fils over wifi
ssh-copy-id -i ${HOME}/.ssh/${HOSTNAME}_id_rsa base
if [ $? -eq 0 ]; then
   printf "OK: ssh-copy-id pi@192.168.27.2\n"
else
   printf "Failed: ssh-copy-id pi@192.168.27.2\n" >&2
   exit 1
fi
# add daves rpi to transfer log fils over enet
ssh-copy-id daves
if [ $? -eq 0 ]; then
   printf "OK: ssh-copy-id pi@192.168.0.40\n"
else
   printf "Failed: ssh-copy-id pi@192.168.0.40\n" >&2
   exit 1
fi

# build & install the wifi-driver
sudo apt install -y dkms
cd ~/repos/88x2bu
sudo ./install-driver.sh

# use vi as an editor for crontab
update-alternatives --auto vi --quiet

# install and configure incron
sudo apt install incron
if [ $? -need 0 ]; then
   printf "Failed: sudo apt install incron\n"
fi

# allow pi to use setcap
echo "${USER} ALL=(ALL:ALL) NOPASSWD: /usr/sbin/setcap" | sudo tee -a /etc/sudoers

#add pi as a user
echo "${USER}" | sudo tee -a /etc/incron.allow 

# configure incron table entries:
incrontab ${source_dir}/incrontab_cam.txt 

sudo systemctl stop bluetooth
sudo systemctl disable bluetooth

# need to transfer in executables and set up
systemd --user enable boomer.service

