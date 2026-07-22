{ pkgs, ... }:
{
  # noctalia writes the *colours* (gtk-3.0/gtk-4.0 noctalia.css, @import'd into
  # gtk.css) and its apply.sh sets the GTK theme to adw-gtk3(-dark) via gsettings —
  # but ONLY if adw-gtk3 is actually installed. Without it, GTK apps (Thunar!) stay
  # on stock Adwaita, which ignores noctalia's libadwaita colour variables and looks
  # unthemed. Installing adw-gtk3 + an icon theme is the missing piece.
  gtk = {
    enable = true;
    theme     = { name = "adw-gtk3-dark"; package = pkgs.adw-gtk3; };
    iconTheme = { name = "Papirus-Dark";  package = pkgs.papirus-icon-theme; };
  };

  # Qt apps (keepassxc, qimgv, pavucontrol) follow the GTK theme
  qt = {
    enable = true;
    platformTheme.name = "gtk3";
  };

  # crisp, consistent Wayland cursor (also exports XCURSOR_* for niri + XWayland)
  home.pointerCursor = {
    gtk.enable = true;
    package = pkgs.bibata-cursors;
    name    = "Bibata-Modern-Classic";
    size    = 24;
  };
}
