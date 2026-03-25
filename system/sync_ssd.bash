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

TARGET_BOOT=$(get_mount_point "$TARGET_BOOT_UUID")
TARGET_EFI=$(get_mount_point "$TARGET_EFI_UUID")
TARGET_ROOT=$(get_mount_point "$TARGET_BTRFS_UUID")

mountpoint -q /boot || { echo "/boot is not mounted." >&2; exit 1; }
mountpoint -q /boot/efi || { echo "/boot/efi is not mounted." >&2; exit 1; }

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

read -rp "Start backup? (y/n): " confirm
if [[ "$confirm" != "y" ]]; then
    echo "Aborted."
    exit 0
fi

run_rsync() {
    rsync "$@" || { rc=$?; [[ $rc -eq 24 ]] && echo "Warning: some files vanished during transfer." >&2 || exit $rc; }
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
