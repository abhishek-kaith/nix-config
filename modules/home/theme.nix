{ pkgs, ... }:
{
  # ── who owns what, and why gtk.theme is NOT set here ─────────────
  # noctalia's GTK template writes the *colours* (gtk-3.0/gtk-4.0 noctalia.css,
  # @import'd into gtk.css) and its apply.sh ALSO picks the GTK theme by mode:
  #   light → adw-gtk3      dark → adw-gtk3-dark
  # It does that by writing the dconf key org/gnome/desktop/interface/gtk-theme.
  #
  # home-manager's gtk.theme option writes that SAME dconf key (see the upstream
  # module misc/gtk/gtk3.nix), and re-applies it on every `nixos-rebuild switch`.
  # Setting it here to a hardcoded "-dark" therefore fights noctalia: with
  # [theme] mode = "auto" in config/noctalia/config.toml the shell flips to the
  # light palette at sunrise, and the next rebuild silently slams GTK apps back to
  # the dark theme while the colours stay light.
  #
  # So: one owner per setting. noctalia owns gtk-theme (it is mode-dependent), we
  # just make sure the theme is INSTALLED so noctalia's theme_exists() check finds
  # it — without that it logs "Theme 'adw-gtk3' not found" and skips the set.
  # Everything below is mode-INdependent, so home-manager can own it outright.
  # The icon theme IS pinned here, and that is the intended workflow: this file is
  # the permanent record. nwg-look writes the same dconf key at runtime, so use it
  # to try themes live, then write the winner here to make it survive. A
  # `nixos-rebuild switch` re-asserts whatever is below — treat anything nwg-look
  # changed as a scratch value until it lands in this file.
  gtk = {
    enable = true;
    iconTheme = { name = "Papirus-Dark"; package = pkgs.papirus-icon-theme; };
  };

  home.packages = with pkgs; [
    adw-gtk3   # installed, but not pinned via gtk.theme — see above
    # GUI for trying icon/cursor/font themes without a rebuild. It writes the same
    # dconf keys and ~/.config/gtk-3.0/settings.ini that home-manager manages, so
    # its changes last until the next rebuild. That is deliberate: preview here,
    # then make it permanent above. It CANNOT usefully set the GTK theme itself —
    # that key belongs to noctalia and gets rewritten on every light/dark flip.
    nwg-look
    # Provides the "Adwaita" cursor that the default cursor name resolves to.
    # Without a cursor theme installed at all, "default" falls through to the tiny
    # legacy X11 pointer.
    adwaita-icon-theme
  ];

  # Qt apps (keepassxc, qimgv, pavucontrol) follow the GTK theme
  qt = {
    enable = true;
    platformTheme.name = "gtk3";
  };

  # Cursor: left at the system default on purpose — no theme pinned. adwaita-icon-theme
  # provides the "Adwaita" cursor that "default" resolves to, so the pointer is a real
  # cursor rather than the tiny X11 fallback. To pin a specific one later:
  #   home.pointerCursor = {
  #     gtk.enable = true;
  #     package = pkgs.bibata-cursors;
  #     name = "Bibata-Modern-Classic";
  #     size = 24;
  #   };
}
