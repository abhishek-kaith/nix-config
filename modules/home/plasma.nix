{ config, inputs, lib, pkgs, repoDir, ... }:
{
  # The USER half of the Plasma layer; modules/nixos/plasma.nix is the system
  # half. Shorter than modules/home/cosmic.nix because Plasma solves the hard
  # part of that file itself: kde-gtk-config (from the plasma6 module) rewrites
  # GTK2/3/4 settings.ini and the GSettings keys whenever the Plasma colour
  # scheme changes, so old GTK3 apps follow light/dark with no sync service.

  imports = [ inputs.plasma-manager.homeModules.plasma-manager ];

  # plasma-manager writes only the keys declared below into Plasma's *rc files,
  # at every activation (overrideConfig stays false). Everything else — panels,
  # theme, wallpaper, every shortcut not named here — stays Plasma's, edited in
  # System Settings. A key named here wins over a GUI edit on the next rebuild,
  # so change these HERE, not in System Settings.
  programs.plasma.enable = true;

  # ── Konveyor: the tiling config ──────────────────────────────────
  # Out-of-store, like nvim and starship: ~/.config/konveyor/config.kdl IS
  # config/konveyor/config.kdl in this repo, so a save is live immediately
  # (Konveyor watches the file) with no rebuild. Konveyor's settings page edits
  # the same file through the link — Qt's QSaveFile resolves symlinks before
  # its atomic rename — so GUI changes land in the repo too. Check a hand edit
  # with `konveyor validate`.
  xdg.configFile."konveyor/config.kdl".source =
    config.lib.file.mkOutOfStoreSymlink "${repoDir}/config/konveyor/config.kdl";

  # ── shortcuts ────────────────────────────────────────────────────
  # Konveyor takes the keys its binds need away from Plasma by itself, so this
  # only re-homes what that displaced: vim Mod+L is focus-right, and Meta+L was
  # Lock Screen. Meta+Backspace is the lock key the old niri config used.
  programs.plasma.shortcuts.ksmserver."Lock Session" = [ "Meta+Backspace" "Screensaver" ];

  # ── sleep: match laptop.nix ──────────────────────────────────────
  # PowerDevil holds logind's lid inhibitor while Plasma runs, so laptop.nix's
  # HandleLidSwitch=suspend-then-hibernate only applies at the greeter. This is
  # the in-session equivalent; it calls logind's SuspendThenHibernate, so
  # laptop.nix's HibernateDelaySec (30min) still sets the delay.
  programs.plasma.powerdevil = lib.genAttrs [ "AC" "battery" "lowBattery" ] (_: {
    whenSleepingEnter = "standbyThenHibernate";
  });

  # ── pinentry ─────────────────────────────────────────────────────
  # pinentry-gnome3 (the default in pass.nix) draws through gcr's prompter,
  # which only gnome-keyring registers — and this host runs KWallet instead
  # (modules/nixos/plasma.nix). Without the prompter it would fall back to a
  # curses prompt, which `pass -c` from a launcher has nowhere to draw.
  services.gpg-agent.pinentry.package = pkgs.pinentry-qt;

  # ── mime defaults for Plasma's own apps ──────────────────────────
  # The DE-agnostic handlers (mpv, qimgv) are in modules/home/xdg.nix and the
  # browser's in its own module; these are the ones that change with the
  # desktop. defaultApplications merges across modules into one list.
  xdg.mimeApps.defaultApplications = {
    "inode/directory"           = "org.kde.dolphin.desktop";
    "x-scheme-handler/terminal" = "org.kde.konsole.desktop";
    "text/plain"                = "org.kde.kate.desktop";
    "application/pdf"           = "org.kde.okular.desktop";
  };
}
