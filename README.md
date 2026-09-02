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
  dev.nix                 #   nix-ld, podman, android tools, AI agents, `,` + nix-index
  desktop.nix             #   DE-agnostic floor: audio, fonts, polkit, gnome-keyring
  cosmic.nix              #   THE desktop environment: COSMIC (from unstable) + greeter
  apps.nix                #   GUI apps COSMIC doesn't ship (mpv, qimgv, gimp, satty,
                          #   obs, libreoffice, keepassxc, …)
  syncthing.nix           #   file sync, GUI on localhost:8384
  laptop.nix              #   t480 only: fwupd, lid->hibernate, battery thresholds
  storage.nix             #   t480 only: btrfs scrub, smartd, snapper snapshots

modules/home/             # USER layer — imported by hosts/<h>/home.nix
  git / zsh / tmux / scripts   #   shell + dotfile wiring
  xdg.nix                 #   XDG user dirs + mime defaults
  direnv.nix              #   direnv + nix-direnv
  firefox.nix             #   hardened firefox + forced extensions
  neovim.nix              #   editable nvim config (out-of-store)
  easyeffects.nix         #   mic denoise/AGC chain (t480 only)
  starship.nix            #   prompt (live-editable config)
  gtk-theme-sync.nix      #   old GTK apps follow COSMIC's light/dark switch

hosts/<h>/                # PER-HOST — only what differs between machines
  default.nix             #   hostname, bootloader, users, ssh, quirks + module imports
  disko.nix               #   disk layout (partitioning)
  hardware-configuration.nix   #   generated kernel modules / microcode
  home.nix                #   home-manager imports for this host's user
