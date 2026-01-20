#!/bin/sh
#
# this is phase 1 bootstrap script which is intended to run the installer

set -xeu

wget -O /tmp/answers "http://${HTTP_SRV}/alpine/answers"

export ERASE_DISKS=/dev/sda
export SWAP_SIZE=0
export USERSSHKEY="http://${HTTP_SRV}/alpine/ssh.key.pub"

setup-alpine -ef /tmp/answers

# TODO: figure out better way to prevent accidental ssh logins during this phase
rc-service sshd stop

mount /dev/sda2 /mnt
printf "permit nopass vagrant as root\n" >/mnt/etc/doas.d/99-vagrant.conf
sync
umount /mnt

reboot
