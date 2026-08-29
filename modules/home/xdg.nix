{ config, ... }:
{
  xdg.enable = true;

  # Standard user directories — file dialogs, portals, screenshot paths and many
  # apps read ~/.config/user-dirs.dirs; without it everything defaults to $HOME.
  xdg.userDirs = {
    enable            = true;
    createDirectories = true;
    desktop   = "${config.home.homeDirectory}/Desktop";
    documents = "${config.home.homeDirectory}/Documents";
    download  = "${config.home.homeDirectory}/Downloads";
    music     = "${config.home.homeDirectory}/Music";
    pictures  = "${config.home.homeDirectory}/Pictures";
    videos    = "${config.home.homeDirectory}/Videos";
    extraConfig.XDG_SCREENSHOTS_DIR = "${config.home.homeDirectory}/Pictures/Screenshots";
  };

  # Default apps for `xdg-open` / "Open with". Only map to apps that are actually
  # installed — a mapping to a missing .desktop silently does nothing.
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      # Directories: what opens when an app says "show in file manager". Thunar
      # used to claim this by itself; cosmic-files ships the only inode/directory
      # handler now, but nothing sets it as the *default*, so state it.
      "inode/directory"  = "com.system76.CosmicFiles.desktop";

      "image/png"        = "qimgv.desktop";
      "image/jpeg"       = "qimgv.desktop";
      "image/gif"        = "qimgv.desktop";
      "image/webp"       = "qimgv.desktop";
      "video/mp4"        = "mpv.desktop";
      "video/x-matroska" = "mpv.desktop";
      "video/webm"       = "mpv.desktop";
      # COSMIC also ships cosmic-reader; papers stays the default until that one
      # proves itself (modules/nixos/apps.nix). Swap the id here if you drop papers.
      "application/pdf"        = "org.gnome.Papers.desktop";
      "text/html"              = "firefox.desktop";
      "x-scheme-handler/http"  = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
    };
  };
}
