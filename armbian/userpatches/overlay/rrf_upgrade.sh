#!/bin/bash
VERSION="0.0.1"

SCRIPT_URL="https://raw.githubusercontent.com/TeamGloomy/rrf_stm32_sbc/dev/armbian/userpatches/overlay/rrf_upgrade.sh"
SCRIPT_LOCATION="${BASH_SOURCE[@]}"
SELF_UPDATER_SCRIPT=/tmp/rrf_selfupdater.sh

SRC="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
DSF_CONF=/opt/dsf/conf/config.json

if [ $# -lt 1 ]; then
    echo "Usage: $0 <RRF_version>. Example: $0 3.4-b7"
    exit 1
fi

if [[ "${EUID}" -ne "0" ]]; then
    echo "This script requires root privileges, trying to use sudo"
    sudo "${SRC}/rrf_upgrade.sh" "$@"
    exit $?
fi

RRF_VERSION="$1"

main()
{
    echo "-----This will install the Duet packages for ${RRF_VERSION} -----"
    echo "-----Update and upgrade the SBC system-----"
    hold_packages
    apt-get -q update && apt-get -y upgrade
    echo "-----Upgrade and Update finished-----"
    add_duet_repo
    echo "-----Updating packages list-----"
    apt -q update
    echo "-----Updating packages finished-----"
    # Backup the config file prior to mess with
    backup_board_conf
    stop_rrf_services
    echo "-----Installing packages-----"
    unhold_packages
    apt install --allow-downgrades \
        duetsoftwareframework=${RRF_VERSION} \
        duetcontrolserver=${RRF_VERSION} \
        duetruntime=${RRF_VERSION} \
        duetsd=1.1.0 \
        duettools=${RRF_VERSION} \
        duetwebcontrol=${RRF_VERSION} \
        duetwebserver=${RRF_VERSION} \
        reprapfirmware=${RRF_VERSION}-1 \
    hold_packages
    echo "-----Installing packages finished-----"
    restore_board_conf
    restart_rrf_services
}

backup_board_conf()
{
    echo "-----Backup board configuration-----"
    cp "$DSF_CONF" "$DSF_CONF.bak"
    SPI_DEVICE="$(grep "^\s\+\"SpiDevice" $DSF_CONF | awk -F': "' '{print $2}')"
    GPIO_CHIP_DEVICE="$(grep "^\s\+\"GpioChipDevice" $DSF_CONF | awk -F': "' '{print $2}')"
    TRANSFER_READY_PIN="$(grep "^\s\+\"TransferReadyPin" $DSF_CONF | awk -F': ' '{print $2}')"
    echo "-----Backup board configuration finished-----"
}

restore_board_conf()
{
    echo "-----Restore board configuration-----"
    sed -i -e 's|"SpiDevice": .*,|"SpiDevice": "'"${SPI_DEVICE}"'|g' "$DSF_CONF"
    sed -i -e 's|"GpioChipDevice": .*,|"GpioChipDevice": "'"${GPIO_CHIP_DEVICE}"'|g' "$DSF_CONF"
    sed -i -e 's|"TransferReadyPin": .*,|"TransferReadyPin": '"${TRANSFER_READY_PIN}"'|g' "$DSF_CONF"
    echo "-----Restore board configuration finished-----"
}

hold_packages()
{
    apt-mark hold \
        duetsoftwareframework \
        duetcontrolserver \
        duetruntime \
        duetsd \
        duettools \
        duetwebcontrol \
        duetwebserver \
        reprapfirmware
}

unhold_packages()
{
    apt-mark unhold \
        duetsoftwareframework \
        duetcontrolserver \
        duetruntime \
        duetsd \
        duettools \
        duetwebcontrol \
        duetwebserver \
        reprapfirmware
}

add_duet_repo()
{
    echo "-----Switching to the unstable branch-----"
    wget -q https://pkg.duet3d.com/duet3d.gpg -O /etc/apt/trusted.gpg.d/
    wget -q https://pkg.duet3d.com/duet3d-unstable.list -O /etc/apt/sources.list.d/duet3d-unstable.list
    rm /etc/apt/sources.list.d/duet3d.list
    echo "-----Switching to the unstable branch finished-----"
}

stop_rrf_services()
{
    echo "-----Stopping Duet services-----"
    # Disable DCS to prevent automatic restart once installed and prior to restore board configuration
    # this way no error will be displayed because of wrong board SPI configuration
    # Check is done in /var/lib/dpkg/info/duetcontrolserver.postinst
    systemctl stop duetcontrolserver
    systemctl disable duetcontrolserver
    echo "-----Stopping Duet services finished-----"
}

restart_rrf_services()
{
    echo "-----Starting Duet services-----"
    systemctl enable duetcontrolserver
    systemctl start duetcontrolserver

    systemctl enable duetpluginservice
    systemctl start duetpluginservice

    systemctl enable duetpluginservice-root
    systemctl start duetpluginservice-root

    /opt/dsf/bin/PluginManager -q reload DuetPiManagementPlugin
    /opt/dsf/bin/PluginManager -q start DuetPiManagementPlugin
    echo "-----Starting Duet services finished-----"
}

self-update()
{
    # Delete previous self-updater script if any
    rm -f "$SELF_UPDATER_SCRIPT"

    TMP_FILE=$(mktemp -p "" "XXXXX.sh")
    curl -s -L "$SCRIPT_URL" > "$TMP_FILE"
    NEW_VER=$(grep "^VERSION" "$TMP_FILE" | awk -F'[="]' '{print $3}')
    ABS_SCRIPT_PATH=$(readlink -f "$SCRIPT_LOCATION")
    if [ "$VERSION" \< "$NEW_VER" ]
    then
        printf "Updating script \e[31;1m%s\e[0m -> \e[32;1m%s\e[0m\n" "$VERSION" "$NEW_VER"

        echo "cp \"$TMP_FILE\" \"$ABS_SCRIPT_PATH\"" > "$SELF_UPDATER_SCRIPT"
        echo "rm -f \"$TMP_FILE\"" >> "$SELF_UPDATER_SCRIPT"
        echo "echo Running script again: `basename ${BASH_SOURCE[@]}` $@" >> "$SELF_UPDATER_SCRIPT"
        echo "exec \"$ABS_SCRIPT_PATH\" \"$@\"" >> "$SELF_UPDATER_SCRIPT"

        chmod +x "$SELF_UPDATER_SCRIPT"
        chmod +x "$TMP_FILE"
        exec "$SELF_UPDATER_SCRIPT"
    else
        echo "The script is up-to-date. Continue..."
        rm -f "$TMP_FILE"
    fi
}

self-update "$@"
main
