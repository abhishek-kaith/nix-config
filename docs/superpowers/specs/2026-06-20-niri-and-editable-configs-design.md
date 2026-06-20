# Niri Compositor + Live-Editable Configs — Design

- **Date:** 2026-06-20
- **Status:** Design approved; pending spec review before planning.

## Goal

Replace **Hyprland** with **niri** (scrollable-tiling Wayland compositor) across
both hosts, and convert the repo's **external config files** to live-editable
**out-of-store symlinks** so they can be edited without a `nixos-rebuild` —
with true hot-reload for the apps that support it (niri, alacritty). Adopt a
new alacritty config, enable niri 26.04 blur, and add a small set of
dark/light wallpapers.

## Context

- Flake-based NixOS config. Two hosts (`vm`, `t480`) built via `lib.mkHost`.
  Shared `modules/nixos/*` and `modules/home/*`; per-host `hosts/<host>/*`.
- **Current desktop:** Hyprland from `pkgs-unstable`, wired as a NixOS module
  (`modules/nixos/hyprland.nix`: `programs.hyprland`, autologin, `NIXOS_OZONE_WL`)
  + a home module (`modules/home/hyprland.nix`: places a **raw Lua** config via
  `xdg.configFile."hypr/hyprland.lua".source`, and `exec start-hyprland` on TTY1).
  Config lives at `config/hypr/hyprland.lua`. Shell = **noctalia**; terminal =
  **alacritty**.
- **The store-symlink limitation that motivates this work:** `xdg.configFile.source`
  symlinks `~/.config/...` **into `/nix/store`**, which is read-only. So configs
  cannot be edited in place — you edit the repo source and `nixos-rebuild`. That
  defeats any app's live-reload watcher.
- **Current external-config wiring (all generate into the read-only store):**
  alacritty via `programs.alacritty.settings`; tmux via
  `programs.tmux.extraConfig = readFile config/tmux.conf`; zsh via
  `programs.zsh.initContent`; git via `programs.git.settings`; scripts via
  `home.file.source`.
- **Verified facts (June 2026):**
  - nixpkgs ships `programs.niri.{enable,package}` natively — **no new flake
    input needed**. It also wires portals + graphics. Launch from TTY via
    `exec niri-session`. Config read from `~/.config/niri/config.kdl`, **auto-applied
    on save**.
  - **niri 26.04** (2026-04-25) added **blur** (normal + xray) via the
    `ext-background-effect` protocol; **noctalia already supports that protocol**.
    `pkgs-unstable.niri` is past 26.04 — confirm exact version at build.
  - **alacritty** hot-reloads by default (`general.live_config_reload = true`).

## Decisions

1. **Niri replaces Hyprland entirely** (not kept alongside). `programs.niri` from
   nixpkgs with `package = pkgs-unstable.niri` (mirrors the Hyprland `pkgs-unstable`
   pattern; needed for ≥26.04 blur). Delete the Hyprland modules + `config/hypr/`.
   - *Rejected:* keeping Hyprland files unimported (clutter; git history suffices).

2. **External configs become live-editable out-of-store symlinks.** Each config
   moves to a raw file under `config/` and is placed with
   `config.lib.file.mkOutOfStoreSymlink "${repoDir}/<path>"`, so `~/.config/...`
   points at the **working tree** (writable). Accepted tradeoffs (the whole point
   of the change):
   - **Reproducibility erodes:** the running config = working tree, including
     **uncommitted edits**. "Committed == running" is no longer automatic.
   - **The repo is a runtime dependency:** symlinks dangle if the repo isn't at
     `repoDir`. On a fresh install the desktop falls back to app defaults until
     the repo is cloned to `repoDir`. Mitigations: document in README; make the
     zsh source line tolerant (`[ -f … ] && source …`).
   - *Rejected:* keeping everything in the home-manager DSL (no live edit);
     half-and-half by app (inconsistent mental model).

3. **`repoDir` is a single knob.** Define once in `modules/home/niri.nix` (or a
   tiny shared `modules/home/_repo.nix`) as
   `repoDir = "${config.home.homeDirectory}/nix-config"`. The repo must live there
   at runtime on every host. Default: `~/nix-config`.

