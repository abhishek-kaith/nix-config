# Declarative disk layout for the ThinkPad T14 Gen 1 (AMD).
# ESP -> LUKS (450G) -> LVM -> swap LV + btrfs root, then ~500G left unallocated.
# The swap LV lives inside LUKS, so it is persistently encrypted and usable
# for hibernation (a random-key swap would break resume).
#
# Same shape as hosts/t480/disko.nix with one difference: NixOS takes a fixed
# 450G, not the whole disk. /dev/nvme0n1 (ADATA LEGEND 710, 954G) is left with
# ~500G of UNALLOCATED space after the LUKS partition, reserved for a Windows
# install later. `nix run .#install -- t14` still wipes the whole disk first
# (disko's destroy step zaps the partition table) — the reserve is empty space
# to partition by hand afterwards, not a preserved partition.
#
# For that future dual boot: the ESP is 1G (the T480 uses 512M) so Windows'
# boot files and systemd-boot's kernels fit side by side, and the Windows
# installer will pick up the existing ESP on its own. Install Windows AFTER
# NixOS and re-run `bootctl install` if it overwrites the boot order.
{
  disko.devices = {
    disk.main = {
      type   = "disk";
      device = "/dev/nvme0n1";
      content = {
        type = "gpt"; # GUID Partition Table — required for UEFI
        partitions = {

          ESP = {
            size = "1G";   # shared with a future Windows install, see above
            type = "EF00"; # EFI System Partition
            content = {
              type       = "filesystem";
              format     = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ]; # protect systemd-boot's random seed
            };
          };

          luks = {
            size = "450G"; # NOT 100%: everything past this stays unallocated
            content = {
              type = "luks";
              name = "cryptroot"; # -> /dev/mapper/cryptroot
              settings.allowDiscards = true; # SSD TRIM through LUKS
              content = {
                type = "lvm_pv";
                vg   = "pool"; # this PV joins volume group "pool"
              };
            };
          };

        };
      };
    };

    lvm_vg.pool = {
      type = "lvm_vg";
      lvs = {
        swap = {
          size = "34G"; # >= 32G RAM for hibernation headroom
          content = {
            type         = "swap";
            resumeDevice = true; # sets boot.resumeDevice for hibernation
          };
        };
        root = {
          size = "100%FREE";
          content = {
            type      = "btrfs";
            extraArgs = [ "-f" ];
            # discard=async: trim continuously in the background instead of in one
            # weekly burst (services.fstrim stays as a backstop). Set only here —
            # the VM hosts drop it, since discard on a virtual disk only does
            # anything if the hypervisor passes it through.
            subvolumes = {
              "@root" = { mountpoint = "/";     mountOptions = [ "compress=zstd" "noatime" "discard=async" ]; };
              "@home" = { mountpoint = "/home"; mountOptions = [ "compress=zstd" "noatime" "discard=async" ]; };
              "@nix"  = { mountpoint = "/nix";  mountOptions = [ "compress=zstd" "noatime" "discard=async" ]; };
            };
          };
        };
      };
    };
  };
}
