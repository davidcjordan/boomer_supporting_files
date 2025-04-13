#!/bin/bash

# ssh keys:
# cam: key copied to base, daves
# base: key copied to cams, daves, speaker
# daves: key copied base, cams, speaker

ping -c1 raspbian.raspberrypi.org
if [ $? -ne 0 ]; then
   printf "Not connected to the internet\n"
   exit 1
fi

if [[ $(hostname) == "base"* ]]; then 
   is_base=1
else
   is_base=0
fi

# printf "is_base=${is_base}\n"
# all of Boomer's repos are public except 'launcher' and 'boomer_cam' so token is not necessary
# if [[ -z "${GITHUB_TOKEN}" && is_base -eq 1 ]]; then 
#    echo "type: 'export GITHUB_TOKEN=something' before running script"; 
#    exit 1
# fi

if [[ $(hostname) =~ ^(left|right)$ ]]; then 
   is_camera=1
else
   is_camera=0
fi

# ideally this would be read from /etc/hosts
# after reboot; the cam should connect to BOOM_NET
boom_net_ip_A_B_C="192.168.27."
if [[ $(hostname) == "left"* ]]; then
   my_boom_net_ip_A_B_C_D="${boom_net_ip_A_B_C}3"
elif [[ $(hostname) == "right"* ]]; then
   my_boom_net_ip_A_B_C_D="${boom_net_ip_A_B_C}4"
fi

# hardcode the IP address for BOOM_NET 
if [ $is_camera -eq 1 ]; then
   sudo echo "
interface wlan0
  static ip_address=${my_boom_net_ip_A_B_C_D}/24" >> /etc/dhcpcd.conf
fi
if [ $? -eq 0 ]; then
   printf "OK: added hardcoded address ${my_boom_net_ip_A_B_C_D} to wlan0\n"
else
   printf "Failed: adding hardcoded address to wlan0\n" >&2
   exit 1
fi

if [[ $(hostname) == "spkr"* ]]; then 
   is_spkr=1
else
   is_spkr=0
fi

user_id="pi"
echo "pi:readysetcrash" | sudo chpasswd

#NOTE: if you name id_rsa something else then make a ln -s to id_rsa;
#   ssh defaults to the filename id_rsa
ssh-keygen -t rsa -f ${HOME}/.ssh/id_rsa -q -N ""
if [ $? -eq 1 ]; then
   printf "Failed: ssh-keygen\n" >&2
   exit 1
fi

source_dir="/home/${USER}/repos/boomer_supporting_files"

# change the wpa_supplicant from the one installed by the imager advanced options, to the one that support BOOM_NET
cd /etc/wpa_supplicant
if [ -e wpa_supplicant.conf ]; then
   sudo mv wpa_supplicant.conf wpa_supplicant.conf-original
fi

if [ $is_base -eq 1 ]; then
   sudo cp -v ${source_dir}/wpa_supplicant_base.conf wpa_supplicant.conf
else
   sudo cp -v ${source_dir}/wpa_supplicant.conf wpa_supplicant.conf
fi
if [ $? -ne 0 ]; then
   printf "copy wpa_supplicant failed.\n"
   exit 1
fi
#enable wifi:  NOTE: this may have already been done by the imager advanced options
rfkill unblock wifi
rfkill unblock bluetooth

#remove "welcome to Raspberry Pi splash screen" on boot-up
sudo sed -i "s/splash//" /boot/cmdline.txt
#remove using tty1 as the console, since the SoC board uses tty1
sudo sed -i "s/console=serial0,115200 console=tty1 //" /boot/cmdline.txt
# the following should be uncommented when shipping to customers.
#remove quiet to see messages on boot; by default it quiet
#sed -i "s/quiet//" /boot/cmdline.txt

# fix locale warning:
sudo sed -i "s/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" /etc/locale.gen
# sudo sed -i "s/en_GB.UTF-8 UTF-8/# en_GB.UTF-8 UTF-8/" /etc/locale.gen
if [ $? -ne 0 ]; then
   printf "enable of en_US in /etc/locale.gen failed.\n"
fi
sudo locale-gen
if [ $? -ne 0 ]; then
   printf "locale-gen failed.\n"
fi

# not sure which of these local commands works; locale change requires reboot?
# sudo update-locale en_US.UTF-8
# NOTE: the following does not change the locale for the current session; the next session will have it
sudo raspi-config nonint do_change_locale en_US.UTF-8
if [ $? -ne 0 ]; then
   printf "update-locale failed.\n"
fi
# sudo locale-gen --purge --no-archive 
# sudo update-initramfs -u

# set locale for this script; locale will permanently be fixed after rebooting
LC_ALL='en_US.UTF-8'; export LC_ALL
LC_LANG='en_US.UTF-8'

