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
    monospace = [ "Iosevka Nerd Font" "JetBrainsMono Nerd Font" ];
    sansSerif = [ "Noto Sans" ];
    serif     = [ "Noto Serif" ];
    emoji     = [ "Noto Color Emoji" ];
  };

  # ── wayland session env ──────────────────────────────────────────
  # Not niri-specific: any Wayland compositor wants Electron/Chromium apps running
  # natively rather than through XWayland.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # ── auth / secret service ────────────────────────────────────────
  security.polkit.enable = true;
  programs.dconf.enable = true;                            # gsettings/dconf backend — GTK apps + noctalia's gsettings theme-set need it
  services.gnome.gnome-keyring.enable = true;              # Secret Service (browser creds, etc.)
  security.pam.services.login.enableGnomeKeyring = true;   # unlock keyring at the TTY autologin

  # ── xdg portals (file pickers + screencast under Wayland) ────────
  # Not configured here, on purpose. Which portal backend serves screencast is a
  # property of the compositor, not of "the desktop" — niri needs the GNOME one,
  # a wlroots compositor needs xdg-desktop-portal-wlr — so the compositor's own
  # NixOS module owns this. `programs.niri` (modules/nixos/niri.nix) already sets
  # xdg.portal.enable, both backends, and config.niri; a second compositor brings
  # its own. PipeWire above is the shared prerequisite screencast needs either way.
}
