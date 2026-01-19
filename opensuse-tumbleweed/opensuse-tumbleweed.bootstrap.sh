#!/usr/bin/env bash

set -ex
umask 022

# save current kernel version
rpm -qa | grep -- "kernel-default" | sort >/tmp/kernel_before_update

# remove DVD repository and add required online ones
zypper --non-interactive removerepo openSUSE-20260113-0
zypper --non-interactive addrepo https://download.opensuse.org/tumbleweed/repo/oss repo-oss
zypper --non-interactive addrepo https://download.opensuse.org/repositories/network:dhcp/openSUSE_Tumbleweed/network:dhcp.repo
zypper --non-interactive addrepo https://download.opensuse.org/repositories/devel:/languages:/python/openSUSE_Tumbleweed/devel:languages:python.repo
zypper --non-interactive addrepo https://download.opensuse.org/repositories/Cloud:/Tools/openSUSE_Tumbleweed/Cloud:Tools.repo
zypper --non-interactive --gpg-auto-import-keys refresh

# update packages and install cloud-init and a few extra ones
zypper --non-interactive update --no-recommends
zypper --non-interactive install --no-recommends cloud-init open-vm-tools gvfs-fuse vim openssl

# check if new kernel has been installed and remove old one in that case
rpm -qa | grep -- "kernel-default" | sort >/tmp/kernel_after_update
if ! cmp -s /tmp/kernel_before_update /tmp/kernel_after_update; then
    rpm -qa | grep -- "kernel-default" | grep -- "$(uname -r | sed -e 's,-default,,')" | xargs -r rpm -e
fi

# stopping services
systemctl stop systemd-journald.socket systemd-journald-dev-log.socket
systemctl stop systemd-journald

# initiate cloud-init for next fresh boot
cloud-init clean --logs --seed --machine-id
mv /etc/cloud/cloud.cfg /etc/cloud/cloud.cfg.orig
install -m644 /tmp/cloud.cfg /etc/cloud/cloud.cfg
truncate -s 0 /etc/machine_id
systemctl enable cloud-init-local.service cloud-init.service cloud-config.service cloud-final.service

# install public key for vagrant user
mkdir -p /home/vagrant/.ssh
chmod 700 /home/vagrant/.ssh
curl -fsSL -o /home/vagrant/.ssh/authorized_keys https://raw.githubusercontent.com/hashicorp/vagrant/main/keys/vagrant.pub
chown -R vagrant:users /home/vagrant/.ssh

# remove kernel firmware packages
rpm -qa | grep -- "kernel-firmware" | xargs -r rpm -e

# remove optional packages
rpm -e glibc-locale

# remove existing interface settings
find /etc/NetworkManager/system-connections/ -type f -name "*.nmconnection" -print -delete

# remove cache
zypper clean -a
find /var/cache/zypp/ -type f -delete

# clean up logs
find /var/log/ -type f -print -delete
rm -rf /var/log/journal/*
rm -rf /var/log/YaST2

# remove systemd random seed so it could be regenerated at first boot
rm -f /var/lib/systemd/random-seed

# remove existing host keys (these should be regenerated on a first boot)
rm -f /etc/ssh/ssh_host_*

# remove root password
passwd -d root

# synchronize cached writes to persistent storage
sync

# mumbo jumbo to give vmware-vdiskmanager more room for defragmenting and shrinking vmdk disk(s)
for destpath in /boot/efi /home/vagrant; do
    if [ ! -d "${destpath}" ]; then
        continue
    fi
    touch ${destpath}/zeroes
    if ! dd if=/dev/zero of=${destpath}/zeroes bs=4k; then
        sync
        rm -f ${destpath}/zeroes
        sync
    fi
done

# emit disk usage so it would be in packer log for future references
df -h
