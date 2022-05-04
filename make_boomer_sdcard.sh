#!/bin/bash

# This script should be run as sudo, e.g. sudo bash make_boomer_sdcard.sh  
#   refer to: stackoverflow.com/questions/18809614/execute-a-shell-script-in-current-shell-with-sudo-permission#23506912

# NOTE: the following should be checked with advanced options in the raspberrypi-imager app
#   the advanced options dialog box is optained using CTRL-SHIFT-x
# reference for advanced options: easyprogramming.net/raspberrypi/raspberry_pi_imager_advanced_options.php
# - enable ssh AND set pi (user) password
# - set locale settings
# - skip first-run wizard
# - the wifi settings dont' matter - they will get over-written

if [ -z $2 ]; then
 printf "arg 2 (sd card, e.g. sdb or sdc) is empty\n"
 printf "usage: sudo bash make_boomer_sdcard.sh function sdcard\n"
 printf "       where function is one of <base, left, right> and sdcard is usually sdb or sdc, e.g.\n"
 printf "sudo bash make_boomer_sdcard.sh left sdb\n"
 exit 1
fi

if [ -z $1 ]; then
 printf "arg 1 (left or right or base) is empty\n"
 exit 1
fi

if [ $1 != "base" ] && [ $1 != "left" ] &&  [ $1 != "right" ] ; then
 printf "arg 1 is not one of 'base', 'left', or 'right'\n"
 exit 1
fi

# configure IP addresses to be used in dhcpcd.conf
if [ -z $3 ]; then
   # normal case (using Daves enet switch)
   eth_ip_A_B_C="192.168.0."
   if [ $1 == "base" ]; then
       eth_ip_D="42"
   elif [ $1 == "left" ]; then
       eth_ip_D="43"
   else
       eth_ip_D="44"
   fi
else
   printf "Using Tom's network addresses\n"
   eth_ip_A_B_C="10.0.1."
   if [ $1 == "base" ]; then
       eth_ip_D="102"
   elif [ $1 == "left" ]; then
       eth_ip_D="103"
   else
       eth_ip_D="104"
   fi
fi

daves_enet_ip_A_B_C_D="${eth_ip_A_B_C}40"
boom_net_ip_A_B_C="192.168.27."
base_boom_net_ip_A_B_C_D="${boom_net_ip_A_B_C}2"
left_boom_net_ip_A_B_C_D="${boom_net_ip_A_B_C}3"
right_boom_net_ip_A_B_C_D="${boom_net_ip_A_B_C}4"
spkr_boom_net_ip_A_B_C_D="${boom_net_ip_A_B_C}6"

if [ $1 == "base" ]; then
   my_boom_net_ip_A_B_C_D=${base_boom_net_ip_A_B_C_D}
elif [ $1 == "left" ]; then
   my_boom_net_ip_A_B_C_D=${left_boom_net_ip_A_B_C_D}
elif [ $1 == "right" ]; then
   my_boom_net_ip_A_B_C_D=${right_boom_net_ip_A_B_C_D}
else
   my_boom_net_ip_A_B_C_D=${spkr_boom_net_ip_A_B_C_D}
fi

mount_root_dir="/media/rootfs"
mount_boot_dir="/media/boot"
user_id="pi"
source_dir="/home/${user_id}/repos/boomer_supporting_files"
binaries_dir="/home/${user_id}/boomer/staged/"

ping -c 1 -q github.com > /dev/null
if [ $? -ne 0 ]; then
   printf "Failed: couldn't ping github (required for driver download)\n" >&2
   exit 1
fi

if [ ! -d ${mount_root_dir} ]; then
   # create mount directory - ignore errors
   mkdir ${mount_root_dir}
fi

mount /dev/${2}2 ${mount_root_dir}
if [ $? -eq 0 ]; then
   printf "OK: mount /dev/${2}2 ${mount_root_dir}\n"
else
   printf "Failed: mount /dev/${2}2 ${mount_root_dir}\n" >&2
   exit 1
