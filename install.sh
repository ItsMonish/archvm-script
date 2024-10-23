#!/bin/bash

#---------------------------------------------------------------------------------
# Color Codes Declaration
#---------------------------------------------------------------------------------
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
LIGHT_BLUE='\033[1;34m'
NC='\033[0m'

#---------------------------------------------------------------------------------
# Variables Initialziation
#---------------------------------------------------------------------------------
USERNAME=""
PASSWORD=""
HOSTNAME=""
ROOT_SIZE=0
DE=""
KERNEL=""
BLACKARCH=""
PACKAGES=""
GUEST_ADDITIONS=""

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
# Checking the installation environment
#---------------------------------------------------------------------------------
prelim_checks() {

    if [ -f /etc/arch-release ];
    then
        okay "Running on arch linux"
    else
        fatal "Must be run on arch linux live"
    fi

    if [ $(id -u) -eq 0 ];
    then
        okay "Running as root"
    else
        fatal "Must be run as root"
    fi

    fw_platform=$(cat /sys/firmware/efi/fw_platform_size 2> /dev/null)
    fw_platform=${fw_platform:-0}

    if [ $fw_platform -eq 64 ];
    then
        okay "Booted in 64-bit UEFI"
    else
        fatal "Not booted in UEFI or 64-bit system"
    fi

    ping -c 1 -q "google.com" &> /dev/null
    if [ $? -eq 0 ];
    then
        okay "Internet connectivity is present"
    else
        fatal "No internet connectivity detected"
    fi

    disks=$(lsblk -n --output KNAME,TYPE | awk -F " " '$2=="disk"{print $1}')
    disks=${disks:-""}

    if [ $disks = "" ];
    then
        fatal "There are no hard disks to install on"
    else
        okay "Found hard disks to install"
        for disk in $disks
        do
            okay "Found /dev/$disk"
        done
    fi

}

#---------------------------------------------------------------------------------
# Get password for user account 
#---------------------------------------------------------------------------------
get_passwords() {

    read -p "Enter password to set [user]:" PASSWORD
    PASSWORD=${PASSWORD:-"user"}

    read -p "Enter password again to confirm: " confirm_password
    confirm_password=${confirm_password:-"user"}

    if [ $PASSWORD != $confirm_password ]; 
    then
        error "Passwords don't match. Enter again"
        get_passwords
    fi

}

#---------------------------------------------------------------------------------
# Collect details for setting up the installation
#---------------------------------------------------------------------------------
collect_details() {

    while true
    do
        read -p "Enter username [user]:" USERNAME
        USERNAME=${USERNAME:-"user"}

        if [ $USERNAME = "root" ];
        then
            error "Username cannot be root. Change to something else"
        else
            break
        fi
    done
    
    get_passwords

    read -p "Enter hostname [arch]:" HOSTNAME
    HOSTNAME=${HOSTNAME:-"arch"}

    while true
    do
        echo "Enter desktop environment to be installed"
        echo "Available:"
        echo -e "xfce\tkde\tgnome"
        read -p "Select option to install [None]:" DE
        DE=${DE:-""}

        if [[ "$DE" == "xfce" ||    \
            "$DE" == "kde" ||       \
            "$DE" == "gnome" ||     \
            -z "$DE" ]]; then
            break
        else
            error "Unrecognized DE given"
        fi
    done


    while true
    do
        read -p "Enter kernel to install (lts/zen/hardened)[vanilla]: " KERNEL
        KERNEL=${KERNEL:-"linux"}
        if [ $KERNEL = "linux" ];
        then
            break
        elif [ $KERNEL = "lts" ]        \
            || [ $KERNEL = "zen" ]      \
            || [ $KERNEL = "hardened" ];
        then
            KERNEL="linux-$KERNEL"
            break
        else
            error "Kernel not recognized. Enter valid kernel name"
        fi
    done

    read -p "Blackarch repo (y/n)[n]:" BLACKARCH
    if [ -n "$BLACKARCH" ] && [ $BLACKARCH = "y" ];
    then
        BLACKARCH=true
    else
        BLACKARCH=false
    fi

    read -p "Guest additions to install? (spice-qemu/vbox/none)[spice-qemu]:" \
        GUEST_ADDITIONS
    GUEST_ADDITIONS=${GUEST_ADDITIONS:-"spice-qemu"}
}

#---------------------------------------------------------------------------------
# Perform partitioning and format partitions. 
# Can be skipped with $SKIP_PARTITION_AND_MOUNT=true
#---------------------------------------------------------------------------------
make_partitions() {

    if [ "$INSTALLATION_DISK" != "" ]; 
    then
        okay "Selecting /dev/$INSTALLATION_DISK for installation"
    elif [ "$INSTALLATION_DISK" = "" ] && [ $(echo $disks | wc -l) -eq 1 ];
    then
        INSTALLATION_DISK=$disks
        okay "Selecting /dev/$INSTALLATION_DISK for installation"
    else
        error "More than one disk is found for install"
        fatal "Set INSTALLATION_DISK variable with the required disk"
    fi

    space=$(lsblk -n --output KNAME,SIZE \
            | awk -F " " -v disk="$INSTALLATION_DISK" '$1==disk {print $2}' \
            | sed 's/G//' | awk -F '.' '{print $1}')
    
    info "Available space for partitioning: $space GB"
    info "Making 1 GB partition for EFI partition"

    read -p "Enter size to be allocated for root partition in GB[8]: " ROOT_SIZE
    ROOT_SIZE=${ROOT_SIZE:-8}

    output=$((
        echo g
        echo n
        echo 
        echo 
        echo +1G
        echo n
        echo 
        echo 
        echo +${ROOT_SIZE}G
        echo n
        echo p
        echo 
        echo 
        echo 
        echo w
        echo q
    ) | fdisk /dev/$INSTALLATION_DISK | grep -E --color=never "^Created")
    
    while IFS= read -r line;
    do
        okay "$line"
    done <<< "$output"

    mkfs.fat -F 32 /dev/"$INSTALLATION_DISK"1 &> /dev/null
    okay "Created boot partition (fat32) at /dev/"$INSTALLATION_DISK"1"
    mkfs.ext4 /dev/"$INSTALLATION_DISK"2 &> /dev/null
    okay "Created root partition (ext4) at /dev/"$INSTALLATION_DISK"2"
    mkfs.ext4 /dev/"$INSTALLATION_DISK"3 &> /dev/null
    okay "Created home partition (ext4) at /dev/"$INSTALLATION_DISK"3"

}

