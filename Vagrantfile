# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  host = RbConfig::CONFIG['host_os']

  # use one quarter of available cores, rounded down to an even number, capped at 2 CPUs (if available)
  cores = `getconf _NPROCESSORS_ONLN`.to_i
  cpus = [2, [(cores / 4) * 2, 1].max].min

  if host =~ /darwin/
    mem = [2048, `sysctl -n hw.memsize`.to_i / 1024 / 1024 / 2].min
  elsif host =~ /linux/
    mem = [2048, `awk '/MemTotal/ {print $2}' /proc/meminfo`.to_i / 1024 / 2].min
  else
    mem = 1024
  end

  # to resize primary disk, uncomment the next line
  # config.vm.disk :disk, size: "15GB", primary: true

  config.vm.provider "vmware_desktop" do |vmw, override|
    vmw.cpus = cpus
    vmw.memory = mem
    vmw.gui = false
    vmw.linked_clone = false
  end

  config.ssh.forward_agent = true

  config.vm.define "al2", autostart: false do |al2|
    al2.vm.box = "defanator/amazonlinux-2"
    al2.vm.hostname = "amazonlinux2"
  end

  config.vm.define "al2023", autostart: false do |al2023|
    al2023.vm.box = "defanator/amazonlinux-2023"
    al2023.vm.hostname = "amazonlinux2023"
  end

  config.vm.define "rocky9", autostart: false do |rocky9|
    rocky9.vm.box = "defanator/rockylinux-9"
    rocky9.vm.hostname = "rockylinux9"
  end

  config.vm.define "rocky10", autostart: false do |rocky10|
    rocky10.vm.box = "defanator/rockylinux-10"
    rocky10.vm.hostname = "rockylinux10"
  end

  config.vm.define "debian12", autostart: false do |debian12|
    debian12.vm.box = "defanator/debian-12"
    debian12.vm.hostname = "debian12"
  end

  config.vm.define "debian13", autostart: false do |debian13|
    debian13.vm.box = "defanator/debian-13"
    debian13.vm.hostname = "debian13"
  end
end
