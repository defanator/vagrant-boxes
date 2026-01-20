#!/bin/sh
#
# this is phase 2 bootstrap script which is intended to configure target image

set -xeu

# setup package repositories
setup-apkrepos -o

# update packages
apk update
apk upgrade

# install additional packages
apk add sudo curl open-vm-tools

# configure sudo (in addition to doas) for vagrant user
printf "vagrant ALL=(ALL:ALL) NOPASSWD: ALL\n" >/etc/sudoers.d/vagrant

# install public key for vagrant user
wget -O - https://raw.githubusercontent.com/hashicorp/vagrant/main/keys/vagrant.pub >/home/vagrant/.ssh/authorized_keys

# remove cache
rm -rf /var/cache/apk/*

# synchronize cached writes to persistent storage
sync

# mumbo jumbo to give vmware-vdiskmanager more room for defragmenting and shrinking vmdk disk(s)
if ! dd if=/dev/zero of=/home/vagrant/zeroes bs=4k; then
    sync
    rm -f /home/vagrant/zeroes
    sync
fi

# emit disk usage so it would be in packer log for future references
df -h
