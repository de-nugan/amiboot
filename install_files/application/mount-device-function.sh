# mount-devce
# Usage: mount-device /dev/node

mount_device ()
{
    if [[ -z $1 || ! -e "${1}" ]]; then

        return

    fi

    if [[ $(grep "${1} " /proc/mounts) ]]; then

        # Device is already mounted, so check if mount path belongs to us
        mount_path=$(lsblk --noheadings -o MOUNTPOINT "${1}")

        if [[ $(echo $mount_path | grep " ${volumes_path}/") ]]; then

            echo $mount_path

        fi

        return

    fi

    label=$(lsblk --noheadings -o LABEL "${1}")

    # Replace troublesome characters now before they cause absolute fucking chaos
    label=${label// /_}

    # If no label or the default mountpoint is in use, append the dev name
    if [[ -z $label || $(grep -F " ${volumes_path}/${label} " /proc/mounts) ]]; then

        # NB use of square brackets causes problems from within emulation as Linux will surround the names with quotes ''
        label="${label}_${1##*/}"

        if [[ $(grep -F " ${volumes_path}/${label} " /proc/mounts) ]]; then

            # Something is mounted at our mountpoint! Should never happen.
            return

        fi

    fi

    mkdir -p "${volumes_path}/${label}" 2>>/dev/zero
    mount $1 "${volumes_path}/${label}" 2>>/dev/zero

    sleep 0.5

    if [[ $(grep "${1}" /proc/mounts) ]]; then

        # Mount successful.
        # Store the path in a var file in case we want to use the unmolested path
        # GGG copy in .info icon file here!
        mkdir -p "${var_path}/dev" 2>>/dev/zero
        echo "${volumes_path}/${label}" > "${var_path}/${1}"
        echo "${volumes_path}/${label}"

    else

        rmdir "${volumes_path}/${label}"

    fi

}