4. **Hot-reload reality is per-app, stated honestly:**

   | Config | `config/` file | Reload behavior |
   |---|---|---|
   | niri | `config/niri/config.kdl` | **instant** — niri watches + applies on save |
   | alacritty | `config/alacritty/alacritty.toml` | **instant** — `live_config_reload` default |
   | tmux | `config/tmux.conf` (re-point) | editable; apply via `prefix+R` / `tmux source-file` |
   | git | `config/git/config` | editable; applies on next `git` invocation |
   | zsh | `config/zsh/rc.zsh` | editable; applies in a new shell / `source` |
   | scripts | `config/scripts/*` | live — read fresh on each run |

5. **zsh keeps a thin home-manager `.zshrc`.** Do **not** go fully raw (would lose
   home-manager's zsh plugin/completion integration). home-manager manages a thin
   `.zshrc` whose body becomes
   `[ -f ${repoDir}/config/zsh/rc.zsh ] && source ${repoDir}/config/zsh/rc.zsh`.
   The current `initContent` bindings move verbatim into `config/zsh/rc.zsh`.

6. **Adopt the provided alacritty config** as `config/alacritty/alacritty.toml`
   (raw TOML, kept verbatim): JetBrainsMono Nerd Font Mono size 14, opacity 0.85,
   padding 5, 100k scrollback, vi-mode toggle, Shift+Return→ESC, save-to-clipboard.
   `nerd-fonts.jetbrains-mono` is already installed (`modules/nixos/desktop.nix`).
   `programs.alacritty.enable = true` stays (for the package); `settings` is dropped
   in favor of the raw file. Keep `[general]` present so `live_config_reload` stays on.

7. **Keybinds translated faithfully to niri's column model** (full table in
   Appendix A). Three Hyprland features have **no niri equivalent** and are dropped:
   `Mod+P` pseudotile, decoration `rounding`, `dwindle preserve_split`. Blur replaces
   Hyprland's blur (niri 26.04). Screenshots use niri's built-in `screenshot` /
   `screenshot-screen` — **`grimblast` is removed** from `modules/nixos/common.nix`.

8. **Wallpapers:** add `config/wallpapers/{dark,light}/` with **2 dark + 2 light**
   images (sourced from the internet, permissively licensed). A default wallpaper is
   set at niri startup via `spawn-at-startup` (`swww` or `swaybg`, whichever is
   simpler). Theme-aware dark/light switching is delegated to noctalia **if** it
   exposes wallpaper management; otherwise the default-wallpaper spawn is the
   committed behavior and switching is a follow-up. Wallpapers are committed as
   binary blobs (accepted repo-weight cost).

9. **README updated:** replace the Hyprland section (two-module note, raw-Lua
   `systemd.enable=false` note, **and the entire Hyprland cachix block**) with a
   niri section. niri comes from `cache.nixos.org` via unstable, so **no special
   binary cache is needed** — a net simplification.

10. **`vm` host gets niri too**, but note the QEMU caveat (Decision 11). Both hosts
    swap their compositor imports.

11. **VM cursor caveat (flagged, not solved here):** `hosts/vm/default.nix` sets
    `WLR_NO_HARDWARE_CURSORS`, which is **wlroots-specific**; niri is Smithay-based
    and ignores it. niri generally works under QEMU/virtio-gpu, but this is a
    "verify in the VM" item. Leave the var (harmless) and confirm at test time.

## Architecture / File Changes

**Remove**
- `modules/nixos/hyprland.nix`
- `modules/home/hyprland.nix`
- `config/hypr/hyprland.lua` (and the `config/hypr/` dir)
- `grimblast` from `modules/nixos/common.nix`

**Add**
- `modules/nixos/niri.nix` — `programs.niri.enable = true`,
  `package = pkgs-unstable.niri`, `services.getty.autologinUser = user`,
  `environment.sessionVariables.NIXOS_OZONE_WL = "1"`.
- `modules/home/niri.nix` — defines `repoDir`; out-of-store symlink for
  `niri/config.kdl`; `programs.zsh.profileExtra` execs `niri-session` on TTY1.
