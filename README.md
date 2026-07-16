# nix-config

Flake-based NixOS configuration.

| Host   | Platform      | User   |
|--------|---------------|--------|
| `vkvm` | QEMU/KVM VM   | `kvm`  |
| `vbx`  | VirtualBox VM | `vbox` |
| `t480` | ThinkPad T480 | `k`    |

## Structure

```
flake.nix
lib/default.nix            # mkHost helper
config/                    # native format files (tmux, scripts)
modules/nixos/             # system modules (common, shell)
modules/home/              # home-manager modules (git, zsh, tmux, scripts)
hosts/vkvm/                # QEMU/KVM host (disko, hardware, home)
hosts/vbx/                 # VirtualBox host
hosts/t480/                # ThinkPad T480 host
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
nix build .#nixosConfigurations.vkvm.config.system.build.toplevel

# evaluate a specific value (useful for debugging options)
nix eval .#nixosConfigurations.vkvm.config.networking.hostName
```

### Update inputs

```bash
nix flake update            # update all inputs
nix flake update nixpkgs    # update one input
```

---

## Binary Caches (Cachix)

Binary caches let Nix download pre-built packages instead of compiling from source.

### Set up a cache (one-time, on Arch)

```bash
nix profile add nixpkgs#cachix   # install cachix CLI
```

After this, `nix build` picks up the cache automatically — no extra flags needed.

### How to find the cachix command for a package

1. Check the project's README / NixOS wiki page — most popular packages document it
2. Search at **cachix.org** — every public cache has a page with the exact `cachix use <name>` command
3. Check the flake's `README` or look for a `cachix.yaml` in the repo

### Caches this config uses

| Package   | Cache command          | Why                              |
|-----------|------------------------|----------------------------------|
| Noctalia  | `cachix use noctalia`  | C++ shell, slow to compile       |

### Adding a cache permanently to NixOS config

Once you've confirmed a cache works, add it to `modules/nixos/common.nix` so every rebuild uses it. The key values come from the cachix cache page at `cachix.org/<name>`.

---

## Gotchas & Notes

### niri: two modules, both needed

| Layer | File | Responsibility |
|---|---|---|
| NixOS | `modules/nixos/niri.nix` | enables `programs.niri`, sets `pkgs-unstable.niri`, autologin |
| home-manager | `modules/home/niri.nix` | symlinks the editable `config/niri/config.kdl`, execs `niri-session` on TTY1 |

niri is from `pkgs-unstable.niri` (needs ≥ 26.04 for blur) and comes from
`cache.nixos.org` — **no special binary cache required**. noctalia (the shell)
is started from `config/niri/config.kdl` and manages the wallpaper itself; its
keybinds use `noctalia msg <command>` per the
[noctalia v5 niri docs](https://docs.noctalia.dev/v5/compositor-settings/niri).

### Editable configs: the repo must live at `~/nix-config`

The external configs are referenced from the **working tree**, not the nix store,
so they can be edited without a rebuild:

| Config | How it's wired | Reload |
|---|---|---|
| niri | `mkOutOfStoreSymlink` → `~/.config/niri/config.kdl` | instant (niri watches) |
| alacritty | `settings.general.import` of the repo TOML | instant (`live_config_reload`) |
| tmux | `source-file` the repo conf | `prefix + R` |
| git | `[include]` of the repo config | next `git` command |
| zsh | managed `.zshrc` sources `config/zsh/rc.zsh` | new shell |
| scripts | `mkOutOfStoreSymlink` → `~/.scripts/` | live |

**How it gets there:** the installer (`nix run .#install`) seeds this repo into
`~/nix-config` on the new system automatically, so a fresh install boots with
these already wired up. For an already-running host, clone it to `~/nix-config`
yourself. `repoDir` in `lib/default.nix` is `/home/<user>/nix-config` (the user
differs per host — `kvm`, `vbox`, `k`); if the repo is absent, these configs fall
back to app defaults (the zsh source is guarded).

### Build on Arch, copy to a VM

Noctalia (C++, no binary cache) needs more RAM than the VM has. Build on Arch, copy
the result (example uses the `vkvm` host / `kvm` user — swap for `vbx`/`vbox`):

```bash
# on Arch
nix build .#nixosConfigurations.vkvm.config.system.build.toplevel
nix copy --to ssh://kvm@<vm-ip> .#nixosConfigurations.vkvm.config.system.build.toplevel

# sync config + apply
rsync -av --exclude='.git' --filter=':- .gitignore' \
  /home/k/Projects/personal/nix-config/ kvm@<vm-ip>:~/nix-config/
ssh kvm@<vm-ip> 'sudo nixos-rebuild switch --flake ~/nix-config#vkvm'
```

---

## Day-to-day

```bash
# apply config (on the host itself; use its own flake attr — vkvm/vbx/t480)
sudo nixos-rebuild switch --flake ~/nix-config#vkvm

# roll back
sudo nixos-rebuild --rollback

# copy repo from Arch host to a VM (example: vkvm / kvm)
rsync -av --exclude='.git' --filter=':- .gitignore' \
  /home/k/Projects/personal/nix-config/ kvm@<vm-ip>:~/nix-config/

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
4. From the repo root, run the installer for your target host — `t480` below,
   `vkvm` for the QEMU/KVM VM, or `vbx` for VirtualBox. This **ERASES the target
   disk**. The
   `--extra-experimental-features` flag covers stock ISOs that don't enable
   flakes by default:
   ```sh
   nix --extra-experimental-features 'nix-command flakes' run .#install -- t480
   ```
   It partitions+mounts via disko, sets `TMPDIR=/mnt/tmp` (the live ISO's `/tmp`
   is RAM-backed and overflows on a desktop closure), and runs `nixos-install`
   with the noctalia cache enabled. During partitioning, disko prompts you to
   set the LUKS disk-encryption passphrase — choose a strong one; you'll enter
   it on every boot.
5. Reboot, then set your password — the installer prints the exact command for
   the host's user (e.g. `passwd kvm`, `passwd vbox`, or `passwd k`).
6. `t480` only — verify hibernation: `systemctl hibernate`, then power on and
   confirm resume. (VMs don't hibernate.)
