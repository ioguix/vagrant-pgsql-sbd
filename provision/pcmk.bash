#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

declare -r PGVER="$1"
declare -r VIP="$2"
shift 2
declare -a NODES=( "$@" )

declare -r PGBIN="/usr/lib/postgresql/${PGVER}/bin"
declare -r MOUNTDIR="/var/lib/postgresql/$PGVER"
declare -r PGDATA="${MOUNTDIR}/main"
declare -r PGETC="${MOUNTDIR}/etc"
declare -r DEV="/dev/vg_san/lv_san"

# create cluster and setup SBD
pcs host auth -u hacluster -p "hapass" "${NODES[@]}"

pcs cluster setup cluster_pgsql --force "${NODES[@]}"

pcs stonith sbd device setup device=/dev/disk/by-partlabel/sbd --force
pcs stonith sbd enable device=/dev/disk/by-partlabel/sbd
pcs cluster start --all --wait

pcs cluster cib conf.xml

pcs -f conf.xml resource defaults migration-threshold=5
pcs -f conf.xml resource defaults resource-stickiness=10
pcs -f conf.xml property set stonith-watchdog-timeout=10s

# setup fencing
pcs -f conf.xml stonith create poisoner fence_sbd \
	devices=/dev/disk/by-partlabel/sbd power_timeout=15

# setup resources

pcs -f conf.xml resource create lv_pg ocf:heartbeat:LVM-activate \
	vgname=vg_san lvname=lv_san vg_access_mode=system_id         \
	--group pgsqlgroup

pcs -f conf.xml resource create fs_pg ocf:heartbeat:Filesystem \
	device="$DEV" "directory=$MOUNTDIR" fstype=ext4            \
	--group pgsqlgroup

pcs -f conf.xml resource create etc_pg ocf:heartbeat:Filesystem \
	fstype=none options=bind "device=$PGETC"                    \
	"directory=/etc/postgresql/${PGVER}/main"                   \
	 --group pgsqlgroup

pcs -f conf.xml resource create pgsqld ocf:heartbeat:pgsql     \
	pgctl="${PGBIN}/pg_ctl" config="${PGETC}/postgresql.conf"  \
	pgdata="${PGDATA}" socketdir="/var/run/postgresql"         \
	logfile="/var/log/postgresql/postgresql-${PGVER}-main.log" \
	rep_mode=none                                              \
	op start timeout=180s                                      \
	op stop timeout=180s                                       \
	op monitor interval=5s timeout=30s                         \
	--group pgsqlgroup

pcs -f conf.xml resource create pgsql-ip ocf:heartbeat:IPaddr2 \
	"ip=$VIP" cidr_netmask=24 op monitor interval=10s          \
	 --group pgsqlgroup

# Add a dummy service avoiding pgsql if possible
pcs -f conf.xml resource create dummy ocf:heartbeat:Dummy
pcs -f conf.xml constraint colocation add dummy with pgsqlgroup -- -15 # must be greater than the stickiness
pcs cluster cib-push conf.xml --config --wait

crm_mon -1Dn
