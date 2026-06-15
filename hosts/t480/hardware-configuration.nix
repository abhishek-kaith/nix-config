# Minimal hardware config for the T480.
# Filesystems are provided by disko, NOT declared here.
# CPU microcode + Intel graphics come from the nixos-hardware t480 profile.
# Regenerate with `nixos-generate-config --no-filesystems` on the machine if needed.
{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "xhci_pci" "thunderbolt" "nvme" "usb_storage" "sd_mod" "rtsx_pci_sdmmc"
  ];
  boot.kernelModules = [ "kvm-intel" ];
}
