#!/bin/bash

# arguments: $RELEASE $LINUXFAMILY $BOARD $BUILD_DESKTOP
#
# This is the image customization script

# NOTE: It is copied to /tmp directory inside the image
# and executed there inside chroot environment
# so don't reference any files that are not already installed

# NOTE: If you want to transfer files between chroot and host
# userpatches/overlay directory on host is bind-mounted to /tmp/overlay in chroot

RELEASE=$1
LINUXFAMILY=$2
BOARD=$3
BUILD_DESKTOP=$4

#Modified display alert from lib/general.sh
#--------------------------------------------------------------------------------------------------------------------------------
# Let's have unique way of displaying alerts
#--------------------------------------------------------------------------------------------------------------------------------
display_alert()
{
    # log function parameters to install.log

    #[[ -n $DEST ]] && echo "Displaying message: $@" >> $DEST/debug/output.log

    local tmp=""
    [[ -n $2 ]] && tmp="[\e[0;33m $2 \x1B[0m]"

    case $3 in
        err)
        echo -e "[\e[0;31m error \x1B[0m] $1 $tmp"
        ;;

        wrn)
        echo -e "[\e[0;35m warn \x1B[0m] $1 $tmp"
        ;;

        ext)
        echo -e "[\e[0;32m o.k. \x1B[0m] \e[1;32m$1\x1B[0m $tmp"
        ;;

        info)
        echo -e "[\e[0;32m o.k. \x1B[0m] $1 $tmp"
        ;;

        *)
        echo -e "[\e[0;32m .... \x1B[0m] $1 $tmp"
        ;;
    esac
}

# Disable core dumps because DSF keep crashing in qemu static
display_alert "Disable core dumps"
ulimit -c 0

# Change Armbian config to add Spidev parameters and activate AppArmor
display_alert "Apply changes to armbianEnv.txt"
echo "param_spidev_spi_bus=0" >> /boot/armbianEnv.txt
echo "extraargs=spidev.bufsiz=8192 apparmor=1" >> /boot/armbianEnv.txt
echo "security=apparmor" >> /boot/armbianEnv.txt

# Disable Armbian ram logging service
display_alert "Disable Armbian ram logging service"
sed -i -e 's/ENABLED=true/ENABLED=false/g' /etc/default/armbian-ramlog

# Install packages to enable mDNS to resolve <hostname>.local
display_alert "Install required packages to enable mDNS"
apt-get -y -qq install avahi-daemon libnss-mdns libnss-mymachines

# Install Duet sources to APT
display_alert "Install Duet sources to APT"
wget -q https://pkg.duet3d.com/duet3d.gpg -O /etc/apt/trusted.gpg.d/duet3d.gpg
wget -q https://pkg.duet3d.com/duet3d.list -O /etc/apt/sources.list.d/duet3d.list
apt-get -y -qq install apt-transport-https
apt-get update

# Install Duet packages
display_alert "Install Duet packages"
apt-get -y -qq install \
    duetsoftwareframework \
    duetpluginservice \
    duetpimanagementplugin

# Mark packages on hold to prevent any unwanted upgrade
display_alert "Mark Duet packages on hold"
apt-mark hold \
    duetsoftwareframework \
    duetcontrolserver \
    duetruntime \
    duetsd \
    duettools \
    duetwebcontrol \
    duetwebserver \
    reprapfirmware

# Enable Duet services
display_alert "Enable Duet services"
systemctl enable duetcontrolserver
systemctl enable duetwebserver
systemctl enable duetpluginservice
systemctl enable duetpluginservice-root

# Install rrf_upgrade script
cp /tmp/overlay/rrf_upgrade.sh /usr/local/bin/rrf_upgrade
chmod a+x /usr/local/bin/rrf_upgrade

# Change DSF configuration according to the board
display_alert "Change DSF configuration according to the board"
sed -i -e 's|"SpiDevice": .*,|"SpiDevice": "/dev/spidev0.0",|g' /opt/dsf/conf/config.json
sed -i -e 's|"GpioChipDevice": .*,|"GpioChipDevice": "/dev/gpiochip1",|g' /opt/dsf/conf/config.json
sed -i -e 's|"TransferReadyPin": .*,|"TransferReadyPin": 18,|g' /opt/dsf/conf/config.json

# Change machine name to match hostname
display_alert "Change machine name to match hostname"
sed -i -e "s/M550 P\"Duet 3\"/\"M550 P\"$(head -n 1 /etc/hostname)\"/g" /opt/dsf/sd/sys/config.g

# Install execonmcode
display_alert "Install execonmcode"
wget -q https://github.com/wilriker/execonmcode/releases/download/v5.2.0/execonmcode-arm64 -O /usr/local/bin/execonmcode
chmod a+x /usr/local/bin/execonmcode
# Install Duet API listener to shutdown the SBC
display_alert "Install Duet API listener" 
wget -q https://raw.githubusercontent.com/wilriker/execonmcode/master/shutdownsbc.service -O /etc/systemd/system/shutdownsbc.service
systemctl enable shutdownsbc.service

# Install picocom to get USB-to-serial communication with the MCU
apt-get -y -qq install picocom
echo "alias stmusb=\"picocom -c --imap lfcrlf /dev/ttyACM0\"" >> /etc/profile.d/00-rrf.sh

# Add user to tty (for picocom) and dsf group once adduser is done
echo "usermod -aG dsf $1" >> /usr/local/sbin/adduser.local
echo "usermod -aG tty $1" >> /usr/local/sbin/adduser.local
chmod u+x /usr/local/sbin/adduser.local
