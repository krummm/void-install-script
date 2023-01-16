#!/bin/bash
user=$(whoami)

if [ $user != root ]; then
    echo "Please execute this script as root."
    exit 1
fi

# Check to see if there is a flag when executing installer.sh and make sure it's a .sh file to be imported as an installation config
if [ $# != 1 ]; then
    echo "Continuing without config file..."
    sleep 1
    configDetected=0
    sleep 1
elif [ $# == 1 ]; then
    echo "Attempting to use user-defined config file..."
    sleep 1

    if [[ $1 == *.sh ]] ; then
        source $1
        configDetected=1
    else
        echo "User-defined config detected but is either misinput or the wrong file type. Please correct this and run again."
        exit 1
    fi

fi

entry() {

    # Defining things the installer will need
    runDirectory=$(pwd)
    locale="LANG=en_US.UTF-8"
    libclocale="en_US.UTF-8 UTF-8"
    installRepo="https://repo-default.voidlinux.org/current"

    # Need to make sure the installer can actually access the internet to install packages

    clear

    echo -e "Testing network connectivity... \n"

    ping -c 1 google.com &>/dev/null

    if [ $? == "0" ]; then
        echo -e "Network check succeeded. \n"
        sleep 1
    elif [ $? == "1" ]; then
        echo -e "Network check failed. Please make sure your network is active."
        exit 1
    fi

    clear

    echo -e "Begin void installer... \n"

    echo -e "Grabbing installer dependencies... \n"
    xbps-install -Sy -R $installRepo fzf parted void-repo-nonfree

    # Check for a config defined as a flag, if one exists then move to confirm options with values defined in said config
    
    if [ $configDetected == "1" ]; then
        confirmInstallationOptions
    else
        diskConfiguration
    fi

}

diskConfiguration() {

    # We're going to define all disk options and use them later on so the user can verify the layout and return to entry to start over if something isn't correct, before touching the disks.
    clear
    # Should probably make this a selection menu to prevent invalid user input
    echo -e "AVAILABLE DISKS: \n"
    lsblk -o NAME,SIZE
    echo -e "The disk you choose will not be modified until you confirm your installation options. \n"
    echo -e "Please enter the disk you would like to partition and install Void Linux to: (Example: 'sda') \n"
    read diskPrompt

    diskInput="/dev/$diskPrompt"

    if [[ $diskInput == /dev/nvme* ]] ; then
        partition1="$diskInput"p1
        partition2="$diskInput"p2
    else
        partition1="$diskInput"1
        partition2="$diskInput"2
    fi

    clear

    # We're going to begin grabbing information for how the user wants their disk to be setup here
    echo -e "Would you like to have a swap partition? (y/n) \n"
    read swapPrompt

    if [ $swapPrompt == "y" ] || [ $swapPrompt == "Y" ]; then
        clear
        echo -e "How large would you like your swap partition to be? (Example: '4G') \n"
        read swapInput
    fi

    clear
    echo "If you would like to limit the size of your root filesystem, such as to have a separate home partition, you can enter a value such as '50G' here."
    echo -e "Otherwise, if you would like your root partition to take up the entire drive, enter 'full' here. \n"
    read rootPrompt

    # If the user wants the root partition to take up all space after the EFI partition, a separate home on this disk isn't possible.
    if [ $rootPrompt == "full" ]; then
        separateHomePossible=0
    else
        separateHomePossible=1
    fi

    if [ $separateHomePossible == "1" ]; then
        clear
        echo -e "Would you like to have a separate home partition on disk $diskInput (y/n) \n"
        read homePrompt

        if [ $homePrompt == "y" ] || [ $homePrompt == "Y" ]; then
            clear
            echo "How large would you like your home partition to be? (Example: '100G')"
            echo -e "You can choose to use the rest of your disk if you didn't give the entire disk to your root partition by entering 'full' \n"
            read homeInput
        fi
    fi

    installOptions

}

installOptions() {

    clear

    # Getting libc options
    mkdir /root/muslOptions
    touch /root/muslOptions/glibc
    touch /root/muslOptions/musl
    cd /root/muslOptions

    clear

    echo -e "What kind of system are you installing? (musl or glibc) \n"
    echo -e "If you chose a glibc installation ISO, please choose glibc here.\n"

    muslSelection=$(fzf --height 10%)

    cd /root

    clear

    # Getting computer hostname
    echo -e "What do you want this computer to be called on the network? (Hostname) \n"
    read hostnameInput

    clear

    # Getting user timezone
    echo -e "Timezone selection... \n"
    echo -e "You can type here to search for your timezone. \n"
    timezonePrompt=$(awk '/^Z/ { print $2 }; /^L/ { print $3 }' /usr/share/zoneinfo/tzdata.zi | sort | fzf --height 10%)

    clear

    # Getting installation profile
    mkdir /root/profileSelection
    touch /root/profileSelection/desktop
    touch /root/profileSelection/minimal
    cd /root/profileSelection
    
    clear

    echo -e "Would you like a minimal installation or a desktop installation? \n"
    echo -e "The minimal installation does not configure networking, graphics drivers, DE/WM, etc. You can manually configure in a chroot after the install has finished. \n"
    echo -e "The desktop installation will allow you to install NetworkManager, install graphics drivers, and install a DE or WM from this installer with sane defaults. \n"

    installType=$(fzf --height 10%)

    cd /root/

    clear

    # Extra install options
    if [ $installType == "desktop" ]; then

        #Graphics driver options
        mkdir /root/graphicsSelection
        touch /root/graphicsSelection/amd
        touch /root/graphicsSelection/intel
        touch /root/graphicsSelection/skip
        cd /root/graphicsSelection
    
        clear

        echo -e "If you would like to install graphics drivers, please choose 'amd' or 'intel' here, depending on what graphics card you have. \n"
        echo -e "If you would like to skip installing graphics drivers here, choose 'skip' \n"

        graphicsChoice=$(fzf --height 10%)

        cd /root/

        clear

        # I don't know why someone wouldn't want NM, but hey;
        echo -e "Would you like to install NetworkManager? (y/n) \n"
        read networkChoice

        clear

        # Audio server
        mkdir /root/audioSelection
        touch /root/audioSelection/pipewire
        touch /root/audioSelection/pulseaudio
        touch /root/audioSelection/skip
        cd /root/audioSelection

        clear

        echo -e "Choose the audio server you would like to install. Pipewire is recommended here."
        echo -e "If you would like to skip installing an audio server, choose skip here. \n"

        audioChoice=$(fzf --height 10%)

        cd /root

        clear

        # GUI selection
        mkdir /root/desktopSelection
        touch /root/desktopSelection/gnome
        touch /root/desktopSelection/kde
        touch /root/desktopSelection/xfce
        touch /root/desktopSelection/sway
        touch /root/desktopSelection/i3
        touch /root/desktopSelection/cinnamon
        touch /root/desktopSelection/skip
        cd /root/desktopSelection

        clear

        echo -e "Choose the desktop environment or window manager you would like to install."
        echo -e "If you would like to skip installing an DE/WM, choose skip here. (Such as to install one that isn't in this list) \n"

        desktopChoice=$(fzf --height 10%)

        cd /root/

        clear

        # Flatpak
        echo -e "Would you like to install flatpak? (y/n) \n"
        read flatpakPrompt

        confirmInstallationOptions
    elif [ $installType == "minimal" ]; then
        confirmInstallationOptions
    fi
}

confirmInstallationOptions() {

    # If a config is being used, we need to set some variables that weren't defined earlier in the script
    if [ $configDetected == "1" ]; then

        if [ $rootPrompt != "full" ]; then
            separateHomePossible=1
        else
            separateHomePossible=0
        fi

        if [[ $diskInput == /dev/nvme* ]] ; then
            partition1="$diskInput"p1
            partition2="$diskInput"p2
        else
            partition1="$diskInput"1
            partition2="$diskInput"2
        fi
    fi

    # Allow the user to make sure things are sound before destroying the data on their disk
    mkdir /root/confirmInstallMenu
    touch /root/confirmInstallMenu/confirm

    if [ $configDetected == "0" ]; then
        touch /root/confirmInstallMenu/restart
    elif [ $configDetected == "1" ]; then
        touch /root/confirmInstallMenu/exit
    fi
    cd /root/confirmInstallMenu
    clear

    echo "Your disk will not be touched until you select 'confirm'"
    if [ $configDetected == "0" ]; then
        echo -e "If these choices are in any way incorrect, you may select 'restart' to go back to the beginning of the installer and start over."
    elif [ $configDetected == "1" ]; then
        echo -e "If these choices are in any way incorrect, you may select 'exit' to close the installer and make changes to your config."
    fi
    echo -e "If the following choices are correct, you may select 'confirm' to proceed with the installation. \n"
    echo -e "Selecting 'confirm' here will destroy all data on the selected disk and install with the options below. \n"

    echo "Install disk: $diskInput"
    echo "Create swap: $swapPrompt"
    if [ $swapPrompt == "y" ] || [ $swapPrompt == "Y" ]; then
        echo "Swap size: $swapInput"
    fi
    echo "Root partition size: $rootPrompt"
    if [ $separateHomePossible == "1" ]; then
        echo "Create separate home: $homePrompt"
        if [ $homePrompt == "y" ] || [ $homePrompt == "Y" ]; then
            echo "Home size: $homeInput"
        fi
    fi
    echo "libc selection: $muslSelection"
    echo "Hostname: $hostnameInput"
    echo "Timezone: $timezonePrompt"
    echo "Installation profile: $installType"
    if [ $installType == "desktop" ]; then
        echo "Graphics drivers: $graphicsChoice"
        echo "Install NetworkManager: $networkChoice"
        echo "Audio server: $audioChoice"
        echo "DE/WM: $desktopChoice"
        echo "Install flatpak: $flatpakPrompt"
    fi

    confirmInstall=$(fzf --height 10%)

    if [ $confirmInstall == "restart" ]; then
        entry
    elif [ $confirmInstall == "confirm" ]; then
        install
    elif [ $confirmInstall == "exit" ]; then
        exit 1
    fi

    cd /root

}

install() {

    clear
    echo "Begin disk partitioning..."

    # Make EFI boot partition and secondary partition to store encrypted volumes
    parted $diskInput mklabel gpt
    parted $diskInput mkpart primary 0% 500M --script
    parted $diskInput set 1 esp on --script
    parted $diskInput mkpart primary 500M 100% --script

    mkfs.vfat $partition1

    clear
    echo "Configuring partitions for encrypted install..."
    echo -e "Enter your encryption passphrase here, the stronger the better. \n"

    cryptsetup luksFormat --type luks1 $partition2
    echo -e "Opening new encrypted container... \n"
    cryptsetup luksOpen $partition2 void
    echo -e "Creating volume group... \n"
    vgcreate void /dev/mapper/void

    echo -e "Creating volumes... \n"

    if [ $swapPrompt == "y" ] || [ $swapPrompt == "Y" ]; then
        echo -e "Creating swap volume..."
        lvcreate --name swap -L $swapInput void
        mkswap /dev/void/swap
    fi

    if [ $rootPrompt == "full" ]; then
        echo -e "Creating full disk root volume..."
        lvcreate --name root -l 100%FREE void
    else
        echo -e "Creating $rootPrompt disk root volume..."
        lvcreate --name root -L $rootPrompt void
    fi

    # Should add support for other FS types at some point
    mkfs.ext4 /dev/void/root

    if [ $separateHomePossible == "1" ]; then
        if [ $homePrompt == "y" ] || [ $homePrompt == "Y" ]; then
            if [ $homeInput == "full" ]; then
                lvcreate --name home -l 100%FREE void
                mkfs.ext4 /dev/void/home
            else
                lvcreate --name home -L $homeInput void
                mkfs.ext4 /dev/void/home
            fi
        fi
    fi

    echo -e "Mounting partitions... \n"
    mount /dev/void/root /mnt
    for dir in dev proc sys run; do mkdir -p /mnt/$dir ; mount --rbind /$dir /mnt/$dir ; mount --make-rslave /mnt/$dir ; done
    mkdir -p /mnt/boot/efi
    mount $partition1 /mnt/boot/efi

    echo -e "Copying keys... \n"
    mkdir -p /mnt/var/db/xbps/keys
    cp /var/db/xbps/keys/* /mnt/var/db/xbps/keys

    echo -e "Installing base system in 3... \n"
    sleep 1
    echo -e "Installing base system in 2... \n"
    sleep 1
    echo -e "Installing base system in 1... \n"
    sleep 1

    xbps-install -Sy -R $installRepo -r /mnt base-system cryptsetup grub-x86_64-efi lvm2
    echo -e "Base system installed... \n"
    sleep 2
    echo -e "Configuring fstab... \n"

    echo "$partition1	/boot/efi	vfat	defaults	0	0" >> /mnt/etc/fstab
    echo "/dev/void/root  /     ext4     defaults              0       0" >> /mnt/etc/fstab

    if [ $swapPrompt == "y" ]; then
        echo "/dev/void/swap  swap  swap    defaults              0       0" >> /mnt/etc/fstab
    fi

    if [ $homePrompt == "y" ] && [ $separateHomePossible == "1" ]; then
        echo "/dev/void/home  /home ext4     defaults              0       0" >> /mnt/etc/fstab
    fi

    if [ $muslSelection == "glibc" ]; then
        echo -e "Configuring locales... \n"
        echo $locale > /mnt/etc/locale.conf
        echo $libclocale >> /mnt/etc/default/libc-locales
    fi

    echo $hostnameInput > /mnt/etc/hostname

    echo -e "Configuring grub... \n"
    partUUIDVar=$(blkid -o value -s UUID $partition2)
    sed -i -e 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=4"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=4 rd.lvm.vg=void rd.luks.uuid='$partUUIDVar'"/g' /mnt/etc/default/grub
    #I really need to change how this is done, I know it's awful.
    echo "GRUB_ENABLE_CRYPTODISK=y" >> /mnt/etc/default/grub
    echo -e "Grub configured... \n"

    if [ $installType == "minimal" ]; then
        chrootFunction
    elif [ $installType == "desktop" ]; then

        # Graphics drivers
        if [ $graphicsChoice == "amd" ]; then
            echo -e "Installing AMD graphics drivers... \n"
            xbps-install -Sy -R $installRepo -r /mnt mesa-dri vulkan-loader mesa-vulkan-radeon mesa-vaapi mesa-vdpau
            echo -e "AMD graphics drivers have been installed... \n"
        elif [ $graphicsChoice == "nvidia" ]; then
            echo -e "Installing NVIDIA graphics drivers... \n"
            xbps-install -Sy -R $installRepo -r /mnt void-repo-nonfree
            xbps-install -Sy -R $installRepo -r /mnt nvidia
            echo -e "NVIDIA graphics drivers have been installed... \n"
        elif [ $graphicsChoice == "intel" ]; then
            echo -e "Installing INTEL graphics drivers... \n"
            xbps-install -Sy -R $installRepo -r /mnt mesa-dri vulkan-loader mesa-vulkan-intel intel-video-accel
            echo -e "INTEL graphics drivers have been installed... \n"
        elif [ $graphicsChoice == "nvidia-optimus" ]; then
            echo -e "Installing INTEL and NVIDIA graphics drivers... \n"
            xbps-install -Sy -R $installRepo -r /mnt void-repo-nonfree
            xbps-install -Sy -R $installRepo -r /mnt nvidia mesa-dri vulkan-loader mesa-vulkan-intel intel-video-accel
            echo -e "INTEL and NVIDIA graphics drivers have been installed... \n"
        fi

        # Networkmanager
        if [ $networkChoice == "y" ] || [ $networkChoice == "Y" ]; then
            echo -e "Installing NetworkManager... \n"
            xbps-install -Sy -R $installRepo -r /mnt NetworkManager
        fi

        # Audio server
        if [ $audioChoice == "pipewire" ]; then
            echo -e "Installing pipewire... \n"
            xbps-install -Sy -R $installRepo -r /mnt pipewire alsa-pipewire
            mkdir -p /mnt/etc/alsa/conf.d
        elif [ $audioChoice == "pulseaudio" ]; then
            echo -e "Installing pulseaudio... \n"
            xbps-install -Sy -R $installRepo -r /mnt pulseaudio alsa-plugins-pulseaudio
        fi

        # DE/WM
        if [ $desktopChoice == "gnome" ]; then
            echo -e "Installing Gnome desktop environment... \n"
            xbps-install -Sy -R $installRepo -r /mnt gnome
            echo -e "Gnome installed. \n"
            sleep 1
        elif [ $desktopChoice == "kde" ]; then
            echo -e "Installing KDE desktop environment... \n"
            xbps-install -Sy -R $installRepo -r /mnt kde5 kde5-baseapps kdegraphics-thumbnailers ffmpegthumbs xorg-minimal
            echo -e "KDE installed. \n"
            sleep 1
        elif [ $desktopChoice == "xfce" ]; then
            echo -e "Installing XFCE desktop environment... \n"
            xbps-install -Sy -R $installRepo -r /mnt xfce4 lightdm lightdm-gtk3-greeter xorg-minimal xorg-fonts
            echo -e "XFCE installed. \n"
            sleep 1
        elif [ $desktopChoice == "sway" ]; then
            echo -e "Sway will have to be started manually on login. This can be done by entering 'dbus-run-session sway' after logging in to the new installation. \n"
            sleep 4
            echo -e "Installing Sway window manager... \n"
            xbps-install -Sy -R $installRepo -r /mnt sway elogind polkit-elogind dbus-elogind foot xorg-fonts
            echo -e "Sway installed. \n"
            sleep 1
        elif [ $desktopChoice == "i3" ]; then
            echo -e "Installing i3wm... \n"
            xbps-install -Sy -R $installRepo -r /mnt xorg-minimal xinit i3 xorg-fonts
            echo -e "i3wm has been installed. \n"
            echo -e "Would you like to install lightdm with i3wm? (y/n) \n"
            read i3prompt
            if [ $i3prompt == "y" ] || [ $i3prompt == "Y" ]; then
                echo -e "Installing lightdm... \n"
                xbps-install -Sy -R $installRepo -r /mnt lightdm lightdm-gtk3-greeter
                echo "lightdm installed."
            fi
        elif [ $desktopChoice == "cinnamon" ]; then
            echo -e "Installing cinnamon... \n"
            xbps-install -Sy -R $installRepo -r /mnt cinnamon lightdm lightdm-gtk3-greeter xorg-minimal xorg-fonts
            echo -e "Cinnamon installed. \n"
        fi

        # Flatpak
        if [ $flatpakPrompt == "y" ] || [ $flatpakPrompt == "Y" ]; then
            xbps-install -Sy -R $installRepo -r /mnt flatpak
        fi

        echo -e "Desktop setup completed. \n"
        echo -e "The system will now chroot into the new installation for final setup... \n"

        chrootFunction
    fi
}

# Passing some stuff over to the new install to be used by the secondary script
chrootFunction() {
    cp /etc/resolv.conf /mnt/etc
    touch /root/selectTimezone
    echo "$timezonePrompt" >> /root/selectTimezone
    cp /root/selectTimezone /mnt/home/selectTimezone
    touch /root/installDrive
    echo "$diskInput" >> /root/installDrive
    cp /root/installDrive /mnt/home/installDrive
    cp -f $runDirectory/systemchroot.sh /mnt/home/systemchroot.sh
    chroot /mnt /bin/bash -c "/bin/bash /home/systemchroot.sh"
}

entry
