boot_command = [
  "<wait>c<wait>",
  "linux /boot/aarch64/linux autoyast=http://{{ .HTTPIP }}:{{ .HTTPPort }}/opensuse-tumbleweed/autoinst-aarch64.xml<wait><enter>",
  "initrd /boot/aarch64/initrd<wait><enter>",
  "boot<wait><enter>",
]
