boot_command = [
  "<wait><down><wait>",
  "autoyast=http://{{ .HTTPIP }}:{{ .HTTPPort }}/opensuse-tumbleweed/autoinst-x86_64.xml<wait><enter>",
]
