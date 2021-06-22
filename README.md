# boomer_supporting_files
config files, such as dhcpcd.conf, hostapd.conf, systemd service files, and shell scripts are in this repository.

## Base configuration
### Networking config:
- /etc/dhcpcd.conf: static address on enet for debug; static address on wlan1 for hostapd; no settings for wlan0 (built-in) to allow dhcp to connect to user-provided WiFi
- /etc/hostapd.conf: sets 2.4 or 5G - here is a reference conf file: https://gist.github.com/renaudcerrato/db053d96991aba152cc17d71e7e0f63c
- wpa_supplicant.conf:  add user provided wifi credentials

### systemd (launching processes on boot and restarting on failure
A file, "bbase.service" is placed in ~/.config/systemd/user.  This file controls starting and restarting boomer_base.
Once the file is in place (you probably have to create the .config, systemd and user directories) then:
```
mkdir ~/.config; mkdir ~/.config/systemd; mkdir ~/.config/systemd/user
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
/home/pi/boomer/logs    IN_CLOSE_WRITE   /home/pi/boomer/scp_log.sh $@/$# > /home/pi/boomer/script_logs/scp_log.sh 2>&1
/home/pi/boomer/staged    IN_CLOSE_WRITE        /home/pi/boomer/scp_cam_executables.sh $@/$# > /home/pi/boomer/script_logs/scp_cam_executables.log 2>&1
```


## Camera configuration

### Networking config:
- /boot/config.txt:  add the following 2 lines: ```dtparam=i2c_vc=on   &    dtoverlay=disable-wifi```
- /etc/dhcpcd.conf: static address on enet for debug; static address on wlan1 for BOOM_NET (wlan0 is disabled in /boot/config.txt)
- /etc/hostapd.conf: sets 2.4 or 5G - here is a reference conf file: https://gist.github.com/renaudcerrato/db053d96991aba152cc17d71e7e0f63c
- wpa_supplicant.conf:  add user provided wifi credentials

### systemd (launching processes on boot and restarting on failure
A file, "bcam.service" is placed in ~/.config/systemd/user.  This file controls starting and restarting boomer_can.
Once the file is in place (you probably have to create the .config, systemd and user directories) then:
```
mkdir ~/.config; mkdir ~/.config/systemd; mkdir ~/.config/systemd/user
systemd --user enable bcam.service
```

### File monitoring (upgrades, log transfers)
Refer to file Monitoring (incrontab) section in the base to install/enable incrontab

Then use incrontab -e and add the following entries for the camera:
```
/home/pi/boomer/logs    IN_CLOSE_WRITE   /home/pi/boomer/scp_log.sh $@/$# > /home/pi/boomer/script_logs/scp_log.sh 2>&1
/home/pi/boomer/staged  IN_CLOSE_WRITE   cp $@/$# /home/pi/boomer/execs
/home/pi/boomer/execs   IN_CREATE        /home/pi/boomer/change_version.sh $@/$# > /home/pi/boomer/script_logs/change_version.log 2>&1
```

## configuration for any CPU (base, camera, sound_player)
### Disable services
'''
sudo systemctl stop bluetooth
sudo systemctl disable bluetooth
'''
