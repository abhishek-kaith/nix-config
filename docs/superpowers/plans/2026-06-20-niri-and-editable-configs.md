# Niri Compositor + Live-Editable Configs — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Hyprland with niri across both hosts, and make the repo's external configs live-editable without a rebuild (true hot-reload for niri + alacritty).

**Architecture:** niri is enabled via the native nixpkgs `programs.niri` module (no new flake input), `package = pkgs-unstable.niri` for ≥26.04 blur. A single `repoDir` is threaded through `home-manager.extraSpecialArgs`. Each app's config is referenced from the **working tree at `repoDir`** rather than the read-only nix store: niri + scripts via `mkOutOfStoreSymlink`; alacritty/git/tmux/zsh via each tool's own include/import/source mechanism pointing at the repo path (a refinement over the spec — see Note below). Hyprland's modules + Lua config are deleted.

**Tech Stack:** NixOS flake, home-manager, niri (Smithay/KDL), alacritty (TOML), noctalia (Quickshell shell), swaybg.

> **Note — mechanism refinement vs. spec (Decision 2/4):** The spec said "drop the home-manager DSL, place raw out-of-store symlinks" for alacritty + git. During planning a strictly better mechanism was found: keep the home-manager module enabled but point its include/import at the editable repo file. This avoids a file-collision between the HM-generated config and the symlink at the same path, and keeps the module's package + integration. Result is identical to the spec's intent (editable external file, no rebuild) with less loss. niri + scripts still use real `mkOutOfStoreSymlink` (no HM module writes those paths).

## Global Constraints

- **`user` = `k`**, home `/home/k` on both hosts (existing convention via `lib.mkHost`).
- **`repoDir` = `/home/k/nix-config`** — the working tree MUST live here at runtime on every host, or the editable configs dangle (apps fall back to defaults; zsh `source` is guarded). Document in README.
- **niri from `pkgs-unstable.niri`**, must be **≥ 26.04** (blur). `pkgs-unstable` = `nixpkgs-unstable`.
- **No new flake inputs** — `programs.niri` is native to nixpkgs.
- **noctalia stays** (`modules/home/noctalia.nix` untouched); its cachix substituter config in `modules/nixos/common.nix` stays.
- **Do not touch** dated files under `docs/superpowers/plans|specs/` (historical records).
- Per-task eval test (requires nix with flakes; add `--extra-experimental-features 'nix-command flakes'` if not enabled globally):
  - `nix eval .#nixosConfigurations.t480.config.system.build.toplevel.drvPath`
  - `nix eval .#nixosConfigurations.vm.config.system.build.toplevel.drvPath`
  - Expected: each prints a `/nix/store/….drv` path with no evaluation error.

---

### Task 1: Thread `repoDir` through home-manager

**Files:**
- Modify: `lib/default.nix:23-29`

**Interfaces:**
- Produces: `repoDir` (string `"/home/${user}/nix-config"`) as a home-manager `extraSpecialArg`, consumed by Tasks 3–8 as a module argument `{ repoDir, ... }`.

- [ ] **Step 1: Add `repoDir` to `extraSpecialArgs`**

In `lib/default.nix`, change the `home-manager.extraSpecialArgs` block:

```nix
          home-manager.extraSpecialArgs = {
            inherit inputs user;
            repoDir = "/home/${user}/nix-config";
            pkgs-unstable = import nixpkgs-unstable {
              inherit system;
              config.allowUnfree = true;
            };
          };
```

- [ ] **Step 2: Verify the flake still evaluates**

Run: `nix eval .#nixosConfigurations.t480.config.system.build.toplevel.drvPath`
Expected: prints a `/nix/store/….drv` path (an unused specialArg is harmless).

- [ ] **Step 3: Commit**

```bash
git add lib/default.nix
git commit -m "refactor(lib): thread repoDir through home-manager specialArgs"
```

---

### Task 2: Write the niri config (`config/niri/config.kdl`)

**Files:**
- Create: `config/niri/config.kdl`

**Interfaces:**
- Consumes: the committed wallpaper `config/wallpapers/dark/starfield.jpg` (absolute path `/home/k/nix-config/config/wallpapers/dark/starfield.jpg`).
- Produces: the file Task 3's home module symlinks to `~/.config/niri/config.kdl`.

- [ ] **Step 1: Create the base config**

Create `config/niri/config.kdl`:

