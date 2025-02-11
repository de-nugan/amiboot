#!/bin/bash
# Run as root to install amiboot

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


case $(uname -m) in
    x86_64)
    arch=amd64
    ;;

    aarch64)
    arch=arm64
    ;;

    *)
    echo "This architecture is not supported."
    exit
    ;;
esac


install_package ()
{
    echo "Installing ${1}.."
    write_log install "Installing package ${1}"

    if [[ $release ]]; then

        apt-get --assume-yes -qq install $1

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
install_package wget  # Not included in Debian aarch64
install_package plymouth
install_package unzip
install_package curl
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

        unzip -q "${archive}" -d "${hdf_path}/"

    fi

done

# Check for EFI System Partition and install rEFInd if found
if [[ $release ]]; then

    if [[ -d "${efi_path}" ]]; then

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

    elif [[ $arch == "amd64" ]]; then

        # Otherwise create an initial default config
        write_log install "EFI path not found. Setting GRUB and launcher defaults.."
        cp "${install_files_path}/conf/AROS.uae" "${uae_config_path}/default.uae"

        # Set GRUB timeout and enable bootsplash
        sed -i -r 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=3/' /etc/default/grub
        sed -i -r 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="splash quiet"/' /etc/default/grub

        /sbin/update-grub

    fi

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
    amiberry_installer=$(ls -vr ./amiberry*${arch}.deb | head -1)

    if [[ ! -f $amiberry_installer ]]; then

        amiberry_zipfile=$(ls -vr ./amiberry*${arch}.zip | head -1)

        if [[ ! -f $amiberry_zipfile ]]; then

            wget_url=$(curl -s https://api.github.com/repos/BlitterStudio/Amiberry/releases/latest | grep browser_download_url.*debian-bookworm-${arch} | cut -d : -f 2,3 | tr -d " \"")
            echo "Fetching Amiberry installer from ${wget_url}"
            write_log install "Fetching Amiberry installer from ${wget_url}"

            wget "${wget_url}"

            amiberry_zipfile=$(ls -vr ./amiberry*${arch}.zip | head -1)

        fi

        if [[ -f $amiberry_zipfile ]]; then

            unzip -o ./amiberry*${arch}.zip

        else

            write_log install "Amiberry installer archive not found!"
            write_log install "URL = ${wget_url}"
            echo "Amiberry download failed."

        fi

        amiberry_installer=$(ls -vr ./amiberry*${arch}.deb | head -1)

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
    pushd "${application_path}"
    . "./boot-handler.sh"
    popd

    echo "Installation appears to have been successful. Please reboot and enjoy!"

else

    write_log install "Amiberry not found. Installation did not complete successfully."
    echo "Amiberry not found. Installation did not complete successfully. Damn!"

fi


