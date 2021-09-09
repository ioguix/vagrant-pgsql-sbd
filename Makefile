# This makefile helps running provisioners in correct order and dependency.

export VAGRANT_BOX_UPDATE_CHECK_DISABLE=1
export VAGRANT_CHECKPOINT_DISABLE=1

.PHONY: all up san pgsql pcmk clean check validate

all: up san lvm pgsql pcmk

up:
	vagrant up

san:
	vagrant provision --provision-with=san

lvm:
	vagrant provision --provision-with=lvm

pgsql:
	vagrant provision --provision-with=pgsql

pcmk:
	vagrant provision --provision-with=pcmk

clean:
	vagrant destroy -f

check: validate

validate:
	@vagrant validate
	@if which shellcheck >/dev/null                                          ;\
	then shellcheck provision/*bash                                          ;\
	else echo "WARNING: shellcheck is not in PATH, not checking bash syntax" ;\
	fi
