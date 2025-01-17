# $1=/dev/node

my_name="${0##*/}"
my_path="${0%/${my_name}}"
. "${my_path}/config.sh"
. "${my_path}/mount-device-function.sh"

mount_device "${1}"