#---------------------------------------------------------------------------------
# Mounting the partitions for installation
# Can be skipped with $SKIP_PARTITION_AND_MOUNT=true
#---------------------------------------------------------------------------------
mount_partitions() {

    mount /dev/"$INSTALLATION_DISK"2 /mnt
    okay "Mounted /dev/"$INSTALLATION_DISK"2 at /mnt as root"

    mount --mkdir /dev/"$INSTALLATION_DISK"1 /mnt/boot
    okay "Mounted /dev/"$INSTALLATION_DISK"1 at /mnt/boot as boot partition"

    mount --mkdir /dev/"$INSTALLATION_DISK"3 /mnt/home
    okay "Mounted /dev/"$INSTALLATION_DISK"3 at /mnt/home as home partition"

}

#---------------------------------------------------------------------------------
# Base Installation and configuration
#---------------------------------------------------------------------------------
install_base() {

    pacstrap -K /mnt $KERNEL linux-firmware base base-devel neovim networkmanager

}

#---------------------------------------------------------------------------------
# Collects relevant packages for installation
#---------------------------------------------------------------------------------
pull_files() {

    BASE_LINK="http://192.168.122.1:8000"
    HOST_SETUP="setup-host.sh"
    BASE_NO_GUI="packages/base"
    BASE_GUI="packages/base-gui"
    KDE="packages/kde"
    XFCE="packages/xfce"
    GNOME="packages/gnome"

    mkdir packages

    curl "$BASE_LINK/$HOST_SETUP" -o $HOST_SETUP

    if [ -z $DE ];
    then
        curl "$BASE_LINK/$BASE_NO_GUI" -o $BASE_NO_GUI
    else
        curl "$BASE_LINK/$BASE_GUI" -o $BASE_GUI
        if [ $DE = "xfce" ];
        then
            curl "$BASE_LINK/$XFCE" -o $XFCE
        elif [ $DE = "kde" ];
        then
            curl "$BASE_LINK/$KDE" -o $KDE
        elif [ $DE = "gnome" ];
        then
            curl "$BASE_LINK/$GNOME" -o $GNOME
        fi
    fi

}

#---------------------------------------------------------------------------------
# Prepares the list of packages to install based on choices given
#---------------------------------------------------------------------------------
prepare_packages() {

    if [ -z $DE ];
    then
        for package in $(cat packages/base)
        do
            PACKAGES="$PACKAGES $package"
        done
    else
        for package in $(cat packages/base-gui)
        do
            PACKAGES="$PACKAGES $package"
        done
        for package in $(cat "packages/$DE")
        do 
            PACKAGES="$PACKAGES $package"
        done
    fi
    if [ $GUEST_ADDITIONS = "spice-qemu" ];
    then
        PACKAGES="$PACKAGES spice-vdagent"
    elif [ $GUEST_ADDITIONS = "vbox" ] && [ ! -z $DE ];
    then
        PACKAGES="$PACKAGES virtualbox-guest-utils"
    elif [ $GUEST_ADDITIONS = "vbox" ];
    then
        PACKAGES="$PACKAGES virtualbox-guest-utils-nox"
    fi

}

#---------------------------------------------------------------------------------
# Prepares the setup file for the chroot system
#---------------------------------------------------------------------------------
prepare_host_setup() {
    {
        echo -e "USERNAME=\""$USERNAME"\""
        echo -e "PASSWORD=\""$PASSWORD"\""
        echo -e "HOSTNAME=\""$HOSTNAME"\""
        echo -e "BLACKARCH=$BLACKARCH"
        echo -e "DE=\""$DE"\""
        echo -e "PACKAGES=\""$PACKAGES"\""
        cat setup-host.sh
    } > setup.sh
}

#---------------------------------------------------------------------------------
# Main Driver function
#---------------------------------------------------------------------------------
main() {

    clear

    info "*** Performing preliminary checks before starting ***"
    prelim_checks
    info "*** Preliminary checks passed ***"

    info "*** Collecting information for installation ***"
    collect_details

    if [ ! $SKIP_PARTITION_AND_MOUNT ]; 
    then
        info "*** Making partitions ***"
        make_partitions

        info "*** Mounting partitions ***"
        mount_partitions
    else
        info "*** Skipping partitioning and mounting ***"
    fi
    
    info "*** Installing kernel and system base ***"
    install_base
    okay "Installed base system and kernel"
    
    info "*** Generating fstab file ***"
    genfstab -U /mnt > /mnt/etc/fstab

    pull_files
    prepare_packages

    prepare_host_setup
    cp -a setup.sh /mnt/
    chmod 777 /mnt/setup.sh

    info "*** Changing root into the new system ***"
    arch-chroot /mnt ./setup.sh

    rm /mnt/setup.sh
    umount -R /mnt
    okay "Unmounted all partitions"

    info "*** Installation successful ***"
    info "Remove installation media and reboot to boot into new arch installation"

}

main