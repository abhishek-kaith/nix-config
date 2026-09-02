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
  #
  # Only DE-agnostic handlers here. The ones that point at the desktop's own apps
  # (directories, terminal, plain text, PDF) live in modules/home/<de>.nix, so a
  # DE swap does not have to touch this file.
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "image/png"        = "qimgv.desktop";
      "image/jpeg"       = "qimgv.desktop";
      "image/gif"        = "qimgv.desktop";
      "image/webp"       = "qimgv.desktop";
      "image/tiff"       = "qimgv.desktop";
      "image/bmp"        = "qimgv.desktop";
      "image/avif"       = "qimgv.desktop";   # what modern cameras and the web emit
      "image/heif"       = "qimgv.desktop";   # iPhone stills
      # SVG is markup, not a raster: qimgv renders it poorly or not at all, and
      # firefox is the best renderer already on the machine.
      "image/svg+xml"    = "firefox.desktop";

      "video/mp4"        = "mpv.desktop";
      "video/x-matroska" = "mpv.desktop";
      "video/webm"       = "mpv.desktop";
      "video/quicktime"  = "mpv.desktop";     # .mov — phone video
      "video/x-msvideo"  = "mpv.desktop";     # .avi
      "video/mpeg"       = "mpv.desktop";

      # Audio too: mpv plays it perfectly well (no window for audio-only files),
      # and without a mapping double-clicking an .mp3 had nothing to open it.
      "audio/mpeg"       = "mpv.desktop";     # .mp3
      "audio/flac"       = "mpv.desktop";
      "audio/x-wav"      = "mpv.desktop";
      "audio/ogg"        = "mpv.desktop";
      "audio/opus"       = "mpv.desktop";
      "audio/mp4"        = "mpv.desktop";     # .m4a
      "audio/aac"        = "mpv.desktop";
      "text/html"              = "firefox.desktop";
      "x-scheme-handler/http"  = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
    };
  };
}
