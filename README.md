# Bootstrap high available PostgreSQL instance using a shared storage

This `Vagrantfile` bootstraps a fresh virtualized cluster with:

* minimum two VM under Debian
* watchdog enabled on all nodes
* one PostgreSQL instance
* one shared storage for PostgreSQL data and _Storage Based Death_
* one vIP moving with the PostgreSQL instance
* one dummy service avoiding to colocate with PostgreSQL, just for fun and demo

This has been developed and tested using:

* vagrant 2.2.14
* vagrant-libvirt 0.5.3
* Debian 11 bullseye as VM OS (vagrant box `debian/bullseye64`)
* Pacemaker 2.0.5
* pcs 0.10.8

## Prerequisites:

You need `vagrant` and `vagrant-libvirt`. 

~~~
apt install make vagrant vagrant-libvirt libvirt-clients # for Debian-like
yum install make vagrant vagrant-libvirt libvirt-client # for RH-like
dnf install make vagrant vagrant-libvirt libvirt-client # for recent RH-like
systemctl enable --now libvirtd
~~~

Alternatively, you can install `vagrant-libvirt` using:

~~~
apt install libvirt-dev ruby-dev
vagrant plugin install vagrant-libvirt
~~~

## Creating the cluster

To create the cluster, run:

~~~
cd vagrant-patroni
make all
~~~

After some minutes and tons of log messages, you can connect to your servers
using eg.:

~~~
vagrant ssh srv1
~~~

Play with the cluster!

~~~console
srv1> sudo -i

srv1# pcs resource

srv1# crm_mon -1D

srv1# crm_mon -1Dn

srv1# # move the resource away (and clear the temp constraint)
srv1# pcs resource move pgsqlgroup --wait
srv1# pcs resource clear pgsqlgroup --wait

srv1# # Kill the node hosting pgsql.
srv1# # Open crm_mon in another term to observe the reaction
srv1# pcs stonith fence srv2
srv1# crm_mon -frAno

srv1# # after the reboot of srv2 node, start the cluster on the node
srv1# pcs cluster start srv2
~~~

## Customizing the cluster

Copy `vagrant.yml-dist` as `vagrant.yml` read comments and edit as needed.


## Destroying the cluster

To destroy your cluster, run:

~~~
make clean
~~~

## Tips

Find all existing VM created by vagrant on your system:

~~~
vagrant global-status
~~~
