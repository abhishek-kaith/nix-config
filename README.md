# nix-config

Flake-based NixOS configuration. Hosts: `vm` (QEMU). User: `k`.

## Structure

```
flake.nix
lib/default.nix            # mkHost helper
config/                    # native format files (tmux, scripts)
modules/nixos/             # system modules (common, shell)
modules/home/              # home-manager modules (git, zsh, tmux, scripts)
hosts/vm/                  # VM host (disko, hardware, home)
```

---

## Nix Commands

### Check / evaluate config (run from repo root)

```bash
# show flake outputs — quick sanity check
nix flake show

# evaluate and type-check all modules without building
nix flake check

# full build — downloads everything, creates ./result symlink
nix build .#nixosConfigurations.vm.config.system.build.toplevel

# evaluate a specific value (useful for debugging options)
nix eval .#nixosConfigurations.vm.config.networking.hostName
```

### Update inputs

```bash
nix flake update            # update all inputs
nix flake update nixpkgs    # update one input
```

---

## Binary Caches (Cachix)

Binary caches let Nix download pre-built packages instead of compiling from source. Hyprland is the main one you need — it's C++ and slow to compile.

### Set up a cache (one-time, on Arch)

```bash
nix profile add nixpkgs#cachix   # install cachix CLI
cachix use hyprland              # adds cache to ~/.config/nix/nix.conf
```

After this, `nix build` picks up the cache automatically — no extra flags needed.

### How to find the cachix command for a package

1. Check the project's README / NixOS wiki page — most popular packages document it
2. Search at **cachix.org** — every public cache has a page with the exact `cachix use <name>` command
3. Check the flake's `README` or look for a `cachix.yaml` in the repo

### Caches this config uses

| Package   | Cache command          | Why                              |
|-----------|------------------------|----------------------------------|
| Hyprland  | `cachix use hyprland`  | C++ compositor, slow to compile  |
| Noctalia  | `cachix use noctalia`  | C++ shell, slow to compile       |

### Adding a cache permanently to NixOS config

Once you've confirmed a cache works, add it to `modules/nixos/common.nix` so every rebuild uses it:

```nix
nix.settings = {
  substituters      = [ "https://hyprland.cachix.org" ];
  trusted-public-keys = [ "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=" ];
};
```

The key values come from the cachix cache page at `cachix.org/<name>`.

---

## Gotchas & Notes

### Hyprland: don't set `nixpkgs.follows`

```nix
# flake.nix — correct
hyprland.url = "github:hyprwm/Hyprland";
# NO: hyprland.inputs.nixpkgs.follows = "nixpkgs";
```

The cachix cache is built with Hyprland's own pinned nixpkgs. Overriding it changes all dependency hashes → cache miss → compiles from source. Leave it unfollowed.

### Hyprland: two modules, both needed

| Module | File | What it does |
|--------|------|-------------|
| NixOS | `modules/nixos/hyprland.nix` | enables compositor, sets packages, autologin |
| home-manager | `modules/home/hyprland.nix` | places Lua config, sets up Hyprland for user |

Both must set `package` to the same flake package or they'll use different Hyprland versions.

### Hyprland: raw Lua config needs `systemd.enable = false`

The home-manager `wayland.windowManager.hyprland` module expects config via `hyprland.settings`. Since we use a raw `hyprland.lua` file instead, disable its systemd integration to suppress the warning:

```nix
wayland.windowManager.hyprland = {
  enable         = true;
  package        = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
  systemd.enable = false;
};
```

### Build on Arch, copy to VM

Noctalia (C++, no binary cache) needs more RAM than the VM has. Build on Arch, copy the result:

```bash
# on Arch
nix build .#nixosConfigurations.vm.config.system.build.toplevel
nix copy --to ssh://k@<vm-ip> .#nixosConfigurations.vm.config.system.build.toplevel

# sync config + apply
rsync -av --exclude='.git' --filter=':- .gitignore' \
  /home/k/Projects/personal/nix-config/ k@<vm-ip>:~/nix-config/
ssh k@<vm-ip> 'sudo nixos-rebuild switch --flake ~/nix-config#vm'
```

---

## Day-to-day

```bash
# apply config (inside VM)
sudo nixos-rebuild switch --flake ~/nix-config#vm

# roll back
sudo nixos-rebuild --rollback

# copy repo from Arch host to VM
rsync -av --exclude='.git' --filter=':- .gitignore' \
  /home/k/Projects/personal/nix-config/ k@<vm-ip>:~/nix-config/

# garbage collect
nix-collect-garbage -d
```

---

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
4. From the repo root, run the installer (ERASES the target disk). The
   `--extra-experimental-features` flag covers stock ISOs that don't enable
   flakes by default:
   ```sh
   nix --extra-experimental-features 'nix-command flakes' run .#install -- t480
   ```
   It partitions+mounts via disko, sets `TMPDIR=/mnt/tmp` (the live ISO's `/tmp`
   is RAM-backed and overflows on a desktop closure), and runs `nixos-install`
   with the noctalia cache enabled.
5. Reboot, then set your password: `passwd k`.
6. Verify hibernation: `systemctl hibernate`, then power on and confirm resume.
