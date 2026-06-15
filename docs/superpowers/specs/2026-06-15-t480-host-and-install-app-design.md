# T480 ThinkPad Host + Declarative Install App — Design

- **Date:** 2026-06-15
- **Status:** Design approved; pending spec review before planning.

## Goal

Add a real-hardware NixOS host for a **Lenovo ThinkPad T480** to the existing
flake-based config, with full-disk encryption and working **suspend-to-disk
(hibernation)**. Provide a single-command install entry point
(`nix run .#install -- <host>`) that bakes in the live-ISO workarounds we
discovered, so installs are reproducible across both the `vm` and `t480` hosts.

## Context

- Flake-based config. Existing host `vm` (LUKS + btrfs, **no swap**). Structure:
  `hosts/<host>/{default,disko,hardware-configuration,home}.nix`, shared
  `modules/nixos/*` and `modules/home/*`, hosts built via `lib.mkHost`.
- noctalia desktop shell via the home-manager module. Its binary cache is
  declared in `modules/nixos/common.nix` (substituters + key). The flake
  intentionally does **not** make the `noctalia` input follow `nixpkgs` — this
  is **required** to use the cache (confirmed by the noctalia v5 NixOS docs).
- **Install lesson:** the live ISO's `/nix/store` and `/tmp` are RAM-backed; a
  desktop closure exhausts RAM → `No space left on device`. Fix:
  `TMPDIR=/mnt/tmp` (a dir on the mounted target disk) during `nixos-install`.
  The disko layout has no swap, so the tmpfs has nothing to spill into.
- **Target hardware:** T480, NVMe `/dev/nvme0n1`, 16 GB RAM, Intel UHD 620 only
  (no discrete NVIDIA GPU).

## Decisions

1. **Hibernation-capable encrypted swap: `LUKS → LVM → (swap LV + btrfs root)`.**
   Single passphrase unlock; swap is encrypted with the persistent LUKS key (a
   random-key swap would break resume); disko's `swap.resumeDevice = true` wires
   `boot.resumeDevice`. Swap sized per-host — **18 GB** for the T480's 16 GB RAM.
   - *Rejected:* btrfs swapfile (needs a per-host `resume_offset`, fiddly and
     non-declarative); zram-only (cannot hibernate).
2. **Install via a flake app:** `nix run .#install -- <host>`. Encodes
   `disko` + `TMPDIR=/mnt/tmp nixos-install` + the noctalia cache `--option`s.
   - *Rejected:* loose shell script (less discoverable); README-only runbook
     (manual, error-prone).
3. **`nixos-hardware` `lenovo-thinkpad-t480` profile** for hardware tuning. It
   imports `common/cpu/intel/kaby-lake` (microcode, Intel graphics, `kvm-intel`),
   `common/pc/ssd` (TRIM), the thinkpad base (TrackPoint), and enables
   `services.throttled` (fixes the T480 BD-PROCHOT throttling). It does **not**
   touch disk/LUKS/bootloader/power-daemon — those stay ours, no conflicts.
   Added as a flake input, **not** following nixpkgs.
4. **New shared `modules/nixos/laptop.nix`** for noctalia's real-hardware
   prerequisites (upower, bluetooth, power-profiles-daemon). Imported by laptop
   hosts only; keeps `vm` clean.
5. **`vm` host unchanged.** Hibernation is meaningless in a VM; not worth
   re-running disko.
6. **zram** in shared `common.nix` (`zramSwap.enable = true`) for runtime memory
   pressure on both hosts. Coexists with the disk hibernation swap (zram has
   higher runtime priority; the LV is used only for resume). *(Included per
   approval; easy to drop in spec review.)*

## Design

### `flake.nix`

- **inputs:** add `nixos-hardware.url = "github:NixOS/nixos-hardware";` (no `follows`).
- **outputs:** add `t480 = lib.mkHost { hostname = "t480"; };` to
  `nixosConfigurations`.
- Confirm `lib.mkHost` passes `inputs` through `specialArgs` so the host can
  reach `inputs.nixos-hardware` (it already does for `inputs.disko` / `inputs.noctalia`).

### `modules/nixos/common.nix`

