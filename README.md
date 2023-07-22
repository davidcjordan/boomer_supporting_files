# boomer_supporting_files
## Overview
It is assumed the reader understands there are 3 Raspberry Pi's running Linux (the base and the 2 cameras. The reader should be familiar with linux/unix facilities, such as shells, systemd, scripts, aliases, etc.

The topics covered in this file are:
- making SD cards and/or images
  - scripts
  - .conf files
- process control (systemd)
  - various services that run the base & camera
- installing a new system
- software upgrade
- aliases & scripts to minimize typing on frequently performed operations, or to help Dave

This repository contains config files, such as dhcpcd.conf, hostapd.conf, systemd service files, and shell scripts.

## Making SD cards and images
There are scripts ```make_boomer_sdcard.sh``` and ```after_boot.sh``` which set configuration settings and install supporting applications, libraries, etc. 
- These scripts run on a linux machine, presumably an RPi, with the target sd-card plugged into an adapter:
  - the boot partition is sdx1 where x is a, b,c or d based on where is plugged in
  - the linux partition is sdx2
- These scripts are run after using raspberrypi-imager to format and load a sd-card.
  - ! The rpi-imager advanced options need to be set using CTRL-SHIFT-x:    [reference](https://www.easyprogramming.net/raspberrypi/raspberry_pi_imager_advanced_options.php)
    - ssh enabled, enable WiFi to set country code and temporary SID, locale settings
    - these settings can be saved and used on multiple runs if the imager
  - ! the scripts should be run as sudo, like this: ```sudo bash make_boomer_sdcard.sh base sdb```  [reference](https://stackoverflow.com/questions/18809614/execute-a-shell-script-in-current-shell-with-sudo-permission#23506912)

 
### Notes:
Here is the timing of making an SD-card with the scripts:
* imager: about 10 minutes
* make_boomer_sdcard: less than a minute
* after_boomer.sh takes about 10-30 minutes.  Most of the time is installing opencv and building the wifi adapter driver

Making an SD card using the scripts:
* Advantages:
  * you know what exactly is being installed or configured
  * it takes less time than copying/cloning a 16 or 32 GB card
* Disadvantages:
  * requires multiple steps and checking for errors

Making an SD card by copying a 4GB SD card (or using a small image) takes 10 minutes and is simpler.

The default when booting an freshly created image is for the OS to resize the root partition (/) to use the whole SD card.  To disable this and have the root partition be 4GB, the following is done by the make_sd script:
```
cp -v ~/repos/boomer_supporting_files/init_resize.sh /media/rootfs/usr/lib/raspi-config
```
init_resize.sh in this repositoary is a copy of /usr/lib/raspi-config/init_resize.sh which sets TARGET_END to 4GB instead of the size of the SD-card.  To make an sd-card with a small linux/root partition, over-write the normal init_resize with the edited one.

After the SD-card is booted, and the after_boot.sh script is run, the 4GB SD-card (or image) that can be copied as follows:
```
sudo dd if=/dev/sdc bs=1M count=4102 status=progress | gzip > ~/Downloads/202Y-MM-DD-base.img.gz
```
This takes about 10 minutes and results in a ~1.7GB compressed image file.

After flashing the above image, use the following command to increase the root filesystem:
```
sudo parted -m /dev/mmcblk0 u s resizepart 2 30GB; sudo resize2fs /dev/mmcblk0p2
```
### Directory structure of boomer base and cameras
```
pi@base:~/boomer $ ls -al
drwxr-xr-x 12 pi pi      4096 Apr  1 09:44 .
drwxr-xr-x 34 pi pi      4096 Apr 20 11:36 ..
lrwxrwxrwx  1 pi pi        26 Apr  1 09:44 audio
-rw-r--r--  1 pi pi       613 Apr  4  2022 autostart
lrwxrwxrwx  1 pi pi        31 Apr 15  2022 bbase.out -> /home/pi/boomer/execs/bbase.out
lrwxrwxrwx  1 pi pi        56 Feb 28  2022 change_version.sh -> /home/pi/repos/boomer_supporting_files/change_version.sh
lrwxrwxrwx  1 pi pi        21 Sep  5  2022 drills -> /home/pi/repos/drills
drwxr-xr-x  2 pi pi      4096 Apr 17 10:15 execs
drwxr-xr-x  2 pi pi      4096 Mar 12 06:58 logs
lrwxrwxrwx  1 pi pi        62 Mar 31  2022 process_staged_files.sh -> /home/pi/repos/boomer_supporting_files/process_staged_files.sh
lrwxrwxrwx  1 pi pi        49 Feb 28  2022 scp_log.sh -> /home/pi/repos/boomer_supporting_files/scp_log.sh
drwxr-xr-x  2 pi pi      4096 Feb  2 07:22 script_logs
drwxr-xr-x  2 pi pi      4096 Apr 17 10:15 staged
drwxr-xr-x  3 pi pi      4096 Apr 18 09:28 this_boomers_data
```
An explanation of the directories:
- execs: executables are stored.  The symbolic link of bbase or bcam from the boomer directory to the executable in the execs directory is a convenience to allow multiple version of the executable if necessary
- staged: executables are placed in this directory for a software upgrade.  A file monitor (incron) invokes a script to move the executable from the staged: directory to the execs directory, give the file permissions, and restart the base/camera process.
- logs: stores persisted log files. The files in this directory are erased on boot in order to prevent running out of file space
- script_logs:  files written to them by the software upgrade scripts or other scripts.
- this_boomers_data: holds machine specific files such as court points, camera locations, servo parameters, user settings and other config files.  It can contain files used by the User Interface to display the boomer ID, e.g. Boomer #3, etc.
On the base RPi, there are an additional directories; symbolic links are used to point the drills/audio to the repositories
- ```drills``` which is cloned from: https://github.com/davidcjordan/drills

- ```audio``` the WAV files in this directory are created by using mpg123 to convert the mp3 files in the cloned repository '~/repos/audio'.  An alias 'make_wav_all' iterates through all the MP3s to create WAV files int the boomer/audio directory

## systemd (launching processes on boot and restarting on failure)
systemd is used to start and stop the following:
- boomer.service: the bbase.out process on the base, and bcam.out on the cameras
- base_gui.service: The user-interface is a web-server using python modules (gunicorn)
  - the code is in the ~/repos/ui-webserver, which requires ~/repos/control_ipc_utils to be cloned
- base_bluetooth.service: runs bash script 'bt_audio_enable.sh' that runs a loop checking for a paired bluetooth device
- mail_on_network.service: enables sending an email when the system boots.  This is used to monitor boomer tests sites and may be removed in the future.

The make_boomer_sdcard.sh script creates the ~/.config/systemd/user directory and copies the *.service files into the directory.
The after_boot.sh script enables the services.
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
  * for the base - it transfers to an external computer, if connected; otherwise it moves them to logs
* /run/shm directory
  * same as the logs directory
* staged directory 
  * performed by process_staged_files.sh & change_version.sh
  * CAM executables that are transferred to the base are scp'd to the cameras staged directory
  * copies the executables to the 'exec' directory sets the executables capabilities and executable mode

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


### Descriptions of parts of the make_sd_card & after_boot.sh
The following sections describe what the scripts now do and are for reference only
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

### .bash_alias file
  bash aliases provide shorthand commands for executing common operations on boomer, such as starting/stopping the base or camera and clearing the log.  On the base, or cam, type 'alias' to see the list of aliased commands.

  Installations have a symbolic link: /home/pi/.bash_aliases -> /home/pi/repos/boomer_supporting_files/.bash_aliases

  Some utilities that were added to help dave:
  - base/bcamsync: scp's the bbase or bcam executable from the host RPi to base 'N' where N is the boomer number (1, 2, etc).  It uses tailscale (IP service on the internet) to transfer the files to the base.  Requires wifi to be connected on the base.
  - vlog and blog: vlog does a 'less' of boomer.log; blog does a 'tail -f' of the log
  - make_wav_all: converts all the mp3's in the repos/audio to WAV's in the ~/boomer/audio directory
  

### A cron table (crontab) is installed on the base/cams by the after_boot script
 - crontab_base runs a script on boot that disables screen blanking
 - crontab_cam reboots every day in the wee hours.
  - this is because the cameras would not connect to BOOM_NET after BOOM_NET was not present for a couple of days
  - it requires the base be setup as a timeserver for the cams to get their date/time using ntp.  This server on the base, and ntp on the cameras are setup by the after_boot script.

### enable score_update on base
A feature was added to write a google sheet with drill metrics at the end of every drill.  In the future, this may also update a 'game' tab on the same sheet.

At the end of a drill, bbase writes a /run/shm/score_update.json with the metrics.  icrontab invokes score_update.py via the scp_logs.sh script when this file is written.  

A file, 'score_update_config.json' needs to be in this_boomers_data.  It contains 2 key-value pairs: {"score_update_sheet_name": "Tappan_scores", "credentials_filename": "write-drill-scores-tappan-280027e40360.json"}.  The credentials file is downloaded from Google's 


### install tailscale on base
tailscale allows ssh'ing to a base unit if it's connected to an internet accessable router.
It was selected instead of using ngrok because up to 20 devices are supported for a free account.
A gmail account 'rio.co.4444@gmail' was created to use as credentials for the devices (boomer base).
Each base has to have a unique hostname, e.g. base-1, base-2; so the hostnames have to be edited after flashing a base SDcard.
After the sd-card has booted, the command ```sudo tailscale up``` needs to be run

### install mutt on base
mutt is a email client: http://www.mutt.org    It is (can be) used to email logs (the report alias) or send an email when the base powers up and connects to the internet.

mutt requires:
- a mutt configuration file: .muttrc
  - gets copied from boomer_support_files into /home/pi
  - edit to update the base name, e.g. base-3
  - currently has the roi.co.4444@gmail.com authorization code, which should be moved to a different file and encrypted

### [OLD - left just in case] install ngrok on base
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
