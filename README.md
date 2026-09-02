# nix-config

Flake-based NixOS for one laptop and two dev VMs. Shared concerns live in
`modules/`, per-machine differences in `hosts/`, and the deep "why" of every
setting is a comment next to it in the module — this file is the map and the
commands.

| Host   | Platform      | User   |
|--------|---------------|--------|
| `t480` | ThinkPad T480 | `k`    |
| `vkvm` | QEMU/KVM VM   | `kvm`  |
| `vbx`  | VirtualBox VM | `vbox` |

## Layout

```
flake.nix               inputs, host list, the `install` app
lib/default.nix         mkHost — wires home-manager + specialArgs (pkgs-unstable, repoDir)
config/                 native dotfiles (nvim, tmux, zsh, git, starship, scripts) — edited live

modules/nixos/          SYSTEM layer, imported by hosts/<h>/default.nix
  base.nix                nix settings/gc, locale, console, boot, zram, earlyoom, sysctl
  network.nix             NetworkManager, DNS (Quad9 + Cloudflare, DoT), firewall
  packages.nix / dev.nix  CLI toolbox / nix-ld, podman, AI agents, runtimes
  shell.nix               zsh, fzf, zoxide, starship
  desktop.nix             DE-agnostic floor: audio, fonts, polkit, keyring
  cosmic.nix              THE desktop (system half): COSMIC from unstable, greeter, GTK glue
  apps.nix                GUI apps COSMIC lacks (mpv, qimgv, gimp, …), flatpak + Flathub
  syncthing.nix           file sync, UI on localhost:8384
  laptop.nix              t480: fwupd, lid → suspend-then-hibernate, battery thresholds
  storage.nix             t480: btrfs scrub, smartd, snapper

modules/home/           USER layer, imported by hosts/<h>/home.nix
  git / zsh / tmux / starship / neovim / scripts / direnv / firefox / easyeffects
  xdg.nix                 user dirs (+ ~/Projects/{work,personal}), DE-agnostic mime defaults
  cosmic.nix              THE desktop (user half): COSMIC mime defaults, GTK3 light/dark sync

hosts/<h>/              hostname, bootloader, user, ssh, VM quirks, disko, hardware-config
```

## Install (from the NixOS live ISO)

```sh
nix-shell -p git --run 'git clone <repo-url> /tmp/nix-config' && cd /tmp/nix-config
lsblk -d      # new machine: fix `device` in hosts/<h>/disko.nix if it is not /dev/nvme0n1,
              # and regenerate hosts/<h>/hardware-configuration.nix:
              #   nixos-generate-config --no-filesystems --show-hardware-config
nix --extra-experimental-features 'nix-command flakes' run .#install -- t480
```

**This erases the target disk.** It partitions via disko (asks for the LUKS
passphrase), runs `nixos-install` with `TMPDIR` on disk (the ISO's `/tmp` is RAM
and overflows), and seeds this repo to `~/nix-config` so the live-edited configs
resolve on first boot. home-manager is a NixOS module — there is no separate
home-manager step, ever.

**First boot**
```sh
passwd                                          # bootstrap password is `password`
git config --global user.name  "Your Name"      # identity is not in the repo
git config --global user.email "you@example.com"
systemctl hibernate                             # t480: confirm resume works once
```
Then in KeePassXC → Settings → Browser Integration → enable, to finish the
Firefox link (the extension itself is force-installed).

## Day-to-day

```sh
sudo nixos-rebuild switch --flake ~/nix-config#t480   # apply (use the host's own attr)
nixos-rebuild build --flake ~/nix-config#t480 && nvd diff /run/current-system result
sudo nixos-rebuild --rollback                          # or hold Space at boot for the menu

nix flake update                     # all inputs
nix flake update nixpkgs-unstable    # just COSMIC's source
nix flake check                      # evaluate every host — run before switch
nix-collect-garbage -d

systemd-analyze && systemd-analyze critical-chain     # before tuning boot, measure
gtk-theme-sync                                        # what the GTK3 sync decided
```