```kdl
// niri config — lives in the nix-config repo, symlinked to ~/.config/niri/config.kdl.
// niri watches this file and hot-reloads on save (no rebuild needed).
// Translated from the previous Hyprland Lua config; see git history.

input {
    keyboard {
        xkb {
            layout "us"
        }
    }
    touchpad {
        tap
        natural-scroll
    }
    focus-follows-mouse
}

layout {
    gaps 10
    focus-ring {
        width 2
    }
    border {
        off
    }
}

prefer-no-csd

spawn-at-startup "noctalia"
spawn-at-startup "swaybg" "-i" "/home/k/nix-config/config/wallpapers/dark/starfield.jpg" "-m" "fill"

binds {
    Mod+Return { spawn "alacritty"; }
    Mod+Q { close-window; }
    Mod+Shift+E { quit; }

    Mod+F { fullscreen-window; }
    Mod+V { toggle-window-floating; }

    // focus — vim keys + arrows (H/L = columns, J/K = windows in a column)
    Mod+H { focus-column-left; }
    Mod+L { focus-column-right; }
    Mod+K { focus-window-up; }
    Mod+J { focus-window-down; }
    Mod+Left  { focus-column-left; }
    Mod+Right { focus-column-right; }
    Mod+Up    { focus-window-up; }
    Mod+Down  { focus-window-down; }

    // move
    Mod+Shift+H { move-column-left; }
    Mod+Shift+L { move-column-right; }
    Mod+Shift+K { move-window-up; }
    Mod+Shift+J { move-window-down; }
    Mod+Shift+Left  { move-column-left; }
    Mod+Shift+Right { move-column-right; }
    Mod+Shift+Up    { move-window-up; }
    Mod+Shift+Down  { move-window-down; }

    // workspaces 1-9
    Mod+1 { focus-workspace 1; }
    Mod+2 { focus-workspace 2; }
    Mod+3 { focus-workspace 3; }
    Mod+4 { focus-workspace 4; }
    Mod+5 { focus-workspace 5; }
    Mod+6 { focus-workspace 6; }
    Mod+7 { focus-workspace 7; }
    Mod+8 { focus-workspace 8; }
    Mod+9 { focus-workspace 9; }

    // move column to workspace 1-9
    Mod+Shift+1 { move-column-to-workspace 1; }
    Mod+Shift+2 { move-column-to-workspace 2; }
    Mod+Shift+3 { move-column-to-workspace 3; }
    Mod+Shift+4 { move-column-to-workspace 4; }
    Mod+Shift+5 { move-column-to-workspace 5; }
    Mod+Shift+6 { move-column-to-workspace 6; }
    Mod+Shift+7 { move-column-to-workspace 7; }
    Mod+Shift+8 { move-column-to-workspace 8; }
    Mod+Shift+9 { move-column-to-workspace 9; }

    // workspace scroll with the mouse wheel
    Mod+WheelScrollDown cooldown-ms=150 { focus-workspace-down; }
    Mod+WheelScrollUp   cooldown-ms=150 { focus-workspace-up; }

    // screenshots (niri built-in; replaces grimblast)
    Mod+Shift+S { screenshot; }
    Mod+S { screenshot-screen; }

    // lock (noctalia)
    Mod+BackSpace { spawn "noctalia" "lock"; }
}
```

- [ ] **Step 2: Validate the config syntax**

Run (from repo root): `nix run github:NixOS/nixpkgs/nixos-unstable#niri -- validate -c config/niri/config.kdl`
(If niri is already installed, just `niri validate -c config/niri/config.kdl`.)
Expected: `Config is valid.` (or no error). If a key is rejected, fix it against the installed niri version's docs before continuing.

- [ ] **Step 3: Add the alacritty blur window-rule**

Append to `config/niri/config.kdl` (niri 26.04 blur; noctalia gets blur automatically via the `ext-background-effect` protocol, but alacritty at opacity 0.85 needs this rule):

```kdl
// alacritty is translucent but does not request blur via the protocol —
// give it a blurred backdrop. (niri 26.04+)
window-rule {
    match app-id="Alacritty"
    geometry-corner-radius 8
    clip-to-geometry true
    background-effect {
        blur true
    }
}
```

- [ ] **Step 4: Re-validate**

