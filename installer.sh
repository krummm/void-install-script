#!/bin/bash
user=$(whoami)

if [ $user != root ]; then
    echo "Please execute this script as root."
    exit 1
fi

locale="LANG=en_US.UTF-8"
libclocale="en_US.UTF-8 UTF-8"

echo -e "Begin void installer... \n"

entry() {
    clear
    echo -e "Please enter the disk you would like to partition and install to: (Example: /dev/nvme0n1) \n"
    read diskInput

    clear

    echo -e "Are you certain $diskInput is the disk you mean to use? (y/n) \n"
    read areYouSure

    if [ $areYouSure == "n" ]; then
        echo -e "Please make certain you choose the correct disk \n"
        echo -e "To view all available disks, run 'lsblk' in your shell."
        exit 1
    elif [ $areYouSure == "y" ]; then
        diskSetup
    fi
}

diskSetup() {
    clear
    echo -e "Should this installation be encrypted? (y/n) \n"
    read encryptionPrompt

    if [ $encryptionPrompt == "y" ]; then
        echo -e "Installing parted... \n"
        xbps-install -Sy parted
        parted $diskInput mklabel gpt
        parted $diskInput mkpart primary 0% 500M --script
        parted $diskInput set 1 esp on --script
        parted $diskInput mkpart primary 500M 100% --script

        if [[ $diskInput == /dev/nvme* ]] ; then
            partition1="$diskInput"p1
            partition2="$diskInput"p2
        else
            partition1="$diskInput"1
            partition2="$diskInput"2
        fi

        clear
        echo "Configuring partitions for encrypted install..."
        echo -e "Enter your encryption passphrase here, the stronger the better. \n"

        cryptsetup luksFormat --type luks1 $partition2
        echo -e "Opening new encrypted container... \n"
        cryptsetup luksOpen $partition2 void
        echo -e "Creating volume group... \n"
        vgcreate void /dev/mapper/void

        clear

        echo -e "Creating partitions... \n"
        clear
        echo -e "Would you like to have a swap partition? (y/n) \n"
        read swapPrompt

        if [ $swapPrompt == "y" ]; then
            clear
            echo -e "How large would you like your swap partition to be? (Example: '4G') \n"
            read swapInput
            echo -e "Creating swap partition... \n"
            lvcreate --name swap -L $swapInput void
            mkswap /dev/void/swap
        fi

        clear
        echo "If you would like to limit the size of your root filesystem, such as to have a separate home partition, you can enter a value such as '50G' here."
        echo -e "Otherwise, if you would like your root partition to take up the entire drive, enter 'full' here. \n"
        read rootPrompt

        if [ $rootPrompt == "full" ]; then
            separateHomePossible=0
            lvcreate --name root -l 100%FREE void
            mkfs.ext4 /dev/void/root
        else
            rootInput=$rootPrompt
            separateHomePossible=1
            lvcreate --name root -L $rootInput void
            mkfs.ext4 /dev/void/root
        fi

        if [ $separateHomePossible == "1" ]; then
            clear
            echo -e "Would you like to have a separate home partition? (y/n) \n"
            read homePrompt

            if [ $homePrompt == "y" ]; then
                clear
                echo "How large would you like your home partition to be? (Example: '100G')"
                echo -e "You can choose to use the rest of your disk if you didn't give the entire disk to your root partition by entering 'full' \n"
                read homeInput

                if [ $homeInput == "full" ]; then
                    lvcreate --name home -l 100%FREE void
                else
                    lvcreate --name home -L $homeInput void
                fi

                mkfs.ext4 -L home /dev/void/home
            fi
        fi

        mkfs.vfat $partition1

        install

    elif [ $encryptionPrompt == "n" ]; then
        echo "Either encrypt your system or use the official installer."

        if [[ $diskInput == /dev/nvme* ]] ; then
            partition1="$diskInput"p1
            partition2="$diskInput"p2
        else
            partition1="$diskInput"1
            partition2="$diskInput"2
        fi
        #Create non-encrypted install option
    fi

}

