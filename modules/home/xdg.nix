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

      # Which terminal "Open in Terminal" uses. cosmic-files asks xdg-mime for
      # this handler first and falls back to com.system76.CosmicTerm when unset,
      # so this line is redundant FOR cosmic-files — it is here for everything
      # else that resolves a terminal through xdg-mime rather than hardcoding
      # COSMIC's, which is most of them.
      "x-scheme-handler/terminal" = "com.system76.CosmicTerm.desktop";

      # Plain text. cosmic-edit is kept installed precisely so this has somewhere
      # to go (see modules/nixos/cosmic.nix); without the mapping it depended on
      # whichever app happened to register for text/plain first.
      "text/plain"       = "com.system76.CosmicEdit.desktop";

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

      # Audio had NO mapping at all: with cosmic-player excluded in favour of mpv,
      # double-clicking an .mp3 in cosmic-files had nothing registered to open it.
      # mpv plays audio perfectly well (it draws no window for audio-only files).
      "audio/mpeg"       = "mpv.desktop";     # .mp3
      "audio/flac"       = "mpv.desktop";
      "audio/x-wav"      = "mpv.desktop";
      "audio/ogg"        = "mpv.desktop";
      "audio/opus"       = "mpv.desktop";
      "audio/mp4"        = "mpv.desktop";     # .m4a
      "audio/aac"        = "mpv.desktop";
      # cosmic-reader is now the only PDF viewer installed — papers was dropped
      # from modules/nixos/apps.nix rather than keeping two. cosmic-reader also
      # ships a thumbnailer, so PDFs get previews in cosmic-files.
      "application/pdf"        = "com.system76.CosmicReader.desktop";
      "text/html"              = "firefox.desktop";
      "x-scheme-handler/http"  = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
    };
  };
}