- `config/niri/config.kdl` — translated config (Appendix A), blur enabled.
- `config/alacritty/alacritty.toml` — provided config (Decision 6).
- `config/git/config` — raw git config (migrated from `programs.git.settings`).
- `config/zsh/rc.zsh` — current `initContent` bindings.
- `config/wallpapers/{dark,light}/*` — 2 dark + 2 light images.

**Modify**
- `modules/home/alacritty.nix` — drop `settings`, add out-of-store symlink for
  `alacritty/alacritty.toml`; keep `enable`.
- `modules/home/tmux.nix` — replace `extraConfig = readFile …` with out-of-store
  symlink to `config/tmux.conf` (or a thin `.tmux.conf` that `source-file`s it).
- `modules/home/git.nix` — drop `settings`, place `config/git/config` via
  out-of-store symlink at `~/.config/git/config`; keep `enable`.
- `modules/home/zsh.nix` — thin `.zshrc` sources `config/zsh/rc.zsh` (Decision 5).
- `modules/home/scripts.nix` — `home.file` → out-of-store symlink so script edits
  are live.
- `hosts/{t480,vm}/default.nix` — swap `hyprland.nix` import → `niri.nix`.
- `hosts/{t480,vm}/home.nix` — swap `hyprland.nix` import → `niri.nix`.
- `README.md` — niri section replaces Hyprland section; drop Hyprland cachix.

**Untouched**
- `modules/home/noctalia.nix` (noctalia manages its own live settings).
- Dated `docs/superpowers/plans|specs/*` — historical records.

## Testing

- `nix flake check` and `nixos-rebuild build --flake .#t480` / `.#vm` — both must
  evaluate and build.
- Manual (requires a boot, give a checklist):
  - niri starts from TTY1; noctalia bar + blur visible; wallpaper set.
  - Edit `config/niri/config.kdl` → save → niri reloads (no rebuild).
  - Edit `config/alacritty/alacritty.toml` → save → running terminal updates.
  - Keybinds from Appendix A behave as mapped.
  - `vm`: confirm cursor renders under QEMU (Decision 11).

## Out of Scope

- xwayland-satellite (X11 app support) — add later if needed.
- noctalia theme/wallpaper-switching internals beyond "set a default wallpaper".
- Per-monitor niri output config (rely on niri auto-detect for now).

## Appendix A — Keybind Translation (Hyprland → niri)

| Action | Hyprland | niri |
|---|---|---|
| terminal | `Super+Return` exec alacritty | `Mod+Return { spawn "alacritty"; }` |
| close window | `Super+Q` | `Mod+Q { close-window; }` |
| exit session | `Super+Shift+E` | `Mod+Shift+E { quit; }` |
| fullscreen | `Super+F` | `Mod+F { fullscreen-window; }` |
| toggle float | `Super+V` | `Mod+V { toggle-window-floating; }` |
| focus left/right | `Super+H/L` | `focus-column-left` / `focus-column-right` |
| focus up/down | `Super+K/J` | `focus-window-up` / `focus-window-down` |
| move left/right | `Super+Shift+H/L` | `move-column-left` / `move-column-right` |
| move up/down | `Super+Shift+K/J` | `move-window-up` / `move-window-down` |
| (arrows mirror H/J/K/L) | yes | yes |
| workspace 1-9 | `Super+1..9` | `Mod+1..9 { focus-workspace N; }` |
| move to ws 1-9 | `Super+Shift+1..9` | `Mod+Shift+1..9 { move-column-to-workspace N; }` |
| ws scroll | `Super+wheel` | `Mod+WheelScrollDown/Up { focus-workspace-down/up; }` |
| screenshot area | `Super+Shift+S` grimblast | `Mod+Shift+S { screenshot; }` |
| screenshot screen | `Super+S` grimblast | `Mod+S { screenshot-screen; }` |
| lock | `Super+Backspace` noctalia lock | `Mod+Backspace { spawn "noctalia" "lock"; }` |
| drag / resize float | `Super+mouse:272/273` | niri defaults (no explicit bind) |
| autostart | `hyprland.start` → noctalia | `spawn-at-startup "noctalia"` |
| **dropped** | `Super+P` pseudo; `rounding`; `preserve_split` | no niri equivalent |
