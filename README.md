# void-install-script
WIP Shell script installer for Void Linux

This installer was primarily created to serve as an installer with encryption support while also having general installation options one would want.

# Features
```
Encrypted install
Experimental config support
Install a bare minimum system quickly
Install a system with networking, graphics drivers, audio server, and a DE/WM ready to go on reboot
Select which of the above features you would like, if any
```

# Instructions
```
Boot into a Void Linux live medium
Login as root
xbps-install -S git
git clone https://github.com/krummm/void-install-script/
cd void-install-script
chmod +x installer.sh
./installer.sh
Follow on-screen steps
Done.
```
# Config usage
```
If you want to use the experimental config feature, run the installer with ./installer.sh /path/to/myconfig.sh
Take a look at exampleconfig.sh for usage.
```

# Notes
Obviously, this is in no way officially supported nor should it be treated like such. Any issues with this install script should be filed here, do not bother
anyone else with this.

Make certain both script files are in the same directory before running installer.sh

As of right now, this script only supports encrypted installs, though it now has experimental arm64 support.

# TODO
```
Add input validation and error checking to the scripts
Add legacy boot support
Add support for filesystems other than ext4
Add script logging
```
