#!/usr/bin/env bash

set -ex
umask 022

#zypper --non-interactive update
zypper --non-interactive install -y cloud-init open-vm-tools

# stopping services
systemctl stop systemd-journald.socket systemd-journald-dev-log.socket
systemctl stop systemd-journald

# initiate cloud-init for next fresh boot
cloud-init clean --logs --seed
install -m644 /tmp/cloud.cfg /etc/cloud/cloud.cfg
truncate -s 0 /etc/machine-id
truncate -s 0 /etc/machine_id

# install public key for vagrant user
mkdir -p /home/vagrant/.ssh
chmod 700 /home/vagrant/.ssh
curl -fsSL -o /home/vagrant/.ssh/authorized_keys https://raw.githubusercontent.com/hashicorp/vagrant/main/keys/vagrant.pub
chown -R vagrant:vagrant /home/vagrant/.ssh

# remove kernel firmware packages
rpm -qa | grep -- "kernel-firmware" | xargs -r rpm -e

# remove optional packages
rpm -e glibc-locale

# remove existing interface settings
find /etc/NetworkManager/system-connections/ -type f -name "*.nmconnection" -print -delete

# remove cache
zypper purge-kernels
zypper clean -a
find /var/cache/zypp/ -type f -delete

# clean up logs
find /var/log/ -type f -print -delete
rm -rf /var/log/journal/*
rm -rf /var/log/agama-installation

# remove systemd random seed so it could be regenerated at first boot
rm -f /var/lib/systemd/random-seed

# remove existing host keys (these should be regenerated on a first boot)
rm -f /etc/ssh/ssh_host_*

# synchronize cached writes to persistent storage
sync

# mumbo jumbo to give vmware-vdiskmanager more room for defragmenting and shrinking vmdk disk(s)
for destpath in /boot /home/vagrant; do
    touch ${destpath}/zeroes
    if ! dd if=/dev/zero of=${destpath}/zeroes bs=4k; then
        sync
        rm -f ${destpath}/zeroes
        sync
    fi
done

# emit disk usage so it would be in packer log for future references
df -h
