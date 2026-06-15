# T480 ThinkPad Host + Install App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an encrypted, hibernation-capable NixOS host for a Lenovo ThinkPad T480 to the existing flake, plus a `nix run .#install -- <host>` app that bakes in the live-ISO TMPDIR/cache workarounds.

**Architecture:** New `hosts/t480/` (disko `LUKS → LVM → 18G swap + btrfs root`, minimal hardware-config, host `default.nix`/`home.nix`) layered on `nixos-hardware`'s `lenovo-thinkpad-t480` profile. A shared `modules/nixos/laptop.nix` carries noctalia's runtime prerequisites; a VM-only Hyprland workaround is moved out of the shared module. The installer is a `writeShellApplication` exposed as a flake app, reused by both hosts.

**Tech Stack:** Nix flakes, NixOS 26.05, disko, LVM-on-LUKS, btrfs, home-manager, nixos-hardware.

**Conventions for this plan:**
- All commands run from the repo root (`/home/k/Projects/personal/nix-config`).
- There is no unit-test framework. The "tests" are Nix evaluation/parse commands:
  - `nix-instantiate --parse <file>` → fast **syntax** check for a single file.
  - `nix eval .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath` → forces **full module evaluation** of a host (no build).
  - `nix eval --raw .#...` → read a specific evaluated option.
- `nix eval` of a NixOS option may need `--no-warn-dirty`; the tree is dirty (uncommitted) during work — that warning is expected and harmless.

---

## File Structure

| File | Responsibility | Action |
|------|----------------|--------|
| `modules/nixos/hyprland.nix` | Shared Hyprland (compositor, autologin, Wayland env) — **remove** VM-only cursor var | Modify |
| `hosts/vm/default.nix` | VM host — **gain** the VM-only cursor var | Modify |
| `modules/nixos/common.nix` | Shared base — **gain** `zramSwap.enable` | Modify |
| `modules/nixos/laptop.nix` | Laptop-only services (upower/bluetooth/power-profiles) for noctalia | Create |
| `flake.nix` | Add `nixos-hardware` input, `t480` host, `install` app | Modify |
| `hosts/t480/disko.nix` | T480 disk layout (LUKS→LVM→swap+btrfs) | Create |
| `hosts/t480/hardware-configuration.nix` | T480 initrd modules (disko owns filesystems) | Create |
| `hosts/t480/home.nix` | T480 home-manager entry (mirrors vm) | Create |
| `hosts/t480/default.nix` | T480 system config | Create |
| `README.md` | Install runbook | Modify |

---

## Task 1: Move the VM-only cursor workaround out of the shared Hyprland module

**Files:**
- Modify: `modules/nixos/hyprland.nix`
- Modify: `hosts/vm/default.nix`

- [ ] **Step 1: Verify current (baseline) state**

Run: `nix eval --raw .#nixosConfigurations.vm.config.environment.sessionVariables.WLR_NO_HARDWARE_CURSORS`
Expected: `1` (it currently comes from the shared module).

- [ ] **Step 2: Remove the VM-only var from the shared module**

In `modules/nixos/hyprland.nix`, change:

```nix
  environment.sessionVariables = {
    NIXOS_OZONE_WL          = "1";  # electron apps use Wayland
    WLR_NO_HARDWARE_CURSORS = "1";  # required in QEMU VM
  };
```

to:

```nix
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";  # electron apps use Wayland
  };
```

- [ ] **Step 3: Add the var to the VM host only**

In `hosts/vm/default.nix`, add this top-level attribute (e.g. just after the `boot.loader` block):

```nix
  # software cursors — required under QEMU; real hardware uses HW cursors
  environment.sessionVariables.WLR_NO_HARDWARE_CURSORS = "1";
```

- [ ] **Step 4: Run tests**

Run: `nix eval --raw .#nixosConfigurations.vm.config.environment.sessionVariables.WLR_NO_HARDWARE_CURSORS`
Expected: `1` (now sourced from the host).

