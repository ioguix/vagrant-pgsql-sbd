#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

declare -r PGVER="$1"
shift 1

declare -r MOUNTDIR="/var/lib/postgresql/$PGVER"
declare -r PGDATA="${MOUNTDIR}/main"
declare -r PGETC="${MOUNTDIR}/etc"
declare -r DEV="/dev/vg_san/lv_san"

# prepare mountpoint and paths
install -o postgres -g postgres -d "$MOUNTDIR"
mount "$DEV" "$MOUNTDIR"
chown postgres: "$MOUNTDIR"
install -o postgres -g postgres -d "${PGDATA}"
install -o postgres -g postgres -d "${PGETC}"
pg_createcluster "$PGVER" main
mv "/etc/postgresql/${PGVER}/main/"* "${PGETC}"
umount "$MOUNTDIR"
