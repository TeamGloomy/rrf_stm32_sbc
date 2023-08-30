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

# Ensure the DTB package can't be updated as it would lead to a broken system
apt-mark hold linux-dtb-current-sunxi64

# Disable core dumps because DSF keep crashing in qemu static
display_alert "Disable core dumps"
ulimit -c 0

# Change Armbian config to add Spidev parameters and activate AppArmor
display_alert "Apply changes to armbianEnv.txt"
echo "param_spidev_spi_bus=0" >> /boot/armbianEnv.txt
echo "extraargs=spidev.bufsiz=8192 apparmor=1" >> /boot/armbianEnv.txt
echo "security=apparmor" >> /boot/armbianEnv.txt

# Disable password security check using cracklib in armbian-firstlogin script and let useradd handle that
display_alert "Disable password security check using cracklib"
sed -i -e 's/okay=\"$[(]awk -F'"'"': '"'"' '"'"'{ print $2}'"'"' <<<"$result")"/okay="OK"/g' /usr/lib/armbian/armbian-firstlogin

# Disable Armbian ram logging service
display_alert "Disable Armbian ram logging service"
sed -i -e 's/ENABLED=true/ENABLED=false/g' /etc/default/armbian-ramlog

# Change motd
display_alert "Change motd"
sed -i -e 's%TERM=linux toilet -f standard -F metal $(echo $BOARD_NAME | sed '"'"'s/Orange Pi/OPi/'"'"' | sed '"'"'s/NanoPi/NPi/'"'"' | sed '"'"'s/Banana Pi/BPi/'"'"')%LOGO="\x1b[40m          \x1b[38;2;255;255;255m##################\x1b[38;2;245;245;248m#\x1b[38;2;162;161;199m#\x1b[38;2;163;162;199m#\x1b[38;2;245;245;249m#\x1b[38;2;255;255;255m##################\x1b[0m\n\x1b[40m          \x1b[38;2;255;255;255m################\x1b[38;2;244;244;247m#\x1b[38;2;158;156;197m#\x1b[38;2;49;47;138m#\x1b[38;2;83;81;159m#\x1b[38;2;91;89;163m#\x1b[38;2;52;50;139m#\x1b[38;2;158;157;199m#\x1b[38;2;245;245;248m#\x1b[38;2;255;255;255m################\x1b[0m\n\x1b[40m          \x1b[38;2;255;255;255m##############\x1b[38;2;244;244;247m#\x1b[38;2;157;157;197m#\x1b[38;2;50;48;138m#\x1b[38;2;88;86;162m#\x1b[38;2;204;203;226m#\x1b[38;2;253;253;254m##\x1b[38;2;212;211;231m#\x1b[38;2;97;96;166m#\x1b[38;2;53;50;140m#\x1b[38;2;158;157;198m#\x1b[38;2;244;244;248m#\x1b[38;2;255;255;255m##############\x1b[0m\n\x1b[40m          \x1b[38;2;255;255;255m############\x1b[38;2;244;244;247m#\x1b[38;2;157;156;196m#\x1b[38;2;50;48;138m#\x1b[38;2;89;86;161m#\x1b[38;2;204;203;226m#\x1b[38;2;252;252;254m#\x1b[38;2;254;254;255m####\x1b[38;2;252;253;254m#\x1b[38;2;211;211;230m#\x1b[38;2;98;96;167m#\x1b[38;2;53;51;140m#\x1b[38;2;158;157;198m#\x1b[38;2;244;244;247m#\x1b[38;2;255;255;255m############\x1b[0m\n\x1b[40m          \x1b[38;2;255;255;255m##########\x1b[38;2;244;244;248m#\x1b[38;2;157;156;197m#\x1b[38;2;51;48;138m#\x1b[38;2;88;86;162m#\x1b[38;2;204;203;226m#\x1b[38;2;252;252;253m#\x1b[38;2;254;254;255m########\x1b[38;2;252;252;254m#\x1b[38;2;211;211;230m#\x1b[38;2;99;97;167m#\x1b[38;2;54;51;141m#\x1b[38;2;157;156;198m#\x1b[38;2;244;243;247m#\x1b[38;2;255;255;255m##########\x1b[0m\n\x1b[40m          \x1b[38;2;255;255;255m########\x1b[38;2;244;244;248m#\x1b[38;2;156;156;197m#\x1b[38;2;55;52;140m#\x1b[38;2;97;95;166m#\x1b[38;2;206;205;228m#\x1b[38;2;252;252;254m#\x1b[38;2;254;254;255m#\x1b[38;2;246;246;247m#\x1b[38;2;196;196;197m#\x1b[38;2;143;143;144m#\x1b[38;2;110;110;111m#\x1b[38;2;95;95;95m#\x1b[38;2;96;96;96m#\x1b[38;2;113;113;114m#\x1b[38;2;149;149;149m#\x1b[38;2;203;203;204m#\x1b[38;2;249;249;250m#\x1b[38;2;254;254;255m#\x1b[38;2;252;252;254m#\x1b[38;2;214;213;231m#\x1b[38;2;106;104;171m#\x1b[38;2;56;54;141m#\x1b[38;2;157;156;198m#\x1b[38;2;245;245;248m#\x1b[38;2;255;255;255m########\x1b[0m\n\x1b[40m          \x1b[38;2;255;255;255m######\x1b[38;2;253;253;253m#\x1b[38;2;176;176;207m#\x1b[38;2;51;48;139m#\x1b[38;2;86;84;160m#\x1b[38;2;208;208;229m#\x1b[38;2;252;252;254m#\x1b[38;2;254;254;255m#\x1b[38;2;254;254;254m#\x1b[38;2;195;195;195m#\x1b[38;2;85;85;85m#\x1b[38;2;53;53;53m#\x1b[38;2;77;77;77m#\x1b[38;2;121;121;121m#\x1b[38;2;143;143;143m#\x1b[38;2;138;138;138m#\x1b[38;2;106;106;106m#\x1b[38;2;62;62;62m#\x1b[38;2;53;53;53m#\x1b[38;2;95;95;95m#\x1b[38;2;210;210;210m#\x1b[38;2;254;254;255m##\x1b[38;2;252;252;254m#\x1b[38;2;213;212;231m#\x1b[38;2;96;94;166m#\x1b[38;2;53;51;140m#\x1b[38;2;176;176;208m#\x1b[38;2;253;253;253m#\x1b[38;2;255;255;255m######\x1b[0m\n\x1b[40m          \x1b[38;2;255;255;255m#####\x1b[38;2;246;246;248m#\x1b[38;2;111;110;171m#\x1b[38;2;36;33;132m#\x1b[38;2;176;174;210m#\x1b[38;2;251;251;253m#\x1b[38;2;249;249;250m#\x1b[38;2;224;224;225m#\x1b[38;2;205;205;206m#\x1b[38;2;177;177;178m#\x1b[38;2;66;66;66m#\x1b[38;2;57;57;57m#\x1b[38;2;161;161;161m#\x1b[38;2;245;245;246m#\x1b[38;2;254;254;255m###\x1b[38;2;253;253;254m#\x1b[38;2;226;226;226m#\x1b[38;2;106;106;107m#\x1b[38;2;51;51;51m#\x1b[38;2;76;76;76m#\x1b[38;2;188;188;188m#\x1b[38;2;205;205;206m#\x1b[38;2;226;226;227m#\x1b[38;2;249;249;250m#\x1b[38;2;252;252;253m#\x1b[38;2;186;186;216m#\x1b[38;2;45;42;137m#\x1b[38;2;111;110;171m#\x1b[38;2;246;246;248m#\x1b[38;2;255;255;255m#####\x1b[0m\n\x1b[40m          \x1b[38;2;255;255;255m####\x1b[38;2;251;251;252m#\x1b[38;2;102;100;165m#\x1b[38;2;36;33;132m#\x1b[38;2;208;207;228m#\x1b[38;2;247;247;249m#\x1b[38;2;162;162;163m#\x1b[38;2;80;80;80m#\x1b[38;2;56;56;56m#\x1b[38;2;66;66;66m#\x1b[38;2;67;67;67m#\x1b[38;2;54;54;54m#\x1b[38;2;59;59;60m#\x1b[38;2;154;154;154m#\x1b[38;2;247;247;248m#\x1b[38;2;254;254;255m#####\x1b[38;2;195;195;196m#\x1b[38;2;52;52;52m##\x1b[38;2;66;66;66m##\x1b[38;2;57;57;57m#\x1b[38;2;83;83;83m#\x1b[38;2;169;169;169m#\x1b[38;2;249;249;250m#\x1b[38;2;219;219;235m#\x1b[38;2;47;44;139m#\x1b[38;2;102;101;166m#\x1b[38;2;252;252;252m#\x1b[38;2;255;255;255m####\x1b[0m\n\x1b[40m          \x1b[38;2;255;255;255m####\x1b[38;2;170;170;203m#\x1b[38;2;13;9;119m#\x1b[38;2;177;176;211m#\x1b[38;2;253;253;254m#\x1b[38;2;151;151;152m#\x1b[38;2;53;53;53m#\x1b[38;2;76;76;76m#\x1b[38;2;200;200;201m#\x1b[38;2;243;243;244m#\x1b[38;2;244;244;245m#\x1b[38;2;212;212;213m#\x1b[38;2;183;183;183m#\x1b[38;2;230;230;231m#\x1b[38;2;253;253;254m#\x1b[38;2;254;254;255m####\x1b[38;2;251;251;252m#\x1b[38;2;172;172;173m#\x1b[38;2;113;113;113m#\x1b[38;2;131;131;131m#\x1b[38;2;233;233;234m#\x1b[38;2;242;242;243m#\x1b[38;2;194;194;195m#\x1b[38;2;72;72;72m#\x1b[38;2;54;54;54m#\x1b[38;2;162;162;162m#\x1b[38;2;254;254;255m#\x1b[38;2;196;195;221m#\x1b[38;2;17;14;122m#\x1b[38;2;171;170;203m#\x1b[38;2;255;255;255m####\x1b[0m\n\x1b[40m          \x1b[38;2;255;255;255m###\x1b[38;2;254;254;253m#\x1b[38;2;72;70;149m#\x1b[38;2;53;51;142m#\x1b[38;2;243;243;249m#\x1b[38;2;254;254;255m#\x1b[38;2;133;133;134m#\x1b[38;2;51;51;51m#\x1b[38;2;91;91;91m#\x1b[38;2;231;231;232m#\x1b[38;2;254;254;255m########\x1b[38;2;242;242;248m#\x1b[38;2;194;194;222m#\x1b[38;2;228;228;240m#\x1b[38;2;254;254;255m####\x1b[38;2;253;253;254m#\x1b[38;2;227;227;227m#\x1b[38;2;83;83;83m#\x1b[38;2;52;52;52m#\x1b[38;2;143;143;143m#\x1b[38;2;254;254;255m#\x1b[38;2;247;246;250m#\x1b[38;2;72;69;152m#\x1b[38;2;72;70;149m#\x1b[38;2;255;255;254m#\x1b[38;2;255;255;255m###\x1b[0m\n\x1b[40m          \x1b[38;2;255;255;255m###\x1b[38;2;251;252;252m#\x1b[38;2;36;33;130m#\x1b[38;2;89;86;162m#\x1b[38;2;250;250;253m#\x1b[38;2;254;254;255m#\x1b[38;2;234;234;235m#\x1b[38;2;119;119;119m#\x1b[38;2;58;58;58m#\x1b[38;2;67;67;67m#\x1b[38;2;103;103;103m#\x1b[38;2;113;113;113m##\x1b[38;2;126;126;126m#\x1b[38;2;234;234;235m#\x1b[38;2;247;247;251m#\x1b[38;2;180;179;213m#\x1b[38;2;96;94;167m#\x1b[38;2;31;28;130m#\x1b[38;2;30;28;131m#\x1b[38;2;214;214;233m#\x1b[38;2;216;216;217m#\x1b[38;2;114;114;114m#\x1b[38;2;113;113;113m##\x1b[38;2;102;102;102m#\x1b[38;2;65;65;65m#\x1b[38;2;59;59;59m#\x1b[38;2;125;125;125m#\x1b[38;2;239;239;240m#\x1b[38;2;254;254;255m#\x1b[38;2;252;252;254m#\x1b[38;2;108;106;173m#\x1b[38;2;36;33;129m#\x1b[38;2;253;253;254m#\x1b[38;2;255;255;255m###\x1b[0m\n\x1b[40m          \x1b[38;2;255;255;255m###\x1b[38;2;254;254;253m#\x1b[38;2;58;55;142m#\x1b[38;2;63;60;148m#\x1b[38;2;245;245;250m#\x1b[38;2;254;254;255m##\x1b[38;2;253;253;254m#\x1b[38;2;225;225;226m#\x1b[38;2;181;181;182m#\x1b[38;2;158;158;158m#\x1b[38;2;154;154;154m#\x1b[38;2;153;153;154m#\x1b[38;2;163;163;163m#\x1b[38;2;240;240;241m#\x1b[38;2;160;160;203m#\x1b[38;2;9;5;118m#\x1b[38;2;4;0;115m##\x1b[38;2;64;62;150m#\x1b[38;2;245;246;250m#\x1b[38;2;228;228;228m#\x1b[38;2;154;154;155m#\x1b[38;2;153;153;154m#\x1b[38;2;154;154;154m#\x1b[38;2;158;158;159m#\x1b[38;2;183;183;184m#\x1b[38;2;227;227;228m#\x1b[38;2;253;253;254m#\x1b[38;2;254;254;255m##\x1b[38;2;248;248;251m#\x1b[38;2;81;79;157m#\x1b[38;2;58;55;142m#\x1b[38;2;255;255;254m#\x1b[38;2;255;255;255m###\x1b[0m\n\x1b[40m          \x1b[38;2;255;255;255m####\x1b[38;2;143;142;189m#\x1b[38;2;13;9;119m#\x1b[38;2;195;194;221m#\x1b[38;2;254;254;255m#####\x1b[38;2;253;253;254m#\x1b[38;2;237;237;246m#\x1b[38;2;179;179;214m#\x1b[38;2;151;151;198m#\x1b[38;2;247;247;251m#\x1b[38;2;238;238;247m#\x1b[38;2;148;148;196m#\x1b[38;2;101;100;170m#\x1b[38;2;124;124;183m#\x1b[38;2;213;214;233m#\x1b[38;2;254;254;255m###########\x1b[38;2;212;212;231m#\x1b[38;2;20;17;123m#\x1b[38;2;143;142;188m#\x1b[38;2;255;255;254m#\x1b[38;2;255;255;255m###\x1b[0m\n\x1b[40m          \x1b[38;2;255;255;255m####\x1b[38;2;242;242;246m#\x1b[38;2;63;62;145m#\x1b[38;2;50;47;140m#\x1b[38;2;226;225;238m#\x1b[38;2;254;254;255m###\x1b[38;2;194;194;221m#\x1b[38;2;88;87;162m#\x1b[38;2;23;20;126m#\x1b[38;2;5;1;115m#\x1b[38;2;106;106;174m#\x1b[38;2;253;253;255m#\x1b[38;2;254;254;255m###############\x1b[38;2;234;233;243m#\x1b[38;2;64;61;148m#\x1b[38;2;64;62;145m#\x1b[38;2;243;243;247m#\x1b[38;2;255;255;255m####\x1b[0m\n\x1b[40m          \x1b[38;2;255;255;255m#####\x1b[38;2;229;229;238m#\x1b[38;2;63;62;145m#\x1b[38;2;50;47;140m#\x1b[38;2;204;204;226m#\x1b[38;2;253;253;254m#\x1b[38;2;252;252;254m#\x1b[38;2;73;71;154m#\x1b[38;2;5;1;116m#\x1b[38;2;4;0;115m#\x1b[38;2;12;9;120m#\x1b[38;2;175;175;212m#\x1b[38;2;254;254;255m##############\x1b[38;2;253;253;254m#\x1b[38;2;215;214;232m#\x1b[38;2;61;59;146m#\x1b[38;2;64;62;145m#\x1b[38;2;229;229;238m#\x1b[38;2;255;255;255m#####\x1b[0m\n\x1b[40m          \x1b[38;2;255;255;255m######\x1b[38;2;243;242;247m#\x1b[38;2;123;121;178m#\x1b[38;2;28;25;128m#\x1b[38;2;118;116;178m#\x1b[38;2;227;227;240m#\x1b[38;2;238;238;246m#\x1b[38;2;179;179;214m#\x1b[38;2;163;163;205m#\x1b[38;2;208;209;230m#\x1b[38;2;252;252;254m#\x1b[38;2;254;254;255m############\x1b[38;2;253;253;254m#\x1b[38;2;233;233;243m#\x1b[38;2;130;128;185m#\x1b[38;2;33;30;129m#\x1b[38;2;123;121;177m#\x1b[38;2;243;243;247m#\x1b[38;2;255;255;255m######\x1b[0m\n\x1b[40m          \x1b[38;2;255;255;255m########\x1b[38;2;217;216;231m#\x1b[38;2;108;106;170m#\x1b[38;2;35;32;130m#\x1b[38;2;93;91;164m#\x1b[38;2;177;175;211m#\x1b[38;2;237;237;245m#\x1b[38;2;252;253;254m#\x1b[38;2;254;254;255m##########\x1b[38;2;253;253;254m#\x1b[38;2;240;240;247m#\x1b[38;2;183;183;215m#\x1b[38;2;101;99;168m#\x1b[38;2;39;37;134m#\x1b[38;2;108;106;169m#\x1b[38;2;216;217;231m#\x1b[38;2;255;255;255m########\x1b[0m\n\x1b[40m          \x1b[38;2;255;255;255m##########\x1b[38;2;239;239;244m#\x1b[38;2;170;170;204m#\x1b[38;2;97;95;164m#\x1b[38;2;47;44;137m#\x1b[38;2;61;59;146m#\x1b[38;2;102;100;169m#\x1b[38;2;139;138;190m#\x1b[38;2;167;165;205m#\x1b[38;2;184;184;216m#\x1b[38;2;193;192;220m#\x1b[38;2;193;192;221m#\x1b[38;2;186;185;217m#\x1b[38;2;168;167;206m#\x1b[38;2;142;140;192m#\x1b[38;2;106;104;172m#\x1b[38;2;66;63;148m#\x1b[38;2;50;47;137m#\x1b[38;2;97;95;164m#\x1b[38;2;170;170;204m#\x1b[38;2;239;239;244m#\x1b[38;2;255;255;255m##########\x1b[0m\n\x1b[40m          \x1b[38;2;255;255;255m############\x1b[38;2;255;255;254m#\x1b[38;2;253;254;253m#\x1b[38;2;231;231;240m#\x1b[38;2;193;192;217m#\x1b[38;2;161;160;200m#\x1b[38;2;137;135;187m#\x1b[38;2;121;119;178m#\x1b[38;2;113;111;173m#\x1b[38;2;113;112;174m#\x1b[38;2;121;119;178m#\x1b[38;2;137;136;187m#\x1b[38;2;161;160;200m#\x1b[38;2;193;192;218m#\x1b[38;2;231;231;240m#\x1b[38;2;253;254;254m#\x1b[38;2;255;255;254m#\x1b[38;2;255;255;255m############\x1b[0m\n\x1b[40m          \x1b[0m"\necho -e "${LOGO}"%g' /etc/update-motd.d/10-armbian-header
sed -i -e 's%echo -e "\\e\[0;91mNo end-user support: \\x1B\[0m$UNSUPPORTED_TEXT\\n"%echo -e "For support, please join the TeamGloomy Discord: https://discord.gg/uS97Qs7\n"%g' /etc/update-motd.d/10-armbian-header

