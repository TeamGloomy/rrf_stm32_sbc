#!/bin/bash
VERSION="0.1.1"

# Scripts up to 0.0.11 re-exec themselves after a self-update with all arguments merged into one
# (e.g. "set-comms usb"), so split a single argument containing whitespace back into words
if [ $# -eq 1 ] && [[ "$1" =~ [[:space:]] ]]; then
    read -r -a SPLIT_ARGS <<< "$1"
    set -- "${SPLIT_ARGS[@]}"
fi

SCRIPT_URL="https://raw.githubusercontent.com/TeamGloomy/rrf_stm32_sbc/master/armbian/userpatches/overlay/rrf_upgrade.sh"
SCRIPT_LOCATION="${BASH_SOURCE[@]}"
SELF_UPDATER_SCRIPT=/tmp/rrf_selfupdater.sh

SRC="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
DSF_CONF=/opt/dsf/conf/config.json

FW_DOWNLOAD_TEMP_DIR="/tmp/teamgloomy_fw_temp"

if [ -t 1 ]; then
    C_RED=$'\033[0;31m'; C_GREEN=$'\033[0;32m'; C_YELLOW=$'\033[0;33m'
    C_BLUE=$'\033[0;34m'; C_CYAN=$'\033[0;36m'; C_BOLD=$'\033[1m'; C_RESET=$'\033[0m'
else
    C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_CYAN=""; C_BOLD=""; C_RESET=""
fi

usage()
{
    echo "Usage: rrf_upgrade                     Interactive menu (choose channel and version)"
    echo "       rrf_upgrade <RRF_version> [--comms spi|usb]. Example: rrf_upgrade 3.4-b7 or rrf_upgrade latest-stable or rrf_upgrade latest-unstable"
    echo "       rrf_upgrade set-comms spi|usb    Switch the SPI/USB communication method without touching installed packages"
}

if [ "${EUID}" -ne "0" ]; then
    echo "This script requires root privileges, trying to use sudo"
    sudo "$0" "$@"
    exit $?
fi

ALL_ARGS=("$@")
ACTION="${1:-}"
COMMS_METHOD=""
RRF_VERSION=""
CHANNEL=""
REPO_PREPARED=0

if [ $# -eq 0 ]; then
    ACTION="interactive"
elif [ "${ACTION}" == "set-comms" ]; then
    COMMS_METHOD="$2"
    if [ "${COMMS_METHOD}" != "spi" ] && [ "${COMMS_METHOD}" != "usb" ]; then
        usage
        exit 1
    fi
else
    RRF_VERSION="$1"
    shift
    while [ $# -gt 0 ]; do
        case "$1" in
            --comms)
                COMMS_METHOD="$2"
                if [ "${COMMS_METHOD}" != "spi" ] && [ "${COMMS_METHOD}" != "usb" ]; then
                    usage
                    exit 1
                fi
                shift 2
                ;;
            *)
                usage
                exit 1
                ;;
        esac
    done
fi

main()
{
    echo "-----This will install the Duet packages for ${RRF_VERSION} -----"
#    echo "-----Update and upgrade the SBC system-----"
    hold_packages
#    apt-get -q update && apt-get -y upgrade
#    echo "-----Upgrade and Update finished-----"
    if [ "${REPO_PREPARED}" -ne 1 ]; then
        add_duet_repo
        echo "-----Updating packages list-----"
        apt-get -q update
        echo "-----Updating packages finished-----"
    fi
    echo "-----Downloading TeamGloomy firmware-----"
    get_teamgloomy_fw
    echo "-----Downloading TeamGloomy firmware finished-----"
    # Backup the config file prior to mess with
    backup_board_conf
    stop_rrf_services
    echo "-----Installing packages-----"
    unhold_packages
    install_packages
    hold_packages
    echo "-----Installing packages finished-----"
    restore_board_conf
    restart_rrf_services
}

backup_board_conf()
{
    echo "-----Backup board configuration-----"
    # Check if configuration has been changed since installation
    INSTALLED_CONF_CHECKSUM=$(cat /var/lib/dpkg/info/duetcontrolserver.md5sums | grep opt/dsf/conf/config.json | awk 'NR==1{print $1}')
    CUR_CONF_CHECKSUM=$(md5sum /opt/dsf/conf/config.json | awk 'NR==1{print $1}')
    DCS_CONF_CHANGED_BY_USER=0; [ "$CUR_CONF_CHECKSUM" != "$INSTALLED_CONF_CHECKSUM" ] && DCS_CONF_CHANGED_BY_USER=1

    cp "$DSF_CONF" "$DSF_CONF.bak"
    SPI_DEVICE="$(grep "^\s\+\"SpiDevice" $DSF_CONF | awk -F': "' '{print $2}')"
    GPIO_CHIP_DEVICE="$(grep "^\s\+\"GpioChipDevice" $DSF_CONF | awk -F': "' '{print $2}')"
    TRANSFER_READY_PIN="$(grep "^\s\+\"TransferReadyPin" $DSF_CONF | awk -F': ' '{print $2}')"
    # Preserve the current CommunicationMethod, unless the user explicitly requested a different one via --comms
    if [ -n "${COMMS_METHOD}" ]; then
        COMMS_METHOD_CONF="${COMMS_METHOD}\","
    else
        COMMS_METHOD_CONF="$(grep "^\s\+\"CommunicationMethod" $DSF_CONF | awk -F': "' '{print $2}')"
    fi
    echo "-----Backup board configuration finished-----"
}

