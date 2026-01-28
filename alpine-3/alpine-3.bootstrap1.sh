#!/bin/sh
#
# this is phase 1 bootstrap script which is intended to run the installer

set -xeu

wget -O /tmp/answers "http://${HTTP_SRV}/alpine/answers"

export ERASE_DISKS=/dev/sda
export SWAP_SIZE=0
export USERSSHKEY="http://${HTTP_SRV}/alpine/ssh.key.pub"

setup-alpine -ef /tmp/answers

# TODO: Replace this ad‑hoc shutdown of sshd with a more robust mechanism that ensures
#       the system is never reachable via SSH while it is only partially configured.
#       Currently, sshd may briefly accept logins using a generic/temporary key between
#       setup-alpine invocation and this stop call, creating a race window when e.g.
#       packer SSH communicator session could be established.
#       Investigate image‑level hardening (e.g. disabling sshd by default, binding to
#       localhost only, or using firewall rules/metadata‑driven controls) so that SSH
#       access is only enabled after 1st phase bootstrap has completed successfully.
rc-service sshd stop

mount /dev/sda2 /mnt
printf "permit nopass vagrant as root\n" >/mnt/etc/doas.d/99-vagrant.conf
sync
umount /mnt

reboot
