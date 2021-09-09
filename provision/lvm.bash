#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# make sure the shared disk partitions are all visible on all nodes.

# look for new partitions on shared disk
partprobe

test -e /dev/disk/by-partlabel/sbd
