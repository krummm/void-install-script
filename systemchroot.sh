#!/bin/bash
chown root:root /
chmod 755 /
echo "Set your root password:"
passwd root

echo -e "Running grub-install... \n"
grub-install --removable --target=x86_64-efi

echo -e "Enabling all services... \n"
if test -e "/etc/sv/dbus" ; then
    echo -e "Starting dbus... \n"
    ln -s /etc/sv/dbus /var/service
fi

if test -e "/etc/sv/NetworkManager" ; then
    echo -e "Starting NetworkManager... \n"
    ln -s /etc/sv/NetworkManager /var/service
fi

if test -e "/usr/share/applications/pipewire.desktop" ; then
    echo -e "Starting Pipewire... \n"
    ln -s /usr/share/applications/pipewire.desktop /etc/xdg/autostart/pipewire.desktop
    ln -s /usr/share/applications/pipewire-pulse.desktop /etc/xdg/autostart/pipewire-pulse.desktop
    ln -s /usr/share/alsa/alsa.conf.d/50-pipewire.conf /etc/alsa/conf.d
    ln -s /usr/share/alsa/alsa.conf.d/99-pipewire-default.conf /etc/alsa/conf.d
fi

if test -e "/etc/sv/gdm" ; then
    echo -e "Starting gdm... \n"
    ln -s /etc/sv/gdm /var/service
fi

if test -e "/etc/sv/sddm" ; then
    echo -e "Starting sddm... \n"
    ln -s /etc/sv/sddm /var/service
fi

if test -e "/etc/sv/lightdm" ; then
    echo -e "Starting lightdm... \n"
    ln -s /etc/sv/lightdm /var/service
fi

if test -e "/usr/bin/grimshot" ; then
    if test -e "/etc/sv/elogind" ; then
        echo -e "Starting elogind... \n"
        ln -s /etc/sv/elogind /var/service
    fi
fi

if test -e "/usr/bin/flatpak" ; then
    echo -e "Adding flathub repo for flatpak... \n"
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
fi

if test -e "/usr/bin/cryptsetup" ; then

    echo -e "Configuring LUKS key... \n"

    diskInput=$(cat /home/installdrive)
    if [[ $diskInput == /dev/nvme* ]] ; then
        partition2="$diskInput"p2
    else
        partition2="$diskInput"2
    fi

    dd bs=1 count=64 if=/dev/urandom of=/boot/volume.key
    echo -e "Enter your encryption passphrase: \n"
    cryptsetup luksAddKey $partition2 /boot/volume.key
    chmod 000 /boot/volume.key
    chmod -R g-rwx,o-rwx /boot

    echo "void   $partition2   /boot/volume.key   luks" >> /etc/crypttab
    
    touch /etc/dracut.conf.d/10-crypt.conf
    dracutConf='install_items+=" /boot/volume.key /etc/crypttab "'
    echo "$dracutConf" >> /etc/dracut.conf.d/10-crypt.conf

    rm /home/installdrive
    echo "LUKS key configured."

fi

clear

echo -e "If you would like to create a new user, enter a username here. \n"
echo -e "If you do not want to add a user now, enter 'skip' \n"
read createUser

if [ $createUser == "skip" ]; then
    xbps-reconfigure -fa
    clear

    echo -e "Installation complete. If you selected manual install or need to create users, you may want to do some configuration in chroot. \n"
    echo -e "If you are ready to reboot into your new system, exit the chroot and reboot. \n"
    rm /home/systemchroot.sh
else

    if test -e "/dev/mapper/void-home" ; then
        mount /dev/mapper/void-home /home
    fi

    useradd $createUser -m -d /home/$createUser
    clear
    echo "Please set the password for the user $createUser:"
    passwd $createUser
    usermod -aG audio,video,input,kvm $createUser
    echo -e "Should this user be a superuser? (y/n) \n"
    read superPrompt

    if [ $superPrompt == "y" ]; then
        usermod -aG wheel $createUser
        sed -i -e 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/g' /etc/sudoers
    fi

    xbps-reconfigure -fa

    clear
    echo -e "Installation complete. If you selected manual install or need to create users, you may want to do some configuration in chroot. \n"
    echo -e "If you are ready to reboot into your new system, enter 'reboot now'. \n"
    rm /home/systemchroot.sh

fi