restore_board_conf()
{
    echo "-----Restore board configuration-----"
    sed -i -e 's|"SpiDevice": .*,|"SpiDevice": "'"${SPI_DEVICE}"'|g' "$DSF_CONF"
    sed -i -e 's|"GpioChipDevice": .*,|"GpioChipDevice": "'"${GPIO_CHIP_DEVICE}"'|g' "$DSF_CONF"
    sed -i -e 's|"TransferReadyPin": .*,|"TransferReadyPin": '"${TRANSFER_READY_PIN}"'|g' "$DSF_CONF"
    sed -i -e 's|"CommunicationMethod": .*,|"CommunicationMethod": "'"${COMMS_METHOD_CONF}"'|g' "$DSF_CONF"

    # Update the package checksum as we could check if the configuration file was modified by the user on the next upgrade
    sed -i -e "s%.*opt/dsf/conf/config.json%$(md5sum /opt/dsf/conf/config.json | awk 'NR==1{print $1}')  opt/dsf/conf/config.json%g" /var/lib/dpkg/info/duetcontrolserver.md5sums
    echo "-----Restore board configuration finished-----"
}

hold_packages()
{
    apt-mark hold \
        duetcontrolserver \
        duetpluginservice \
        duetpimanagementplugin \
        duetruntime \
        duetsd \
        duetsoftwareframework \
        duettools \
        duetwebcontrol \
        duetwebserver \
        reprapfirmware
}

unhold_packages()
{
    apt-mark unhold \
        duetcontrolserver \
        duetpluginservice \
        duetpimanagementplugin \
        duetruntime \
        duetsd \
        duetsoftwareframework \
        duettools \
        duetwebcontrol \
        duetwebserver \
        reprapfirmware
}

