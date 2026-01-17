#!/usr/bin/env bash

set -ex
umask 022

# ensure that initial cloud-init has completed
cloud-init status --long

# install open-vm-tools
yum install -y open-vm-tools

# stopping services
systemctl stop systemd-journald-audit.socket
systemctl stop systemd-journald-dev-log.socket
systemctl stop systemd-journald.socket
systemctl stop systemd-journald
systemctl stop amazon-ssm-agent
systemctl disable amazon-ssm-agent

# initiate cloud-init for next fresh boot
cloud-init clean --logs --seed
mv /etc/cloud/cloud.cfg /etc/cloud/cloud.cfg.orig
install -m644 /tmp/cloud.cfg /etc/cloud/cloud.cfg
rm -f /etc/cloud/cloud.cfg.d/02_amazon-onprem.cfg
truncate -s 0 /etc/machine_id

# remove existing interface settings
rm -f /etc/udev/rules.d/70-persistent-net.rules
rm -f /etc/sysconfig/network-scripts/ifcfg-eth*

# this one triggers package repository indices fetching on every boot
rm -f /etc/update-motd.d/70-available-updates

# uninstall optional packages
rpm -e amazon-ssm-agent awscli-2

# remove cache
rm -rf /var/cache/dnf

# clean up logs
rm -rf /var/log/journal/*
find /var/log/ -type f -print -delete

# install public key for vagrant user
mkdir -p /home/vagrant/.ssh
chmod 700 /home/vagrant/.ssh
curl -fsSL -o /home/vagrant/.ssh/authorized_keys https://raw.githubusercontent.com/hashicorp/vagrant/main/keys/vagrant.pub
chown -R vagrant:vagrant /home/vagrant/.ssh

# remove existing host keys (these should be regenerated on a first boot)
rm -f /etc/ssh/ssh_host_*

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
