#!/bin/bash

# Config vars and common functions for amiboot scripts
# Paths should not end with a slash

release=1

# Installation vars
application_name="amiboot"
base_path="/Amiga"
application_version="0.2.1"
uae_config_path="${base_path}/conf"
application_path="${base_path}/${application_name}"
volumes_path="${base_path}/Volumes"
var_path="${application_path}/var"
log_path="${application_path}/var/log"
adf_path="${base_path}/floppies"
hdf_path="${base_path}/harddrives"
rom_path="${base_path}/roms"
cdrom_path="${base_path}/cdroms"


# Local OS stuff
kernel_prefix="vmlinuz"
initrd_prefix="initrd.img"
efi_path="/boot/efi/EFI"
refind_previousboot_file="${efi_path}/refind/vars/PreviousBoot"


# Common functions #

write_log ()
{
    if [[ ! -d "${log_path}" ]]; then

        mkdir -p "${log_path}" 2>/dev/zero

    fi

    if [[ $# -gt 1 ]]; then

        echo "$(date +%y%m%d%H%M%S) ${my_name} : ${2}" >> "${log_path}/${1}.log"

    else

        echo "$(date +%y%m%d%H%M%S) ${my_name} : ${1}" >> "${log_path}/${application_name}.log"

    fi

    if [[ $debug ]]; then

        echo $*

    fi
}










