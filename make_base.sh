#!/bin/bash

# NOTE: the following should be checked with advanced options in the raspberrypi-imager app
#   the advanced options dialog box is optained using CTRL-X
# - enable ssh AND set pi (user) password
# - set locale settings
# - skip first-run wizard
# - the wifi settings dont' matter - they will get over-written

if [ -z $2 ]; then
 printf "arg 2 (device, e.g. sdb or sdc) is empty\n"
 exit 1
fi
if [ -z $1 ]; then
 printf "arg 1 (base) is empty\n"
 exit 1
fi

# configure IP addresses to be used in dhcpcd.conf
if [ -z $3 ]; then
   # normal case (using Daves enet switch)
   eth_ip_A_B_C="192.168.0."
   eth_ip_D="42"
else
   # testing on Tom's network
   eth_ip_A_B_C="10.0.1."
   eth_ip_D="102"
fi

boom_net_ip_A_B_C_D="192.168.27.2"

mount_root_dir="/media/rootfs"
mount_boot_dir="/media/boot"
user_id="pi"
source_dir="/home/${user_id}/repos/boomer_supporting_files"

ping -c 3 -q github.com
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

if [ -e dhcpcd.conf ]; then
   mv dhcpcd.conf dhchpcd.conf-original
fi
cp -p ${source_dir}/dhcpcd_template.conf dhcpcd.conf
sed -i "s/my_eth0_ip/${eth_ip_A_B_C}${eth_ip_D}/g" dhcpcd.conf
sed -i "s/my_router_ip/${eth_ip_A_B_C}1/g" dhcpcd.conf
sed -i "s/my_wlan0_ip/${boom_net_ip_A_B_C_D}/g" dhcpcd.conf
# wlan0 connects to whatever is in wpa_supplicant
# wlan1 is used by hostapd to generate BOOM_NET, hence it has the boom_net IP
sed -i "s/wlan0/wlan1/g" dhcpcd.conf
cat "    nohook wpa_supplicant" >> dhcpcd.conf
cp -p ${source_dir}/hostapd.conf .

if [ -e wpa_supplicant/wpa_supplicant.conf ]; then
   mv wpa_supplicant/wpa_supplicant.conf wpa_supplicant/wpa_supplicant.conf-original
fi
cp ${source_dir}/wpa_supplicant.conf wpa_supplicant/wpa_supplicant.conf

#disable swap
sed -i "s/CONF_SWAPSIZE=100/CONF_SWAPSIZE=0/" dphys-swapfile

# setup boomer directories and files
cd ${mount_root_dir}/home/${user_id}
sudo -u $user_id ln -s ${source_dir}/.bash_aliases
sudo -u $user_id mkdir .ssh
sudo -u $user_id mkdir boomer
cd boomer
sudo -u $user_id mkdir staged
sudo -u $user_id mkdir execs
sudo -u $user_id mkdir logs
sudo -u $user_id mkdir script_logs
sudo -u $user_id ln -s ${source_dir}/scp_log.sh .
sudo -u $user_id ln -s ${source_dir}/change_version.sh .
sudo -u $user_id ln -s ${source_dir}/process_staged_files.sh .
sudo -u git clone https://github.com/davidcjordan/drills

#make boomer.service to start cam automatically
cd ${mount_root_dir}/home/${user_id}
sudo -u $user_id mkdir this_boomers_data #holds cam_params, shottable, other config data
sudo -u $user_id mkdir -p .config/systemd/user
sudo -u $user_id cp -p ${source_dir}/base_boomer.service .config/systemd/user/boomer.service

# have linux delete logs on start-up:
sed -i "s/exit 0/rm \/home\/${user_id}\/boomer\/logs\/*\n\nexit 0/" ${mount_root_dir}/etc/rc.local

# install usb-wifi adapter driver
cd ${mount_root_dir}/home/${user_id}
sudo -u $user_id mkdir repos; cd repos
sudo -u $user_id git clone https://github.com/mdavidcjordan/boomer_supporting_files
sudo -u $user_id git clone https://github.com/morrownr/88x2bu.git
sudo -u $user_id git clone https://github.com/morrownr/88x2bu-20210702
cd 88x2bu
./raspi32.sh
# running the following has to be done when booted off the sd-card
# sudo apt install -y dkms git
# sudo ./install-driver.sh

#cd out of the mounted file system before un-mounting
cd
umount ${mount_root_dir}

#/boot/config.txt - enable camera (start_x), i2c, disable built-in Wifi
if [ ! -d ${mount_boot_dir} ]; then
   # create mount directory - ignore errors
   mkdir ${mount_boot_dir}
fi

#/boot/config.txt - enable i2c - used by the motors
mount /dev/${2}1 ${mount_boot_dir}
if [ $? -eq 0 ]
then
   printf "OK: mount /dev/${2}1 ${mount_boot_dir}\n"
else
   printf "Failed: mount /dev/${2}1 ${mount_boot_dir}\n" >&2
   exit 1
fi
sed -i "s/#dtparam=i2c_arm=on/dtparam=i2c_arm=on/" ${mount_boot_dir}/config.txt

cd
umount ${mount_boot_dir}

printf "Done with make_base (success) \n"
