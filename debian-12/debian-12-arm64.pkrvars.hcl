boot_command = ["<wait>c<wait>linux /install.a64/vmlinuz auto=true preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/debian/preseed.cfg<enter>initrd /install.a64/initrd.gz<enter>boot<enter>"]