- Add `zramSwap.enable = true;` (shared by both hosts — runtime memory pressure;
  coexists with the T480's disk hibernation swap).

### `hosts/t480/disko.nix`

```nix
{
  disko.devices = {
    disk.main = {
      type   = "disk";
      device = "/dev/nvme0n1";
      content = {
        type = "gpt";
        partitions = {
          ESP  = { size = "512M"; type = "EF00";
                   content = { type = "filesystem"; format = "vfat"; mountpoint = "/boot"; }; };
          luks = { size = "100%";
                   content = { type = "luks"; name = "cryptroot";
                               settings.allowDiscards = true;       # SSD TRIM through LUKS
                               content = { type = "lvm_pv"; vg = "pool"; }; }; };
        };
      };
    };
    lvm_vg.pool = {
      type = "lvm_vg";
      lvs = {
        swap = { size = "18G";
                 content = { type = "swap"; resumeDevice = true; }; };   # → boot.resumeDevice
        root = { size = "100%FREE";
                 content = { type = "btrfs"; extraArgs = [ "-f" ];
                             subvolumes = {
                               "@root" = { mountpoint = "/";     mountOptions = [ "compress=zstd" "noatime" ]; };
                               "@home" = { mountpoint = "/home"; mountOptions = [ "compress=zstd" "noatime" ]; };
                               "@nix"  = { mountpoint = "/nix";  mountOptions = [ "compress=zstd" "noatime" ]; };
                             }; }; };
      };
    };
  };
}
```

### `hosts/t480/default.nix`

- **imports:** `inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t480`,
  `./disko.nix`, `./hardware-configuration.nix`, the shared nixos modules
  (common, shell, hyprland, desktop), and `../../modules/nixos/laptop.nix`.
- `boot.loader.systemd-boot.enable = true; boot.loader.efi.canTouchEfiVariables = true;`
- `networking.hostName = "t480"; networking.networkmanager.enable = true;`
- `users.users.k` (wheel, networkmanager, zsh) — same as `vm`.
- `system.stateVersion = "26.05";`
- Optional: `services.logind.lidSwitch = "suspend-then-hibernate";` (note in plan).

### `hosts/t480/hardware-configuration.nix`

Minimal committed file — disko provides the filesystems:

```nix
{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];
  boot.initrd.availableKernelModules = [ "xhci_pci" "thunderbolt" "nvme" "usb_storage" "sd_mod" "rtsx_pci_sdmmc" ];
  boot.kernelModules = [ "kvm-intel" ];
}
```

Regenerate with `nixos-generate-config --no-filesystems` on the machine if
anything is missing.

### `hosts/t480/home.nix`

Same module imports as `hosts/vm/home.nix` (git, zsh, tmux, scripts, hyprland,
noctalia, alacritty) plus `home.username` / `home.homeDirectory` / `home.stateVersion`.

### `modules/nixos/laptop.nix`

```nix
{ ... }:
{
  services.upower.enable               = true;   # noctalia battery widget
  hardware.bluetooth.enable            = true;   # noctalia bluetooth widget
  services.power-profiles-daemon.enable = true;  # noctalia power-profile toggle
}
```

(No TLP — it conflicts with power-profiles-daemon, and the t480 profile doesn't pull it.)

### Install app

A `pkgs.writeShellApplication` exposed as `apps.${system}.install`, taking the
hostname as `$1`:

```sh
host="$1"
disko --mode destroy,format,mount --flake ".#${host}"   # exact disko invocation finalized in plan
mkdir -p /mnt/tmp
TMPDIR=/mnt/tmp nixos-install --flake ".#${host}" --root /mnt \
  --option extra-substituters https://noctalia.cachix.org \
  --option extra-trusted-public-keys noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4=
```

- Decide in the plan: drive disko via `diskoConfigurations.<host>` exposed from
  the flake vs. a path to `hosts/<host>/disko.nix`. `runtimeInputs` includes
  `disko`. `nixos-install` comes from the live environment.
- Works identically for `vm` and `t480` — the RAM/TMPDIR fix is now permanent.

### Install runbook (also for README)

1. Boot the NixOS live ISO; get networking.
2. Clone the repo (e.g. `/tmp/nix-config`) and `cd` in.
3. New machine only: confirm the disk with `lsblk -d`; regenerate
   `hardware-configuration.nix` if needed.
4. `nix run .#install -- t480` (applies TMPDIR + cache automatically).
   **Caution:** disko's `destroy` mode wipes the target disk — confirm `device`
   in `disko.nix` matches the intended drive before running.
5. Set passwords on first boot (`passwd k`).
6. Verify hibernation: `systemctl hibernate`, confirm clean resume.

## Non-goals

- Changing the `vm` host's disk layout.
- NVIDIA / PRIME config (this T480 is Intel-only).
- Fingerprint reader, declarative noctalia `settings`, secrets management — future.

## Open items / notes

- **Optional cosmetic:** `modules/nixos/common.nix` could switch to
  `extra-substituters` / `extra-trusted-public-keys` to match the noctalia docs.
  **Not required** — verified against nixpkgs `nixos-26.05` that plain
  `substituters` merges with `cache.nixos.org` (NixOS adds it via `mkAfter`), so
  the default cache is retained. Left as-is.
- Confirm `lib.mkHost` wiring and that home-manager `useGlobalPkgs` + the
  noctalia overlay (already in `desktop.nix`) make `pkgs.noctalia` resolvable.

## Verification

- `nixos-rebuild build --flake .#t480` (and `nix flake check`) evaluates and
  builds the closure.
- On hardware: install completes pulling from caches (no source build of
  noctalia), boots, LUKS unlock works, `swapon --show` lists the LV, and
  `systemctl hibernate` round-trips cleanly.
