# Declarative disk layout for the ThinkPad T480.
# LUKS (whole disk after ESP) -> LVM -> swap LV + btrfs root.
# The swap LV lives inside LUKS, so it is persistently encrypted and usable
# for hibernation (a random-key swap would break resume).
{
  disko.devices = {
    disk.main = {
      type   = "disk";
      device = "/dev/nvme0n1";
      content = {
        type = "gpt"; # GUID Partition Table — required for UEFI
        partitions = {

          ESP = {
            size = "512M";
            type = "EF00"; # EFI System Partition
            content = {
              type       = "filesystem";
              format     = "vfat";
              mountpoint = "/boot";
            };
          };

          luks = {
            size = "100%"; # rest of the disk
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
          size = "18G"; # >= 16G RAM for hibernation headroom
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
            subvolumes = {
              "@root" = { mountpoint = "/";     mountOptions = [ "compress=zstd" "noatime" ]; };
              "@home" = { mountpoint = "/home"; mountOptions = [ "compress=zstd" "noatime" ]; };
              "@nix"  = { mountpoint = "/nix";  mountOptions = [ "compress=zstd" "noatime" ]; };
            };
          };
        };
      };
    };
  };
}
