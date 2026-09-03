{ pkgs, ... }:
{
  # The DE-agnostic graphical floor: audio, fonts, keyring, polkit. Whatever
  # desktop environment sits on top (currently modules/nixos/cosmic.nix) brings
  # its own compositor, portals, session entry and theming — this file is what
  # would stay identical if that were swapped out tomorrow.

  # ── audio (PipeWire) ─────────────────────────────────────────────
  services.pipewire = {
    enable       = true;
    alsa.enable  = true;
    pulse.enable = true;
  };
  services.pulseaudio.enable = false;

  # ── fonts ────────────────────────────────────────────────────────
  # COSMIC adds its own (fira, open-sans, noto); these are ours — the Nerd Font
  # glyphs the terminal / prompt / neovim config depend on.
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
  # Not DE-specific: any Wayland compositor wants Electron/Chromium apps running
  # natively rather than through XWayland.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # ── auth / secret service ────────────────────────────────────────
  # All three are also set by the COSMIC module (polkit/dconf outright, keyring
  # as an mkDefault). Stated here anyway because they are the floor any graphical
  # session needs, not a COSMIC detail — a DE swap should not silently take the
  # Secret Service or the polkit agent with it.
  #
  # Chromium-family browsers use this to encrypt their cookie store and fall back
  # to plaintext without it. KeePassXC remains available as the credential store,
  # but its browser integration and the browser's own password-manager setting are
  # deliberately configured in their UIs. gvfs mounts and future flatpak apps may
  # also use the Secret Service.
  security.polkit.enable = true;
  programs.dconf.enable = true;                # gsettings/dconf backend for GTK apps
  services.gnome.gnome-keyring.enable = true;  # Secret Service — see the note above

  # ── xdg portals (file pickers + screencast under Wayland) ────────
  # Deliberately not configured here. Which portal backend can serve screencast
  # is a property of the compositor, not of "the desktop" — COSMIC needs
  # xdg-desktop-portal-cosmic, a wlroots compositor needs …-wlr — so the DE's own
  # module owns it. `services.desktopManager.cosmic` already sets xdg.portal.enable,
  # both backends (cosmic + gtk) and configPackages. Don't re-declare any of that
  # here: a hand-written xdg.portal.config OVERRIDES upstream's rather than
  # extending it. PipeWire above is the shared prerequisite either way.
}
