#!/usr/bin/env bash

set -xeu
umask 022

# stopping services
###systemctl stop cron
systemctl stop systemd-journald-dev-log.socket
systemctl stop systemd-journald-audit.socket
systemctl stop systemd-journald.socket
systemctl stop systemd-journald

# install cloud-init and open-vm-tools
apt-get update -y
apt-get install --no-install-recommends --no-install-suggests -y cloud-init open-vm-tools

# initiate cloud-init for next fresh boot
cloud-init clean --logs --seed
install -m644 /tmp/cloud.cfg /etc/cloud/cloud.cfg
rm -f /etc/cloud/cloud.cfg.d/90_dpkg.cfg
truncate -s 0 /etc/machine-id

# remove existing interface settings
rm -f /etc/cloud/cloud.cfg.d/90-installer-network.cfg /etc/cloud/cloud.cfg.d/99-installer.cfg /etc/netplan/50-cloud-init.yaml

# enable DHCP for all interfaces managed by systemd-networkd
cat > /etc/systemd/network/99-dhcp-all.network << EOT
[Match]
Name=*

[Network]
DHCP=yes
LLMNR=no
EOT

# remove existing host keys (these should be regenerated on a first boot)
rm -f /etc/ssh/ssh_host_*

# uninstall kernel headers/sources, old kernel(s), X11 stuff
dpkg -l | awk '{print $2}' | grep -- "linux-headers" | xargs -r apt-get -y purge
dpkg -l | awk '{print $2}' | grep -- "linux-image-[1-9].*" | grep -v -- "$(uname -r)" | xargs -r apt-get -y purge
dpkg -l | awk '{print $2}' | grep -- '-dev\(:[a-z0-9]\+\)\?$' | grep -v -- "systemd-dev" | xargs -r apt-get -y purge
apt-get purge -y libx11-data xauth libxmuu1 libx11-6 libxext6 intel-microcode unattended-upgrades
apt-get autoremove -y --purge

# remove cache
rm -rf /var/cache/apt/*
find /var/lib/apt/lists/ -type f -delete
rm -rf /var/cache/swcatalog/cache
rm -rf /var/cache/apparmor/*

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
