{ lib, pkgs, user, ... }:
let
  konveyor = pkgs.callPackage ../../pkgs/konveyor.nix { };
in
{
  # The SYSTEM half of the desktop-environment layer, KDE Plasma flavour; the user
  # half is modules/home/plasma.nix. It is the drop-in alternative to the
  # cosmic.nix pair (README: "Switch desktop") — a host imports one pair, never
  # both: greeter, autologin, portals and the Secret Service all collide.
  #
  # Plasma comes from the host's own nixpkgs, never overlaid from unstable the
  # way COSMIC is. Plasma is Qt all the way down, and pulling it from a second
  # nixpkgs means a second Qt build in the same session: its platform-theme and
  # style plugins land on the shared plugin path, and Qt apps from the first
  # nixpkgs (qimgv, keepassxc, …) reject plugins built against a newer Qt and
  # lose their theming. COSMIC is Rust/iced and has no such coupling. A host
  # that needs a newer Plasma moves whole — t14 is `channel = "unstable"` in
  # flake.nix for exactly this (Konveyor, below, needs KWin 6.7).
  # Everything Plasma stores in ~/.config (kwinrc, kglobalshortcutsrc, panels,
  # theme) is Plasma's own state, edited in System Settings and never managed
  # here; the few keys that are managed live in modules/home/plasma.nix.
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

  # Konveyor builds against this nixpkgs' KWin and needs >= 6.7. Without this,
  # importing the module on a stable 26.05 host (Plasma 6.6) fails deep inside
  # a CMake log instead of saying why.
  assertions = [{
    assertion = lib.versionAtLeast pkgs.kdePackages.kwin.version "6.7";
    message = "modules/nixos/plasma.nix: Konveyor needs KWin >= 6.7, this host has ${pkgs.kdePackages.kwin.version}. Build the host with `channel = \"unstable\";` in flake.nix, or wait for a release that ships Plasma 6.7.";
  }];

  environment.systemPackages = [
    # Scrolling-column tiling, niri-style: every window is a column on one
    # endless horizontal row, with workspaces stacked above and below. A native
    # KWin effect (pkgs/konveyor.nix), switched on by default there. Configured
    # by ~/.config/konveyor/config.kdl — the vim binds — which
    # modules/home/plasma.nix links to config/konveyor/config.kdl in this repo.
    # It takes any KDE shortcut its binds need away from Plasma by itself, and
    # gives them back if it is ever removed.
    #
    # Not installed: upstream's optional "Konveyor widgets" (taskbar, Kontrol
    # Panel launcher, monitors). They live in a git submodule and swap out
    # Plasma's own launcher; the tiling is complete without them.
    #
    # Also not granted: the `input` group. Konveyor reads raw /dev/input only
    # for 3/4/5-finger touchpad *taps* (swipes and pinches work without it), and
    # that group lets any process running as you read every keystroke.
    konveyor

    # Title bars hidden on every window, Meta+T toggles them all (a KWin
    # script; see the package for why it is on with nothing in kwinrc).
    (pkgs.callPackage ../../pkgs/titlebar-toggle { })

    # The top bar's workspace numbers (the panel is in modules/home/plasma.nix).
    (pkgs.callPackage ../../pkgs/workspace-indicator { })

    # Disk usage as a clickable sunburst — the GUI half of ncdu/duf
    # (packages.nix). Also opens from Dolphin's context menu on any folder.
    pkgs.kdePackages.filelight
  ];

  # The Plasma UI font (modules/home/plasma.nix sets it). System-wide, beside
  # desktop.nix's, so Qt, GTK and the browser all resolve the same family.
  fonts.packages = [ pkgs.inter ];

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