install() {
    clear
    echo -e "Mounting partitions... \n"
    mount /dev/void/root /mnt
    for dir in dev proc sys run; do mkdir -p /mnt/$dir ; mount --rbind /$dir /mnt/$dir ; mount --make-rslave /mnt/$dir ; done
    mkdir -p /mnt/boot/efi
    mount $partition1 /mnt/boot/efi
    echo -e "Copying keys... \n"
    mkdir -p /mnt/var/db/xbps/keys
    cp /var/db/xbps/keys/* /mnt/var/db/xbps/keys/

    echo -e "Installing base system in 3... \n"
    sleep 1
    echo -e "Installing base system in 2... \n"
    sleep 1
    echo -e "Installing base system in 1... \n"
    sleep 1

    xbps-install -Sy -R https://repo-default.voidlinux.org/current -r /mnt base-system cryptsetup grub-x86_64-efi lvm2
    echo -e "Base system installed... \n"
    sleep 2
    echo -e "Configuring fstab... \n"

    echo "$partition1	/boot/efi	vfat	defaults	0	0" >> /mnt/etc/fstab
    echo "/dev/void/root  /     ext4     defaults              0       0" >> /mnt/etc/fstab

    if [ $swapPrompt == "y" ]; then
        echo "/dev/void/swap  swap  swap    defaults              0       0" >> /mnt/etc/fstab
    fi

    if [ $homePrompt == "y" ]; then
        echo "/dev/void/home  /home ext4     defaults              0       0" >> /mnt/etc/fstab
    fi

    clear

    echo -e "Are you installing a musl system? (y/n) \n"
    echo -e "If you chose a glibc installation ISO, please enter 'n' here. \n"
    read muslSelection

    if [ $muslSelection == n ]; then
        echo -e "Configuring locales... \n"
        echo $locale > /mnt/etc/locale.conf
        echo $libclocale >> /mnt/etc/default/libc-locales
    fi

    clear

    echo -e "What do you want this computer to be called on the network? (Hostname) \n"
    read hostnameInput
    echo $hostnameInput > /mnt/etc/hostname

    echo -e "Configuring grub... \n"
    partUUIDVar=$(blkid -o value -s UUID $partition2)
    sed -i -e 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=4"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=4 rd.lvm.vg=void rd.luks.uuid='$partUUIDVar'"/g' /mnt/etc/default/grub
    #I really need to change how this is done, I know it's awful.
    echo "GRUB_ENABLE_CRYPTODISK=y" >> /mnt/etc/default/grub
    echo -e "Grub configured... \n"

    clear

    echo -e "Would you like a minimal installation or a desktop installation? \n"
    echo -e "The minimal installation does not configure networking, graphics drivers, DE/WM, etc. Manually configure in the chroot after the install has finished. \n"
    echo -e "The desktop installation will allow you to install NetworkManager, install graphics drivers, and install a DE or WM from this installer with sane defaults. \n"
    echo -e "Enter 'm' for minimal, enter 'd' for desktop. \n"
    read installType

    if [ $installType == "m" ]; then
        cp /etc/resolv.conf /mnt/etc
        touch installdrive
        echo "$diskInput" >> installdrive
        cp installdrive /mnt/home/installdrive
        echo -e "Chrooting into new installation for final setup... \n"
        sleep 1
        cp -f systemchroot.sh /mnt/home/systemchroot.sh
        chroot /mnt /bin/bash -c "/bin/bash /home/systemchroot.sh"
    elif [ $installType == "d" ]; then
        desktopExtras
    fi
}

desktopExtras() {
    clear
    echo -e "If you would like to install graphics drivers, please enter 'amd' or 'nvidia' or 'intel' here, depending on what graphics card you have. \n"
    echo -e "If you would like to skip installing graphics drivers here, enter 'skip' \n"
    read graphicsChoice

    if [ $graphicsChoice == "amd" ]; then
        echo -e "Installing AMD graphics drivers... \n"
        xbps-install -Sy -R https://repo-default.voidlinux.org/current -r /mnt mesa-dri vulkan-loader mesa-vulkan-radeon mesa-vaapi mesa-vdpau
        echo -e "AMD graphics drivers have been installed... \n"
    elif [ $graphicsChoice == "nvidia" ]; then
        echo -e "Installing NVIDIA graphics drivers... \n"
        xbps-install -Sy -R https://repo-default.voidlinux.org/current -r /mnt void-repo-nonfree
        xbps-install -Sy -R https://repo-default.voidlinux.org/current -r /mnt nvidia
        echo -e "NVIDIA graphics drivers have been installed... \n"
    elif [ $graphicsChoice == "intel" ]; then
        echo -e "Installing INTEL graphics drivers... \n"
        xbps-install -Sy -R https://repo-default.voidlinux.org/current -r /mnt mesa-dri vulkan-loader mesa-vulkan-intel intel-video-accel
        echo -e "INTEL graphics drivers have been installed... \n"
    fi

    clear

    echo -e "Would you like to install NetworkManager? (y/n) \n"
    read networkChoice

    if [ $networkChoice == "y" ]; then
        echo -e "Setting up NetworkManager... \n"
        xbps-install -Sy -R https://repo-default.voidlinux.org/current -r /mnt NetworkManager
        echo -e "NetworkManager installed... \n"
    fi

    clear

    echo -e "Would you like to install an audio server? If you would like to install pipewire, enter 'pipewire' here. (Recommended)"
    echo "Pipewire should be started by your desktop environment or window manager post-installation,"
    echo -e "void-install will automatically create a .desktop file for pipewire to be autostarted, though this might have to be overwritten by the user post-installation. \n"
    echo -e "If you would instead like to use pulseaudio, enter 'pulseaudio' here. \n"
    echo -e "If you would like to skip installing an audio server, enter 'skip' here. \n"
    read audioChoice

    if [ $audioChoice == "pipewire" ]; then
        xbps-install -Sy -R https://repo-default.voidlinux.org/current -r /mnt pipewire alsa-pipewire
        mkdir -p /mnt/etc/alsa/conf.d
    elif [ $audioChoice == "pulseaudio" ]; then
        xbps-install -Sy -R https://repo-default.voidlinux.org/current -r /mnt pulseaudio alsa-plugins-pulseaudio
    fi

    clear

    echo "If you would like to install a desktop environment or window manager here, the following options are available:"
    echo -e "'gnome' 'kde' 'xfce' 'sway' 'i3' 'cinnamon' \n"
    echo -e "Note: if you chose not to install graphics drivers, this will likely cause problems. \n"
    echo -e "If you would like to skip installing a DE/WM (Such as to install one that isn't in this list), enter 'skip' here. \n"

    read desktopChoice

    if [ $desktopChoice == "gnome" ]; then
        echo -e "Installing Gnome desktop environment... \n"
        xbps-install -Sy -R https://repo-default.voidlinux.org/current -r /mnt gnome
        echo -e "Gnome installed. \n"
        sleep 1
    elif [ $desktopChoice == "kde" ]; then
        echo -e "Installing KDE desktop environment... \n"
        xbps-install -Sy -R https://repo-default.voidlinux.org/current -r /mnt kde5 kde5-baseapps kdegraphics-thumbnailers ffmpegthumbs xorg-minimal
        echo -e "KDE installed. \n"
        sleep 1
    elif [ $desktopChoice == "xfce" ]; then
        echo -e "Installing XFCE desktop environment... \n"
        xbps-install -Sy -R https://repo-default.voidlinux.org/current -r /mnt xfce4 xfce4-goodies lightdm lightdm-gtk-greeter
        echo -e "XFCE installed. \n"
        sleep 1
    elif [ $desktopChoice == "sway" ]; then
        echo -e "Sway will have to be started manually on login. This can be done by entering 'dbus-run-session sway' after logging in to the new installation. \n"
        echo -e "Installing Sway window manager... \n"
        sleep 4
        xbps-install -Sy -R https://repo-default.voidlinux.org/current -r /mnt sway elogind polkit-elogind dbus-elogind foot
        echo -e "Sway installed. \n"
        sleep 1
    elif [ $desktopChoice == "i3" ]; then
        echo -e "Installing i3wm... \n"
        xbps-install -Sy -R https://repo-default.voidlinux.org/current -r /mnt xorg xinit i3
        echo -e "i3wm has been installed. \n"
        echo -e "If you would like to install a display manager (lightdm) here, enter 'dm' \n"
        echo -e "Otherwise, enter 'skip'. You will have to manually start i3 once you boot into your new system."
        read i3prompt
        if [ $i3prompt == "dm" ]; then
            echo -e "Installing lightdm... \n"
            xbps-install -Sy -R https://repo-default.voidlinux.org/current -r /mnt lightdm lightdm-gtk-greeter
            echo "Lightdm installed."
        fi
    elif [ $desktopChoice == "cinnamon" ]; then
        echo -e "Installing cinnamon... \n"
        xbps-install -Sy -R https://repo-default.voidlinux.org/current -r /mnt cinnamon lightdm lightdm-gtk-greeter
        echo -e "Cinnamon installed. \n"
    fi

    clear

    echo -e "Would you like to install flatpak? (y/n) \n"
    read flatpakPrompt
    
    if [ $flatpakPrompt == "y" ]; then
        xbps-install -Sy -R https://repo-default.voidlinux.org/current -r /mnt flatpak
    fi

    clear

    echo -e "If you would like to install any extra packages, enter them here with a space between each package name. \n"
    echo -e "Example: 'nano firefox vscode' \n"
    echo -e "If you would like to skip this, enter 'skip' \n"
    read extraPackages

    if [ $extraPackages != "skip" ]; then
        xbps-install -Sy -R https://repo-default.voidlinux.org/current -r /mnt $extraPackages
    fi

    clear

    echo -e "Desktop setup completed. \n"
    echo -e "The system will now chroot into the new installation for final setup... \n"

    cp /etc/resolv.conf /mnt/etc
    touch installdrive
    echo "$diskInput" >> installdrive
    cp installdrive /mnt/home/installdrive
    cp -f systemchroot.sh /mnt/home/systemchroot.sh
    chroot /mnt /bin/bash -c "/bin/bash /home/systemchroot.sh"

}

entry