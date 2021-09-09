#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# set -x # enable debug

declare -r DISKID="$1"
declare _SHARED_DEV
_SHARED_DEV=$(readlink -f "/dev/disk/by-id/virtio-${DISKID}")
declare -r SHARED_DEV="$_SHARED_DEV"

echo "$SHARED_DEV"
apt-get update
apt-get upgrade

apt-get install --no-install-recommends lvm2 parted

if vgs --foreign|grep -q vg_san ; then
	declare vgsysid

	{ [ -e /dev/mapper/vg_san-lv_san ] && umount -q /dev/vg_san/lv_san; } || true

	vgsysid=$(vgs --foreign --noheadings -o systemid vg_san)
	[ "${vgsysid// }" ] && vgchange -y --systemid='' \
		--config "local/extra_system_ids=[\"${vgsysid// }\"]" vg_san

	vgchange -an vg_san
	lvremove -y vg_san/lv_san
	vgremove -y vg_san
fi

parted -s "$SHARED_DEV" mklabel gpt mkpart "sbd" 1MB 3MB mkpart "lvm" 3MB 100%

pvcreate "${SHARED_DEV}2"
vgcreate vg_san "${SHARED_DEV}2"
lvcreate -l 100%FREE -an vg_san --name lv_san
vgchange -ay vg_san
mkfs.ext4 /dev/mapper/vg_san-lv_san

parted -s "$SHARED_DEV" print
