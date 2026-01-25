#!/usr/bin/env bash
#
# This script is intended to be used as a shell-local packer provisioner
# to install Alpine Linux from a standard bootable ISO on aarch64.
#
# It expects serial console to be up and connected to the 127.0.0.1:7777
# listener.

set -xeuo pipefail

echo "PACKER_HTTP_ADDR: ${PACKER_HTTP_ADDR}"

{
  # phase 1
  sleep 3
  printf "\n"
  sleep 1
  printf "root\n"
  sleep 2
  printf "ip link set eth0 up\n"
  sleep 2
  printf "udhcpc -i eth0\n"
  sleep 5
  printf "export HTTP_SRV=%s\n" "${PACKER_HTTP_ADDR}"
  sleep 2
  printf "wget -O /tmp/bootstrap.sh %s/alpine/bootstrap1.sh\n" "\${HTTP_SRV}"
  sleep 2
  printf "/bin/sh /tmp/bootstrap.sh\n"
  sleep 30
  # phase 2
  printf "\n"
  sleep 1
  printf "root\n"
  sleep 2
  printf "export HTTP_SRV=%s\n" "${PACKER_HTTP_ADDR}"
  sleep 2
  printf "wget -O /tmp/bootstrap.sh %s/alpine/bootstrap2.sh\n" "\${HTTP_SRV}"
  sleep 2
  printf "/bin/sh /tmp/bootstrap.sh\n"
  sleep 30
  printf "poweroff\n"
  sleep 5
} | nc -t 127.0.0.1 7777
