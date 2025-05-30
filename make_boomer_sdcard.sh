#!/bin/bash

# This script should be run as sudo, e.g. sudo bash make_boomer_sdcard.sh  
#   refer to: stackoverflow.com/questions/18809614/execute-a-shell-script-in-current-shell-with-sudo-permission#23506912

# NOTE: the following should be checked with advanced options in the raspberrypi-imager app
#   the advanced options dialog box is optained using CTRL-SHIFT-x
# reference for advanced options: easyprogramming.net/raspberrypi/raspberry_pi_imager_advanced_options.php
# - enable ssh AND set pi (user) password
# - enable wifi: set country, SSID, password.  IMPORTANT need this in order to have rfkill unblock wifi run
# - set local & timezone
# 
# This script will configure dhcp, hostapd, the USB-wifi adapter driver, etc
# the 'after_boot.sh' script will update the wpa_supplicant, since the raspberry imager overwrites it

if [ -z $2 ]; then
 printf "arg 2 (sd card, e.g. sdb or sdc) is empty\n"
 printf "usage: sudo bash make_boomer_sdcard.sh function sdcard\n"
 printf "       where function is one of <base-n, left, right, spkr> and sdcard is usually sdb or sdc, e.g.\n"
 printf "sudo bash make_boomer_sdcard.sh base-n sdb\n"
 exit 1
fi

if [ -z $1 ]; then
 printf "arg 1 (left or right or base or spkr) is empty\n"
 exit 1
fi

if [ $1 == 'left' ] || [ $1 == 'right' ]; then
   is_camera=1
else
   is_camera=0
fi

if [[ $1 == "base"* ]]; then 
   is_base=1
else
   is_base=0
fi

if [[ $1 == "spkr"* ]]; then 
   is_spkr=1
else
   is_spkr=0
fi

if [ $is_base -eq 0 ] && [ $is_camera -eq 0 ] &&  [ $is_spkr -eq 0 ]; then
 printf "arg 1 is not one of 'base', 'left','right' or 'spkr' \n"
 exit 1
fi

