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
  # installed; add a browser/pdf handler once you install one.
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "image/png"        = "qimgv.desktop";
      "image/jpeg"       = "qimgv.desktop";
      "image/gif"        = "qimgv.desktop";
      "image/webp"       = "qimgv.desktop";
      "video/mp4"        = "mpv.desktop";
      "video/x-matroska" = "mpv.desktop";
      "video/webm"       = "mpv.desktop";
      "application/pdf"        = "org.gnome.Papers.desktop";
      "text/html"              = "firefox.desktop";
      "x-scheme-handler/http"  = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
    };
  };
}