Run: `nix run github:NixOS/nixpkgs/nixos-unstable#niri -- validate -c config/niri/config.kdl`
Expected: valid. **If `background-effect`/`blur` is rejected** by the installed niri version, this is the one syntax my sources disagreed on — check `Configuration: Window Rules` for the exact key in your niri version and adjust the `window-rule` block. The rest of the config and the noctalia (protocol) blur are unaffected; you may also delete this block and ship without window blur.

- [ ] **Step 5: Commit**

```bash
git add config/niri/config.kdl
git commit -m "feat(niri): add translated niri config with blur + wallpaper"
```

---

### Task 3: Compositor swap — niri in, Hyprland out

This is the atomic switch: create niri's two modules, point both hosts at them, delete the Hyprland modules + Lua config, and drop grimblast. After this task both hosts evaluate with niri and Hyprland is gone.

**Files:**
- Create: `modules/nixos/niri.nix`
- Create: `modules/home/niri.nix`
- Delete: `modules/nixos/hyprland.nix`
- Delete: `modules/home/hyprland.nix`
- Delete: `config/hypr/hyprland.lua`
- Modify: `modules/nixos/common.nix:68` (remove grimblast)
- Modify: `hosts/t480/default.nix:11`, `hosts/vm/default.nix:10`
- Modify: `hosts/t480/home.nix:8`, `hosts/vm/home.nix:8`

**Interfaces:**
- Consumes: `pkgs-unstable`, `user` (NixOS specialArgs); `repoDir`, `config` (home specialArgs from Task 1); `config/niri/config.kdl` (Task 2).
- Produces: `niri-session` on PATH (used by the TTY1 exec); `~/.config/niri/config.kdl` symlink.

- [ ] **Step 1: Create the niri NixOS module**

Create `modules/nixos/niri.nix`:

```nix
{ pkgs, pkgs-unstable, user, ... }:
{
  programs.niri = {
    enable  = true;
    package = pkgs-unstable.niri;  # >= 26.04 for blur
  };

  # TTY1 autologin — zprofile in home/niri.nix execs niri-session
  services.getty.autologinUser = user;

  environment.sessionVariables.NIXOS_OZONE_WL = "1";  # electron apps use Wayland

  # niri has no built-in wallpaper renderer; swaybg sets one (spawn-at-startup in config.kdl)
  environment.systemPackages = [ pkgs.swaybg ];
}
```

- [ ] **Step 2: Create the niri home module**

Create `modules/home/niri.nix`:

```nix
{ config, repoDir, ... }:
{
  # editable + hot-reloading: symlink points at the working tree, not the store.
  # niri watches this file and applies changes on save.
  xdg.configFile."niri/config.kdl".source =
    config.lib.file.mkOutOfStoreSymlink "${repoDir}/config/niri/config.kdl";

  # login shell: exec niri only on TTY1
  programs.zsh.profileExtra = ''
    [ "$(tty)" = "/dev/tty1" ] && exec niri-session
  '';
}
```

- [ ] **Step 3: Point both hosts' NixOS imports at niri**

In `hosts/t480/default.nix`, replace the hyprland import line:

```nix
    ../../modules/nixos/niri.nix     # compositor, portals, autologin
```

In `hosts/vm/default.nix`, replace the hyprland import line:

```nix
    ../../modules/nixos/niri.nix      # compositor, portals, autologin
```

- [ ] **Step 4: Point both hosts' home imports at niri**

In `hosts/t480/home.nix` and `hosts/vm/home.nix`, replace the hyprland import line with:

```nix
    ../../modules/home/niri.nix       # kdl config (out-of-store), TTY1 exec
```

- [ ] **Step 5: Remove grimblast (niri has built-in screenshots)**

In `modules/nixos/common.nix`, delete the line:

```nix
    grimblast  # screenshot: area and fullscreen to clipboard
```

- [ ] **Step 6: Delete the Hyprland modules and Lua config**

```bash
git rm modules/nixos/hyprland.nix modules/home/hyprland.nix config/hypr/hyprland.lua
```

- [ ] **Step 7: Verify both hosts evaluate with niri**