fi

cd ${mount_root_dir}/etc
if [ $? -eq 0 ]; then
   printf "OK: cd ${mount_root_dir}/etc\n"
else
   printf "Failed: cd ${mount_root_dir}/etc\n" >&2
   exit 1
fi

# change hostname
sed -i "s/raspberrypi/${1}/g" hostname
sed -i "s/raspberrypi/${1}/g" hosts
#add host IPs:
echo "${base_boom_net_ip_A_B_C_D}    base" >> hosts
echo "${left_boom_net_ip_A_B_C_D}    left" >> hosts
echo "${right_boom_net_ip_A_B_C_D}    right" >> hosts
echo "${spkr_boom_net_ip_A_B_C_D}    spkr" >> hosts
echo "${daves_enet_ip_A_B_C_D}    daves" >> hosts

if [ -e dhcpcd.conf ]; then
   mv dhcpcd.conf dhchpcd.conf-original
fi
cp ${source_dir}/dhcpcd_template.conf dhcpcd.conf
sed -i "s/my_eth0_ip/${eth_ip_A_B_C}${eth_ip_D}/g" dhcpcd.conf
sed -i "s/my_router_ip/${eth_ip_A_B_C}1/g" dhcpcd.conf
# builtin wpa is disabled on camera & spkr RPi; so configure wpa0
# the base uses the built-in wpa0 to connect to nearby WiFi, use dhcp for wlan0
#   and use wlan1 to host BOOM_NET
if [ $1 == "base" ]; then
   # remove wlan0 config in order to use dhcp
   sed -i "s/^.*wlan0.*//g" dhcpcd.conf
   echo "interface wlan1" >> dhcpcd.conf
   echo "  static ip_address=${base_boom_net_ip_A_B_C_D}/24" >> dhcpcd.conf
   echo "  nohook wpa_supplicant" >> dhcpcd.conf
else
   sed -i "s/my_wlan0_ip/${my_boom_net_ip_A_B_C_D}/g" dhcpcd.conf
fi

if [ -e wpa_supplicant/wpa_supplicant.conf ]; then
   mv wpa_supplicant/wpa_supplicant.conf wpa_supplicant/wpa_supplicant.conf-original
fi

if [ $1 == "base" ]; then
   cp -v ${source_dir}/wpa_supplicant_base.conf wpa_supplicant/wpa_supplicant.conf
else
   cp -v ${source_dir}/wpa_supplicant.conf wpa_supplicant/wpa_supplicant.conf
fi

# put i2c-dev in /etc/modules file (this is usually done with raspi-config)
# sed /etc/modules -i -e "s/^#[[:space:]]*\(i2c[-_]dev\)/\1/"
echo "i2c-dev" >> /etc/modules
# the following is in raspi-config, but doesn't appear to be necessary:
# BLACKLIST=/etc/modprobe.d/raspi-blacklist.conf
# if ! [ -e $BLACKLIST ]; then
#     touch $BLACKLIST
#   fi
# sed $BLACKLIST -i -e "s/^\(blacklist[[:space:]]*i2c[-_]bcm2708\)/#\1/"

#the following is unnecessary to disable swap, using: systemctl disable dphys-swapfile.service
#sed -i "s/CONF_SWAPSIZE=100/CONF_SWAPSIZE=0/" dphys-swapfile

# fix locale
sed -i "s/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" locale.gen
#in after_boot.sh:  sudo locale-gen; sudo update-locale en_US.UTF-8

# setup boomer directories and files
cd ${mount_root_dir}/home/${user_id}
sudo -u ${user_id} ln -s ${source_dir}/.bash_aliases
sudo -u ${user_id} mkdir .ssh
sudo -u ${user_id} mkdir boomer
cd boomer
sudo -u ${user_id} mkdir staged
sudo -u ${user_id} mkdir execs
sudo -u ${user_id} mkdir logs
sudo -u ${user_id} mkdir script_logs
sudo -u ${user_id} mkdir this_boomers_data #holds cam_params, other config data
sudo -u ${user_id} ln -s ${source_dir}/scp_log.sh
sudo -u ${user_id} ln -s ${source_dir}/change_version.sh
sudo -u ${user_id} ln -s ${source_dir}/process_staged_files.sh

