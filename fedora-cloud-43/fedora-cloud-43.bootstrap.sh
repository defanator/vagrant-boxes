#!/usr/bin/env bash

set -ex
umask 022

# update grub config
awk -i inplace '/console=ttyS/ {print "#" $0; gsub(/console=ttyS[^ "]* */, ""); print; next}
     /console=ttyAMA/ {print "#" $0; gsub(/console=ttyAMA[^ "]* */, ""); print; next}
     /^GRUB_TERMINAL_/ {print "#" $0; next}
     /^GRUB_TIMEOUT=/ {print "#" $0; print "GRUB_TIMEOUT=5"; next} 1' /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg

# save current kernel version
rpm -qa | grep -E -- "kernel-core|kernel-modules-core" >/tmp/kernel_before_update

# update packages and install open-vm-tools
dnf update -y
dnf install -y open-vm-tools

# check if new kernel has been installed and remove old one in that case
rpm -qa | grep -E -- "kernel-core|kernel-modules-core" >/tmp/kernel_after_update
if ! cmp -s /tmp/kernel_before_update /tmp/kernel_after_update; then
    rpm -qa | grep -E -- "kernel-core|kernel-modules-core" | grep -- "$(uname -r)" | xargs -r rpm -e
    find /boot/loader/entries/ -type f -name "*$(uname -r)*" -print -delete
fi

# stopping services
systemctl stop systemd-journald.socket systemd-journald-audit.socket systemd-journald-dev-log.socket
systemctl stop systemd-journald

# initiate cloud-init for next fresh boot
cloud-init clean --logs --seed --machine-id
install -m644 /tmp/cloud.cfg /etc/cloud/cloud.cfg
truncate -s 0 /etc/machine_id

# clean up logs
find /var/log/ -type f -print -delete
rm -rf /var/log/journal/*

# install public key for vagrant user
mkdir -p /home/vagrant/.ssh
chmod 700 /home/vagrant/.ssh
curl -fsSL -o /home/vagrant/.ssh/authorized_keys https://raw.githubusercontent.com/hashicorp/vagrant/main/keys/vagrant.pub
chown -R vagrant:vagrant /home/vagrant/.ssh

# remove existing interface settings
find /etc/NetworkManager/system-connections/ -type f -name "*.nmconnection" -print -delete

# remove cache
rm -rf /var/cache/dnf
rm -rf /var/cache/libdnf5

# remove systemd random seed so it could be regenerated at first boot
rm -f /var/lib/systemd/random-seed

# remove existing host keys (these should be regenerated on a first boot)
rm -f /etc/ssh/ssh_host_*

# synchronize cached writes to persistent storage
sync

# mumbo jumbo to give vmware-vdiskmanager more room for defragmenting and shrinking vmdk disk(s)
# fedora uses btrfs with zstd compression, hence we need to disable compression for a target file first
for destpath in /boot /home/vagrant; do
    touch ${destpath}/zeroes
    chattr +m ${destpath}/zeroes
    if ! dd if=/dev/zero of=${destpath}/zeroes bs=4k; then
        sync
        rm -f ${destpath}/zeroes
        sync
    fi
done

# emit disk usage so it would be in packer log for future references
df -h
