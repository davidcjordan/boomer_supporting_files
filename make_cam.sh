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
 printf "arg 1 (left or right) is empty\n"
 exit 1
fi

# configure IP addresses to be used in dhcpcd.conf
if [ -z $3 ]; then
   # normal case (using Daves enet switch)
   eth_ip_A_B_C="192.168.0."
   if [ $1 == "left" ]; then
       eth_ip_D="43"
   else
       eth_ip_D="44"
   fi
else
   # testing on Tom's network
   eth_ip_A_B_C="10.0.1."
   if [ $1 == "left" ]; then
       eth_ip_D="103"
   else
       eth_ip_D="104"
   fi
fi
if [ $1 == "left" ]; then
      boom_net_ip_A_B_C_D="192.168.27.3"
else
      boom_net_ip_A_B_C_D="192.168.27.4"
fi

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
#add host IPs:
echo "192.168.27.2    base" >> hosts
echo "192.168.27.3    left" >> hosts
echo "192.168.27.4    right" >> hosts
echo "192.168.0.40    daves" >> hosts
#echo "192.168.0.42    base" >> hosts
#echo "192.168.0.43    left" >> hosts
#echo "192.168.0.44    right" >> hosts

if [ -e dhcpcd.conf ]; then
   mv dhcpcd.conf dhchpcd.conf-original
fi
cp ${source_dir}/dhcpcd_template.conf dhcpcd.conf
sed -i "s/my_eth0_ip/${eth_ip_A_B_C}${eth_ip_D}/g" dhcpcd.conf
sed -i "s/my_router_ip/${eth_ip_A_B_C}1/g" dhcpcd.conf
sed -i "s/my_wlan0_ip/${boom_net_ip_A_B_C_D}/g" dhcpcd.conf

if [ -e wpa_supplicant/wpa_supplicant.conf ]; then
   mv wpa_supplicant/wpa_supplicant.conf wpa_supplicant/wpa_supplicant.conf-original
fi
cp ${source_dir}/wpa_supplicant.conf wpa_supplicant/wpa_supplicant.conf

# generate the en_US locate to avoid a login warning
sed -i "s/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" etc/locale.gen
#in after_boot.sh:  sudo locale-gen; sudo update-locale en_US.UTF-8

# setup boomer directories and files
cd ${mount_root_dir}/home/${user_id}
sudo -u ${user_id} cp -p ${source_dir}/.bash_aliases .
sudo -u ${user_id} mkdir .ssh
sudo -u ${user_id} mkdir boomer
cd boomer
sudo -u ${user_id} mkdir staged
sudo -u ${user_id} mkdir execs
sudo -u ${user_id} mkdir logs
sudo -u ${user_id} mkdir script_logs
sudo -u ${user_id} cp -p ${source_dir}/scp_log.sh .
sudo -u ${user_id} cp -p ${source_dir}/change_version.sh .

#make boomer.service to start cam automatically
cd ${mount_root_dir}/home/${user_id}
sudo -u ${user_id} mkdir this_boomers_data #holds cam_params, shottable, other config data
sudo -u ${user_id} mkdir -p .config/systemd/user
sudo -u ${user_id} cp -p ${source_dir}/cam_boomer.service .config/systemd/user/boomer.service

# have linux delete logs on start-up:
sed -i "s/exit 0/rm \/home\/pi\/boomer\/logs\/*\n\nexit 0/" ${mount_root_dir}/etc/rc.local

# install the libraries needed by the cam (opencv & arducam)
#cd /usr/lib
#cp -p ${source_dir}/cam_libs.tar .
#tar -xf cam_libs.tar.gz

# install supporting [install] files & usb-wifi adapter driver
cd ${mount_root_dir}/${HOME}
sudo -u $USER mkdir repos; cd repos
sudo -u $USER git clone https://github.com/davidcjordan/boomer_supporting_files
sudo -u $USER git clone https://github.com/morrownr/88x2bu.git
cd 88x2bu
./raspi32.sh

#cd out of the mounted file system before un-mounting
cd
umount ${mount_root_dir}

#/boot/config.txt - enable camera (start_x), i2c, disable built-in Wifi
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
echo "dtoverlay=disable-wifi" >> ${mount_boot_dir}/config.txt
echo "dtparam=i2c_vc=on" >> ${mount_boot_dir}/config.txt
echo "start_x=1" >> ${mount_boot_dir}/config.txt
echo "gpu_mem=128" >> ${mount_boot_dir}/config.txt
echo "dtoverlay=pwm" >> ${mount_boot_dir}/config.txt

cd
umount ${mount_boot_dir}

printf "Done with make_cam (success) >> run cam_after_boot.sh after the sdcard is booted.\n"
