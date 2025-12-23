boot_command = ["<wait><esc><wait>auto preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/debian/preseed-amd64.cfg<wait><enter>"]
