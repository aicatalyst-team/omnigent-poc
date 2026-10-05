#!/usr/bin/env bash
# Resolve OpenShift-assigned IDs as the sandbox account in this shell.
if [ -n "${NSS_WRAPPER_PASSWD:-}" ] && [ ! -r "$NSS_WRAPPER_PASSWD" ]; then
    unset NSS_WRAPPER_PASSWD NSS_WRAPPER_GROUP
fi

if [ -z "${NSS_WRAPPER_PASSWD:-}" ]; then
    _omnigent_uid=$(id -u)
    if [ "$_omnigent_uid" -ne 0 ]; then
        _omnigent_gid=$(id -g)
        _omnigent_image_uid=$(getent passwd sandbox | cut -d: -f3)
        if [ -n "$_omnigent_image_uid" ] && [ "$_omnigent_uid" != "$_omnigent_image_uid" ]; then
            _omnigent_nss_dir=$(mktemp -d "${TMPDIR:-/tmp}/omnigent-nss.XXXXXXXX")
            if [ -n "$_omnigent_nss_dir" ]; then
                awk -F: -v uid="$_omnigent_uid" '$1 != "sandbox" && $3 != uid {print}' /etc/passwd > "$_omnigent_nss_dir/passwd"
                printf 'sandbox:x:%s:%s::/sandbox:/bin/bash\n' "$_omnigent_uid" "$_omnigent_gid" >> "$_omnigent_nss_dir/passwd"
                awk -F: -v gid="$_omnigent_gid" '$1 != "sandbox" && $3 != gid {print}' /etc/group > "$_omnigent_nss_dir/group"
                printf 'sandbox:x:%s:\n' "$_omnigent_gid" >> "$_omnigent_nss_dir/group"
                export NSS_WRAPPER_PASSWD="$_omnigent_nss_dir/passwd"
                export NSS_WRAPPER_GROUP="$_omnigent_nss_dir/group"
                export LD_PRELOAD="/usr/lib64/libnss_wrapper.so${LD_PRELOAD:+:$LD_PRELOAD}"
            fi
        fi
    fi
fi

if [ "$(id -u)" -ne 0 ]; then
    export USER=sandbox LOGNAME=sandbox
fi
unset _omnigent_uid _omnigent_gid _omnigent_image_uid _omnigent_nss_dir
