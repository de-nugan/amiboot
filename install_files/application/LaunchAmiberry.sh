#!/bin/bash
clear

my_name="${0##*/}"
my_path="${0%/${my_name}}"
. "${my_path}/config.sh"
. "${my_path}/mount-device-function.sh"

# NB This seems to be the only way to get Amiberry to observe a custom config dir
AMIBERRY_HOME_DIR="${base_path}"
AMIBERRY_CONFIG_DIR="${uae_config_path}"
export AMIBERRY_HOME_DIR
export AMIBERRY_CONFIG_DIR


preprocess_config_file()
{
    # Fix paths
    grep -v "amiberry.rom_path=" ${1} > "${1}.temp" && mv -f "${1}.temp" "${1}"
    grep -v "amiberry.floppy_path=" ${1} > "${1}.temp" && mv -f "${1}.temp" "${1}"
    grep -v "amiberry.hardfile_path=" ${1} > "${1}.temp" && mv -f "${1}.temp" "${1}"
    grep -v "amiberry.cd_path=" ${1} > "${1}.temp" && mv -f "${1}.temp" "${1}"

    echo "amiberry.rom_path=${rom_path}/" >> ${1}
    echo "amiberry.floppy_path=${adf_path}/" >> ${1}
    echo "amiberry.hardfile_path=${hdf_path}/" >> ${1}
    echo "amiberry.cd_path=${cdrom_path}/" >> ${1}

    # Look for markers in config description line
    ConfigLine=$(grep -i "config_description=" ${1})

    if [[ -n $ConfigLine ]]; then

        GW=$(echo $ConfigLine | grep -Eo 'GW=[AB][0-3]')
        HDD=$(echo $ConfigLine | grep -Eo 'HDD=''AUTO|DIR|NATIVE')

        # Backup the config file
        if [[ -n $GW || -n $HDD ]]; then

            cp -f "${1}" "${1}.bak"

        fi

        # echo "; Added by ${my_name}" >> ${1}

        if [[ -n $GW ]]; then

            GWCablePos=${GW:3:1}
            GWAmigaDriveNo=${GW:4:1}

            # Clear the floppybridge config lines
            grep -v "amiberry.drawbridge_" ${1} > "${1}.temp" && mv -f "${1}.temp" "${1}"
            egrep -v "floppy${GWAmigaDriveNo}type" ${1} > "${1}.temp" && mv -f "${1}.temp" "${1}"
            egrep -v "floppy${GWAmigaDriveNo}subtype" ${1} > "${1}.temp" && mv -f "${1}.temp" "${1}"

            # GGG Loop to check for other numbers
            # GGG Check / confirm device type
            if [[ -e "/dev/ttyACM0" ]]; then

                # echo "Greaseweazle detected at /dev/ttyACM0.."
                write_log "Adding Greaseweazle /dev/ttyACM0 cable position ${GWCablePos} as DF${GWAmigaDriveNo}"

                # GGG Assume this is a Greaseweazle
                echo "amiberry.drawbridge_driver=1" >> ${1}
                echo "amiberry.drawbridge_serial_autodetect=true" >> ${1}
                # echo "amiberry.drawbridge_serial_port=/dev/ttyACM0" >> ${1}
                echo "amiberry.drawbridge_serial_port=" >> ${1}
                echo "amiberry.drawbridge_smartspeed=false" >> ${1}
                echo "amiberry.drawbridge_autocache=false" >> ${1}

                if [[ ${GWCablePos} == 'B' ]]; then
                    echo "amiberry.drawbridge_connected_drive_b=true" >> ${1}
                else
                    echo "amiberry.drawbridge_connected_drive_b=false" >> ${1}
                fi

                echo "floppy${GWAmigaDriveNo}type=8" >> ${1}
                echo "floppy${GWAmigaDriveNo}subtype=1" >> ${1}
                echo "floppy${GWAmigaDriveNo}subtypeid=2:Compatible" >> ${1}

            elif [[ $GWAmigaDriveNo -gt 1 ]]; then

                # Virtual floppies 2 and 3 require type=0, so replace the line if we removed it
                echo "floppy${GWAmigaDriveNo}type=0" >> ${1}

            fi
        fi

        if [[ -z $HDD ]]; then

            # HDD option not pecified, so just mount any connected devices
            for dev in $(ls /dev/sd[a-z][1-9]); do

                mount_device "${dev}"

            done

        else

            HDD=${HDD#HDD=}

            if [[ $HDD == AUTO || $HDD == DIR ]]; then

                # Delete HDD folder lines from config
                grep -v "${volumes_path}/" ${1} > "${1}.temp" && mv -f "${1}.temp" "${1}"

                DD=0

                for dev in $(ls /dev/sd[a-z][1-9]); do

                    mount_path=$(mount_device $dev)

                    if [[ -d $mount_path ]]; then

                        # echo "Adding local path ${mount_path}.."
                        write_log "Adding ${mount_path} as device DD${DD}"

                        echo "filesystem2=rw,DD${DD}:${mount_path##*/}:${mount_path},0" >> ${1}
                        echo "uaehf1=dir,rw,DD${DD}:${mount_path##*/}:${mount_path},0" >> ${1}

                        ((DD++))

                    fi

                done

                # Allow /proc/mounts to catch up
                sleep 0.5

            fi

            if [[ $HDD == AUTO || $HDD == NATIVE ]]; then

                # Delete /dev lines from config
                grep -v "/dev/sd" ${1} > "${1}.temp" && mv -f "${1}.temp" "${1}"

                DX=0

                for dev in $(ls /dev/sd[a-z]); do

                    if [[ ! $(grep "${dev}" /proc/mounts) ]]; then

                        # echo "Adding local disk ${dev}.."
                        write_log "Adding ${dev} as device DX${DX}"

                        echo "hardfile2=rw,DX${DX}:${dev},0,0,0,512,0,,uae0" >> ${1}
                        echo "uaehf1=hdf,rw,DX${DX}:${dev},0,0,0,512,0,,uae0" >> ${1}

                        ((DX++))

                    fi
                done
            fi
        fi
    fi
}


launch_amiberry()
{
    if [[ -f "${uae_config_path}/${1}.uae" ]]; then

        config_file="${uae_config_path}/${1}.uae"

    elif [[ -f "${refind_previousboot_file}" ]]; then

        # Read contents of file, use sed to strip non-ASCII
        boot_line=$(sed 's/[^[:print:]]//g' ${refind_previousboot_file})

        # Trim line to selection name
        launch_string=${boot_line#*: }
        launch_string=${launch_string#*Boot }
        launch_string=${launch_string%% from *}

        if [[ -f "${uae_config_path}/${launch_string}.uae" ]]; then

            config_file="${uae_config_path}/${launch_string}.uae"

        fi

    fi

    # If $config_file is undefined or doesn't exist, fallback to default if available
    if [[ ! -f "${config_file}" ]]; then

        if [[ -f "${uae_config_path}/default.uae" ]]; then

            config_file="${uae_config_path}/default.uae"

        fi

    fi


    if [[ -f "${config_file}" ]]; then

        # echo "Using config file ${config_file}"
        write_log "Using config file ${config_file}"
        preprocess_config_file "${config_file}"
        amiberry -f "${config_file}" -s use_gui=no

    else

        amiberry

    fi

}

write_log "${application_name} ${application_version}"
# Start watches once
/bin/bash "${my_path}/usb-handler.sh" &
/bin/bash "${my_path}/boot-handler.sh" watch &
# Full auto silent import can overwrite files accidentally, better use AROS/DOpus!
#/bin/bash "${my_path}/import-handler.sh" &

# Remove non-mounted directories in Volumes path
for dir in "${volumes_path}/"*/; do

    if [[ -d "${dir}" ]]; then

        if [[ ! $(grep "${dir%/}" /proc/mounts) ]]; then

            rmdir "${dir%/}" 2>>/dev/zero

        fi

    fi

done

# Operation
# Depending on config options, block devices connected before starting emulation will be added to the config as native drives or hddirs
# Drives added during emulation will be mounted under USB/ which can be accessed as a hddir from within emulation
# If an unpartitioned or Amiga native drive is added during emulation it will fail to mount but can be added to the emulated system by restarting the emulator which will repeat the preprocessing stage
# If a hddir drive is added during emulation (and mounted under USB/) but the user wants it mounted as a seperate drive, this can be achieved by restarting the PC
# Alternatively, mounted USB drives could be unmounted when the emulator exits and re-attached by the preprocessor on restart but the user may not want this.
# In short, don't unmount anything when the emulator exits.

while [[ 1 ]]; do

    launch_amiberry "${1}"

    clear
    echo "ctrl-c to quit to terminal."
    echo -n "Restarting in "

    i=5

    while [[ $i -gt 0 ]]; do
        echo -en "${i}..\b\b\b"
        sleep 1
        ((i--))
    done

done


