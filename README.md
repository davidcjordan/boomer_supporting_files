# boomer_supporting_files
config files, such as dhcpcd.conf, hostapd.conf, systemd service files, and shell scripts are in this repository.

## Base configuration
### Networking config:
- /etc/dhcpcd.conf: static address on enet for debug; static address on wlan1 for hostapd; no settings for wlan0 (built-in) to allow dhcp to connect to user-provided WiFi
- /etc/hostapd.conf: sets 2.4 or 5G - here is a reference conf file: https://gist.github.com/renaudcerrato/db053d96991aba152cc17d71e7e0f63c
- wpa_supplicant.conf:  add user provided wifi credentials if there is a public network

### systemd (launching processes on boot and restarting on failure
A file, "bbase.service" is placed in ~/.config/systemd/user.  This file controls starting and restarting boomer_base.
Once the file is in place (you probably have to create the .config, systemd and user directories) then:
```
mkdir -p ~/.config/systemd/user
systemd --user enable bbase.service
```

### File monitoring (upgrades, log transfers)
A facility, incrontab, is used to monitor directories for new files and call a script or do some other action.

incrontab has to be installed and enabled:
```
sudo apt-get install incron;
sudo vi /etc/incron.allow       #add pi as a user
```
Then use incrontab -e and add the following entries for the base: The 1st copies logs to a computer for analysis; the 2nd copies cam executables to the cameras for a software update.  Note: the long text lines are difficult to edit in nano.  You can use ```sudo update-alternatives --config editor``` to change the editor to vi.
```
/home/pi/boomer/logs    IN_CLOSE_WRITE  /home/pi/boomer/scp_log.sh $@/$#
/home/pi/boomer/staged  IN_CLOSE_WRITE  /home/pi/boomer/scp_cam_executables.sh $@ $# > /home/pi/boomer/script_logs/scp_cam_executables.log 2>&1
/home/pi/boomer/execs   IN_CLOSE_WRITE  /home/pi/boomer/change_version.sh $@ $# > /home/pi/boomer/script_logs/change_version.log 2>&1
```

### Directory structure:
```
pi@base:~/boomer $ ls -al
total 116
drwxr-xr-x 10 pi pi  4096 Jun 25 06:58 .
drwxr-xr-x 12 pi pi  4096 Jun 24 13:14 ..
drwxrwxrwx  2 pi pi 20480 Mar 31 20:23 audio
lrwxrwxrwx  1 pi pi    62 May 18 09:36 bbase.out -> /home/pi/execs/bbase.out
-rw-r--r--  1 pi pi   926 May 22 13:16 boomer.service
-rwxr-xr-x  1 pi pi  1703 May 21 04:38 change_version.sh
drwxrwxrwx  2 pi pi 36864 Jun 24 13:29 drills
drwxr-xr-x  2 pi pi  4096 Jun 25 06:22 execs
drwxr-xr-x  2 pi pi  4096 Jun 23 13:50 logs
-rwxr-xr-x  1 pi pi   376 Jun 11 08:26 play_file.sh
-rw-r--r--  1 pi pi    50 May 19 06:29 pswd
-rwxr-xr-x  1 pi pi   738 Jun 11 12:22 scp_cam_executables.sh
-rwxr-xr-x  1 pi pi   791 Jun 19 09:41 scp_log.sh
drwxr-xr-x  2 pi pi  4096 May 20 12:18 script_logs
drwxr-xr-x  2 pi pi  4096 Jun 25 06:58 staged
```
To get this structure:
```
mkdir boomer
cd boomer
mkdir staged
mkdir execs
mkdir logs
mkdir script_logs
git clone https://github.com/davidcjordan/audio
git clone https://github.com/davidcjordan/drills
```

## Camera configuration

### Networking config:
- /boot/config.txt:  add the following 2 lines: ```dtparam=i2c_vc=on   &    dtoverlay=disable-wifi```
- /etc/dhcpcd.conf: static address on enet for debug; static address on wlan1 for BOOM_NET (wlan0 is disabled in /boot/config.txt)
- wpa_supplicant.conf:  the file should contain BOOM_NET and it's password.

### systemd (launching processes on boot and restarting on failure
A file, "bcam.service" is placed in ~/.config/systemd/user.  This file controls starting and restarting boomer_can.
Once the file is in place (you probably have to create the .config, systemd and user directories) then:
```
mkdir -p ~/.config/systemd/user
systemd --user enable bcam.service
```

### File monitoring (upgrades, log transfers)
Refer to file Monitoring (incrontab) section in the base to install/enable incrontab

Then use incrontab -e and add the following entries for the camera:
```
/home/pi/boomer/logs    IN_CLOSE_WRITE   /home/pi/boomer/scp_log.sh $@/$# > /home/pi/boomer/script_logs/scp_log.sh 2>&1
/home/pi/boomer/staged  IN_CLOSE_WRITE   rm /home/pi/boomer/execs/$#; cp $@/$# /home/pi/boomer/execs
/home/pi/boomer/execs   IN_CLOSE_WRITE   /home/pi/boomer/change_version.sh $@/$# > /home/pi/boomer/script_logs/change_version.log 2>&1
```
### Install arducam libraries:
arducam libraries have a dependency on opencv, so that has to be installed (first line below)
The reference for installing arducam stuff is:  https://github.com/ArduCAM/MIPI_Camera/tree/master/RPI
```
sudo apt-get install libzbar-dev libopencv-dev
git clone https://github.com/ArduCAM/MIPI_Camera.git; cd MIPI_Camera/RPI/; make install
```

## configuration for any CPU (base, camera, sound_player)
### Disable services
```
sudo systemctl stop bluetooth
sudo systemctl disable bluetooth
```
### enable user pi to do sudo in scripts (change_version.sh)
```
sudo visudo
add the following line:
pi ALL=(ALL:ALL) NOPASSWD: /usr/sbin/setcap
```
### Installing keys for ssh & scp (instead of using passwords)
The keys are required for transferring (scp'ing) files between computers which is used for software upgrades.
The keys make it so passwords are not required for scp and ssh.
```
#Create a key on computer that will be accessing the RPi: 
cd ~/.ssh  #keys are stored in this directory
echo "Hit ‘enter’ for both passphrase questions when running keygen (no passphrase)"
ssh-keygen -t rsa  #create the key
#Copy the generated key file from your computer to the RPi to be accessed with ssh/scp:
scp ~/.ssh/id_rsa.pub pi@base:/home/pi/.ssh
#
#Append the key onto the destination RPi
#ssh to the RPi - using the password for this time
#cd .ssh
#cat id_rsa.pub >> authorized_keys
```
Test the key installation:
Type ‘exit’ to terminate the ssh session
Type ssh pi@<ip name or addr>
It should not ask for a password

Reference: https://www.tecmint.com/ssh-passwordless-login-using-ssh-keygen-in-5-easy-steps/ or: https://alvinalexander.com/linux-unix/how-use-scp-without-password-backups-copy/

### Install .bash_alias file
  bash aliases provide shorthand commands for executing common operations on boomer, such as starting/stopping the base or camera and clearing the log.