# Install packages to enable mDNS to resolve <hostname>.local
display_alert "Update packages list"
apt-get update

# Install packages to enable mDNS to resolve <hostname>.local
display_alert "Install required packages to enable mDNS"
apt-get -y -qq install avahi-daemon libnss-mdns libnss-mymachines

apt-get -y -qq install gpiod

# Install Duet sources to APT
display_alert "Install Duet sources to APT"
wget -q https://pkg.duet3d.com/duet3d.gpg -O /etc/apt/trusted.gpg.d/duet3d.gpg
wget -q https://pkg.duet3d.com/duet3d.list -O /etc/apt/sources.list.d/duet3d.list
apt-get -y -qq install apt-transport-https
apt-get update

# Install Duet packages
display_alert "Install Duet packages"
apt-get -y -qq install \
    apparmor \
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

chown -R "dsf:dsf" /opt/dsf

# Install 3rd-party DWC plugins
display_alert "Install 3rd-party plugins"
# Install pip and python modules needed for installation scripts
apt-get -y -qq install python3-pip
pip3 install requests dsf-python
# Install BtnCmd plugin
python3 /tmp/overlay/BtnCmd_plugin_install.py

# Install BtnCmd SBCC plugin
display_alert "Install BtnCmd SBCC plugin"
wget https://raw.githubusercontent.com/MintyTrebor/BtnCmd/main/SBCC/SBCC_Main.py -O /opt/dsf/plugins/BtnCmd/dwc/SBCC_Main.py
chown "dsf:dsf" /opt/dsf/plugins/BtnCmd/dwc/SBCC_Main.py