`system.stateVersion` / `home.stateVersion` stay at `26.05` forever — they are an
install-time marker, not the NixOS version.

Rebuilds never touch your data: home-manager manages only the files it linked,
directories it created (`~/Projects/{work,personal}`, `~/Pictures/Screenshots`, …)
are `mkdir -p` and never removed. Anything under `~/.config/cosmic/` (keybinds,
wallpaper, theme) is COSMIC's own state — not managed, survives rebuilds, not in
git.

## How this repo grows

No enable-flags, no profiles, no `mkIf hostName`. A host *is* its import list;
a little duplication between hosts is the price of reading one file and knowing
what a machine does.

- **Shared concern** → `modules/nixos/<concern>.nix` or `modules/home/<concern>.nix`,
  then one import line in each host that wants it. About a *kind* of machine
  (`laptop.nix`) → `modules/`; about *this* machine → `hosts/<h>/`.
- **New host** → copy the nearest `hosts/<h>/`, change the `nixos-hardware` line
  (e.g. `lenovo-thinkpad-t14-amd-gen1`), `disko.nix`, `hardware-configuration.nix`
  and `hostName`; add one line to `flake.nix`. `laptop.nix` is generic ThinkPad
  sysfs — nothing else is hardware-specific. Asahi/aarch64 =
  `mkHost { system = "aarch64-linux"; }` + that platform's input. A macOS machine
  would be nix-darwin reusing `modules/home/` only — fine, because home imports
  are explicit per host.
- **Switch desktop** (KDE, niri, Hyprland…) → write the pair
  `modules/nixos/<de>.nix` + `modules/home/<de>.nix` and flip two import lines.
  One DE per host — greeter, autologin, portals and theming collide. Try it on a
  VM host first.
- **Personal, not machine** (prompt, editor, scripts) → `config/`, no rebuild.

## Live-edited configs

`repoDir` (`lib/default.nix`) is `~/nix-config`; these read the working tree:

| Config   | Wiring                                   | Reload            |
|----------|------------------------------------------|-------------------|
| nvim     | out-of-store symlink → `~/.config/nvim`  | restart nvim      |
| starship | out-of-store symlink                     | new prompt        |
| tmux     | `source-file` the repo conf              | `prefix + r`      |
| zsh      | managed `.zshrc` sources `config/zsh/`   | new shell         |
| git      | `[include]` of `config/git/config`       | next `git`        |
| scripts  | out-of-store symlink → `~/.scripts/`     | live              |

If something outside nix overwrote a managed file, the rebuild moves it aside as
`*.hm-bak` instead of failing.

## Where to look

| Want to…                                  | Read / edit                                   |
|-------------------------------------------|-----------------------------------------------|
| change DNS, open a port                    | `modules/nixos/network.nix`                   |
| re-enable sshd on the laptop (key-only)    | comment in `hosts/t480/default.nix`           |
| battery thresholds, lid behaviour          | `modules/nixos/laptop.nix` (`chargeStart/End`) |
| firmware updates                           | `fwupdmgr refresh && fwupdmgr get-updates && fwupdmgr update` |
| undo a file change (t480)                  | `snapper -c home list` / `undochange N..M path` — an undo, **not a backup** |
| why GTK3/Qt/flatpak theming works the way it does | `modules/nixos/cosmic.nix` (toolkit map) |
| bump COSMIC, or a `cosmic-*` attr errors   | the overlay table in `modules/nixos/cosmic.nix` |
| add a binary cache                         | `nix.settings.extra-substituters` + `extra-trusted-public-keys` in `base.nix` |
| nix builds hogging the desktop             | `nix.daemon*Sched*` in `base.nix` (already batch/low-I/O); cap with `max-jobs` per host |
| a runaway agent/browser ate all the RAM    | `journalctl -u earlyoom` says what it killed and why |
