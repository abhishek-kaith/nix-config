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
  # (satty came back, but lives in cosmic.nix: it fills a COSMIC gap —
  #  cosmic-screenshot cannot annotate — and Plasma's Spectacle already can.)

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
                       # For marking up a screenshot, the DE's tool is the far
                       # shorter path: Spectacle on Plasma, satty on COSMIC.
    # The newest LibreOffice line. 26.05 calls it `libreoffice-fresh` (plain
    # `libreoffice` is the older "still" line there); unstable renamed the scheme,
    # made plain `libreoffice` the newest and turned `-fresh` into a warning
    # alias. Choosing by whether the new name exists keeps stable hosts on
    # fresh and an unstable host (t14) warning-free.
    (if pkgs ? libreoffice-stable then libreoffice else libreoffice-fresh)
                       # .docx/.xlsx/.pptx + ODF. Nothing else here opens them —
                       # the browser will not, and the PDF readers only read PDF. No
                       # mime mappings for it in home/xdg.nix on purpose: it is the
                       # only handler for those types, so it wins the default by
                       # itself, and naming its .desktop ids wrongly would silently
                       # map them to nothing.
    pavucontrol        # GUI audio mixer (per-app volume) — finer-grained than the applet
    keepassxc          # password manager; browser integration is configured in the app

    # ── screen capture ─────────────────────────────────────────────
    # Taking the picture is the DE's job (cosmic-screenshot + satty, or
    # Spectacle). This is the part neither covers well: long recordings,
    # streaming, webcam overlays.
    obs-studio         # screen + webcam recording and streaming. Captures through
                       # the DE's screencast portal (xdg-desktop-portal-cosmic,
                       # version-locked to cosmic-comp in cosmic.nix, or -kde)
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
