#!/bin/bash
set -euo pipefail

[[ $EUID -ne 0 ]] && { echo "Must be run as root." >&2; exit 1; }

TARGET_BOOT_UUID="efe613c4-e1ec-4232-a133-43da78129420"
TARGET_EFI_UUID="2FA9-E66A"
TARGET_BTRFS_UUID="55c0cdd1-b639-4636-aef8-b3a085f973ea"

get_mount_point() {
    local uuid=$1
    local mount
    mount=$(findmnt -rn -o TARGET -S "UUID=$uuid") || {
        echo "Mount point for UUID=$uuid not found. Ensure the partition is mounted." >&2
        return 1
    }
    echo "$mount"
}

TARGET_BOOT=$(get_mount_point "$TARGET_BOOT_UUID") || exit 1
TARGET_EFI=$(get_mount_point "$TARGET_EFI_UUID") || exit 1
TARGET_ROOT=$(get_mount_point "$TARGET_BTRFS_UUID") || exit 1

mountpoint -q /boot || { echo "/boot is not mounted." >&2; exit 1; }
mountpoint -q /boot/efi || { echo "/boot/efi is not mounted." >&2; exit 1; }

# Guard against syncing to the currently booted partitions
SOURCE_ROOT_UUID=$(findmnt -rn -o UUID -T /)
SOURCE_BOOT_UUID=$(findmnt -rn -o UUID -T /boot)
SOURCE_EFI_UUID=$(findmnt -rn -o UUID -T /boot/efi)
for pair in "$TARGET_BTRFS_UUID:$SOURCE_ROOT_UUID:/" "$TARGET_BOOT_UUID:$SOURCE_BOOT_UUID:/boot" "$TARGET_EFI_UUID:$SOURCE_EFI_UUID:/boot/efi"; do
    IFS=: read -r target source label <<< "$pair"
    if [[ "$target" == "$source" ]]; then
        echo "Refusing to sync: target UUID $target matches currently mounted $label." >&2
        exit 1
    fi
done

# Ensure target btrfs is mounted with compression
target_opts=$(findmnt -rn -o OPTIONS -S "UUID=$TARGET_BTRFS_UUID")
if [[ "$target_opts" != *compress=zstd* ]]; then
    echo "Target is not mounted with compress=zstd. Remounting..." >&2
    mount -o remount,compress=zstd "$TARGET_ROOT"
fi

echo "Target boot: $TARGET_BOOT"
echo "Target EFI:  $TARGET_EFI"
echo "Target root: $TARGET_ROOT"
echo ""

USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
if mountpoint -q "$USER_HOME/Drive" 2>/dev/null; then
    fusermount -uz "$USER_HOME/Drive" && echo "Unmounted $USER_HOME/Drive"
fi

read -rp "Start backup? (y/n): " confirm
if [[ "$confirm" != "y" ]]; then
    echo "Aborted."
    exit 0
fi

run_rsync() {
    rsync "$@" || { rc=$?; if [[ $rc -eq 24 ]]; then echo "Warning: some files vanished during transfer." >&2; else exit $rc; fi; }
}

echo ""
echo "=== boot ==="
run_rsync -aAXx --info=progress2 --delete /boot/ "$TARGET_BOOT/"

echo ""
echo "=== efi ==="
run_rsync -a --info=progress2 --delete --no-perms --no-owner --no-group /boot/efi/ "$TARGET_EFI/"

echo ""
echo "=== root (/) ==="
run_rsync -aAXx --info=progress2 --delete --exclude='/.snapshots' --exclude='/home' / "$TARGET_ROOT/"

echo ""
echo "=== home (/home) ==="
mkdir -p "$TARGET_ROOT/home"
run_rsync -aAXx --info=progress2 --delete /home/ "$TARGET_ROOT/home/"

echo ""
echo "Backup complete. Target is up-to-date."

umount "$TARGET_EFI" 2>/dev/null && echo "Unmounted $TARGET_EFI" || echo "Warning: failed to unmount $TARGET_EFI" >&2
umount "$TARGET_BOOT" 2>/dev/null && echo "Unmounted $TARGET_BOOT" || echo "Warning: failed to unmount $TARGET_BOOT" >&2
umount "$TARGET_ROOT" 2>/dev/null && echo "Unmounted $TARGET_ROOT" || echo "Warning: failed to unmount $TARGET_ROOT" >&2
