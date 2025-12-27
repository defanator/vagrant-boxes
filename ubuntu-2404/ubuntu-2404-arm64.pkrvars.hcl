boot_command = ["<wait>c<wait>linux /casper/vmlinuz autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ubuntu2404-arm64/<enter>initrd /casper/initrd<enter>boot<enter>"]
