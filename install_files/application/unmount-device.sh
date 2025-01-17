# $1=/dev/node_to_be_mounted

my_name="${0##*/}"
my_path="${0%/${my_name}}"
. "${my_path}/config.sh"

# Enable debugging
# set -x

max_attempts=5
attempts=0

# Options to get mount path
# /proc/mounts - accurate but spaces replaced with octal \040
# /etc/mtab - as above but a copy of the data?
# mount command - as above
# lsblk -o MOUNTPOINT - will not return any device info if the device has been removed (although it is still mounted)
# store in a file

mount_path=$(cat "${var_path}/${1}")

while [[ -d "${mount_path}" && $attempts -lt $max_attempts ]]; do

    sleep 1

    umount "${1}"

    sleep 1

    if [[ ! $(grep -F "${mount_path}" /proc/mounts) ]]; then

        rmdir "${mount_path}"

    fi

    ((attempts++))

done






