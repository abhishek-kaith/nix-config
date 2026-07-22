{ pkgs, ... }:
{
  # End-user graphical applications. The graphical *infrastructure* (audio, fonts,
  # portals, keyring, polkit) is desktop.nix; this is the apps that sit on top.
  # Imported by graphical hosts.

  # ── file manager: Thunar + archives + thumbnails ─────────────────
  programs.thunar = {
    enable  = true;
    plugins = with pkgs.xfce; [
      thunar-archive-plugin   # right-click → create / extract archive (uses xarchiver)
      thunar-volman           # auto-manage removable media
    ];
  };
  programs.xfconf.enable  = true;  # let Thunar persist its settings
  services.tumbler.enable = true;  # thumbnail daemon (images, pdf, fonts)
  services.gvfs.enable    = true;  # trash, mounting, network browsing

  environment.systemPackages = with pkgs; [
    # ── media ──────────────────────────────────────────────────────
    mpv                # video/audio player — ffmpeg bundles the codecs; HW-accel on t480
    yt-dlp             # stream/download from URLs (`mpv <url>`)

    # ── images + screenshot markup ─────────────────────────────────
    qimgv              # fast image viewer
    grim slurp         # capture (grim) + region select (slurp) → piped into satty
    satty              # annotate screenshots: arrows, text, blur, crop, numbering

    # ── documents / archives / audio ───────────────────────────────
    papers             # GTK PDF viewer (evince successor)
    xarchiver          # archive GUI + backend for thunar-archive-plugin
    ffmpegthumbnailer  # video thumbnails for tumbler
    pavucontrol        # GUI audio mixer (per-app volume)
  ];
}
