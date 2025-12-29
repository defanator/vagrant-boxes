#!/usr/bin/env bash

set -ex
umask 022

dnf install -y open-vm-tools

systemctl stop systemd-journald.socket systemd-journald-audit.socket systemd-journald-dev-log.socket
systemctl stop systemd-journald

cloud-init clean --logs --seed
truncate -s 0 /etc/machine_id

rm -f /etc/ssh/ssh_host_*
rm -rf /var/cache/yum

find /var/log/ -type f -print -delete
rm -rf /var/log/journal/*

# install public key for vagrant user
mkdir -p /home/vagrant/.ssh
chmod 700 /home/vagrant/.ssh
curl -fsSL -o /home/vagrant/.ssh/authorized_keys https://raw.githubusercontent.com/hashicorp/vagrant/main/keys/vagrant.pub
chown -R vagrant:vagrant /home/vagrant/.ssh

# remove systemd random seed so it could be regenerated at first boot
rm -f /var/lib/systemd/random-seed

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