add_duet_repo()
{
    if [ -z "${CHANNEL}" ]; then
        if [ "${RRF_VERSION}" == "latest-stable" ]; then CHANNEL="stable"; else CHANNEL="unstable"; fi
    fi
    if [ "${CHANNEL}" == "stable" ];
    then
        echo "-----Switching to the stable branch-----"
        wget -q https://pkg.duet3d.com/duet3d.gpg -O /etc/apt/trusted.gpg.d/duet3d.gpg
        wget -q https://pkg.duet3d.com/duet3d.list -O /etc/apt/sources.list.d/duet3d.list
        rm -f /etc/apt/sources.list.d/duet3d-unstable.list
        add_preference_file
        echo "-----Switching to the stable branch finished-----"
    else
        echo "-----Switching to the unstable branch-----"
        wget -q https://pkg.duet3d.com/duet3d.gpg -O /etc/apt/trusted.gpg.d/duet3d.gpg
        wget -q https://pkg.duet3d.com/duet3d-unstable.list -O /etc/apt/sources.list.d/duet3d-unstable.list
        rm -f /etc/apt/sources.list.d/duet3d.list
        add_preference_file
        echo "-----Switching to the unstable branch finished-----"
    fi
}

add_preference_file()
{
    # Set priority higher than 1000 for duet package to allow them to be downgraded
    # even if there is a newer version currently installed on the system
    tee /etc/apt/preferences.d/10-duet-teamgloomy > /dev/null << END
# DO NOT EDIT THIS FILE !
# ANY CHANGE WILL BE OVERWRITTEN BY THE rrf_upgrade SCRIPT
# USE ANOTHER FILE WITH HIGHER PRIORITY INSTEAD e.g 00-duet
Package: *
Pin: origin "pkg.duet3d.com"
Pin-Priority: 1001
END
}

