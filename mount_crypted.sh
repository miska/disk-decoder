#!/bin/sh
#
# Disk Decoder - Simple script to automatically unlock encrypted drives
# Copyright (C) 2020  Michal Hrusecky
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
# 

[ "$DST" ] || DST="$1"
[ "$DST" ] || DST="`cat /etc/ssh_crypt | sed -n 's|^:||p'`"

DRIVES="`blkid | grep 'TYPE="crypto_LUKS"'`"

# Format UUID:name:service1,service2,service3[:options[:subvol1,subvol2,subvol3]]
CFG="`cat /etc/ssh_crypt | grep -v '^[#:]'`"

get_ip() {
	echo "$1" | sed 's|^[^@]*@||' | sed 's|:[0-9]*$||'
}

get_target() {
	echo "$1" | sed 's|\(.*\):[0-9]*$|\1|'
}

get_port() {
	res="`echo "$1" | sed -n 's|.*:\([0-9]*\)$|\1|p'`"
	[ "$res" ] || res=22
	echo "$res"
}

get_name() {
	echo "$1" | cut -f 2 -d :
}

get_uuid() {
	echo "$1" | cut -f 1 -d :
}

get_dev() {
	[ -z "$1" ] || blkid -o device -U "$1"
}

get_options() {
	res="`echo "$1" | cut -f 4 -d :`"
	[ -z "$res" ] || res="$res,"
	echo "$res"
}

get_subvols() {
	res="`echo "$1" | cut -f 5 -d : | sed 's|,| |g'`"
	[ "$res" ] || res="@"
	echo "$res"
}

get_services() {
	echo "$1" | cut -f 3 -d : | sed 's|,| |g'
}

parse_config() {
	name="`get_name "$cr_conf"`"
	uuid="`get_uuid "$cr_conf"`"
	dev="`get_dev "$uuid"`"
	cr_dev="cr_${name}_`basename $dev`"
	options="`get_options "$cr_conf"`"
}

# Decode drives
echo "$CFG" | while read cr_conf; do
	parse_config
	if [ -n "$dev" ] && [ -b "$dev" ] && [ \! -b "/dev/mapper/$cr_dev" ]; then
		for dst in $DST; do
			port="`get_port "$dst"`"
			if nmap -p "$port" "`get_ip "$dst"`" 2>&1 | grep -q '/tcp.*open'; then
				key="`ssh -p "$port" "$(get_target "$dst")" | sed -n "s|^$uuid:||p"`"
				if [ -n "$key" ]; then
					echo -n "$key" | cryptsetup -q luksOpen --key-file - "$dev" "$cr_dev"
					[ $? -ne 0 ] || break
				fi
			fi
		done
	fi
done
# Scan for btrfs raids
btrfs device scan --all-devices > /dev/null
echo "$CFG" | while read cr_conf; do
	parse_config
	if [ -b "/dev/mapper/$cr_dev" ] && [ "`stat -c %m /mnt/$name`" = / ] && [ "$options" \!= "nomount," ]; then
		mkdir -p /mnt/$name
		for subvol in `get_subvols "$cr_conf"`; do
			mkdir -p "/mnt/$name/`echo "$subvol" | sed 's|^@||'`"
			mount -o "`get_options "$cr_conf"`subvol=$subvol" -t btrfs "/dev/mapper/$cr_dev" "/mnt/$name/`echo "$subvol" | sed 's|^@||'`"
		done
		for service in `get_services "$cr_conf"`; do
			[ \! -x "/etc/init.d/$service" ] || "/etc/init.d/$service" restart
			[ \! -x "/usr/bin/systemctl" ] || systemctl restart "$service"
		done
	fi
done