if [ $is_base -eq 1 ]; then
   base_id=${1#*-}
fi
printf "base_id=${base_id}\n"

# configure IP addresses to be used in dhcpcd.conf
if [ -z $3 ]; then
   # normal case (using Daves enet switch)
   eth_ip_A_B_C="192.168.28."
   if [ $is_base -eq 1 ]; then
       eth_ip_D="42"
   elif [[ $1 == "left"* ]]; then
       eth_ip_D="43"
   elif [[ $1 == "right"* ]]; then
       eth_ip_D="44"
   else
       eth_ip_D="46"
   fi
else
   printf "Using IP=$3 for the enet in /etc/dhcpcd.conf\n"
   IFS='.' read -r a b c d <<< "$3"
   #printf "Octet 1: $a  Octet 2: $b  Octet 3: $c  Octet 4: $d\n"
   eth_ip_A_B_C="$a.$b.$c."
   eth_ip_D="$d"
fi

daves_enet_ip_A_B_C_D="${eth_ip_A_B_C}40"
boom_net_ip_A_B_C="192.168.27."
base_boom_net_ip_A_B_C_D="${boom_net_ip_A_B_C}2"
left_boom_net_ip_A_B_C_D="${boom_net_ip_A_B_C}3"
right_boom_net_ip_A_B_C_D="${boom_net_ip_A_B_C}4"
spkr_boom_net_ip_A_B_C_D="${boom_net_ip_A_B_C}6"

if [ $is_base -eq 1 ]; then
   my_boom_net_ip_A_B_C_D=${base_boom_net_ip_A_B_C_D}
elif [[ $1 == "left"* ]]; then
   my_boom_net_ip_A_B_C_D=${left_boom_net_ip_A_B_C_D}
elif [[ $1 == "right"* ]]; then
   my_boom_net_ip_A_B_C_D=${right_boom_net_ip_A_B_C_D}
else
   my_boom_net_ip_A_B_C_D=${spkr_boom_net_ip_A_B_C_D}
fi

mount_root_dir="/media/rootfs"
mount_boot_dir="/media/boot"
user_id="pi"
source_dir="/home/${user_id}/repos/boomer_supporting_files"
staged_dir="/home/${user_id}/boomer/staged/"
execs_dir="/home/${user_id}/boomer/execs"
base_program="bbase.out"
cam_program="bcam.out"

ping -c 1 -q github.com > /dev/null
if [ $? -ne 0 ]; then
   printf "Failed: couldn't ping github (required for driver download)\n" >&2
   exit 1
fi

if [ ! -d ${mount_root_dir} ]; then
   # create mount directory - ignore errors
   mkdir ${mount_root_dir}
fi

mount -v /dev/${2}2 ${mount_root_dir}
if [ $? -ne 0 ]; then
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

cp ${source_dir}/dhcpcd_template.conf dhcpcd.conf
sed -i "s/my_eth0_ip/${eth_ip_A_B_C}${eth_ip_D}/g" dhcpcd.conf
sed -i "s/my_router_ip/${eth_ip_A_B_C}1/g" dhcpcd.conf

# wlan0 has no config in dhcpcd_template.conf, so that dhcp can be used on first boot
# for the camera, the after_boot script will:
#    disable the built-in wifi after the external wifi adapter driver is built
#    configure wlan0 in dhcpcd.conf to the hardcoded left/right IP address on BOOM_NET

# the base uses the built-in wpa0 to connect to nearby WiFi, use dhcp for wlan0
#   and use wlan1 to host BOOM_NET
if [ $is_base -eq 1 ]; then
   echo "interface wlan1" >> dhcpcd.conf
   echo "  static ip_address=${base_boom_net_ip_A_B_C_D}/24" >> dhcpcd.conf
   echo "  nohook wpa_supplicant" >> dhcpcd.conf
fi

# copy in the wifi config.  Developer networks can be put in the wpa_supplicant_base.conf file.
if [ $is_base -eq 1 ]; then
   cp ${source_dir}/wpa_supplicant_base.conf wpa_supplicant/wpa_supplicant.conf
else
   cp ${source_dir}/wpa_supplicant.conf wpa_supplicant/
fi

# init_resize.sh has been modified to keep the filesystem at 4G instead of the whole SD card
cp -v ${source_dir}/init_resize.sh /media/rootfs/usr/lib/raspi-config
if [ $? -ne 0 ]; then
   printf "copy init_resize.sh failed.\n"
   exit 1
fi


# setup boomer directories and files
cd ${mount_root_dir}/home/${user_id}
sudo -u ${user_id} ln -s ${source_dir}/.bash_aliases
sudo -u ${user_id} mkdir .ssh
sudo -u ${user_id} ln -s ${source_dir}/ssh_config.txt .ssh/config
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

# copy in default motor/servo config files:
cd this_boomers_data
sudo cp ${source_dir}/default_this_boomers_data/creep_calib_values.txt .
sudo cp ${source_dir}/default_this_boomers_data/servo_calib_values.txt .
sudo cp ${source_dir}/default_this_boomers_data/wheel_calib_values.txt .

#make boomer.service to start cam automatically
cd ${mount_root_dir}/home/${user_id}
sudo -u ${user_id} mkdir -p .config/systemd/user

if [ $is_base -eq 1 ]; then
   sudo -u ${user_id} cp -p ${source_dir}/base_boomer.service .config/systemd/user/boomer.service
   sudo -u ${user_id} cp -p ${source_dir}/base_gui.service .config/systemd/user
   sudo -u ${user_id} cp -p ${source_dir}/base_bluetooth.service .config/systemd/user
   sudo -u ${user_id} cp -p ${source_dir}/update_repos.service .config/systemd/user
   # running openocd as a service is not necessary - openocd is called from bbase using popen
   # sudo -u ${user_id} cp -p ${source_dir}/openocd.service .config/systemd/user
   sudo -u ${user_id} cp -p ${source_dir}/.muttrc .
   sed -i "s/NN/${base_id}/" .muttrc
   # add drivers for USB-bluetooth adapter:
   sudo curl -s https://raw.githubusercontent.com/Realtek-OpenSource/android_hardware_realtek/rtk1395/bt/rtkbt/Firmware/BT/rtl8761b_fw -o /lib/firmware/rtl_bt/rtl8761b_fw.bin
   sudo curl -s https://raw.githubusercontent.com/Realtek-OpenSource/android_hardware_realtek/rtk1395/bt/rtkbt/Firmware/BT/rtl8761b_config -o /lib/firmware/rtl_bt/rtl8761b_config.bin
   sed -i "s/bluetoothd/bluetoothd --noplugin=sap/" /etc/systemd/system/bluetooth.target.wants/bluetooth.service
else 
   sudo -u ${user_id} cp -p ${source_dir}/cam_boomer.service .config/systemd/user/boomer.service
fi

# have linux delete logs on start-up:
sed -i "s/^exit 0$/#exit 0\n/" ${mount_root_dir}/etc/rc.local
echo "rm -f \/home\/pi\/boomer\/logs\/*" >> ${mount_root_dir}/etc/rc.local
# turn on performance mode for the governor
echo "echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor" >> ${mount_root_dir}/etc/rc.local

# turn on the pulse generator (only needs to be done for Tom's home setup using the RPi pulse)
if [ $is_camera -eq 1 ]; then
   echo "cd /sys/class/pwm/pwmchip0; echo 0 > export; cd pwm0; echo 16688200 > period;" >> ${mount_root_dir}/etc/rc.local
   echo "echo 8000000 > duty_cycle; echo 1 > enable" >> ${mount_root_dir}/etc/rc.local
fi
echo "exit 0" >> ${mount_root_dir}/etc/rc.local

# install supporting files & arducam driver
cd ${mount_root_dir}/home/${user_id}
sudo -u ${user_id} mkdir repos; cd repos

sudo -u ${user_id} git clone https://github.com/davidcjordan/boomer_supporting_files

# the following is a hack: need to find some server to store these images:
# install boomer executables; done here becuase the host machine that has the executables
if [ $is_camera -eq 1 ]; then
   sudo -u ${user_id} cp -v ${staged_dir}/${cam_program} ${mount_root_dir}${execs_dir}
   sudo -u root -g sudo setcap 'cap_sys_nice=eip' ${mount_root_dir}${execs_dir}/${cam_program}
   chmod +x ${mount_root_dir}${execs_dir}/${cam_program}
   sudo -u ${user_id} cp -v ${staged_dir}/dat2png.out ${mount_root_dir}${execs_dir}
   chmod +x ${mount_root_dir}${execs_dir}/dat2png.out
fi
if [ $is_base -eq 1 ]; then
   sudo -u ${user_id} cp -v ${execs_dir}/${base_program} ${mount_root_dir}${execs_dir}
   sudo -u root -g sudo setcap 'cap_sys_nice=eip' ${mount_root_dir}${execs_dir}/${base_program}
   chmod +x ${mount_root_dir}${execs_dir}/${base_program}
   sudo -u ${user_id} cp -v ${staged_dir}/soc_20240517.elf ${mount_root_dir}${staged_dir}
   sudo -u ${user_id} ln -s ${mount_root_dir}${staged_dir}/soc_20240517.elf ${mount_root_dir}${staged_dir}/soc_firmware.elf
fi

# Disable "Welcome to Raspberry Pi" setup wizard at system start
# refer to: https://forums.raspberrypi.com/viewtopic.php?t=231557
if [ $is_base -eq 1 ]; then
   rm -v ${mount_root_dir}/etc/xdg/autostart/piwiz.desktop
fi

#cd out of the mounted file system before un-mounting
cd
umount -v ${mount_root_dir}

#/boot/config.txt - enable camera (start_x), i2c, disable built-in Wifi
if [ ! -d ${mount_boot_dir} ]; then
   # create mount directory - ignore errors
   mkdir ${mount_boot_dir}
fi

mount -v /dev/${2}1 ${mount_boot_dir}
if [ $? -ne 0 ]; then
   printf "Failed: mount /dev/${2}1 ${mount_boot_dir}\n" >&2
   exit 1
fi

# the following enables ssh
touch ${mount_boot_dir}/ssh

# DID NOT WORK: the following commands are added to /boot/firstrun.sh
# refer to /usr/bin/raspi-config
# an alternative is here: https://unix.stackexchange.com/questions/127705/automatically-run-rfkill-unblock-on-startup
#NOTE: firstrun.sh will only get created if 'Advanced Options' are selected:
#sed -i "s/^KBEOF$/KBEOF\nrfkill unblock wifi/" ${mount_boot_dir}/firstrun.sh
# do ssh does the following:  update-rc.d ssh enable && invoke-rc.d ssh start &&
#sed -i "s/^KBEOF$/KBEOF\nsudo raspi-config nonint do_ssh 1/" ${mount_boot_dir}/firstrun.sh

sed -i "s/#dtparam=i2c_arm=on/dtparam=i2c_arm=on/" ${mount_boot_dir}/config.txt
echo "" >> ${mount_boot_dir}/config.txt
echo "#boomer" >> ${mount_boot_dir}/config.txt

if [ $is_camera -eq 1 ]; then
   echo "#dtoverlay=disable-wifi" >> ${mount_boot_dir}/config.txt
   echo "dtparam=i2c_vc=on" >> ${mount_boot_dir}/config.txt
   echo "start_x=1" >> ${mount_boot_dir}/config.txt
   echo "#gpu_mem=128" >> ${mount_boot_dir}/config.txt
   echo "dtoverlay=pwm" >> ${mount_boot_dir}/config.txt
fi
if [ $is_base -eq 1  ]; then
   # the following is per https://forums.raspberrypi.com/viewtopic.php?t=299193
   # to force hdmi 0 & 1 plugs
   #HOWEVER: don't force both, because then linux will think there are 2, which is unusable

   echo "#hdmi_ignore_edid:0=0xa5000080" >> ${mount_boot_dir}/config.txt
   # the HDMI needs the force hotplug in order to keep the touchscreen on all the time:
   echo "hdmi_force_hotplug:0=1" >> ${mount_boot_dir}/config.txt
   echo "hdmi_group:0=2" >> ${mount_boot_dir}/config.txt
   echo "#hdmi_mode 28 is 1280x800" >> ${mount_boot_dir}/config.txt
   echo "hdmi_mode:0=28" >> ${mount_boot_dir}/config.txt

   # the following is to configure hdmi connector #1 - unncessary?
   echo "#hdmi_ignore_edid:1=0xa5000080" >> ${mount_boot_dir}/config.txt
   echo "#hdmi_force_hotplug:1=1" >> ${mount_boot_dir}/config.txt
   echo "#hdmi_group:1=2" >> ${mount_boot_dir}/config.txt
   echo "#hdmi_mode:1=28" >> ${mount_boot_dir}/config.txt

   # echo "hdmi_group=2" >> ${mount_boot_dir}/config.txt
   # echo "hdmi_mode=28" >> ${mount_boot_dir}/config.txt
   # the following is necessary for the tachometer, which uses UART 2
   echo "dtoverlay=uart2" >> ${mount_boot_dir}/config.txt
   # the following is for the USB Bluetooth adapter
   echo "dtoverlay=disable-bt" >> ${mount_boot_dir}/config.txt
fi

cd
umount ${mount_boot_dir}

printf "Done with make_boomer_sdcard (success) >> run after_boot.sh after the sdcard is booted.\n"
