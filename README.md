# nix-config

Flake-based NixOS configuration for one laptop and two dev VMs. Everything is
organised so that **shared concerns live in `modules/`** and **per-machine
differences live in `hosts/`**.

| Host   | Platform      | User   |
|--------|---------------|--------|
| `t480` | ThinkPad T480 | `k`    |
| `vkvm` | QEMU/KVM VM   | `kvm`  |
| `vbx`  | VirtualBox VM | `vbox` |

---

## Structure

```
flake.nix                 # inputs, host list, the `install` app
lib/default.nix           # mkHost helper — wires home-manager + specialArgs
config/                   # native-format dotfiles, edited live (see below)

modules/nixos/            # SYSTEM layer — imported by hosts/<h>/default.nix
  base.nix                #   nix settings + gc, locale, console/TTY font, zram, sysctl
  packages.nix            #   system-wide CLI toolbox (network/dev/archive/nix tools)
  network.nix             #   NetworkManager, DNS (Quad9 + Cloudflare, DoT), firewall
  shell.nix               #   zsh, fzf, zoxide, starship (package + shell init)
  desktop.nix             #   audio, fonts, polkit, xdg-portals, gnome-keyring
  niri.nix                #   niri compositor + session entry (TTY1 autologin)
  noctalia.nix            #   noctalia overlay + binary cache + runtime deps
  laptop.nix              #   upower, bluetooth, power-profiles (physical hosts only)

modules/home/             # USER layer — imported by hosts/<h>/home.nix
  git / zsh / tmux / scripts   #   shell + dotfile wiring
  xdg.nix                 #   XDG user dirs + mime defaults
  direnv.nix              #   direnv + nix-direnv
  niri.nix / noctalia.nix #   niri kdl config + noctalia shell (home side)
  alacritty.nix / starship.nix #   terminal + prompt (noctalia-themeable)

hosts/<h>/                # PER-HOST — only what differs between machines
  default.nix             #   hostname, bootloader, users, ssh, quirks + module imports
  disko.nix               #   disk layout (partitioning)
  hardware-configuration.nix   #   generated kernel modules / microcode
  home.nix                #   home-manager imports for this host's user
```

**Where does X go?** Anything hardware- or machine-specific (GPU tools, microcode,
disk layout, guest additions, `hostName`) → `hosts/<h>/`. Anything shared → the
matching `modules/nixos/*` or `modules/home/*` by concern.

---

## Installing a host (from the NixOS live ISO)

1. Boot the live ISO, get networking (`nmtui` / `iwctl`), then clone the repo:
   ```sh
   nix-shell -p git --run 'git clone <repo-url> /tmp/nix-config'
   cd /tmp/nix-config
   ```
2. New machine only: confirm the target disk with `lsblk -d`; if it isn't
   `/dev/nvme0n1`, edit `device` in `hosts/<host>/disko.nix`, and regenerate
   `hosts/<host>/hardware-configuration.nix` with
   `nixos-generate-config --no-filesystems --show-hardware-config`.

### Recommended: one-command installer

```sh
nix --extra-experimental-features 'nix-command flakes' run .#install -- t480
```
This **erases the target disk**, then: partitions + mounts via disko → runs
`nixos-install` (with `TMPDIR=/mnt/tmp` so the RAM-backed ISO `/tmp` doesn't
overflow, and the noctalia cache enabled) → **seeds this repo to `~/nix-config`**
on the new system so the editable configs resolve on first boot. disko will
prompt for the LUKS passphrase during partitioning.

### Manual (the same thing, by hand)

```sh
disko --mode destroy,format,mount --flake .#t480      # partition + mount to /mnt
nixos-install --flake .#t480 --root /mnt --no-root-passwd \
  --option extra-substituters https://noctalia.cachix.org \
  --option extra-trusted-public-keys noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4=
# then copy this repo to /mnt/home/<user>/nix-config yourself
```
There is **no separate home-manager step** — home-manager runs as a NixOS module
(see `lib/default.nix`), so `nixos-install` / `nixos-rebuild` activates the user
config too.

3. Reboot, then set your password — the installer prints the exact command
   (`passwd k` / `passwd kvm` / `passwd vbox`). The bootstrap password is
   `password`; **change it on first login.**
4. `t480` only — verify hibernation: `systemctl hibernate`, power on, confirm resume.

---

## Binary cache (noctalia)

noctalia is a Qt/QML shell that is slow to compile, so we pull it prebuilt. The
cache has to be configured in **two places for two different moments**:

| Where | Whose Nix builds | Covers |
|---|---|---|
| `--option extra-substituters …` in `nix run .#install` | the **live ISO** | the one-time install build (system config isn't on disk yet) |
| `nix.settings` in `modules/nixos/noctalia.nix` | the **installed machine** | every later `nixos-rebuild` |

Both use the same URL + key; keep them in sync. The flake also tracks noctalia's
**`cachix` branch** (not `main`) so the commit you build is guaranteed to be in
the cache — otherwise a rebuild can miss it and compile from source.

**Adding another cache in future:** get the `cachix use <name>` URL + public key
from its page on `cachix.org`, then add them to a module's `nix.settings`
(`extra-substituters` + `extra-trusted-public-keys`). Once it's in the system
config, rebuilds use it automatically — no per-command flags.

---

## Editable configs — the repo must live at `~/nix-config`

Some configs are referenced from the **working tree**, not the nix store, so they
can be edited without a rebuild. `repoDir` in `lib/default.nix` is
`/home/<user>/nix-config`; the installer seeds it automatically (clone it yourself
on an already-running host).

| Config | How it's wired | Reload |
|---|---|---|
| niri | `mkOutOfStoreSymlink` → `~/.config/niri/config.kdl` | instant (niri watches) |
| alacritty | `settings.general.import` of the repo TOML | instant (`live_config_reload`) |
| starship | `mkOutOfStoreSymlink` → `~/.config/starship.toml` | new prompt |
| tmux | `source-file` the repo conf | `prefix + R` |
| git | `[include]` of the repo config | next `git` command |
| zsh | managed `.zshrc` sources `config/zsh/rc.zsh` | new shell |
| scripts | `mkOutOfStoreSymlink` → `~/.scripts/` | live |

noctalia themes alacritty / starship / niri by writing **separate** theme files
these configs import/include — it never edits a nix-managed symlink. `home-manager.backupFileExtension = "hm-bak"` is the safety net for the one case it
still can.

---

## Day-to-day

```bash
# apply config (on the host itself, using its own attr — t480 / vkvm / vbx)
sudo nixos-rebuild switch --flake ~/nix-config#t480

# preview what a rebuild would change (uses nvd, from packages.nix)
nvd diff /run/current-system result

# roll back the last generation
sudo nixos-rebuild --rollback

# update inputs (stay current within 26.05, or bump the input URLs for 26.11)
nix flake update              # everything
nix flake update noctalia     # one input

# quick checks
nix flake check               # evaluate + typecheck all hosts
nix eval .#nixosConfigurations.t480.config.networking.hostName

# garbage collect
nix-collect-garbage -d
```

> `system.stateVersion` / `home.stateVersion` (`26.05`) is a **compatibility marker
> pinned to the install version** — leave it fixed even after upgrading to a newer
> NixOS release.

---

## Configuring common things

**DNS** (`modules/nixos/network.nix`) — Quad9 primary + Cloudflare fallback over
DoT. Change providers via `networking.nameservers` (primary) and
`services.resolved.settings.Resolve.FallbackDNS`. To go back to ISP/DHCP DNS,
delete the `services.resolved` block and set
`networking.networkmanager.dns = "default";`.

**Firewall / ports** (`modules/nixos/network.nix`) — on and default-deny inbound.
Open/close a port by editing the list:
```nix
networking.firewall.allowedTCPPorts = [ 8080 ];   # (or allowedUDPPorts)
```
sshd opens 22 itself; syncthing opens 22000/tcp + 21027/udp via its module.

**Git identity** — not stored in the repo. Set it once per machine:
```bash
git config --global user.name  "Your Name"
git config --global user.email "you@example.com"
```
The rest (rebase-on-pull, autostash, prune, zdiff3, histogram, …) is in
`config/git/config`.

**Syncthing** — web UI at http://127.0.0.1:8384 (localhost only). Add folders /
pair devices there; nix won't overwrite them.

**Keybinds (niri + noctalia)** — `Mod+B` toggle top bar (hidden on login),
`Mod+C` clipboard, `Mod+W` wallpaper picker, `Mod+Space` launcher,
`Print`/`Shift+Print` region/full screenshot → satty.

**Firefox** — default browser, hardened (no telemetry, strict tracking protection,
HTTPS-only) with uBlock Origin + KeePassXC-Browser force-installed. Enable
"Browser Integration" in KeePassXC's settings to complete the KeePassXC link.

**noctalia config** — editable base at `config/noctalia/config.toml` (t480); the
app merges its runtime state (`~/.local/state/noctalia/settings.toml`) on top.
