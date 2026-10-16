{ lib, pkgs, user, ... }:
let
  # KWin loads a script or effect when kwinrc says `<id>Enabled=true` — or, when
  # kwinrc says nothing at all, when the plugin's metadata says EnabledByDefault
  # (kwin src/scripting/scripting.cpp: `value.isNull() ? isEnabledByDefault() : …`).
  # Both plugins below ship `false`, which would mean a trip to System Settings on
  # every fresh install. Flipping the default in a copy of the package brings them
  # up on first login with nothing written to kwinrc, and switching one off in
  # System Settings still sticks: that writes an explicit `false`, which wins.
  #
  # A copy (runCommand) rather than overrideAttrs + postInstall, so this cannot
  # silently do nothing if a package's installPhase stops running its hooks.
  enabledByDefault = pkg: pkgs.runCommand "${pkg.name}-enabled" { nativeBuildInputs = [ pkgs.jq ]; } ''
    cp -r --no-preserve=mode ${pkg} $out
    find $out/share/kwin -name metadata.json | while read -r m; do
      jq '.KPlugin.EnabledByDefault = true' "$m" > "$m.tmp"
      mv "$m.tmp" "$m"
    done
  '';
in
{
  # The SYSTEM half of the desktop-environment layer, KDE Plasma flavour; the user
  # half is modules/home/plasma.nix. It is the drop-in alternative to the
  # cosmic.nix pair (README: "Switch desktop") — a host imports one pair, never
  # both: greeter, autologin, portals and the Secret Service all collide.
  #
  # Plasma comes from the system nixpkgs (26.05: Plasma 6.6), deliberately NOT
  # overlaid from unstable the way COSMIC is. Plasma is Qt all the way down, and
  # pulling it from unstable means a second Qt build in the same session: its
  # platform-theme and style plugins land on the shared plugin path, and the
  # stable Qt apps here (qimgv, keepassxc, …) reject plugins built against a
  # newer Qt, losing their theming. COSMIC is Rust/iced and has no such coupling.
  # Plasma moves when nixpkgs moves to the next release.
  # Everything Plasma stores in ~/.config (kwinrc, kglobalshortcutsrc, panels,
  # theme) is Plasma's own state, edited in System Settings and never managed here.
  services.desktopManager.plasma6.enable = true;

  # Defaults the module installs that this machine already has, or must not have.
  # Removing these is supported: they come from the module's optional list, not
  # its required one.
  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    elisa        # music player — mpv plays audio (modules/home/xdg.nix)
    gwenview     # image viewer — qimgv is the viewer and the mime default
    khelpcenter  # offline handbook browser
    krdp         # an RDP *server*. Nothing here should accept inbound remote
                 # desktop on foreign wifi — same reasoning as no sshd (hosts/t14)
    kwin-x11     # the X11 session; this machine is Wayland-only
  ];

  environment.systemPackages = [
    # Scrolling-column tiling, niri-style, as a KWin script: every window is a
    # column on one horizontal strip, Meta+A/D walks it, Meta+W/S moves within a
    # stacked column. Several of its default keys are already Plasma's;
    # modules/home/plasma.nix frees them and binds Karousel. One known gap:
    # Karousel tiles a single screen only.
    (enabledByDefault pkgs.kdePackages.karousel)
    # Animates windows moved or resized by a script. Without it every Karousel
    # move is an instant jump; upstream recommends the pair.
    (enabledByDefault pkgs.kwin-script-geometry-change)

    # Disk usage as a clickable sunburst — the GUI half of ncdu/duf
    # (packages.nix). Also opens from Dolphin's context menu on any folder.
    pkgs.kdePackages.filelight
  ];

  # ── KDE Connect ──────────────────────────────────────────────────
  # Phone ↔ laptop: notifications, shared clipboard, send files, media and
  # remote input, phone battery in the panel. Pairs with the KDE Connect app
  # (Android / iOS); nothing talks until a device is paired by hand on both
  # ends, and all traffic is TLS.
  #
  # The cost: it opens 1714–1764 TCP+UDP on EVERY interface, and while it runs
  # it announces this laptop's name to the local network — café wifi included.
  # Pairing is still required to do anything, but the name is visible. Drop this
  # line to close the ports again.
  programs.kdeconnect.enable = true;

  # ── session entry: greeter + passwordless autologin ──────────────
  # Same arrangement as cosmic.nix: the disk is already unlocked by a LUKS
  # passphrase in stage 1, so a second password at the greeter adds nothing.
  # SDDM is what the plasma6 module is built around (it sets the Wayland greeter
  # with kwin as its compositor); it is only seen after a logout.
  services.displayManager = {
    sddm.enable = true;
    autoLogin = {
      enable = true;
      inherit user;
    };
  };

  # ── Secret Service: KWallet, not gnome-keyring ───────────────────
  # desktop.nix turns gnome-keyring on as the floor any session needs. Under
  # Plasma that floor is KWallet instead: the module sets up kwallet-pam, and
  # kwallet 6's ksecretd answers the Secret Service API (org.freedesktop.secrets)
  # itself. Running both leaves two daemons racing for that one D-Bus name, and
  # an app that gets the other one finds an empty keyring — Chromium-family
  # browsers then mint a fresh key and lose every saved password and cookie.
  #
  # Nothing in the old ~/.local/share/keyrings is migrated or deleted; it simply
  # stops being read. What lived there must be re-entered once into KWallet
  # (`gh auth login` is the one that matters — gh keeps its token in the keyring).
  #
  # Autologin means no password reaches PAM, so the wallet comes up locked and
  # the first app wanting a secret asks once per login — same as gnome-keyring
  # did under COSMIC. Giving the wallet an empty password when it is created
  # removes even that, at the cost of anything running as you being able to read
  # it (the disk itself stays LUKS-encrypted).
  services.gnome.gnome-keyring.enable = lib.mkForce false;

  # gnome-keyring also brought the SSH agent (gcr-ssh-agent follows it), so that
  # goes too. Plain OpenSSH ssh-agent replaces it; the plasma6 module already
  # points SSH_ASKPASS at ksshaskpass, so a key's passphrase is asked in a
  # Plasma dialog, and AddKeysToAgent keeps it for the rest of the session
  # rather than asking on every `git push`.
  programs.ssh.startAgent = true;
  programs.ssh.extraConfig = ''
    AddKeysToAgent yes
  '';

  # Lid / sleep: PowerDevil takes the lid over from logind while Plasma runs;
  # modules/home/plasma.nix points it at the same suspend-then-hibernate that
  # laptop.nix configures.
}
