# Declarative disk layout for the VM.
# disko will partition, format, and mount everything from this file.
# Change `device` to /dev/sda if your VM uses IDE instead of virtio.
{
  disko.devices.disk.main = {
    type   = "disk";
    device = "/dev/vda";
    content = {
      type = "gpt"; # GUID Partition Table — required for UEFI
      partitions = {

        ESP = {
          size = "512M";
          type = "EF00"; # EFI System Partition type code (gdisk format)
          content = {
            type       = "filesystem";
            format     = "vfat";     # FAT32 — UEFI can only read this
            mountpoint = "/boot";
          };
        };

        luks = { # no partition type needed — disko sets 8309 (Linux LUKS) automatically
          size = "100%"; # rest of the disk
          content = {
            type = "luks";
            name = "cryptroot"; # becomes /dev/mapper/cryptroot after unlock
            settings.allowDiscards = true; # enables TRIM (needed for SSDs, fine for VMs)
            content = {
              type      = "btrfs";
              extraArgs = [ "-f" ]; # overwrite any existing filesystem
              subvolumes = {
                # each subvolume can be snapshotted independently
                "@root" = {
                  mountpoint   = "/";
                  mountOptions = [ "compress=zstd" "noatime" ];
                  # compress=zstd: transparent compression — saves space, often faster
                  # noatime: skip updating access timestamps on reads — small perf win
                };
                "@home" = {
                  mountpoint   = "/home"; # user files — separate from root for independent snapshots
                  mountOptions = [ "compress=zstd" "noatime" ];
                };
                "@nix" = {
                  mountpoint   = "/nix";
                  mountOptions = [ "compress=zstd" "noatime" ];
                  # nix store doesn't need snapshots — nix generations handle rollback
                };
              };
            };
          };
        };

      };
    };
  };
}