Run:
```bash
nix eval .#nixosConfigurations.t480.config.system.build.toplevel.drvPath
nix eval .#nixosConfigurations.vm.config.system.build.toplevel.drvPath
```
Expected: both print a `/nix/store/….drv` path, no errors (no reference to the deleted hyprland module).

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat(niri): replace Hyprland with niri on both hosts"
```

---

### Task 4: Alacritty — adopt provided config, editable

**Files:**
- Create: `config/alacritty/alacritty.toml`
- Modify: `modules/home/alacritty.nix`

**Interfaces:**
- Consumes: `repoDir` (Task 1).
- Produces: alacritty config imported from `${repoDir}/config/alacritty/alacritty.toml`; alacritty live-reloads it on save.

- [ ] **Step 1: Create the alacritty config (provided verbatim)**

Create `config/alacritty/alacritty.toml`:

```toml
[general]

[window]
opacity = 0.85

[window.padding]
x = 5
y = 5

[scrolling]
history               = 100000
multiplier            = 3

[font]
normal                = { family = "JetBrainsMono Nerd Font Mono", style = "Medium" }
bold                  = { family = "JetBrainsMono Nerd Font Mono", style = "Bold" }
italic                = { family = "JetBrainsMono Nerd Font Mono", style = "Italic" }
bold_italic           = { family = "JetBrainsMono Nerd Font Mono", style = "Bold Italic" }
size                  = 14

[selection]
save_to_clipboard = true

[[keyboard.bindings]]
key = "Space"
mods = "Control|Shift"
action = "ToggleViMode"

[[keyboard.bindings]]
key = "Return"
mods = "Shift"
chars = ""
```

- [ ] **Step 2: Point home-manager's alacritty at the editable file**

Replace the contents of `modules/home/alacritty.nix`:

```nix
{ repoDir, ... }:
{
  programs.alacritty = {
    enable = true;
    # the real config is the editable repo file; alacritty imports it and
    # live-reloads on save (live_config_reload is on by default)
    settings.general.import = [ "${repoDir}/config/alacritty/alacritty.toml" ];
  };
}
```

- [ ] **Step 3: Verify evaluation**

Run: `nix eval .#nixosConfigurations.t480.config.system.build.toplevel.drvPath`
Expected: prints a `/nix/store/….drv` path.

- [ ] **Step 4: Commit**

```bash
git add config/alacritty/alacritty.toml modules/home/alacritty.nix
git commit -m "feat(alacritty): adopt provided config as editable import"
```

---

### Task 5: Git — editable config via include

**Files:**
- Create: `config/git/config`
- Modify: `modules/home/git.nix`

**Interfaces:**
- Consumes: `repoDir` (Task 1).
- Produces: git settings sourced from `${repoDir}/config/git/config` via `[include]`.

- [ ] **Step 1: Create the editable git config (migrated from `settings`)**

Create `config/git/config`:

```ini
[user]
	name = Abhishek Kaith
	email = abhishekkaith76@gmail.com
[init]
	defaultBranch = main
[push]
	autoSetupRemote = true
[pull]
	rebase = false
```

- [ ] **Step 2: Replace `settings` with an include**

Replace the contents of `modules/home/git.nix`:

```nix
{ repoDir, ... }:
{
  programs.git = {
    enable = true;
    # real settings live in the editable repo file; HM only adds an [include]
    includes = [ { path = "${repoDir}/config/git/config"; } ];
  };
}
```

- [ ] **Step 3: Verify evaluation**

Run: `nix eval .#nixosConfigurations.t480.config.system.build.toplevel.drvPath`
Expected: prints a `/nix/store/….drv` path.

- [ ] **Step 4: Commit**

```bash
git add config/git/config modules/home/git.nix
git commit -m "feat(git): move git config to editable include file"
```

---

### Task 6: Tmux — source the editable conf

**Files:**
- Modify: `modules/home/tmux.nix`
- (Uses existing `config/tmux.conf` — no change to its contents.)

**Interfaces:**
- Consumes: `repoDir` (Task 1); existing `config/tmux.conf`.
- Produces: tmux `source-file`s the editable repo conf (apply live with `prefix+R` / `tmux source-file`).

- [ ] **Step 1: Replace `readFile` inlining with a `source-file`**

Replace the contents of `modules/home/tmux.nix`:

```nix
{ repoDir, ... }:
{
  programs.tmux = {
    enable = true;
    # source the editable repo file instead of inlining it at eval time;
    # apply edits with `prefix + R` or `tmux source-file ~/.config/tmux/tmux.conf`
    extraConfig = "source-file ${repoDir}/config/tmux.conf";
  };
}
```

- [ ] **Step 2: Verify evaluation**

Run: `nix eval .#nixosConfigurations.t480.config.system.build.toplevel.drvPath`
Expected: prints a `/nix/store/….drv` path.

