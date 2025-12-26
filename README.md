# Vagrant boxes

This repository provides automated build tools for creating Vagrant boxes from multiple Linux distributions, including Amazon Linux, Rocky Linux, and Debian.

It supports building boxes from various source formats using [Packer](https://developer.hashicorp.com/packer/docs/intro), including pre-built KVM/qcow2 images as well as traditional ISOs.

Currently designed for macOS hosts and VMware providers, but adding support for Linux hosts (including WSL) and additional providers should be straightforward.

Pre-built boxes are available from Vagrant Cloud: [https://portal.cloud.hashicorp.com/vagrant/discover/defanator](https://portal.cloud.hashicorp.com/vagrant/discover/defanator)

## Supported images

- **Amazon Linux 2** - [amazonlinux-2/](amazonlinux-2/)
- **Amazon Linux 2023** - [amazonlinux-2023/](amazonlinux-2023/)
- **Rocky Linux 9** - [rockylinux-9/](rockylinux-9/)
- **Rocky Linux 10** - [rockylinux-10/](rockylinux-10/)
- **Debian 12 "bookworm"** - [debian-12](debian-12/)
- **Debian 13 "trixie"** - [debian-13](debian-13/)

Both images support:
- x86_64 (amd64) architecture
- ARM64 architecture (with EFI firmware)

## Prerequisites

### Required tools
- [Packer](https://www.packer.io/) (>= 1.14.0)
- [VMware Fusion](https://www.vmware.com/products/fusion.html)
- `qemu-img` (for image format conversion)
- `curl` and `sha256sum`
- GNU Make

### macOS installation
```bash
# Install Packer
brew install packer

# Install QEMU for qemu-img
brew install qemu

# Ensure VMware Fusion is installed
# Download from: https://www.vmware.com/products/fusion.html
```

## Usage

### Base targets
```bash
# Show available targets
make

# Build latest version of a specific box (e.g., Amazon Linux 2)
make box-amazonlinux-2

# Build latest Amazon Linux 2023 box
make box-amazonlinux-2023
```

### Individual steps

For more granular control, you can run individual steps:

```bash
# Show help for a specific image
make help-amazonlinux-2

# Fetch the original KVM image
make fetch-amazonlinux-2

# Convert KVM image to VMDK format
make convert-amazonlinux-2

# Build the box using Packer
make build-amazonlinux-2

# Package the final Vagrant box
make box-amazonlinux-2
```

### Auxiliary targets
```bash
# Show current environment configuration
make show-env

# Show environment for a specific image (including versions etc)
make show-env-amazonlinux-2
```

## Build process

The build process consists of several stages:

1. **Fetch**: Downloads latest official Amazon Linux KVM image (in QCOW2 format)
2. **Convert**: Converts the QCOW2 image to VMDK format for VMware compatibility
3. **Prepare**: Creates source VM configuration and cloud-init seed ISO
4. **Build**: Uses Packer to customize the VM and install necessary components
5. **Package**: Creates the final Vagrant box file

### What's included

The resulting Vagrant boxes include:
- Pre-configured `vagrant` user with sudo privileges
- VMware Tools installed
- SSH key authentication configured
- Cleaned up logs and temporary files for smaller box size

## Box features

- **Default user**: `vagrant` with password `vagrant`
- **SSH access**: Password and key-based authentication enabled
- **Provider**: VMware Desktop (Fusion/Workstation)
- **Architecture**: Automatically detected (amd64 or arm64)

## Output

Built boxes are placed in:
```
work/
├── amazonlinux-2/
│   └── output/
│       ├── amazonlinux-2*.box     # Vagrant box file
│       ├── metadata.json          # Box metadata
│       └── SHA256SUMS             # Checksums
└── amazonlinux-2023/
    └── output/
        ├── amazonlinux-2023*.box  # Vagrant box file
        ├── metadata.json          # Box metadata
        └── SHA256SUMS             # Checksums
```

### How to add locally built box to vagrant

In the corresponding output directory, run:
```
% vagrant box add metadata.json
==> box: Loading metadata for box 'metadata.json'
    box: URL: file:///Users/xxxx/git/vagrant-boxes/work/amazonlinux-2023/output/metadata.json
==> box: Adding box 'defanator/amazonlinux-2023' (v2023.9.20251117.1-1) for provider: vmware_desktop (arm64)
    box: Downloading: amazonlinux-2023-v2023.9.20251117.1-1-arm64.box
==> box: Successfully added box 'defanator/amazonlinux-2023' (v2023.9.20251117.1-1) for 'vmware_desktop (arm64)'!
```

## Cleanup

```bash
# Clean all build artifacts
make clean

# Clean specific VM artifacts while leaving the KVM image (useful for debugging to avoid extra downloads)
make -C amazonlinux-2 preclean
```

### Adding new images

1. Create a new directory following the existing pattern
2. Copy and modify Makefile and template files
3. Update image URLs and version detection logic
4. Test the build process

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for bugs and feature requests.
