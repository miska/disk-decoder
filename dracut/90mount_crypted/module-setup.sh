#!/bin/bash
# dracut module-setup for mount_crypted

# Include when requested on the kernel command line, when a host config
# exists, or when explicitly added with "dracut --add mount_crypted".
check() {
    require_binaries ssh cryptsetup btrfs || return 1

    local arg
    for arg in $(cat /proc/cmdline 2> /dev/null); do
        case "$arg" in
            rd.mount_crypted|rd.mount_crypted=1|rd.mount_crypted=yes|rd.mount_crypted=on) return 0 ;;
        esac
    done

    [ -f "$dracutsysrootdir/etc/ssh_crypt" ] && return 0

    return 255
}

depends() {
    echo "systemd crypt btrfs network"
    return 0
}

install() {
    # nmap is optional at build time; the script handles its absence at boot.
    inst_multiple -o ssh cryptsetup btrfs blkid nmap
    inst_multiple -o /etc/ssh/ssh_config

    if [ -f "$dracutsysrootdir/etc/ssh_crypt" ]; then
        inst_simple "$dracutsysrootdir/etc/ssh_crypt" /etc/ssh_crypt
    fi

    inst_simple "$moddir/mount_crypted.service" "$systemdsystemunitdir/mount_crypted.service"

    # Install the script next to the path baked into the generated unit.
    local exe
    exe="$(sed -n 's|^ExecStart=\([^ ]*\)/mount_crypted$|\1|p' "$moddir/mount_crypted.service")"
    [ -n "$exe" ] || exe="/usr/local/sbin"
    inst_simple "$moddir/mount_crypted" "$exe/mount_crypted"

    $SYSTEMCTL -q --root "$initdir" add-wants local-fs-pre.target mount_crypted.service
}
