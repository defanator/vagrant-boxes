boot_command = ["<wait>c<wait>linux /casper/vmlinuz autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ubuntu2204-arm64/<enter>initrd /casper/initrd<enter>boot<enter>"]
