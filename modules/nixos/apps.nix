{ pkgs, ... }:
{
  # End-user graphical applications that the desktop environment does NOT already
  # ship. The graphical infrastructure (audio, fonts, keyring, polkit) is
  # desktop.nix; the DE itself (and its file manager, terminal, screenshot tool,
  # PDF reader, app store, …) is cosmic.nix. Imported by graphical hosts.
  #
  # Removed with niri/noctalia, because COSMIC ships an equivalent:
  #   thunar + xfconf + tumbler + ffmpegthumbnailer + xarchiver → cosmic-files
  #   grim + slurp                                             → cosmic-screenshot
  # (satty came back — see the screen capture section below. cosmic-screenshot
  #  captures but cannot annotate, and epoch 1 has no replacement for that.)

  services.gvfs.enable = true;  # trash, mounting, network browsing for cosmic-files

  environment.systemPackages = with pkgs; [
    # ── media ──────────────────────────────────────────────────────
    mpv                # video/audio player — ffmpeg bundles the codecs; HW-accel on t480
                       # (cosmic-player is excluded in cosmic.nix in favour of this)
    yt-dlp             # stream/download from URLs (`mpv <url>`)

      # ── images / documents ─────────────────────────────────────────
    qimgv              # fast image viewer — COSMIC epoch 1 has no image viewer
    gimp3              # the editor behind the viewer: crop, retouch, layers.
                       # imagemagick (packages.nix) covers the scriptable half.
                       # `satty` below is for screenshots specifically — reach for
                       # that first, it is a far shorter path for an annotation.
    libreoffice-fresh  # .docx/.xlsx/.pptx + ODF. Nothing else here opens them —
                       # the browser will not, and the PDF readers only read PDF. No
                       # mime mappings for it in home/xdg.nix on purpose: it is the
                       # only handler for those types, so it wins the default by
                       # itself, and naming its .desktop ids wrongly would silently
                       # map them to nothing.
    pavucontrol        # GUI audio mixer (per-app volume) — finer-grained than the applet
    keepassxc          # password manager; browser integration is configured in the app

    # ── screen capture ─────────────────────────────────────────────
    # cosmic-screenshot takes the picture and stops there — epoch 1 has no
    # annotation and no recording at all.
    satty              # annotate a capture: arrows, boxes, blur, text. Feed it a
                       # saved screenshot (`satty -f ~/Pictures/Screenshots/x.png`).
    obs-studio         # screen + webcam recording and streaming. Captures under
                       # COSMIC through xdg-desktop-portal-cosmic's screencast
                       # (installed and version-locked to cosmic-comp in cosmic.nix)
                       # — there is nothing to configure, pick "Screen Capture
                       # (PipeWire)" as the source. The virtual camera is the one
                       # thing that needs more: it wants the v4l2loopback kernel
                       # module, not enabled here.
  ];

  # ── run apps that aren't in nixpkgs ──────────────────────────────
  programs.appimage = {
    enable = true;
    binfmt = true;   # execute .AppImage files directly (./foo.AppImage)
  };
  # ── flatpak ──────────────────────────────────────────────────────
  # Also makes the COSMIC module ship `cosmic-store`; upstream only adds the Store
  # when Flatpak is enabled. Remotes are persistent state and are user-managed.
  services.flatpak.enable = true;
}