# without update, then install libopencv will fail
sudo apt update && sudo apt --yes upgrade

# enable i2c (creates /dev/i2c-0 -1)
sudo modprobe i2c-dev

# build & install the wifi-driver
if [ $is_spkr -ne 1 ]; then
   sudo apt --yes install bc
   sudo apt --yes install dkms
   cd ~/repos/88x2bu-20210702
   sudo ./install-driver.sh NoPrompt
   sudo sed -i "s/rtw_power_mgnt=1/rtw_power_mgnt=0/" /etc/modprobe.d/88x2bu.conf
fi

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
# refer to: https://unix.stackexchange.com/questions/78299/allow-a-specific-user-or-group-root-access-without-password-to-bin-date
#echo "${USER} ALL=(ALL:ALL) NOPASSWD: /bin/date" | sudo tee -a /etc/sudoers

#add pi as a user
echo "${USER}" | sudo tee -a /etc/incron.allow 

# configure incron table entries:
incrontab ${source_dir}/incrontab.txt

# disable unused services
sudo systemctl stop avahi-daemon.service
sudo systemctl disable avahi-daemon.service
sudo systemctl stop dphys-swapfile.service
sudo systemctl disable dphys-swapfile.service
sudo systemctl stop triggerhappy.service
sudo systemctl disable triggerhappy.service
sudo systemctl stop hciuart.service
sudo systemctl disable hciuart.service
# sudo systemctl stop alsa-state.service
# sudo systemctl disable alsa-state.service
# if [ $is_camera -eq 1 ] || [ $(hostname) == 'spkr' ]; then
#    printf "disabling systemd-timesyncd.service\n"
#    sudo systemctl stop systemd-timesyncd.service
#    sudo systemctl disable systemd-timesyncd.service
# fi

sudo apt --yes install git
#sudo apt --yes install i2c-dev
sudo apt --yes install i2c-tools

# load arducam shared library (.so), which requires opencv shared libraries installed first
if [ $is_camera -eq 1 ]; then
   sudo apt --yes install libzbar-dev libopencv-dev
   cd ~/repos
   git clone https://github.com/ArduCAM/MIPI_Camera.git
   cd MIPI_Camera/RPI/; make install
   cd ~/boomer
   ln -s execs/bcam.out .
   # install ntp client so the cameras can get the time from the base:
   sudo apt --yes install ntpdate
   if [ $? -ne 0 ]; then
      printf "install of ntp client failed.\n"
   fi
   sudo sed -i "s/#server ntp.your-provider.example/server 192.168.27.2 prefer iburst/" /etc/ntp.conf
   if [ $? -ne 0 ]; then
      printf "configuration ntp client failed.\n"
   fi
   sudo sed -i "s/pool/# pool/" /etc/ntp.conf
fi

