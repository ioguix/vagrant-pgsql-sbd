#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

declare -r PGVER="$1"

# system update and install required packages
cat <<EOF > /etc/apt/apt.conf.d/00silent
Dpkg::Use-Pty "0";
APT::Get::Assume-Yes "true";
Quiet "2";
EOF

apt-get update
apt-get upgrade

apt-get install --no-install-recommends lvm2 parted \
	pacemaker pacemaker-cli-utils fence-agents pcs sbd extrepo

# disable potential apt-cacher-ng proxy
if ! grep -qrn postgresql /etc/apt; then
	http_proxy='' extrepo enable postgresql
fi

apt-get update
apt-get install "postgresql-$PGVER" "postgresql-client-$PGVER"

# prepare pgsql requirements
if pg_lsclusters|grep -q main; then
	pg_dropcluster "$PGVER" main --stop
fi

# disable all possible pgsql instances using the "meta-service"
systemctl disable postgresql.service

# make sure the required temp directory exists
cat <<EOF > /etc/tmpfiles.d/postgresql-part.conf
# Directory for PostgreSQL temp stat files
d /run/postgresql/${PGVER}-main.pg_stat_tmp 0700 postgres postgres - -
EOF

systemd-tmpfiles --create /etc/tmpfiles.d/postgresql-part.conf

# setup lvm

test ! -f /etc/lvm/lvmlocal.conf.orig && cp /etc/lvm/lvmlocal.conf /etc/lvm/lvmlocal.conf.orig
cat <<EOF > /etc/lvm/lvmlocal.conf
global {
	system_id_source = "uname"
}
EOF

# cluster setup
pcs cluster destroy
test ! -f /etc/default/pacemaker.dist && cp /etc/default/pacemaker /etc/default/pacemaker.dist
cat<<EOF > /etc/default/pacemaker
PCMK_debug=yes
PCMK_logpriority=debug
EOF

# setting up pcs
systemctl --quiet --now enable pcsd.service
echo -e "hapass\nhapass"|passwd -q hacluster &>/dev/null
