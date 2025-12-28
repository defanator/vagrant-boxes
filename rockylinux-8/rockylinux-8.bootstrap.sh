#!/usr/bin/env bash

set -xeu
umask 022

# stopping services
systemctl stop crond
systemctl stop systemd-journald-dev-log.socket
systemctl stop systemd-journald.socket
systemctl stop systemd-journald

# install cloud-init and open-vm-tools
dnf install -y cloud-init open-vm-tools

# initiate cloud-init for next fresh boot
cloud-init clean --logs --seed
truncate -s 0 /etc/machine-id
truncate -s 0 /etc/machine_id

# remove existing interface settings
rm -f /etc/udev/rules.d/70-persistent-net.rules
rm -f /etc/sysconfig/network-scripts/ifcfg-eth*
rm -f /etc/NetworkManager/system-connections/*.nmconnection

# uninstall unnecessary packages
rpm -qa | grep -- '-firmware' | xargs -r rpm -e
rpm -qa | grep -- 'geolite2' | xargs -r rpm -e

# remove cache
rm -rf /var/cache/dnf

# clean up logs
find /var/log/ -type f -print -delete
rm -rf /var/log/journal/*

# install public key for vagrant user
mkdir -p /home/vagrant/.ssh
chmod 700 /home/vagrant/.ssh
curl -fsSL -o /home/vagrant/.ssh/authorized_keys https://raw.githubusercontent.com/hashicorp/vagrant/main/keys/vagrant.pub
chown -R vagrant:vagrant /home/vagrant/.ssh

# remove systemd random seed so it could be regenerated at first boot
rm -f /var/lib/systemd/random-seed

# remove existing host keys (these should be regenerated on a first boot)
rm -f /etc/ssh/ssh_host_*

# synchronize cached writes to persistent storage
sync

# mumbo jumbo to give vmware-vdiskmanager more room for defragmenting and shrinking vmdk disk(s)
if ! dd if=/dev/zero of=/home/vagrant/zeroes bs=64k; then
    sync
    rm -f /home/vagrant/zeroes
    sync
fi

# emit disk usage so it would be in packer log for future references
df -h