install_packages()
{
    if [ "${RRF_VERSION}" == "latest-stable" ] || [ "${RRF_VERSION}" == "latest-unstable" ];
    then
        apt-get -y install --allow-downgrades -o Dpkg::Options::=--force-confnew \
            duetcontrolserver \
            duetpluginservice \
            duetpimanagementplugin \
            duetruntime \
            duetsd \
            duetsoftwareframework \
            duettools \
            duetwebcontrol \
            duetwebserver \
            reprapfirmware
    else
        apt-get -y install --allow-downgrades -o Dpkg::Options::=--force-confnew \
            duetcontrolserver=${RRF_VERSION} \
            duetpluginservice=${RRF_VERSION} \
            duetpimanagementplugin=${RRF_VERSION} \
            duetruntime=${RRF_VERSION} \
            duetsd=1.1.0 \
            duetsoftwareframework=${RRF_VERSION} \
            duettools=${RRF_VERSION} \
            duetwebcontrol=${RRF_VERSION} \
            duetwebserver=${RRF_VERSION} \
            reprapfirmware=${RRF_VERSION}-1
    fi
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

set_comms_method()
{
    echo "-----Setting communication method to ${COMMS_METHOD}-----"
    stop_rrf_services
    cp "$DSF_CONF" "$DSF_CONF.bak"
    sed -i -e 's|"CommunicationMethod": .*,|"CommunicationMethod": "'"${COMMS_METHOD}"'",|g' "$DSF_CONF"
    restart_rrf_services
    echo "-----Communication method set to ${COMMS_METHOD}-----"
}

install_teamgloomy_fw_files()
{
    for FILE in `find "${FW_DOWNLOAD_TEMP_DIR}" -maxdepth 1 -type f`
    do
        FILENAME=$(basename ${FILE})
        if [[ "$FILENAME" =~ firmware-.*-sbc-.*\.bin ]]
        then
            if [ "${RRF_VERSION}" == "3.4.1" ]
            then
                # Rename firmware-mcutype-sbc-version.bin files into firmware-mcutype.bin (Specific to 3.4.1)
                echo "Move ${FW_DOWNLOAD_TEMP_DIR}"/"${FILENAME} to /opt/dsf/sd/firmware/"${FILENAME%-*}.bin""
                mv "${FW_DOWNLOAD_TEMP_DIR}"/"${FILENAME}" /opt/dsf/sd/firmware/"${FILENAME%-*}.bin"
            else
                # Rename firmware-mcutype-sbc-version.bin files into firmware-mcutype-sbc.bin
                echo "Move ${FW_DOWNLOAD_TEMP_DIR}"/"${FILENAME} to /opt/dsf/sd/firmware/"${FILENAME%-*-*}.bin""
                mv "${FW_DOWNLOAD_TEMP_DIR}"/"${FILENAME}" /opt/dsf/sd/firmware/"${FILENAME%-*-*}.bin"
            fi
        else
            echo "Move ${FILE} to /opt/dsf/sd/firmware/"${FILENAME}""
            mv "${FILE}" /opt/dsf/sd/firmware/
        fi
    done
}

get_teamgloomy_fw()
{
    if [ "${RRF_VERSION}" == "latest-stable" ] || [ "${RRF_VERSION}" == "latest_stable" ]
    then
        # Get the most recent non-prerelease, non-draft release
        FW_REPO="https://api.github.com/repos/gloomyandy/RepRapFirmware/releases/latest"
        RELEASE_DATA=$(curl -s "${FW_REPO}")
    elif [ "${RRF_VERSION}" == "latest-unstable" ] || [ "${RRF_VERSION}" == "latest_unstable" ]
    then
        # Get the most recent release
        FW_REPO="https://api.github.com/repos/gloomyandy/RepRapFirmware/releases"
        RELEASE_DATA=$(curl -s "${FW_REPO}" | jq '.[0]')
    else
        # Get the release for a specific version
        FW_REPO="https://api.github.com/repos/gloomyandy/RepRapFirmware/releases"
        # Get data related to the last teamgloomy release for the selected Duet version
        RELEASE_DATA=$(curl -s "${FW_REPO}" | jq '.[] | select(.tag_name? | match("v'${RRF_VERSION//\~/-}'(_.*)?"))')
    fi
    if [ -z "${RELEASE_DATA}" ] || ! echo -E "${RELEASE_DATA}" | jq -e . > /dev/null 2>&1
    then
        echo -e "\033[0;31mWarning: Unable to retrieve release data from GitHub for ${RRF_VERSION}, skipping firmware download\033[0m"
        return
    fi

    # Get SBC related zip files for that release
    # NB: using jq -r to remove quotes for wget to work
    ASSETS_URLS=$(echo -E "${RELEASE_DATA}" | jq -r '.assets[] | select(.name? | match("firmware-.*-sbc-.*\\.zip"|"STM32RepRapFirmwareSBC\\.zip")) | .browser_download_url')

    if [ -z "${ASSETS_URLS}" ]
    then
        echo -e "\033[0;31mWarning: No teamgloomy firmware found for ${RRF_VERSION}\033[0m"
    else
        mkdir -p "${FW_DOWNLOAD_TEMP_DIR}"
        for url in ${ASSETS_URLS}
        do
            echo "Download TeamGloomy firmware archive from ${url}:"
            wget -q --show-progress "${url}" -O teamgloomy_fw.zip
            unzip -o -d "${FW_DOWNLOAD_TEMP_DIR}" teamgloomy_fw.zip
            rm teamgloomy_fw.zip

            chown "dsf:dsf" "${FW_DOWNLOAD_TEMP_DIR}"/*
            install_teamgloomy_fw_files
        done
        rm -rf "${FW_DOWNLOAD_TEMP_DIR}"
    fi
}

self-update()
{
    # Delete previous self-updater script if any
    rm -f "$SELF_UPDATER_SCRIPT"

    TMP_FILE=$(mktemp -p "" "XXXXX.sh")
    if ! curl -s -f -L "$SCRIPT_URL" -o "$TMP_FILE" || [ ! -s "$TMP_FILE" ]
    then
        echo -e "\033[0;31mWarning: Unable to download the latest rrf_upgrade script, skipping self-update\033[0m"
        rm -f "$TMP_FILE"
        return
    fi

    NEW_VER=$(grep "^VERSION" "$TMP_FILE" | awk -F'[="]' '{print $3}')
    ABS_SCRIPT_PATH=$(readlink -f "$SCRIPT_LOCATION")
    if [ -n "$NEW_VER" ] && [ "$VERSION" != "$NEW_VER" ] && [ "$(printf '%s\n%s\n' "$VERSION" "$NEW_VER" | sort -V | tail -n1)" == "$NEW_VER" ]
    then
        printf "Updating script \e[31;1m%s\e[0m -> \e[32;1m%s\e[0m\n" "$VERSION" "$NEW_VER"

        echo "cp \"$TMP_FILE\" \"$ABS_SCRIPT_PATH\"" > "$SELF_UPDATER_SCRIPT"
        echo "rm -f \"$TMP_FILE\"" >> "$SELF_UPDATER_SCRIPT"
        echo "echo Running script again: `basename ${BASH_SOURCE[@]}` $@" >> "$SELF_UPDATER_SCRIPT"
        {
            printf 'exec %q' "$ABS_SCRIPT_PATH"
            [ $# -gt 0 ] && printf ' %q' "$@"
            printf '\n'
        } >> "$SELF_UPDATER_SCRIPT"

        chmod +x "$SELF_UPDATER_SCRIPT"
        chmod +x "$TMP_FILE"
        exec "$SELF_UPDATER_SCRIPT"
    else
        echo "The script is up-to-date. Continue..."
        rm -f "$TMP_FILE"
    fi
}

# ---------------------------------------------------------------------------
# Interactive UI (used when the script is run without arguments)
# ---------------------------------------------------------------------------

header()  { echo -e "\n${C_CYAN}${C_BOLD}=== $* ===${C_RESET}"; }
info()    { echo -e "${C_BLUE}$*${C_RESET}"; }
success() { echo -e "${C_GREEN}$*${C_RESET}"; }
warn()    { echo -e "${C_YELLOW}$*${C_RESET}"; }
error()   { echo -e "${C_RED}$*${C_RESET}"; }

get_installed_dsf_version()
{
    dpkg-query -W -f='${Version}' duetsoftwareframework 2>/dev/null
}

get_current_channel()
{
    if [ -f /etc/apt/sources.list.d/duet3d-unstable.list ]; then
        echo "unstable"
    elif [ -f /etc/apt/sources.list.d/duet3d.list ]; then
        echo "stable"
    else
        echo "unknown"
    fi
}

get_current_comms()
{
    grep "^\s\+\"CommunicationMethod" "$DSF_CONF" 2>/dev/null | awk -F': "' '{print $2}' | tr -d '",'
}

# List the duetsoftwareframework versions available in the configured repositories, newest first
# (same source of truth as https://github.com/DanalEstes/DuetVersions)
list_dsf_versions()
{
    apt-cache madison duetsoftwareframework 2>/dev/null | awk '{print $3}' | sort -uV -r
}

# Print the reprapfirmware and duetwebcontrol versions a given duetsoftwareframework version depends on
describe_dsf_version()
{
    local depends rrf dwc
    depends=$(apt-cache show "duetsoftwareframework=$1" 2>/dev/null | awk -F': ' '/^Depends:/{print $2; exit}')
    rrf=$(echo "${depends}" | grep -o 'reprapfirmware (= [^)]*)' | sed 's/.*= //;s/)//')
    dwc=$(echo "${depends}" | grep -o 'duetwebcontrol (= [^)]*)' | sed 's/.*= //;s/)//')
    printf "RRF %-12s DWC %s" "${rrf:-?}" "${dwc:-?}"
}

# Sets RRF_VERSION, returns 1 if the user went back or nothing is available
select_version()
{
    local channel="$1" limit=15 versions=() i choice
    info "Refreshing the ${channel} package list..."
    add_duet_repo > /dev/null
    apt-get -q update > /dev/null 2>&1
    REPO_PREPARED=1

    mapfile -t versions < <(list_dsf_versions)
    if [ "${#versions[@]}" -eq 0 ]; then
        error "No duetsoftwareframework versions found in the ${channel} repository"
        return 1
    fi

    while true; do
        header "Select version (${channel})"
        echo "  0) Latest ${channel} (recommended)"
        for ((i = 0; i < ${#versions[@]} && i < limit; i++)); do
            printf "  %d) DSF %-14s %s\n" "$((i + 1))" "${versions[$i]}" "$(describe_dsf_version "${versions[$i]}")"
        done
        [ "${#versions[@]}" -gt "${limit}" ] && echo "  a) Show all ${#versions[@]} versions"
        echo "  b) Back"
        read -r -p "Choose a version: " choice
        case "${choice}" in
            0) RRF_VERSION="latest-${channel}"; return 0 ;;
            a|A) limit=${#versions[@]} ;;
            b|B|q|Q) return 1 ;;
            *)
                if [[ "${choice}" =~ ^[0-9]+$ ]] && [ "${choice}" -ge 1 ] && [ "${choice}" -le "${#versions[@]}" ] && [ "${choice}" -le "${limit}" ]; then
                    RRF_VERSION="${versions[$((choice - 1))]}"
                    return 0
                fi
                warn "Invalid selection"
                ;;
        esac
    done
}

select_comms()
{
    local choice
    header "Communication method"
    echo "  1) Keep current ($(get_current_comms))"
    echo "  2) SPI"
    echo "  3) USB"
    read -r -p "Choose [1]: " choice
    case "${choice:-1}" in
        2) COMMS_METHOD="spi" ;;
        3) COMMS_METHOD="usb" ;;
        *) COMMS_METHOD="" ;;
    esac
}

interactive_install()
{
    local answer
    CHANNEL="$1"
    select_version "${CHANNEL}" || return
    select_comms

    header "Summary"
    echo "  Channel : ${CHANNEL}"
    echo "  Version : ${RRF_VERSION}"
    echo "  Comms   : ${COMMS_METHOD:-keep current}"
    warn "Duet services will be stopped during the upgrade and the board configuration restored afterwards."
    read -r -p "Proceed with installation? [y/N] " answer
    if [[ "${answer}" =~ ^[Yy]$ ]]; then
        main
        success "Done."
        exit 0
    fi
    info "Cancelled."
}

interactive_set_comms()
{
    local answer
    select_comms
    if [ -z "${COMMS_METHOD}" ]; then
        info "Communication method unchanged."
        return
    fi
    read -r -p "Switch communication method to ${COMMS_METHOD}? [y/N] " answer
    if [[ "${answer}" =~ ^[Yy]$ ]]; then
        set_comms_method
        exit 0
    fi
    COMMS_METHOD=""
}

interactive_menu()
{
    local choice
    if [ ! -t 0 ]; then
        usage
        exit 1
    fi
    while true; do
        header "TeamGloomy RRF upgrade v${VERSION}"
        echo "  Installed DSF : $(get_installed_dsf_version)"
        echo "  Channel       : $(get_current_channel)"
        echo "  Comms         : $(get_current_comms)"
        echo
        echo "Select release channel:"
        echo "  1) Stable (recommended)"
        echo "  2) Unstable (bleeding edge)"
        echo "  3) Switch SPI/USB communication"
        echo "  4) Restart Duet services"
        echo "  5) Exit"
        read -r -p "Choose an option: " choice
        case "${choice}" in
            1) interactive_install stable ;;
            2) interactive_install unstable ;;
            3) interactive_set_comms ;;
            4) restart_rrf_services ;;
            5|q|Q) exit 0 ;;
            *) warn "Invalid selection" ;;
        esac
    done
}

self-update "${ALL_ARGS[@]}"

if [ "${ACTION}" == "interactive" ]; then
    interactive_menu
elif [ "${ACTION}" == "set-comms" ]; then
    set_comms_method
else
    main
fi