Run: `nix eval --raw .#nixosConfigurations.vm.config.environment.sessionVariables.NIXOS_OZONE_WL`
Expected: `1` (still set by the shared module).

- [ ] **Step 5: Commit**

```bash
git add modules/nixos/hyprland.nix hosts/vm/default.nix
git commit -m "refactor(hyprland): move QEMU software-cursor var to vm host"
```

---

## Task 2: Add zram to the shared base module

**Files:**
- Modify: `modules/nixos/common.nix`

- [ ] **Step 1: Add zram**

In `modules/nixos/common.nix`, add this top-level attribute (e.g. directly after the closing `}` of the `nix = { ... };` block, before `nixpkgs.config.allowUnfree`):

```nix
  # compressed RAM swap — eases memory pressure; coexists with disk hibernation swap
  zramSwap.enable = true;
```

- [ ] **Step 2: Run test**

Run: `nix eval .#nixosConfigurations.vm.config.zramSwap.enable`
Expected: `true`

Run: `nix eval .#nixosConfigurations.vm.config.system.build.toplevel.drvPath`
Expected: a `/nix/store/....drv` path (vm still evaluates cleanly).

- [ ] **Step 3: Commit**

```bash
git add modules/nixos/common.nix
git commit -m "feat(common): enable zram swap on all hosts"
```

---

## Task 3: Create the shared laptop module

**Files:**
- Create: `modules/nixos/laptop.nix`

- [ ] **Step 1: Create the module**

`modules/nixos/laptop.nix`:

```nix
# Laptop-only services. Imported by physical hosts, not the VM.
# These back noctalia's battery / bluetooth / power-profile widgets.
{ ... }:
{
  services.upower.enable                = true;  # battery + power events
  hardware.bluetooth.enable             = true;  # bluetooth radio
  services.power-profiles-daemon.enable = true;  # performance/balanced/saver toggle
  # NOTE: do NOT enable TLP here — it conflicts with power-profiles-daemon.
}
```

- [ ] **Step 2: Run test (syntax)**

Run: `nix-instantiate --parse modules/nixos/laptop.nix`
Expected: prints the parsed expression, no error. (Semantic evaluation happens in Task 9 when the T480 imports it.)

- [ ] **Step 3: Commit**

```bash
git add modules/nixos/laptop.nix
git commit -m "feat(nixos): add laptop module for noctalia prerequisites"
```

---

## Task 4: Add the nixos-hardware flake input

**Files:**
- Modify: `flake.nix`
- Modify: `flake.lock` (generated)

- [ ] **Step 1: Add the input**

In `flake.nix`, inside `inputs = { ... }`, add (after the `noctalia` input):

```nix
    # hardware-specific tuning profiles (e.g. ThinkPad T480)
    nixos-hardware.url = "github:NixOS/nixos-hardware";
```

- [ ] **Step 2: Lock the input**

Run: `nix flake lock`
Expected: `warning: updating lock file ...` and a new `nixos-hardware` entry; exit 0.

- [ ] **Step 3: Run test (nothing broke)**

Run: `nix eval .#nixosConfigurations.vm.config.system.build.toplevel.drvPath`
Expected: a `/nix/store/....drv` path (vm still evaluates with the new input present).

- [ ] **Step 4: Commit**

```bash
git add flake.nix flake.lock
git commit -m "feat(flake): add nixos-hardware input"
```

---

## Task 5: Create the T480 disko layout

**Files:**
- Create: `hosts/t480/disko.nix`

- [ ] **Step 1: Create the disko config**

`hosts/t480/disko.nix`:

```nix
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
```

- [ ] **Step 2: Run test (syntax)**

Run: `nix-instantiate --parse hosts/t480/disko.nix`
Expected: parses, no error.

- [ ] **Step 3: Commit**

