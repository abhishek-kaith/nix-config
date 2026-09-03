# Minimal hardware config for the ThinkPad T14 Gen 1 (AMD, Ryzen 7 PRO 4750U).
# Filesystems are provided by disko, NOT declared here.
# CPU microcode + amdgpu come from the nixos-hardware t14-amd-gen1 profile.
# Module list taken from the running kernel on this machine (lsmod) — the same
# set `nixos-generate-config --no-filesystems` emits for this model.
{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "nvme" "xhci_pci" "usb_storage" "sd_mod" "rtsx_pci_sdmmc"
  ];
  boot.kernelModules = [ "kvm-amd" ];
}
