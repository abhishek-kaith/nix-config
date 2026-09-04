# Generated on the T14 with `nixos-generate-config --no-filesystems`.
# Filesystems come from disko.nix; this file contains detected boot modules and
# the platform default. CPU microcode comes from the nixos-hardware T14 profile.
{ lib, modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "nvme" "ehci_pci" "xhci_pci_renesas" "xhci_pci" "rtsx_pci_sdmmc"
  ];
  boot.initrd.kernelModules = [ "dm-snapshot" ];
  boot.kernelModules = [ "kvm-amd" ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
