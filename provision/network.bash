#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

declare -r NODENAME="$1"
shift 1
declare -a NODES

# set hostname
hostnamectl set-hostname "${NODENAME}"

# fill /etc/hosts
for N in "$@"; do
	declare HNAME="${N%=*}"
	declare HIP="${N##*=}"
	NODES+=( "$HNAME" )
	if ! grep -Eq "${HNAME}\$" /etc/hosts; then
		echo "${HIP} ${HNAME}" >> /etc/hosts
	fi
done

# ssh setup
cat <<-'EOF' > "/home/vagrant/.ssh/config"
Host *
  CheckHostIP no
  StrictHostKeyChecking no
EOF

chown -R "vagrant:" "/home/vagrant/.ssh"
chmod 0700 "/home/vagrant/.ssh"
chmod 0600 "/home/vagrant/.ssh/id_rsa"
chmod 0644 "/home/vagrant/.ssh/id_rsa.pub"
chmod 0600 "/home/vagrant/.ssh/config"
chmod 0600 "/home/vagrant/.ssh/authorized_keys"

cp -R "/home/vagrant/.ssh" "/root"

# force proper permissions on .ssh files
chown -R "root:" "/root/.ssh"
chmod 0700 "/root/.ssh"
chmod 0600 "/root/.ssh/id_rsa"
chmod 0644 "/root/.ssh/id_rsa.pub"
chmod 0600 "/root/.ssh/config"
chmod 0600 "/root/.ssh/authorized_keys"
