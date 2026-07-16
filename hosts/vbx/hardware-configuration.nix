# Hand-authored for a VirtualBox guest (not nixos-generate-config output).
# Filesystems/mounts come from disko.nix — this file only carries the kernel
# modules the initrd needs to reach the virtual disk, plus the platform.
{ lib, ... }:

{
  # VirtualBox exposes disks via an emulated Intel SATA/AHCI (and IDE) controller,
  # so the initrd needs these to find root. This is the set nixos-generate-config
  # produces inside VirtualBox.
  boot.initrd.availableKernelModules = [ "ata_piix" "ohci_pci" "ehci_pci" "ahci" "sd_mod" "sr_mod" ];
  boot.initrd.kernelModules = [ ];
  # no kvm-amd here — we are the guest; nested virt isn't available/needed
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
