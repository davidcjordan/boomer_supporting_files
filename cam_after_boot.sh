#!/bin/bash
ssh-keygen -t rsa -f /home/{user}/.ssh/id_rsa -q -N ""
if [ $? -eq 0 ]; then
   printf "OK: ssh-copy-id pi@192.168.27.2\n"
else
   printf "Failed: ssh-keygen\n" >&2
   exit 1
fi
ssh-copy-id pi@192.168.27.2
if [ $? -eq 0 ]; then
   printf "OK: ssh-copy-id pi@192.168.27.2\n"
else
   printf "Failed: ssh-copy-id pi@192.168.27.2\n" >&2
   exit 1
fi
# add daves rpi
ssh-copy-id pi@192.168.0.40
if [ $? -eq 0 ]; then
   printf "OK: ssh-copy-id pi@192.168.0.40\n"
else
   printf "Failed: ssh-copy-id pi@192.168.0.40\n" >&2
   exit 1
fi

# build & install the wifi-driver
sudo apt install -y dkms
sudo ./install-driver.sh

systemd --user enable boomer.service

#how to do the following (needs to boot from the sd-card in order to perform the edits
# install and configure incron
sudo apt-get install incron
if [ $? -need 0 ]; then
   printf "Failed: ssudo apt-get install incron\n"
fi
# use vi as an editor for crontab
update-alternatives --auto vi --quiet
#add pi as a user
sudo vi /etc/incron.allow 
# add incrobtab to add entries:
incrontab -e