- [ ] **Step 3: Commit**

```bash
git add modules/home/tmux.nix
git commit -m "feat(tmux): source editable repo conf instead of inlining"
```

---

### Task 7: Zsh — source an editable rc file

**Files:**
- Create: `config/zsh/rc.zsh`
- Modify: `modules/home/zsh.nix`

**Interfaces:**
- Consumes: `repoDir` (Task 1).
- Produces: home-manager `.zshrc` sources `${repoDir}/config/zsh/rc.zsh` (guarded); apply in a new shell.

- [ ] **Step 1: Create the editable zsh rc (migrated from `initContent`)**

Create `config/zsh/rc.zsh`:

```zsh
# Interactive zsh config — editable; sourced by the home-manager-managed .zshrc.
# Apply changes by opening a new shell (or: source ~/.zshrc).
bindkey -v
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward
bindkey -s '^f' '~/.scripts/tmux-sessionizer\n'
```

- [ ] **Step 2: Replace `initContent` body with a guarded source**

Replace the contents of `modules/home/zsh.nix`:

```nix
{ repoDir, ... }:
{
  programs.zsh = {
    enable    = true;   # tells home-manager to create and manage ~/.zshrc
    # keep the bulk of interactive config in an editable repo file; the guard
    # avoids a broken shell if the repo isn't present at repoDir
    initContent = ''
      [ -f ${repoDir}/config/zsh/rc.zsh ] && source ${repoDir}/config/zsh/rc.zsh
    '';
  };
}
```

- [ ] **Step 3: Verify evaluation**

Run: `nix eval .#nixosConfigurations.t480.config.system.build.toplevel.drvPath`
Expected: prints a `/nix/store/….drv` path.

- [ ] **Step 4: Commit**

```bash
git add config/zsh/rc.zsh modules/home/zsh.nix
git commit -m "feat(zsh): source editable rc.zsh from managed .zshrc"
```

---

### Task 8: Scripts — out-of-store symlink

**Files:**
- Modify: `modules/home/scripts.nix`
- Ensure `config/scripts/tmux-sessionizer` is executable in the repo.

**Interfaces:**
- Consumes: `repoDir`, `config` (Task 1).
- Produces: `~/.scripts/tmux-sessionizer` → editable repo script (edits are live; the `^f` zsh binding runs it).

- [ ] **Step 1: Ensure the repo script is executable**

