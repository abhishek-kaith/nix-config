{ pkgs, ... }:
{
  # The compositor-agnostic graphical layer: audio, fonts, portals, keyring,
  # polkit. The compositor itself (niri) + how the session starts is niri.nix;
  # the noctalia shell's system bits are noctalia.nix.

  # ── audio (PipeWire) ─────────────────────────────────────────────
  services.pipewire = {
    enable       = true;
    alsa.enable  = true;
    pulse.enable = true;
  };
  services.pulseaudio.enable = false;

  # ── fonts ────────────────────────────────────────────────────────
  fonts.packages = with pkgs; [
    nerd-fonts.iosevka
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-color-emoji   # colour emoji — without it, glyphs render as tofu
  ];
  fonts.fontconfig.defaultFonts = {
    monospace = [ "JetBrainsMono Nerd Font" ];
    sansSerif = [ "Noto Sans" ];
    serif     = [ "Noto Serif" ];
    emoji     = [ "Noto Color Emoji" ];
  };

  # ── auth / secret service ────────────────────────────────────────
  security.polkit.enable = true;
  services.gnome.gnome-keyring.enable = true;              # Secret Service (browser creds, etc.)
  security.pam.services.login.enableGnomeKeyring = true;   # unlock keyring at the TTY autologin

  # ── xdg portals (file pickers + screencast under Wayland) ────────
  # niri is a Smithay compositor, so screencast goes through the GNOME portal,
  # NOT xdg-desktop-portal-wlr (which won't capture under niri).
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk       # file chooser + fallback
      xdg-desktop-portal-gnome     # screencast / screenshot (needs PipeWire, above)
    ];
    config.niri = {
      default = [ "gnome" "gtk" ];
      "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
      "org.freedesktop.impl.portal.ScreenCast"  = [ "gnome" ];
      "org.freedesktop.impl.portal.Screenshot"  = [ "gnome" ];
    };
  };

  # ── misc graphical tools ─────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    imv   # lightweight Wayland image viewer
  ];
}
