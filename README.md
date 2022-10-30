# boomer_supporting_files
config files, such as dhcpcd.conf, hostapd.conf, systemd service files, and shell scripts are in this repository.

init_resize.sh is a copy of /usr/lib/raspi-config/init_resize.sh whcih sets TARGET_END to 4GB instead of the size of the SD-card.  To make an sd-card with a small linux/root partition, over-write the normal init_resize with the edited one.

There are scripts ```make_boomer_sdcard.sh``` and ```after_boot.sh``` which set configuration settings and install supporting applications, libraries, etc. 
- These scripts run on a linux machine, presumably an RPi, with the target sd-card plugged into an adapter:
  - the boot partition is sdx1 where x is a, b,c or d based on where is plugged in
  - the linux partition is sdx2
- These scripts are run after using raspberrypi-imager to format and load a sd-card.
  - ! The rpi-imager advanced options need to be set using CTRL-SHIFT-x:    [reference](https://www.easyprogramming.net/raspberrypi/raspberry_pi_imager_advanced_options.php)
    - ssh enabled, enable WiFi to set country code and temporary SID, locale settings
    - these settings can be saved and used on multiple runs if the imager
  - ! the scripts should be run as sudo, like this: ```sudo bash make_boomer_sdcard.sh base sdb```  [reference](https://stackoverflow.com/questions/18809614/execute-a-shell-script-in-current-shell-with-sudo-permission#23506912)

## Problems to solve:
* firstrun.sh failures:
 * rfkill
 * raspi-config do_ssh (currently using touch ssh)
 * Disable "Welcome to Raspberry Pi" setup wizard at system start (put in make_boomer script, but not tested)
 * ?change desktop
 
## Notes:
Here is the timing of making an SD-card with the scripts:
* imager: about 10 minutes, but it requires typing in a password
* make_boomer_sdcard: less than a minute
* after_boomer.sh takes about 10-30 minutes.  Most of the time is installing opencv

Making an SD card using the scripts:
* Advantages:
  * you know what exactly is being installed or configured
  * it takes less time than copying/cloning a 16 or 32 GB card
* Disadvantages:
  * requires multiple steps and checking for errors

Making an SD card by copying a 4GB SD card (or using a small image) takes ?? minutes and is simpler.

The default when booting an freshly created image is for the OS to resize the root partition (/) to use the whole SD card.  To disable this and have the root partition be 4GB, do the following after making the image and mounting the root directory (but before booting the SD-card):
```
cp -v ~/repos/boomer_supporting_files/init_resize.sh /media/rootfs/usr/lib/raspi-config
```
After the SD-card is booted, and the after_boot.sh script is run, you should have a 4GB SD-card (or image) that can be copied.

## Directory structure:
```
pi@base:~/boomer $ ls -al
total 116
drwxr-xr-x 10 pi pi  4096 Jun 25 06:58 .
drwxr-xr-x 12 pi pi  4096 Jun 24 13:14 ..
lrwxrwxrwx  1 pi pi    62 May 18 09:36 bbase.out -> /home/pi/execs/bbase.out
-rw-r--r--  1 pi pi   926 May 22 13:16 boomer.service
-rwxr-xr-x  1 pi pi  1703 May 21 04:38 change_version.sh
drwxrwxrwx  2 pi pi 36864 Jun 24 13:29 drills
drwxr-xr-x  2 pi pi  4096 Jun 25 06:22 execs
drwxr-xr-x  2 pi pi  4096 Jun 23 13:50 logs
-rwxr-xr-x  1 pi pi   738 Jun 11 12:22 process_staged_files.sh
-rwxr-xr-x  1 pi pi   791 Jun 19 09:41 scp_log.sh
drwxr-xr-x  2 pi pi  4096 May 20 12:18 script_logs
drwxr-xr-x  2 pi pi  4096 Jun 25 06:58 staged
```
On the base RPi, there is an additional directory ```drills``` which is cloned from: https://github.com/davidcjordan/drills

On the speaker RPi, there is an additional directory ```audio``` which is cloned from: https://github.com/davidcjordan/audio

A directory in the home directory ```this_boomers_data``` is also created - it holds machine specific files such as cam_parameters, ball throwing configuration (shot table), and other config files.  It will contain files used by the User Interface to display the boomer ID, e.g. Boomer #3, etc.

## systemd (launching processes on boot and restarting on failure
A file, "boomer.service" is placed in ~/.config/systemd/user.  This file controls starting and restarting bbase.
Once the file is in place (you probably have to create the .config, systemd and user directories) then:
```
mkdir -p ~/.config/systemd/user
systemd --user enable boomer.service
```
On the base: There is a base_gui.service in ~/.config/systemd/user which starts the web-server.

## File monitoring (upgrades, log transfers)
A facility, incrontab, is used to monitor directories for new files and call a script or do some other action.

incrontab has to be installed and enabled:
```
sudo apt-get install incron;
sudo vi /etc/incron.allow       #add pi as a user
```
The incron table can be loaded with ```incrontab ~/repos/boomer_supporting_files/incrontab.txt ``` or use incrontab -e
Note: the long text lines are difficult to edit in nano.  You can use ```sudo update-alternatives --config editor``` to change the editor to vi.

Refer to the incrontab.txt file for specifics.  But basically there are 3 directory watchers:
* logs directory: to an external support computer; currently uses enet
  * performed by scp_logs.sh
  * for the cams - it transfers the files to base
  * for the base - it transfers to an external computer, of connected; otherwise it moves them to logs
* /run/shm directory
  * same as the logs directory
* staged directory 
  * performed by process_staged_files.sh & change_version.sh
  * scp executables to cameras & speaker staged, and/or move them to the execs directory
  * sets the executables capabilities and mode

## Security Config (ssh)
There is a ~/.ssh directory which holds keys, ssh config, and known_hosts
ssh host key checking is disabled on BOOM_NET; refer to the .ssh/config file and https://www.shellhacks.com/disable-ssh-host-key-checking/

### Installing keys for ssh & scp
The keys are required for transferring (scp'ing) files between computers which is used for software upgrades; it avoids the request to enter passwords.
```
#Create a key on computer that will be accessing the RPi: 
cd ~/.ssh  #keys are stored in this directory
echo "Hit ‘enter’ for both passphrase questions when running keygen (no passphrase)"
ssh-keygen -t rsa  #create the key
```

Copy the generated key file from your computer to the RPi to be accessed with ssh/scp:
```
ssh-copy-id left (or right or daves)
```

Reference: https://www.tecmint.com/ssh-passwordless-login-using-ssh-keygen-in-5-easy-steps/ or: https://alvinalexander.com/linux-unix/how-use-scp-without-password-backups-copy/


## Base configuration
### Networking config:
- /etc/dhcpcd.conf: static address on enet for debug; static address on wlan1 for hostapd; no settings for wlan0 (built-in) to allow dhcp to connect to user-provided WiFi
- /etc/hostapd.conf: sets 2.4 or 5G - here is a reference conf file: https://gist.github.com/renaudcerrato/db053d96991aba152cc17d71e7e0f63c
- wpa_supplicant_base.conf:  add user provided wifi credentials if there is a public network
- /etc/hosts has the IP addresses for left, right, base and the supporting RPi (Daves)

## Camera configuration
### Networking config:
- /boot/config.txt:  add the following 2 lines: ```dtparam=i2c_vc=on   &    dtoverlay=disable-wifi```
- /etc/dhcpcd.conf: static address on enet for debug; static address on wlan1 for BOOM_NET (wlan0 is disabled in /boot/config.txt)
- wpa_supplicant.conf:  the file should contain BOOM_NET and it's password.

### UI config
In addition to launching the web-ui using systemd (described previously):

Chromium is launched on startup using /etc/xdg/lxsession/LXDE-pi/autostart:
* it is launched in full-screen mode
* !TOBE DONE: disable 'hover' input from the touch-screen
* use pkill -o chromium to stop it
* an external mouse messes up the touchscreen input
* an external keyboard allows the operator to hit 'F11' to exit full screen mode

## Additional details
The following sections describe what the scripts now do and are for reference only
### Install arducam libraries:
arducam libraries have a dependency on opencv, so that has to be installed (first line below)
The reference for installing arducam stuff is:  https://github.com/ArduCAM/MIPI_Camera/tree/master/RPI
```
sudo apt-get install libzbar-dev libopencv-dev
git clone https://github.com/ArduCAM/MIPI_Camera.git; cd MIPI_Camera/RPI/; make install
```

NOTE: [!THIS IS A WORK IN PROGRESS AND ISN'T FINISHED] A tar file with the libraries was created as follows:
- tar -c -f /home/pi/cam_libs.tar arm-linux-gnueabihf/libopencv_*.so*
- tar -r -f /home/pi/cam_libs.tar libarducam_mipicamera.so
- this tar file is untar'd in /usr/lib with the make_cam.sh script
### Test the camera is enabled
```
vcgencmd get_camera    #should get: supported=1 detected=0
```

## configuration for any CPU (base, camera, sound_player)
### Run raspi-config
```
sudo raspi-config: enable i2c (base), camera and ?audio
```
### edit hostname
```
sudo nano /etc/hostname   > change raspberrypi to left/right/base/spkr
sudo nano /etc/hosts   > change 127.0.1 to left/right/base; add 192.168.27.2 (or 3 or 4) to base, left, right
```

### USB-Wifi adapter driver
refer to: https://github.com/morrownr/88x2bu

### Disable services
```
sudo systemctl stop bluetooth
sudo systemctl disable bluetooth
sudo systemctl stop avahi-daemon
sudo systemctl disable avahi-daemon
```
If snapd has been installed (to get cmake) then disable it:
```
sudo systemctl disable snapd.service
sudo systemctl disable snapd.socket
sudo systemctl disable snapd.seeded
sudo systemctl disable snapd.snap-repair.timer
```
Disable swap:
```
sed -i "s/CONF_SWAPSIZE=100/CONF_SWAPSIZE=0/" dphys-swapfile
```
### enable user pi to do sudo in scripts (change_version.sh)
```
sudo visudo
add the following line:
pi ALL=(ALL:ALL) NOPASSWD: /usr/sbin/setcap
```

### Install .bash_alias file
  bash aliases provide shorthand commands for executing common operations on boomer, such as starting/stopping the base or camera and clearing the log.

### Install datetime bash command to run via crontab so logging will have correct time on cams, speaker
  sudo crontab crontab_cam.txt

### install ngrok on base
ngrok allows ssh'ing to a base unit if it's connected to an internet accessable router (wifi or enet).

To find the URL and port to use, go to the ngrok dashboard: https://dashboard.ngrok.com/cloud-edge/endpoints

To install and start as a service:
```
wget https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-arm.tgz
sudo tar xvzf ~/Downloads/ngrok-stable-linux-arm.tgz -C /usr/local/bin
cp -p ~/repos/boomer_supporting_files/ngrok.yml ~/.ngrok2/
cp -p ~/repos/boomer_supporting_files/ngrok.service ~/.config/systemd/user/
#add token to ngrok.yml
./ngrok authtoken TOKEN 
systemctl --user unmask ngrok
systemctl --user enable ngrok
systemctl --user start ngrok
systemctl --user status ngrok
```
