{ config, lib, pkgs, pkgs-unstable, user, ... }:
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
  # This file is the SYSTEM half of the desktop-environment layer; the user half
  # (mime defaults for COSMIC's apps, the GTK3 light/dark sync) is
  # modules/home/cosmic.nix. Every graphical host imports the pair, and nothing
  # else in the repo depends on COSMIC specifically. Swapping DE later = write
  # the same pair for the new one and change two import lines per host.
  nixpkgs.overlays = [
    (_final: _prev: lib.mapAttrs (_stable: unstable: pkgs-unstable.${unstable}) cosmicPackages)
  ];

  services.desktopManager.cosmic.enable = true;

  # 1.5 split the OSD/notification sounds out into their own package. The stable
  # module predates it, so it never adds it — without this, `xdg.sounds.enable`
  # (which the module DOES set, for cosmic-osd) has no theme to find.
  environment.systemPackages = [
    pkgs-unstable.cosmic-sound-theme

    # The GTK3 theme modules/home/cosmic.nix points settings.ini at; see
    # the toolkit section below for why that service has to exist at all.
    #
    # SYSTEM packages rather than home.packages on purpose: GTK finds themes by
    # walking XDG_DATA_DIRS/themes, and the COSMIC session (started by greetd,
    # not by a login shell) inherits NixOS's XDG_DATA_DIRS — which always
    # contains /run/current-system/sw/share — but not home-manager's, which is
    # exported by hm-session-vars.sh that only a shell sources.
    pkgs.adw-gtk3
  ];

  # cosmic-player is in the module's optional list, not `corePkgs`, so excluding
  # it is a supported operation and does not destabilise the session. mpv is the
  # video player and the mime handler for video (modules/home/xdg.nix), so
  # cosmic-player would only ever be a second one.
  #
  # cosmic-term is NOT excluded — it is the terminal. It reads the COSMIC theme
  # directly out of com.system76.CosmicTheme.*, so light/dark and the accent
  # follow the desktop with no sync machinery at all; that is exactly why
  # alacritty and its palette-sync service were dropped.
  #
  # cosmic-edit is likewise kept, though neovim is the real editor: excluding it
  # left the machine with no graphical text editor at all, so opening a .txt or
  # .conf from cosmic-files had nothing to hand it to.
  #
  # networkmanagerapplet is also NOT excluded, though its tray icon is dead weight
  # under COSMIC (cosmic-applets has its own network applet). The package is what
  # ships `nm-connection-editor`, still the only GUI here able to set up a VPN or
  # enterprise 802.1X wifi — COSMIC's own network page cannot.
  environment.cosmic.excludePackages = with pkgs; [ cosmic-player ];

  # ── how light/dark reaches everything that is NOT a COSMIC app ───
  # COSMIC's own theming stops at COSMIC's own apps. Everything else learns that
  # the desktop went dark through the XDG settings portal: xdg-desktop-portal-
  # cosmic answers org.freedesktop.appearance/color-scheme and emits
  # SettingChanged, so all of these follow live with NOTHING configured here.
  #
  #   GTK4 + libadwaita        reads the portal
  #   Qt6 (>= 6.5)             libQt6Gui and the qxdgdesktopportal platform theme
  #                            both read the same key — this is every current
  #                            KDE/KF6 app, keepassxc and qimgv included
  #   Brave Origin / Chromium  read the portal
  #   electron
  #   flatpaks of the above    the sandbox forces portal use
  #
  # Two toolkits cannot be reached that way, and no amount of configuration
  # changes that — they predate the standard:
  #
  #   plain GTK3   has no concept of a colour-scheme *preference* at all.
  #                libgdk-3 (3.24.52) contains no org.freedesktop.appearance, and
  #                its only "color-scheme" symbol is `gtk-color-scheme`, the
  #                deprecated GTK2-era colour-PALETTE property — unrelated. Its
  #                sole levers are gtk-theme-name and
  #                gtk-application-prefer-dark-theme, reachable only through
  #                settings.ini. Writing that file is the entire job of
  #                modules/home/cosmic.nix. GIMP, meld and
  #                nm-connection-editor live in this tier.
  #   Qt5          libQt5Gui (5.15) has neither string. Nothing installed here is
  #                Qt5 today; if a Qt5 app ever appears it needs qt5ct or
  #                Kvantum, which is a separate decision from this file.
  #
  # Rejected as an alternative to that service, so it does not get re-proposed:
  # GDK *does* have portal support (GTK_USE_PORTAL, org.gnome.desktop.interface,
  # SettingChanged), so GTK3 could in principle pull `gtk-theme` over D-Bus. But
  # xdg-desktop-portal-cosmic does not serve the gtk-theme key, and COSMIC never
  # sets it — its "Apply current theme to GNOME apps" toggle resolves to
  # cosmic_theme::model::theme::Theme::gtk_prefer_colorscheme, i.e. it sets the
  # GSettings color-scheme and nothing else. That route therefore needs the same
  # glue, writing dconf instead of a file, plus two extra moving parts.

  # DO NOT set QT_QPA_PLATFORMTHEME here, nor NixOS's `qt.platformTheme` /
  # `qt.style`. Qt6 follows COSMIC *because* it falls through to the portal
  # platform theme; naming qt5ct, kvantum or gtk2 displaces that plugin and
  # breaks the one toolkit that currently needs no help at all. Leftover
  # ~/.config/Kvantum and ~/.config/kdeglobals from earlier desktops are inert
  # as long as nothing exports that variable.

  # ── GTK3 flatpaks ────────────────────────────────────────────────
  # gtk-theme-sync writes the HOST's settings.ini, which a sandboxed app cannot
  # read, and which names a theme the sandbox does not contain. Both halves have
  # to be handed in explicitly:
  #
  #   1. the theme    flatpak mounts org.gtk.Gtk3theme.<name> into the sandbox by
  #                   itself once it is installed, picking <name> off the host's
  #                   GTK theme setting. BOTH variants are installed because
  #                   gtk-theme-sync switches between them by name, not by
  #                   flipping a dark flag on one theme.
  #   2. the setting  --filesystem=xdg-config/gtk-3.0:ro lets GTK inside the
  #                   sandbox read the settings.ini that names it. gtk-4.0 is
  #                   granted too, for GTK4 apps that are not libadwaita and so
  #                   never see the portal's answer.
  #
  # Guarded on services.flatpak.enable (set in modules/nixos/apps.nix, which
  # every graphical host imports) so this file stays importable on its own.
  systemd.services.flatpak-gtk3-theme = lib.mkIf config.services.flatpak.enable {
    description = "Install the adw-gtk3 flatpak theme and grant GTK config access";
    # flatpak-flathub-remote (apps.nix) registers the remote this installs from.
    # `wants` + `after`, deliberately not `requires`: with wait-online off
    # (network.nix) the remote unit can fail on a first boot and then retry itself,
    # and a Requires= would have marked this unit failed at that first attempt
    # with no way to be pulled back in when the remote finally lands. Instead this
    # unit retries on its own the same way — `flatpak install` exits non-zero with
    # no remote or no network, and 30s later it tries again.
    after    = [ "network-online.target" "flatpak-flathub-remote.service" ];
    wants    = [ "network-online.target" "flatpak-flathub-remote.service" ];
    wantedBy = [ "multi-user.target" ];
    startLimitIntervalSec = 0;
    # config.services.flatpak.package, not pkgs.flatpak — same reasoning as the
    # remote unit in apps.nix: it cannot drift from the version actually running.
    path = [ config.services.flatpak.package ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = "30s";
    };
    script = ''
      # Checked by hand rather than with an --if-not-exists style flag, because
      # `flatpak install` on an already-installed ref exits non-zero — which
      # would fail this unit on every boot after the first.
      for theme in adw-gtk3 adw-gtk3-dark; do
        ref="org.gtk.Gtk3theme.$theme"
        if ! flatpak info "$ref" >/dev/null 2>&1; then
          flatpak install --system --noninteractive flathub "$ref"
        fi
      done

      # No app argument = the global override for this installation. Rewrites the
      # same two keys every time, so running it on each boot is a no-op.
      flatpak override --system \
        --filesystem=xdg-config/gtk-3.0:ro \
        --filesystem=xdg-config/gtk-4.0:ro
    '';
  };

  # `flatpak override` is PER-INSTALLATION, so the system override above does not
  # reach an app that cosmic-store put in the user installation. The theme
  # extensions need no such twin — flatpak resolves extensions across
  # installations, so the system copies serve user-installed apps too.
  systemd.user.services.flatpak-gtk3-theme-override = lib.mkIf config.services.flatpak.enable {
    description = "Grant flatpaks read access to the host GTK config (user installation)";
    # default.target, not graphical-session.target: this only writes a file under
    # ~/.local/share/flatpak, and wants to be in place before the first flatpak
    # runs rather than tied to a compositor being up.
    wantedBy = [ "default.target" ];
    path = [ config.services.flatpak.package ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      flatpak override --user \
        --filesystem=xdg-config/gtk-3.0:ro \
        --filesystem=xdg-config/gtk-4.0:ro
    '';
  };

  # ── how to drop all of the above ─────────────────────────────────
  # Written down because it is obvious today and gone in six months. The nix half
  # unwinds by itself: delete the two units and `pkgs.adw-gtk3` here, drop the
  # gtk-theme-sync half of modules/home/cosmic.nix, rebuild.
  # home-manager's startServices defaults to true, so it STOPS the obsolete user
  # units for you; NixOS removes the system one. Keep the toolkit map above even
  # then — it is the record of *why*.
  #
  # What a rebuild will NOT clean up, because nix never owned any of it:
  #
  #   rm -f ~/.config/gtk-3.0/settings.ini ~/.config/gtk-4.0/settings.ini
  #   dconf reset /org/gnome/desktop/interface/gtk-theme
  #   dconf reset /org/gnome/desktop/interface/color-scheme
  #   flatpak override --system --nofilesystem=xdg-config/gtk-3.0 \
  #                             --nofilesystem=xdg-config/gtk-4.0
  #   flatpak override --user   --nofilesystem=xdg-config/gtk-3.0 \
  #                             --nofilesystem=xdg-config/gtk-4.0
  #   flatpak uninstall org.gtk.Gtk3theme.adw-gtk3 org.gtk.Gtk3theme.adw-gtk3-dark
  #
  # `--nofilesystem` rather than `flatpak override --reset`: reset is
  # all-or-nothing per installation and would also wipe overrides set by hand for
  # other apps. It leaves a negative entry rather than deleting the key; if the
  # global override files hold nothing else, deleting them outright is cleaner.
  #
  # Blast radius of dropping it: old GTK3 apps freeze at whatever theme
  # settings.ini last named. Nothing else changes — Qt6, libadwaita and the
  # browsers follow the portal and never depended on any of this.

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
