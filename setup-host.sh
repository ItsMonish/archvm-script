
#---------------------------------------------------------------------------------
# Color Codes Declaration
#---------------------------------------------------------------------------------
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
LIGHT_BLUE='\033[1;34m'
NC='\033[0m'

#---------------------------------------------------------------------------------
# Throw error and exit
#---------------------------------------------------------------------------------
fatal() {
    echo -e "${RED}[Error]${NC}: $1"
    echo -e "${RED}*** Encountered fatal error exitting script ***${NC}"
    exit 1
}

#---------------------------------------------------------------------------------
# Just throw an error
#---------------------------------------------------------------------------------
error() {
    echo -e "${RED}[Error]${NC}: $1"
}

#---------------------------------------------------------------------------------
# Display okay status with message
#---------------------------------------------------------------------------------
okay() {
    echo -e "${GREEN}[OK]${NC}: $1"
}

#---------------------------------------------------------------------------------
# Print info
#---------------------------------------------------------------------------------
info() {
    echo -e "${LIGHT_BLUE}$1${NC}"
}

#---------------------------------------------------------------------------------
# Configure and generates locale and sync to hardware clock
#---------------------------------------------------------------------------------
configure_time_and_locale() {

    ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
    hwclock --systohc
    okay "Configured time zone and system clock"

    sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
    locale-gen &> /dev/null
    echo "LANG=en_US.UTF-8" > /etc/locale.conf
    okay "Locale generated"

}

#---------------------------------------------------------------------------------
# Basic configuration for user setup
#---------------------------------------------------------------------------------
configure_system() {

    info "*** Configuring Networks ***"
    echo "$HOSTNAME" > /etc/hostname
    systemctl enable NetworkManager.service
    okay "Network manager started successfully"

    (
        echo $PASSWORD
        echo $PASSWORD
    ) | passwd &> /dev/null
    okay "Root password set"

    info "*** Making user account ***"
    useradd -m -G wheel -s /bin/bash $USERNAME
    (
        echo $PASSWORD
        echo $PASSWORD
    ) | passwd $USERNAME &> /dev/null
    sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
    okay "User account setup"

}

#---------------------------------------------------------------------------------
# Installs yay - AUR helper
#---------------------------------------------------------------------------------
install_yay() {

    info "*** Attempting to install yay ***"
    su - $USERNAME -c 'git clone https://aur.archlinux.org/yay.git > /dev/null'
    okay "Collected yay from git"
    info "*** Making yay ***"
    su - $USERNAME -c 'cd yay && makepkg -si --noconfirm && cd .. && rm -fr yay'
    info "*** Installed yay successfully"
    
}

#---------------------------------------------------------------------------------
# Installs GRUB - Bootloader
#---------------------------------------------------------------------------------
install_grub() {

    info "*** Installing grub boot loader ***"

    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg

    okay "Installed grub successfully"

}

#---------------------------------------------------------------------------------
# Installs GUI based on the value DE variable is set to
#---------------------------------------------------------------------------------
install_gui() {
    
    info "*** Installing Graphical User Interface Components ***"

    echo $PACKAGES

    su - $USERNAME -c "yay -S --noconfirm $PACKAGES"

    okay "Installed required components"

    if [ $DE = "gnome" ];
    then
        systemctl enable gdm.service
    else
        systemctl enable sddm.service
    fi
    
    info "*** Successfully installed GUI components ***"
}

#---------------------------------------------------------------------------------
# Installs mirrors to access blackarch repo
#---------------------------------------------------------------------------------
install_blackarch() {

    info "*** Installing blackarch repos ***"

    curl -O https://blackarch.org/strap.sh
    chmod +x strap.sh
    ./strap.sh

    rm ./strap.sh

    info "*** Installed blackarch repos ***"

}

#---------------------------------------------------------------------------------
# Main driver function
#---------------------------------------------------------------------------------
main() {

    info "*** Starting chroot system setup ***"

    configure_time_and_locale

    configure_system

    info "*** Installing git and grub ***"

    pacman -S --noconfirm grub efibootmgr git go

    install_yay

    install_grub

    if [ $DE = "" ];
    then
        info "*** No Window Manger or Desktop Environment is installed \
            as None as selected ***"
        info "*** Installing necessary packages ***"
        su - $USERNAME -c 'yay -S --noconfirm $PACKAGES'
    else
        install_gui
    fi

    if [ $BLACKARCH = true ]; 
    then
        install_blackarch
    fi

    sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

    info "*** Installation on chroot system is done ***"

    exit 0
}

main