```

**Where does X go?** Anything hardware- or machine-specific (GPU tools, microcode,
disk layout, guest additions, VM display quirks, `hostName`) → `hosts/<h>/`.
Anything shared → the matching `modules/nixos/*` or `modules/home/*` by concern.

The desktop environment is deliberately **one file, imported once per graphical
host**: `modules/nixos/cosmic.nix`. Nothing else in the repo names COSMIC. To try
a different DE later, write `modules/nixos/<de>.nix` alongside it and change one
import line per host — `desktop.nix` (audio/fonts/keyring) and `apps.nix` stay put.

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
overflow) → **seeds this repo to `~/nix-config`**
on the new system so the editable configs resolve on first boot. disko will
prompt for the LUKS passphrase during partitioning.

### Manual (the same thing, by hand)

```sh
disko --mode destroy,format,mount --flake .#t480      # partition + mount to /mnt
nixos-install --flake .#t480 --root /mnt --no-root-passwd
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

## Desktop environment (COSMIC)

`modules/nixos/cosmic.nix` is the whole desktop layer. Three things in it are
worth knowing:

**Packages come from `nixpkgs-unstable`, the module from stable.** nixos-26.05
ships COSMIC epoch 1.2; unstable is on 1.6. The file overlays the COSMIC packages
(comp, panel, settings, greeter, portal, …) with their unstable versions while the
stable NixOS module keeps doing the session wiring — the same trick the old niri
config used for `pkgs-unstable.niri`. The overlay is an **explicit attr table, not
a `cosmic-*` glob**, so an upstream rename (1.5 renamed `cosmic-applibrary` →
`cosmic-app-library`) fails the build loudly instead of quietly leaving one
package behind at 1.2. (Upstream has tagged epoch 1.7, but nixpkgs has not
packaged it on any branch yet — 1.6 is the current ceiling.) If `nix flake update`
ever errors with a missing
`cosmic-…` attribute, that is this table asking to be updated — nothing is broken.

**Login is passwordless.** `cosmic-greeter` runs on greetd, and
`services.displayManager.autoLogin` makes greetd start the session directly at
boot; the greeter itself is then only the lock screen and the post-logout login.
Consequence: the gnome-keyring is **not** unlocked at boot — there is no password
to unlock it with — so it comes up locked (a greeter login after a logout does
unlock it). Locked is not broken: the first app to request a secret gets a gcr
unlock/create dialog. In practice almost nothing here asks. Firefox does **not**
use the Secret Service (it keeps logins in `logins.json`/`key4.db` in the profile,
and its password manager is disabled anyway — KeePassXC is the store); the one
real consumer is chromium, which uses it for its cookie encryption key and falls
back to plaintext without it.

**One of COSMIC's own apps is excluded**, because this repo already installs a
better-configured equivalent: `cosmic-player` (mpv is the video player and the
video/audio mime handler). It is in the module's optional list rather than its
`corePkgs`, so dropping it is supported. `cosmic-term` is **kept** and is the
terminal — it reads `com.system76.CosmicTheme.*` directly, so light/dark and the
accent follow the desktop with no sync machinery at all, which is why alacritty
and its palette-sync service were dropped. `cosmic-edit` is likewise kept
(otherwise nothing graphical opens a .txt), and so is `networkmanagerapplet` —
its tray icon is dead under COSMIC, but it ships `nm-connection-editor`, the only
GUI here that can configure a VPN or enterprise wifi.

**COSMIC owns theming, keybinds and the wallpaper** — all of it lives in
COSMIC Settings, not in this repo. There is no dotfile to edit and no colour
palette generated at runtime; COSMIC-native and libadwaita apps follow it on
their own. The one exception is plain GTK3, below.

**Adding a binary cache in future:** get the `cachix use <name>` URL + public key
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
| starship | `mkOutOfStoreSymlink` → `~/.config/starship.toml` | new prompt |
| tmux | `source-file` the repo conf | `prefix + r` |
| git | `[include]` of the repo config | next `git` command |
| zsh | managed `.zshrc` sources `config/zsh/rc.zsh` | new shell |
| scripts | `mkOutOfStoreSymlink` → `~/.scripts/` | live |

`home-manager.backupFileExtension = "hm-bak"` is the safety net for when
something outside nix writes to a file home-manager manages: the rebuild moves
the stray file aside instead of aborting with "file would be clobbered".

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
nix flake update                    # everything
nix flake update nixpkgs-unstable   # one input (this is where COSMIC comes from)

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
syncthing opens 22000/tcp + 21027/udp via its module. **The t480 runs no sshd** —
it joins networks it does not control, and `openFirewall` would put :22 on every
interface (see the comment in `hosts/t480/default.nix` for how to re-enable it
key-only). The VMs do run one, on the local host network.

**Flatpak / COSMIC Store** (`modules/nixos/apps.nix`) — Flatpak is on, and the
**Flathub remote is registered declaratively** by the `flatpak-flathub-remote`
systemd unit, so a fresh install comes up with a populated Store instead of an
empty one. Note that `services.flatpak.enable` is also what makes the COSMIC
module ship `cosmic-store` at all — turning Flatpak off removes the Store too.
Check the remote with `flatpak remotes`; add another the same way as the unit does.

**Git identity** — not stored in the repo. Set it once per machine:
```bash
git config --global user.name  "Your Name"
git config --global user.email "you@example.com"
```
The rest (rebase-on-pull, autostash, prune, zdiff3, histogram, …) is in
`config/git/config`.

**Syncthing** — web UI at http://127.0.0.1:8384 (localhost only). Add folders /
pair devices there; nix won't overwrite them.

**Power / lid (t480)** (`modules/nixos/laptop.nix`) — closing the lid suspends,
and after 30 minutes shut it hibernates to the encrypted swap LV and powers off
(`HibernateDelaySec`). Battery charging stops at 80% and does not resume until
75%, which is what keeps a machine that lives on AC from cycling at 100% all day.
COSMIC Settings **cannot** set those thresholds — cosmic-settings 1.6 only renders
the power-profile list — so they are written to sysfs by a small systemd unit.
Going away without a charger? Raise `chargeStart` / `chargeEnd` at the top of that
file to 95/100 and rebuild. Check what is in force with:
```bash
cat /sys/class/power_supply/BAT*/charge_control_{start,end}_threshold
```

**Firmware updates (t480)** — `fwupd` is on, so Lenovo's UEFI and Thunderbolt
updates come from LVFS: `fwupdmgr refresh && fwupdmgr get-updates && fwupdmgr
update`. A UEFI capsule is staged on the ESP and applies during the *next* boot.

**Snapshots (t480)** (`modules/nixos/storage.nix`) — snapper takes hourly
timeline snapshots of `/` and `/home` (`/nix` is excluded: it is reproducible from
this repo and would pin every path `nix.gc` wants to delete).
```bash
snapper -c home list                        # what exists
snapper -c home status 42..43               # what changed between two
snapper -c home undochange 42..43 some/file # put a file back
```
These live on the same disk as the data, so they are an **undo, not a backup** —
they do not survive a dead SSD or a stolen laptop, and syncthing is replication
(it propagates deletions), not a backup either. Off-machine copies are still an
open item. btrfs scrub runs monthly and smartd watches the NVMe; both only report.

**Theming past COSMIC's own apps.** The whole map lives in one place —
`modules/nixos/cosmic.nix` — because the answer differs per toolkit and is easy
to break by accident. The native mechanism is the XDG settings portal
(`org.freedesktop.appearance` → `color-scheme`), which
`xdg-desktop-portal-cosmic` serves with live `SettingChanged`:

| App kind | Follows COSMIC unaided? | Why |
|---|---|---|
| COSMIC / iced | yes | reads `com.system76.CosmicTheme.*` |
| GTK4 + libadwaita | yes | reads the portal |
| **Qt6 ≥ 6.5 (KDE/KF6 apps)** | yes | `libQt6Gui` + the `qxdgdesktopportal` platform theme read the same key |
| firefox / chromium / electron | yes | read the portal |
| flatpaks of the above | yes | the sandbox forces portal use |
| **plain GTK3** | **no** | see below |
| **Qt5** | no | `libQt5Gui` 5.15 has no portal colour-scheme support |

Plain GTK3 has no concept of a colour-scheme *preference* at all: `libgdk-3`
(3.24.52) contains no `org.freedesktop.appearance`, and its only `color-scheme`
symbol is the deprecated GTK2-era colour-*palette* property. Its sole levers are
`gtk-theme-name` and `gtk-application-prefer-dark-theme`, reachable only through
`settings.ini`. GIMP, Meld and `nm-connection-editor` sit in that tier, and no
configuration can make them native — so `modules/home/gtk-theme-sync.nix` runs a
`.path` unit on COSMIC's `is_dark` flag and writes that file (`adw-gtk3` /
`adw-gtk3-dark` for gtk-3.0, prefer-dark only for gtk-4.0), plus the matching
GSettings keys. The theme itself is installed system-wide in `cosmic.nix`, so the
greetd-started session finds it on `XDG_DATA_DIRS`.

Run `gtk-theme-sync` by hand to see what it decided — the one line it prints is
the whole diagnostic. Most GTK apps restyle live; stubborn ones pick it up on
next launch. Accent colour is deliberately *not* reproduced in GTK: adw-gtk3 has
no accent hook, and generating a stylesheet from COSMIC's RON theme is exactly
the fragile-across-epochs machinery this replaced.

**GTK3 flatpaks** need both halves handed into the sandbox, which
`systemd.services.flatpak-gtk3-theme` (cosmic.nix) does: it installs
`org.gtk.Gtk3theme.adw-gtk3{,-dark}` — flatpak then mounts the matching one
automatically — and grants `--filesystem=xdg-config/gtk-{3,4}.0:ro` so GTK inside
the sandbox can read the `settings.ini` that names it. `flatpak override` is
per-installation, so a user-level twin unit covers apps `cosmic-store` installed
into the user installation.

> **Do not set `QT_QPA_PLATFORMTHEME`, `qt.platformTheme` or `qt.style`.** Qt6
> follows COSMIC *because* it falls through to the portal platform theme; naming
> `qt5ct`, `kvantum` or `gtk2` displaces that plugin and breaks the one toolkit
> that needs no help. Leftover `~/.config/Kvantum` and `~/.config/kdeglobals` are
> inert as long as nothing exports that variable.

The terminal needs none of this — `cosmic-term` is COSMIC-native and follows
light/dark and the accent by itself.

**Keybinds, theming, wallpaper, displays** — COSMIC Settings, not this repo.
Keyboard shortcuts are per-user state under `~/.config/cosmic/`; nix does not
manage them, so they survive rebuilds and are not version-controlled.

**Firefox** — default browser, hardened (no telemetry, strict tracking protection,
HTTPS-only) with uBlock Origin + KeePassXC-Browser force-installed. Enable
"Browser Integration" in KeePassXC's settings to complete the KeePassXC link.