#make boomer.service to start cam automatically
cd ${mount_root_dir}/home/${user_id}
sudo -u ${user_id} mkdir -p .config/systemd/user
if [ $1 == "base" ]; then
   sudo -u ${user_id} cp -p ${source_dir}/base_boomer.service .config/systemd/user/boomer.service
   sudo -u ${user_id} cp -p ${source_dir}/base_gui.service .config/systemd/user/base_gui.service
else 
   sudo -u ${user_id} cp -p ${source_dir}/cam_boomer.service .config/systemd/user/boomer.service
fi
# have linux delete logs on start-up:
sed -i "s/^exit 0$/rm \/home\/pi\/boomer\/logs\/*\n\nexit 0/" ${mount_root_dir}/etc/rc.local

# install supporting files & arducam driver
cd ${mount_root_dir}/home/${user_id}
sudo -u ${user_id} mkdir repos; cd repos

# copying boomer_supporting_files instead of cloning to avoid authentication
sudo -u ${user_id} cp -r ${source_dir} .
# sudo -u ${user_id} git clone https://github.com/davidcjordan/boomer_supporting_files

# can't install arducam repository with this script - it's too big, since it's before the 
#   initial boot resizes the root partition to fill the sd-card
# install 5G usb-wifi adapter driver; it will be built with the after-boot script
sudo -u ${user_id} git clone https://github.com/morrownr/88x2bu.git
sudo -u ${user_id} git clone https://github.com/morrownr/88x2bu-20210702
cd 88x2bu-20210702
./ARM_RPI.sh

if [ $1 == "left" ] || [$1 == "right"]; then
   cp -v ${binaries}/bcam.out ${mount_root_dir}${binaries}
   cp -v ${binaries}/dat2png.out ${mount_root_dir}${binaries}
fi

#cd out of the mounted file system before un-mounting
cd
umount ${mount_root_dir}


#/boot/config.txt - enable camera (start_x), i2c, disable built-in Wifi
if [ ! -d ${mount_boot_dir} ]; then
   # create mount directory - ignore errors
   mkdir ${mount_boot_dir}
fi

mount /dev/${2}1 ${mount_boot_dir}
if [ $? -eq 0 ]
then
   printf "OK: mount /dev/${2}1 ${mount_boot_dir}\n"
else
   printf "Failed: mount /dev/${2}1 ${mount_boot_dir}\n" >&2
   exit 1
fi

sed -i "s/#dtparam=i2c_arm=on/dtparam=i2c_arm=on/" ${mount_boot_dir}/config.txt
echo "" >> ${mount_boot_dir}/config.txt
echo "#boomer" >> ${mount_boot_dir}/config.txt

if [ $1 != "base" ]; then
   echo "dtoverlay=disable-wifi" >> ${mount_boot_dir}/config.txt
   echo "dtparam=i2c_vc=on" >> ${mount_boot_dir}/config.txt
   echo "start_x=1" >> ${mount_boot_dir}/config.txt
   echo "#gpu_mem=128" >> ${mount_boot_dir}/config.txt
   echo "dtoverlay=pwm" >> ${mount_boot_dir}/config.txt
fi
if [ $1 == "base" ]; then
   echo "hdmi_group=2" >> ${mount_boot_dir}/config.txt
   echo "#mode 28 is 1280x800" >> ${mount_boot_dir}/config.txt
   echo "hdmi_mode=28" >> ${mount_boot_dir}/config.txt
   echo "dtoverlay=uart2" >> ${mount_boot_dir}/config.txt
fi

cd
umount ${mount_boot_dir}

printf "Done with make_boomer_sdcard (success) >> run after_boot.sh after the sdcard is booted.\n"
