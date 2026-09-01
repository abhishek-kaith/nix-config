{ lib, pkgs, pkgs-unstable, user, ... }:
let
  # ── COSMIC packages from nixpkgs-unstable ────────────────────────
  # nixos-26.05 ships COSMIC epoch 1.2; unstable is on 1.6. The NixOS *module*
  # stays the stable one (it drives the whole session wiring), so we only swap
  # the PACKAGES underneath it with an overlay — the same trick the old niri.nix
  # used with `pkgs-unstable.niri`.
  #
  # The mapping is spelled out attr-by-attr on purpose instead of globbing
  # `cosmic-*`. Upstream renames things between epochs (1.5 renamed
  # `cosmic-applibrary` → `cosmic-app-library`), and with an explicit table a
  # rename fails eval LOUDLY here, instead of silently leaving that one package
  # behind at 1.2 while every other piece of the session moved on — which is
  # exactly the kind of skew that makes a compositor half-work.
  #
  #   left  = attribute the stable NixOS module asks for
  #   right = attribute that provides it in unstable
  cosmicPackages = {
    # core — the module refuses to be sensible without these
    cosmic-applets            = "cosmic-applets";
    cosmic-applibrary         = "cosmic-app-library";  # renamed upstream in 1.5
    cosmic-bg                 = "cosmic-bg";
    cosmic-comp               = "cosmic-comp";
    cosmic-files              = "cosmic-files";
    cosmic-greeter            = "cosmic-greeter";
    cosmic-idle               = "cosmic-idle";
    cosmic-initial-setup      = "cosmic-initial-setup";
    cosmic-launcher           = "cosmic-launcher";
    cosmic-notifications      = "cosmic-notifications";
    cosmic-osd                = "cosmic-osd";
    cosmic-panel              = "cosmic-panel";
    cosmic-session            = "cosmic-session";
    cosmic-settings           = "cosmic-settings";
    cosmic-settings-daemon    = "cosmic-settings-daemon";
    cosmic-workspaces-epoch   = "cosmic-workspaces-epoch";
    # apps + assets shipped alongside the session
    cosmic-edit               = "cosmic-edit";
    cosmic-icons              = "cosmic-icons";
    cosmic-player             = "cosmic-player";
    cosmic-randr              = "cosmic-randr";
    cosmic-reader             = "cosmic-reader";
    cosmic-screenshot         = "cosmic-screenshot";
    cosmic-store              = "cosmic-store";
    cosmic-term               = "cosmic-term";
    cosmic-wallpapers         = "cosmic-wallpapers";
    # must move in lockstep with cosmic-comp — they speak the same private
    # wayland protocols, so a mixed pair breaks screencast / file pickers
    xdg-desktop-portal-cosmic = "xdg-desktop-portal-cosmic";
    pop-launcher              = "pop-launcher";  # cosmic-launcher's search backend
    pop-icon-theme            = "pop-icon-theme";
  };
in
{
  # This file is THE desktop-environment layer: it is imported by every graphical
  # host in place of a compositor module, and nothing else in the repo depends on
  # COSMIC specifically. Swapping DE later = write modules/nixos/<de>.nix and
  # change one import line per host.
  nixpkgs.overlays = [
    (_final: _prev: lib.mapAttrs (_stable: unstable: pkgs-unstable.${unstable}) cosmicPackages)
  ];

  services.desktopManager.cosmic.enable = true;

  # 1.5 split the OSD/notification sounds out into their own package. The stable
  # module predates it, so it never adds it — without this, `xdg.sounds.enable`
  # (which the module DOES set, for cosmic-osd) has no theme to find.
  environment.systemPackages = [ pkgs-unstable.cosmic-sound-theme ];

  # Both of these are in the module's optional list, not `corePkgs`, so excluding
  # them is a supported operation and does not destabilise the session.
  #
  #   cosmic-player — mpv is the video player and the mime handler for video
  #                   (modules/home/xdg.nix), so this is a second one.
  #   cosmic-term   — alacritty is the terminal, configured and themed in this
  #                   repo. Safe to drop only because modules/home/xdg.nix now
  #                   sets x-scheme-handler/terminal: cosmic-files resolves
  #                   "Open in Terminal" by asking xdg-mime for that handler and
  #                   only falls back to com.system76.CosmicTerm when it is unset.
  #                   It spawns the terminal with the folder as the working
  #                   directory rather than as an argument, so alacritty — whose
  #                   .desktop Exec takes no field codes — lands in the right place.
  #
  # cosmic-edit is deliberately NOT excluded, though neovim is the real editor:
  # excluding it left the machine with no graphical text editor at all, so opening
  # a .txt or .conf from cosmic-files had nothing to hand it to.
  #
  # networkmanagerapplet is also NOT excluded, though its tray icon is dead weight
  # under COSMIC (cosmic-applets has its own network applet). The package is what
  # ships `nm-connection-editor`, still the only GUI here able to set up a VPN or
  # enterprise 802.1X wifi — COSMIC's own network page cannot.
  environment.cosmic.excludePackages = with pkgs; [ cosmic-player cosmic-term ];

  # ── session entry: greeter + passwordless autologin ──────────────
  # Replaces the old getty-autologin + `exec niri` from .zprofile. cosmic-greeter
  # runs on greetd; with autoLogin set, greetd's `initial_session` starts the
  # COSMIC session directly at boot and the greeter is only used for the lock
  # screen and for logging back in after a logout.
  services.displayManager = {
    cosmic-greeter.enable = true;
    autoLogin = {
      enable = true;
      inherit user;
    };
  };

  # NOT set here: security.pam.services.greetd.enableGnomeKeyring. The greetd
  # module already defaults it to services.gnome.gnome-keyring.enable, which the
  # COSMIC module turns on — so writing it out changed nothing.
  #
  # What it means with autologin: the boot path has no password, so PAM cannot
  # unlock the keyring and it comes up LOCKED (logging in through the greeter
  # after a logout does unlock it). Locked is not broken — the first app to ask
  # for a secret gets a gcr unlock/create dialog, and gcr is in the closure and
  # D-Bus-activatable. In practice almost nothing here asks: chromium wants it for
  # its cookie "safe storage" key and falls back to plaintext without it, and
  # KeePassXC — the actual password store — does not use the Secret Service at all.
}
