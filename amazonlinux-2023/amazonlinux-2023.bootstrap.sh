#!/usr/bin/env bash

set -ex
umask 022

yum install -y open-vm-tools

systemctl stop amazon-ssm-agent
systemctl disable amazon-ssm-agent
systemctl stop systemd-journald-audit.socket
systemctl stop systemd-journald-dev-log.socket
systemctl stop systemd-journald.socket
systemctl stop systemd-journald

cloud-init clean --logs
truncate -s 0 /etc/machine_id

rm -f /etc/ssh/ssh_host_*
rm -rf /var/log/journal/*
rm -f /etc/udev/rules.d/70-persistent-net.rules
rm -f /etc/sysconfig/network-scripts/ifcfg-eth*
rm -rf /var/cache/yum
find /var/log/ -type f -print -delete

# install public key for vagrant user
mkdir -p /home/vagrant/.ssh
chmod 700 /home/vagrant/.ssh
curl -fsSL -o /home/vagrant/.ssh/authorized_keys https://raw.githubusercontent.com/hashicorp/vagrant/main/keys/vagrant.pub
chown -R vagrant:vagrant /home/vagrant/.ssh

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