GITHUB_USER=davidcjordan
if [ $is_base -eq 1 ]; then
   sudo apt --yes install hostapd; sudo systemctl stop hostapd
   sudo apt --yes install dnsmasq; sudo systemctl stop dnsmasq
   sudo mv /etc/hostapd/hostapd.conf /etc/hostapd/hostapd.conf.orig
   sudo cp ${source_dir}/hostapd.conf /etc/hostapd
   sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig
   sudo cp ${source_dir}/dnsmasq.conf /etc/dnsmasq.conf
   sudo systemctl unmask hostapd.service 
   sudo apt --yes install gpiod
   sudo apt --yes install mutt  #mail client used to email power-on or reports
   sudo apt --yes install matchbox-keyboard #virtual keyboard for touchscreen. https://raspberrytips.com/install-virtual-keyboard-raspberry-pi/

   # the tailscale service is used to ssh into base-N which are connected to the internet to do maintenance
   curl -fsSL https://tailscale.com/install.sh | sh

   sudo apt --yes install imagemagick  #used to change PNG to JPEG using the convert command
  
   # install stuff for bluetooth sound (ALSA) used to play WAV files; it installs bluez
   sudo apt install --yes bluealsa
   # sudo apt install --yes bluez-tools

   #install ntp server so the cameras can get the time from the base:
   sudo apt --yes install ntp

   #have chromium autostart; refer to: https://forums.raspberrypi.com/viewtopic.php?t=294014
   # fullscreen mode allows F11 to get out of full screen mode if a keyboard is connected
   # for more info on auto start options: 
   #    https://stackoverflow.com/questions/42503701/chromium-kiosk-mode-fullscreen-and-remove-address-bar
   # echo "@chromium --start-fullscreen --disable-infobars --noerrdialogs --enable-features=OverlayScrollbar,OverlayScrollbarFlashAfterAnyScrollUpdate,OverlayScrollbarFlashWhenMouseEnter http://localhost:1111" | sudo tee -a /etc/xdg/lxsession/LXDE-pi/autostart
   echo "@chromium --kiosk --disable-restore-session-state http://localhost:1111" | sudo tee -a /etc/xdg/lxsession/LXDE-pi/autostart
   
   cd ~/repos
   #public repos:
   git clone https://github.com/${GITHUB_USER}/drills
   git clone https://github.com/${GITHUB_USER}/audio
   git clone https://github.com/${GITHUB_USER}/control_ipc_utils
   git clone https://github.com/${GITHUB_USER}/ui-webserver
   #previously private repos:
   # git clone https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com/${GITHUB_USER}/ui-webserver
   if [ $? -ne 0 ]; then
      printf "clone of ui-webserver failed.\n"
      exit 1
   fi

   # install python packages for python web-server
   cd ui-webserver
   python3 -m venv venv
   . venv/bin/activate
   python3 -m pip upgrade
   python3 -m pip install gunicorn==20.1.0 eventlet==0.30.2
   # refer to these versions in 2022: https://github.com/miguelgrinberg/python-socketio/discussions/1042
   # otherwise get the error: type object 'Server' has no attribute 'reason'
   python3 -m pip install python-engineio==4.3.4
   python3 -m pip install python-socketio==5.7.1
   python3 -m pip install flask==2.2.5
   python3 -m pip install flask-socketio==5.3.1
    ./make-links.sh
   deactivate
   
   cd ~/boomer
   ln -s ~/repos/drills .
   ln -s execs/bbase.out .

   # the following is necessary to not have the screen blank
   ln -s ${source_dir}/dont_blank_screen.sh .
   crontab ${source_dir}/crontab_base.txt

   # fill audio directory with wav files:
   mkdir audio
   cd ~/repos/audio
   sudo apt --yes install mpg123
   for f in *.mp3; do mpg123 -q -vm2 -w "/home/${USER}/boomer/audio/${f%.mp3}.WAV" "$f"; done

   systemctl --user enable base_gui.service
   systemctl --user enable base_bluetooth.service
   systemctl --user enable update_repos.service
   # systemctl --user enable openocd.service   <- don't need service - can just call reset flash from the command line

   # install files to support the STM32 on the SoC board: openocd, ocdconfig, firmware elf
   sudo apt -y install libtool
   cd ~/repos
   git clone  https://github.com/raspberrypi/openocd.git
   cd openocd 
   ./bootstrap
   ./configure --enable-bcm2835gpio
   make -j4
   sudo make install

   #currently not used: install capability to write a google sheet for the customer's performance records
   install_write_sheets=0
   if [ $install_write_sheets -eq 1 ]; then
      cd ~/repos
      git clone https://github.com/manningt/write_sheet
      if [ $? -ne 0 ]; then
         printf "clone of write_sheet failed.\n"
         exit 1
      fi

      # install python packages for write_sheets
      sudo apt --yes install libssl-dev
      cd write_sheet
      python3 -m virtualenv venv_sheets
      source ./venv_sheets/bin/activate
      pip3 install oauth2client
      pip3 install PyOpenSSL
      pip3 install gspread
      deactivate

      # # the following is commented out because it requires too much disk & it is interactive.
      # ? If it is still required, it can be done on installation, along with the write_sheets config
      # curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
      # source "$HOME/.cargo/env"
   fi
fi

# the following is obsolete, but should not be invoked either:
if [ $is_spkr -eq 1 ]; then
   sudo apt --yes install mpg123
   # get audio files;
   cd ~/repos
   git clone https://github.com/${GITHUB_USER}/audio
   cd ~/boomer
   ln -s audio ~/repos/audio
   ln -s execs/bspkr.out .
fi

#the following is required to have the base/cam service start when not logged in
loginctl enable-linger pi
if [ $? -ne 0 ]; then
   printf "enable-linger failed.\n"
   exit 1
fi

systemctl --user enable boomer.service

printf "\n  Success - the sd-card has been configured.\n"
printf "    HOWEVER: "
printf "      1) the newest version of bcam.out or bbase.out have to be loaded.\n"
printf "      2) To increase the root partition size, do the following commands:\n"
printf "          sudo parted -m /dev/mmcblk0 u s resizepart 2 30GB; sudo resize2fs /dev/mmcblk0p2\n"
printf "      3) on install, copy the ssh keys to the other computers, eg. ssh-copy-id pi@daves/left/right/base\n"
if [ $is_base -eq 1 ]; then
   printf "      4) enable tailscale: sudo tailscale up\n"
   printf "      5) Optionally enable mutt mail for 'report' by editing .muttrc with password and machine name"
fi
printf "and REBOOT to have changes take effect.\n\n"