cp /tmp/overlay/SBCC_Config.json /opt/dsf/sd/sys/
chown "dsf:dsf" /opt/dsf/sd/sys/SBCC_Config.json

cp /tmp/overlay/BtnCmdAutoRestore.json /opt/dsf/sd/sys/
chown "dsf:dsf" /opt/dsf/sd/sys/BtnCmdAutoRestore.json

cp /tmp/overlay/SBCC_Default_Cmds.json /opt/dsf/sd/sys/
chown "dsf:dsf" /opt/dsf/sd/sys/SBCC_Default_Cmds.json

wget https://raw.githubusercontent.com/MintyTrebor/BtnCmd/main/SBCC/SBCCSvs.service -O /etc/systemd/system/SBCCSvs.service
systemctl enable SBCCSvs.service

echo '{"machine":{"enabledPlugins":["BtnCmd"]}}' > /opt/dsf/sd/sys/dwc-settings.json
chown "dsf:dsf" /opt/dsf/sd/sys/dwc-settings.json

# Install rrf_upgrade script
display_alert "Install RRF upgrade script"
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
# NB: use simple-quote as $1 doesn't get expanded here
echo 'usermod -aG dsf $1' >> /usr/local/sbin/adduser.local
echo 'usermod -aG tty $1' >> /usr/local/sbin/adduser.local
chmod u+x /usr/local/sbin/adduser.local
