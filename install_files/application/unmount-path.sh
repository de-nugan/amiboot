# $1=/path/to/mountpoint

max_attempts=5
attempts=0

while [[ -d "${1}" && $attempts -lt $max_attempts ]]; do

    sleep 1

    umount "${1}"

    sleep 1

    if [[ ! $(grep -F "${1}" /proc/mounts) ]]; then

        rmdir "${1}"

    fi

    ((attempts++))

done






