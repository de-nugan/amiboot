#!/bin/bash
# Run as root to install amiboot

# set -x

my_name=${0##*/}
my_path=${0%/${my_name}}
install_files_path="${my_path}/install_files"

if [[ ! -d "${install_files_path}" ]]; then

    echo "${install_files_path} not found. Installation cannot continue."
    exit

fi

if [[ -f "${install_files_path}/application/config.sh" ]]; then

    . "${install_files_path}/application/config.sh"

else

    echo "${install_files_path}/application/config.sh not found. Installation cannot continue."
    exit

fi


install_package ()
{
    if [[ $release ]]; then

        echo "Installing ${1}.."
        write_log install "Installing package ${1}"
        apt-get --assume-yes -qq --show-progress install $1

    fi
}

echo "WARNING!"
echo "${application_name} should ONLY be installed on a clean, minimal Debian Linux system."
echo "Do not install ${application_name} onto a system that contains important data or is used for any other purpose."
echo "${application_name} is free software and is offered without any warranty of any kind."
echo
echo "This installer and ${application_name} both must run as root."
echo -n "Do you wish to proceed? (Y/N) : "

read answer

if [[ $answer != "y" && $answer != "Y" ]]; then

    exit

fi

pushd "${my_path}"

# Add contrib repo
if [[ ! $(grep -E "^deb .* contrib" /etc/apt/sources.list) ]]; then

    write_log install "Adding contrib to /etc/apt/sources.list"
    sed -r -i 's/^deb(.*)$/deb\1 contrib/g' /etc/apt/sources.list
    apt-get update

fi

# Install prereqs
install_package plymouth
install_package unzip
install_package inotify-tools
install_package libegl1  # required?
# GGG need to get correct version from apt!
install_package libgegl-common
# install_package libgegl-0.4-0
install_package $(apt-cache pkgnames libgegl-0)

# Create application folders and install files
mkdir -p "${base_path}/Volumes"
mkdir -p "${application_path}/var"
mkdir -p "${uae_config_path}"
mkdir -p "${adf_path}"
mkdir -p "${hdf_path}"
mkdir -p "${rom_path}"

cp -R "${install_files_path}/application/"* "${application_path}/"
cp -R "${install_files_path}/conf/"* "${uae_config_path}/"
cp -R "${install_files_path}/floppies/"* "${adf_path}/"
cp -R "${install_files_path}/harddrives/"*.hdf "${hdf_path}/"

for archive in "${install_files_path}/harddrives/"*.zip; do

    extract_dir=${archive##*/}
    extract_dir=${extract_dir%.zip}

    if [[ ! -d "${hdf_path}/${extract_dir}" ]]; then

        unzip "${archive}" -d "${hdf_path}/"

    fi

done

# Check for EFI System Partition and install rEFInd if found
if [[ $release && -d "${efi_path}" ]]; then

    write_log install "EFI path found. Installing rEFInd.."
    install_package refind

    refind_config_file="/boot/efi/EFI/refind/refind.conf"

    if [[ ! $(grep "include ${application_name}" "${refind_config_file}") ]]; then

        echo "" >> "${refind_config_file}"
        echo "# Added by ${application_name}" >> "${refind_config_file}"
        echo "include ${application_name}\\${application_name}.conf" >> "${refind_config_file}"
        echo "include ${application_name}\\boot.conf"  >> "${refind_config_file}"

    fi

    cp -R "${install_files_path}/boot" /

else

    # Otherwise create an initial default config
    write_log install "EFI path not found."
    cp "${install_files_path}/conf/AROS.uae" "${uae_config_path}/default.uae"

fi


if [[ $release ]]; then

    cp -R "${install_files_path}/etc" /
    cp -R "${install_files_path}/usr" /

    if [[ $(which plymouth-set-default-theme) ]]; then

        write_log install "Setting Plymouth default theme.."
        plymouth-set-default-theme -R amiboot

    fi

fi

# Now the main event - install Amiberry if required
if [[ ! $(which amiberry) ]]; then

    pushd "${install_files_path}"
    amiberry_installer=$(ls -vr ./amiberry*amd64.deb | head -1)

    if [[ ! -f $amiberry_installer ]]; then

        amiberry_zipfile=$(ls -vr ./amiberry*amd64.zip | head -1)

        if [[ ! -f $amiberry_zipfile ]]; then

            # GGG Would be much nicer to find the latest release here
            echo "Downloading Amiberry installer.."

            wget_url="https://github.com/BlitterStudio/amiberry/releases/download/${amiberry_current_version}/amiberry-${amiberry_current_version}-debian-bookworm-amd64.zip"

            write_log install "Downloading Amiberry from ${wget_url}"

            wget "${wget_url}"

            amiberry_zipfile=$(ls -vr ./amiberry*amd64.zip | head -1)

        fi

        if [[ -f $amiberry_zipfile ]]; then

            unzip -o ./amiberry*amd64.zip

        else

            write_log install "Amiberry zip file not found! (${amiberry_zipfile})"
            write_log install "Amiberry version = ${amiberry_current_version}"
            write_log install "wget URL = ${wget_url}"
            echo "Amiberry installer zip file was not found and could not be downloaded."

        fi

        amiberry_installer=$(ls -vr ./amiberry*amd64.deb | head -1)

    fi

    if [[ -f $amiberry_installer ]]; then

        install_package $amiberry_installer

    else

        write_log install "Amiberry installer not found! Please download and install manually."
        echo "Amiberry installer not found! Please download and install manually."

    fi

    pushd -1
fi


if [[ $(which amiberry) ]]; then

    cp -r /usr/share/amiberry/roms/* "${rom_path}/"
    chmod -R 777 "${base_path}"

    if [[ $release && ! $(grep "${application_path}/LaunchAmiberry.sh" /root/.profile) ]]; then

        # Warning. Running from profile as new process (&) may be nice but will break the ctrl+c to exit
        write_log install "Adding launcher to root/.profile"
        echo "" >> /root/.profile
        echo "# Added by amiboot" >> /root/.profile
        echo "clear" >> /root/.profile
        echo "${application_path}/LaunchAmiberry.sh" >> /root/.profile

    fi

    write_log install "Executing ${application_path}/boot-handler.sh"
    . "${application_path}/boot-handler.sh"
    echo "Installation appears to have been successful. Please reboot and enjoy!"

else

    write_log install "Amiberry not found. Installation did not complete successfully."
    echo "Amiberry not found. Installation did not complete successfully. Damn!"

fi