```bash
git add hosts/t480/disko.nix
git commit -m "feat(t480): add disko layout (LUKS->LVM->swap+btrfs)"
```

---

## Task 6: Create the T480 hardware-configuration

**Files:**
- Create: `hosts/t480/hardware-configuration.nix`

- [ ] **Step 1: Create the file**

`hosts/t480/hardware-configuration.nix`:

```nix
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
```

- [ ] **Step 2: Run test (syntax)**

Run: `nix-instantiate --parse hosts/t480/hardware-configuration.nix`
Expected: parses, no error.

- [ ] **Step 3: Commit**

```bash
git add hosts/t480/hardware-configuration.nix
git commit -m "feat(t480): add minimal hardware-configuration"
```

---

## Task 7: Create the T480 home-manager entry

**Files:**
- Create: `hosts/t480/home.nix`

- [ ] **Step 1: Create the file** (mirrors `hosts/vm/home.nix`)

`hosts/t480/home.nix`:

```nix
{ ... }:
{
  imports = [
    ../../modules/home/git.nix
    ../../modules/home/zsh.nix
    ../../modules/home/tmux.nix
    ../../modules/home/scripts.nix
    ../../modules/home/hyprland.nix   # lua config, TTY1 exec
    ../../modules/home/noctalia.nix   # noctalia shell
    ../../modules/home/alacritty.nix  # terminal
  ];

  home.username      = "k";
  home.homeDirectory = "/home/k";

  # must match system.stateVersion in hosts/t480/default.nix
  home.stateVersion  = "26.05";
}
```

- [ ] **Step 2: Run test (syntax)**

Run: `nix-instantiate --parse hosts/t480/home.nix`
Expected: parses, no error.

- [ ] **Step 3: Commit**

```bash
git add hosts/t480/home.nix
git commit -m "feat(t480): add home-manager entry"
```

---

## Task 8: Create the T480 system config

**Files:**
- Create: `hosts/t480/default.nix`

- [ ] **Step 1: Create the file** (mirrors `hosts/vm/default.nix`, minus QEMU bits, plus hardware profile + laptop module)

`hosts/t480/default.nix`:

```nix
# inputs comes from specialArgs set in lib/default.nix
{ pkgs, inputs, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t480  # CPU/gfx/SSD/TrackPoint/throttled
    inputs.disko.nixosModules.disko
    ./disko.nix
    ./hardware-configuration.nix
    ../../modules/nixos/common.nix    # timezone, nix settings, zram, base packages
    ../../modules/nixos/shell.nix     # zsh, starship, fzf, zoxide
    ../../modules/nixos/hyprland.nix  # compositor, portals, autologin
    ../../modules/nixos/desktop.nix   # audio, fonts, polkit, noctalia overlay
    ../../modules/nixos/laptop.nix    # upower, bluetooth, power-profiles (noctalia prereqs)
  ];

  networking = {
    hostName = "t480";
    networkmanager.enable = true;
  };

  # systemd-boot: simple UEFI bootloader
  boot.loader = {
    systemd-boot.enable      = true;
    efi.canTouchEfiVariables = true;
  };

  users.users.k = {
    isNormalUser = true;
    extraGroups  = [ "wheel" "networkmanager" ];
    shell        = pkgs.zsh;
    # set password on first boot: passwd k
  };

  security.sudo.wheelNeedsPassword = true;

  # SSH — optional on a laptop; disable PasswordAuthentication if exposed to untrusted networks
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };

  system.stateVersion = "26.05";
}
```

- [ ] **Step 2: Run test (syntax)**

Run: `nix-instantiate --parse hosts/t480/default.nix`
Expected: parses, no error.

- [ ] **Step 3: Commit**

```bash
git add hosts/t480/default.nix
git commit -m "feat(t480): add system config"
```

---

## Task 9: Wire the T480 into the flake (integration point)

**Files:**
- Modify: `flake.nix`

- [ ] **Step 1: Write the failing test**