Run:
```bash
chmod +x config/scripts/tmux-sessionizer
git update-index --chmod=+x config/scripts/tmux-sessionizer 2>/dev/null || true
```
(The symlink preserves the target's mode; the repo file must be `+x`.)

- [ ] **Step 2: Replace the store copy with an out-of-store symlink**

Replace the contents of `modules/home/scripts.nix`:

```nix
{ config, repoDir, ... }:
{
  # editable: symlink to the working tree so script edits take effect immediately
  home.file.".scripts/tmux-sessionizer".source =
    config.lib.file.mkOutOfStoreSymlink "${repoDir}/config/scripts/tmux-sessionizer";
}
```

- [ ] **Step 3: Verify evaluation**

Run: `nix eval .#nixosConfigurations.t480.config.system.build.toplevel.drvPath`
Expected: prints a `/nix/store/….drv` path.

- [ ] **Step 4: Commit**

```bash
git add modules/home/scripts.nix config/scripts/tmux-sessionizer
git commit -m "feat(scripts): symlink tmux-sessionizer from working tree"
```

---

### Task 9: README — niri section, drop Hyprland cachix

**Files:**
- Modify: `README.md` (Hyprland sections around lines 47-114)

**Interfaces:** none (docs only).

- [ ] **Step 1: Remove the Hyprland cachix guidance**

In `README.md`, in the binary-cache section (~lines 47-78), remove the Hyprland-specific cache instructions (the `cachix use hyprland` command, the Hyprland row in the cache table, and the `hyprland.cachix.org` substituter snippet). niri comes from `cache.nixos.org` via unstable — no extra cache needed. Leave the noctalia cache content intact.

- [ ] **Step 2: Replace the Hyprland how-it-works section**

Replace the `### Hyprland: …` subsections (~lines 88-114) with:

```markdown
### niri: two modules, both needed

| Layer | File | Responsibility |
|---|---|---|
| NixOS | `modules/nixos/niri.nix` | enables `programs.niri`, sets `pkgs-unstable.niri`, autologin, swaybg |
| home-manager | `modules/home/niri.nix` | symlinks the editable `config/niri/config.kdl`, execs `niri-session` on TTY1 |

niri is from `pkgs-unstable.niri` (needs ≥ 26.04 for blur) and comes from
`cache.nixos.org` — **no special binary cache required**.

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

**Requirement:** clone this repo to `~/nix-config` on each host. If it's elsewhere,
update `repoDir` in `lib/default.nix`. If the repo is absent, these configs fall
back to app defaults (the zsh source is guarded).
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: replace Hyprland README section with niri + editable configs"
```

---

### Task 10: Full build verification + boot checklist

**Files:** none (verification only).

**Interfaces:** consumes everything above.

- [ ] **Step 1: Build both host closures (heavier than eval)**

Run:
```bash
nix build --no-link .#nixosConfigurations.t480.config.system.build.toplevel
nix build --no-link .#nixosConfigurations.vm.config.system.build.toplevel
```
Expected: both build successfully (pulls niri/swaybg from cache.nixos.org, noctalia from its cachix). No build errors.

- [ ] **Step 2: `nix flake check`**

Run: `nix flake check`
Expected: no errors.

- [ ] **Step 3: Hand the user the boot-time manual checklist**

These require an actual boot/deploy (`nixos-rebuild switch`) and cannot be verified here:
- [ ] niri starts from TTY1 login; noctalia bar appears; wallpaper (`starfield.jpg`) is set.
- [ ] Blur is visible behind the noctalia bar; alacritty (opacity 0.85) shows a blurred backdrop (or the window-rule was dropped per Task 2 Step 4).
- [ ] Keybinds behave (Appendix A of the spec): `Mod+Return` alacritty, `Mod+H/L` column focus, `Mod+J/K` window focus, `Mod+1..9` workspaces, `Mod+Shift+S` screenshot, `Mod+BackSpace` lock.
- [ ] Edit `config/niri/config.kdl` (e.g. change `gaps`), save → niri reloads with no rebuild.
- [ ] Edit `config/alacritty/alacritty.toml` (e.g. change `opacity`), save → running terminal updates.
- [ ] `prefix + R` re-sources tmux; a new shell picks up `rc.zsh` edits.
- [ ] **vm only:** cursor renders correctly under QEMU (spec Decision 11 — `WLR_NO_HARDWARE_CURSORS` does not apply to niri; if the cursor is broken, investigate niri/virtio-gpu cursor handling).

- [ ] **Step 4: Commit (if any verification fixes were made)**

```bash
git add -A && git commit -m "fix: address build/boot verification findings" || echo "nothing to commit"
```

---

## Self-Review

**Spec coverage:** niri replaces Hyprland (T3) ✓; programs.niri from nixpkgs, pkgs-unstable, blur (T2/T3) ✓; out-of-store editability for niri/alacritty/tmux/git/zsh/scripts (T2–T8) ✓; repoDir single knob (T1) ✓; hot-reload reality preserved (mechanism refined, Note) ✓; alacritty provided config (T4) ✓; zsh thin wrapper (T7) ✓; grimblast removed + niri screenshots (T2/T3) ✓; keybind translation (T2, matches spec Appendix A) ✓; wallpapers wired via swaybg (T2/T3; images already committed) ✓; README rewrite incl. dropping Hyprland cachix (T9) ✓; VM cursor caveat (T10) ✓; testing via eval/build/validate (all tasks) ✓. Soft spec item "noctalia wallpaper switching" is explicitly out of scope (swaybg default used) — consistent with spec Out-of-Scope.

**Placeholder scan:** every code/config step contains literal content; no TBD/TODO. The single genuinely version-dependent value (niri blur key) is gated by `niri validate` with an explicit fallback, not left as a placeholder.

**Type/name consistency:** `repoDir` produced in T1 and consumed identically (`{ repoDir, ... }`) in T3–T8. `mkOutOfStoreSymlink` requires `config`, declared in the arg list of T3 (home/niri.nix) and T8 (scripts.nix). niri module arg list matches specialArgs (`pkgs`, `pkgs-unstable`, `user`). app-id `Alacritty` matches the alacritty default. Wallpaper path `/home/k/nix-config/config/wallpapers/dark/starfield.jpg` matches the committed file and `repoDir`.
