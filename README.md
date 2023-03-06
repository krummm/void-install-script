# void-install-script
WIP Shell script installer for Void Linux

This installer was primarily created to serve as an installer with encryption support while also having general installation options one would want.

# Features
```
-Option to fully encrypt installation disk
-Option to pre-install and pre-configure the following;
--Graphics drivers
--Networking
--Audio server
--DE or WM
--Flatpak
--Or, choose to do none of these and install a bare-minimum system
-Option to securely erase the installation disk with shred
-Config support
-Choose between glibc and musl libc implementations
-User creation and basic configuration
-Experimental arm64 support (Remains untested)
-Configure partitions in the installer for home, swap, and root with LVM and ext4
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
If you want to use the config feature, run the installer with ./installer.sh /path/to/myconfig.sh
Take a look at exampleconfig.sh for usage.
```

# Notes
This installer is not officially supported, if you run into any problems please file them on this github page.


# TODO
```
Add input validation and error checking to the scripts
```
