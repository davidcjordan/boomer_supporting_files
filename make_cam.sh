#!/bin/bash

if [ -z $2 ]; then
 printf "arg 2 (device, e.g. sdb or sdc) is empty"
 exit 1
fi
if [ -z $1 ]; then
 printf "arg 1 (left or right) is empty"
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
source_dir="~/repos/boomer_supporting_files"

if [ ! -d ${mount_root_dir} ]; then
   # create mount directory - igno
   mkdir ${mount_root_dir}
fi

mount /dev/${2}2 ${mount_root_dir}
if [ $? -eq 0 ]
then
   printf "OK: mount /dev/${2}2 ${mount_root_dir}\n"
else
   printf "Failed: mount /dev/${2}2 ${mount_root_dir}\n" >&2
   exit 1
fi

cd ${mount_root_dir}/etc
if [ $? -eq 0 ]
then
   printf "OK: cd ${mount_root_dir}/etc\n"
else
   printf "Failed: cd ${mount_root_dir}/etc\n" >&2
   exit 1
fi

# change hostname
sed -i 's/raspberrypi/$1/g' hostname
sed -i 's/raspberrypi/$1/g' hosts

mv dhcpcd.conf dhchpcd.conf-original
cp ${source_dir}/cam_dhcpcd.conf dhcpcd.conf
sed -i 's/my_eth0_ip/${eth_ip_A_B_C}${eth_ip_D}/g' dhcpcd.conf
sed -i 's/my_router_ip/${eth_ip_A_B_C}1/g' dhcpcd.conf
sed -i 's/my_wlan0_ip/${boom_net_ip_A_B_C_D}/g' dhcpcd.conf

mv wpa_supplicant/wpa_supplicant.conf wpa_supplicant/wpa_supplicant.conf-original
cp ${source_dir}/wpa_supplicant.conf wpa_supplicant/wpa_supplicant.conf

cd ${mount_root_dir}/home/pi
cp -p ${source_dir}/.bash_aliases .
mkdir .ssh
mkdir boomer
cd boomer
mkdir staged
mkdir execs
mkdir logs
mkdir script_logs
cp -p ${source_dir}/scp_log.sh .
cp -p ${source_dir}/change_version.sh .

#make boomer.service to start cam automatically
cd ${mount_root_dir}/home/pi
mkdir -p .config/systemd/user
cp -p ${source_dir}/cam_boomer.service boomer.service

#need to copy ssh key from base to cam's .ssh
# ? ssh enabled via advanced options CTRL-X with the raspberrypi-imager app

#cd out of the mounted file syste
cd
umount ${mount_root_dir}

#/boot/config.txt:
mount /dev/${2}1 ${mount_boot_dir}
if [ $? -eq 0 ]
then
   printf "OK: mount /dev/${2}1 ${mount_boot_dir}\n"
else
   printf "Failed: mount /dev/${2}1 ${mount_boot_dir}\n" >&2
   exit 1
fi
cat ${source_dir}/cam_config_append.txt >> ${mount_boot_dir}/config.txt
cd
umount ${mount_boot_dir}


#how to do the following (needs to boot from the sd-card)
# incrontab -e to add icron entries
#
# do any rasp-config commands need to be run?  sudo raspi-config nonint do_camera 0 ? necessary


