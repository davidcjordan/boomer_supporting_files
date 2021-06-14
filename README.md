# boomer_supporting_files
config files, such as dhcpcd.conf, hostapd.conf, systemd service files, and shell scripts are in this repository.

## Base configuration
### Networking config:
- /etc/dhcpcd.conf: static address for enet for debug; ignore wlan1 for hostapd
- /etc/hostapd.conf
- wpa_supplicant.conf:  add public wifi address in the future

### systemd (launching processes on boot and restarting on failure
A file, "boomer.service" is placed in ~/.config/systemd/user.  This file controls starting and restarting boomer_base or boomer_cam.
Once the file is in place (you probably have to create the .config, systemd and user directories) then:
```
systemd --user enable boomer.service
```

### File monitoring (upgrades, log transfers)
A facility, incrontab, is used to monitor directories for new files and call a script or do some other action.

incrontab has to be installed and enabled:
```
sudo apt-get install incron;
sudo vi /etc/incron.allow       #add pi as a user
```
Then use incrontab -e and add the following entries for the base:
```
/home/pi/boomer/logs    IN_CLOSE_WRITE   /home/pi/boomer/scp_log.sh $@/$# > /home/pi/boomer/script_logs/scp_log.sh 2>&1
```


## Camera configuration


### File monitoring (upgrades, log transfers)
Refer to file Monitoring (incrontab) section in the base to install/enable incrontab

Then use incrontab -e and add the following entries for the camera:
```
/home/pi/boomer/logs    IN_CLOSE_WRITE   /home/pi/boomer/scp_log.sh $@/$# > /home/pi/boomer/script_logs/scp_log.sh 2>&1
/home/pi/boomer/staged  IN_CLOSE_WRITE   cp $@/$# /home/pi/boomer/execs
/home/pi/boomer/execs   IN_CREATE        /home/pi/boomer/change_version.sh $@/$# > /home/pi/boomer/script_logs/change_version.log 2>&1
```