Run: `nix eval .#nixosConfigurations.t480.config.system.build.toplevel.drvPath`
Expected: **FAIL** — `error: attribute 't480' missing`.

- [ ] **Step 2: Add the host**

In `flake.nix`, change:

```nix
      nixosConfigurations = {
        vm = lib.mkHost { hostname = "vm"; };
      };
```

to:

```nix
      nixosConfigurations = {
        vm   = lib.mkHost { hostname = "vm"; };
        t480 = lib.mkHost { hostname = "t480"; };
      };
```

- [ ] **Step 3: Run the integration test (full evaluation)**

Run: `nix eval .#nixosConfigurations.t480.config.system.build.toplevel.drvPath`
Expected: a `/nix/store/....drv` path — the entire host (disko + nixos-hardware + laptop + home-manager) evaluates.

- [ ] **Step 4: Verify hibernation wiring**

Run: `nix eval --raw .#nixosConfigurations.t480.config.boot.resumeDevice`
Expected: a `/dev/...` device path (disko set it from the swap LV's `resumeDevice = true`). A non-empty path confirms resume is wired.

Run: `nix eval --json .#nixosConfigurations.t480.config.swapDevices`
Expected: JSON containing the swap LV device (non-empty array).

- [ ] **Step 5: Verify the laptop prereqs landed**

Run: `nix eval .#nixosConfigurations.t480.config.services.upower.enable`
Expected: `true`

Run: `nix eval .#nixosConfigurations.t480.config.services.power-profiles-daemon.enable`
Expected: `true`

- [ ] **Step 6: Commit**

```bash
git add flake.nix
git commit -m "feat(flake): add t480 nixos configuration"
```

---

## Task 10: Add the install flake app

**Files:**
- Modify: `flake.nix`

- [ ] **Step 1: Add `pkgs`, the installer, and the app output**

In `flake.nix`, change the `outputs` `let` block from:

```nix
    let
      lib = import ./lib { inherit nixpkgs nixpkgs-unstable inputs; };
    in
```

to:

```nix
    let
      system = "x86_64-linux";
      lib    = import ./lib { inherit nixpkgs nixpkgs-unstable inputs; };
      pkgs   = import nixpkgs { inherit system; };

      # One-command installer: partition+mount via disko, then nixos-install.
      # TMPDIR=/mnt/tmp keeps build scratch on the target disk (the live ISO's
      # /tmp is RAM-backed and overflows on a desktop closure).
      installer = pkgs.writeShellApplication {
        name = "install";
        runtimeInputs = [ pkgs.disko pkgs.nixos-install-tools pkgs.coreutils ];
        text = ''
          host="''${1:-}"
          if [ -z "$host" ]; then
            echo "usage: nix run .#install -- <hostname>" >&2
            exit 1
          fi

          echo ">>> Partitioning + mounting disk for '$host' (this ERASES the target disk)"
          disko --mode destroy,format,mount --flake ".#$host"

          echo ">>> Installing NixOS (TMPDIR on disk to avoid live-ISO RAM exhaustion)"
          mkdir -p /mnt/tmp
          TMPDIR=/mnt/tmp nixos-install --flake ".#$host" --root /mnt \
            --option extra-substituters https://noctalia.cachix.org \
            --option extra-trusted-public-keys noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4=

          echo ">>> Done. Set a password on first boot: passwd k"
        '';
      };
    in
```

Then add this output attribute alongside `nixosConfigurations` (inside the returned `{ ... }`):

```nix
      apps.${system}.install = {
        type    = "app";
        program = "${installer}/bin/install";
      };
```

- [ ] **Step 2: Run test (build the installer — runs shellcheck)**

Run: `nix build --no-link --print-out-paths .#apps.x86_64-linux.install.program`
Expected: a `/nix/store/...` path. `writeShellApplication` runs `shellcheck` at build time, so a passing build means the script is valid. (A shell mistake fails here.)

- [ ] **Step 3: Smoke-test the usage guard (safe — no disk action)**

Run: `nix run .#install`
Expected: prints `usage: nix run .#install -- <hostname>` and exits non-zero. (No `$host` ⇒ it bails before touching any disk.)

- [ ] **Step 4: Commit**

```bash
git add flake.nix
git commit -m "feat(flake): add 'install' app wrapping disko + nixos-install"
```

---

## Task 11: Document the install runbook in the README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Find the install section**

Run: `grep -n "install\|nixos-install\|disko\|## " README.md`
Expected: lists the headings; pick the install/usage section (or add a new `## Installing` section near the top if none exists).

- [ ] **Step 2: Add/replace the install runbook**

Insert this section (adjust the surrounding heading level to match the file):

```markdown
## Installing a host (from the NixOS live ISO)

1. Boot the NixOS live ISO and get networking (`nmtui` or `iwctl`).
2. Clone this repo and enter it:
   ```sh
   nix-shell -p git --run 'git clone <repo-url> /tmp/nix-config'
   cd /tmp/nix-config
   ```
3. New machine only: confirm the target disk with `lsblk -d` and, if it isn't
   `/dev/nvme0n1`, edit `device` in `hosts/<host>/disko.nix`. Regenerate
   `hosts/<host>/hardware-configuration.nix` with
   `nixos-generate-config --no-filesystems --show-hardware-config` if needed.
4. Run the installer (ERASES the target disk):
   ```sh
   nix run .#install -- t480
   ```
   It partitions+mounts via disko, sets `TMPDIR=/mnt/tmp` (the live ISO's `/tmp`
   is RAM-backed and overflows on a desktop closure), and runs `nixos-install`
   with the noctalia cache enabled.
5. Reboot, then set your password: `passwd k`.
6. Verify hibernation: `systemctl hibernate`, then power on and confirm resume.
```

- [ ] **Step 3: Run test (sanity)**

Run: `grep -n "nix run .#install" README.md`
Expected: matches the new runbook line.

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: add live-ISO install runbook"
```

---

## Task 12: Final whole-flake gate

**Files:** none (verification only)

- [ ] **Step 1: Evaluate the whole flake**

Run: `nix flake check`
Expected: no errors. Evaluates both hosts and builds the small `install` app. (This does not build the full system closures.)

- [ ] **Step 2 (optional, heavy — best run on the T480 or a machine with resources): build the closure**

Run: `nixos-rebuild build --flake .#t480`
Expected: builds the toplevel, pulling noctalia from `noctalia.cachix.org` and the rest from `cache.nixos.org` (no source compile of noctalia). Produces a `result` symlink.

---

## Self-Review

**Spec coverage:**
- Hibernation-capable encrypted swap (LUKS→LVM→swap+btrfs) → Task 5 + verified in Task 9 (`boot.resumeDevice`, `swapDevices`). ✓
- Install flake app with TMPDIR + cache → Task 10. ✓
- `nixos-hardware` t480 profile → Task 4 (input) + Task 8 (import). ✓
- Shared `laptop.nix` (upower/bluetooth/power-profiles) → Task 3 + verified Task 9. ✓
- zram in `common.nix` → Task 2. ✓
- `vm` host unchanged in layout (only the cursor var relocates, behavior preserved) → Task 1. ✓
- README runbook → Task 11. ✓
- Non-goal "optional extra-substituters cosmetic" → intentionally not done (noted in spec). ✓

**Placeholder scan:** No TBD/TODO/"handle errors" — every code step shows full content and every command shows expected output. ✓

**Type/name consistency:** host name `t480`, VG `pool`, LUKS mapper `cryptroot`, LV `swap`/`root`, module path `modules/nixos/laptop.nix`, app `apps.x86_64-linux.install` — used identically across Tasks 4–12. The disko `device` (`/dev/nvme0n1`) matches the README's "confirm the disk" caveat. ✓
