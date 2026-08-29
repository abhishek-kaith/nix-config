{ pkgs, ... }:
{
  # End-user graphical applications that the desktop environment does NOT already
  # ship. The graphical infrastructure (audio, fonts, keyring, polkit) is
  # desktop.nix; the DE itself (and its file manager, terminal, screenshot tool,
  # PDF reader, app store, …) is cosmic.nix. Imported by graphical hosts.
  #
  # Removed with niri/noctalia, because COSMIC ships an equivalent:
  #   thunar + xfconf + tumbler + ffmpegthumbnailer + xarchiver → cosmic-files
  #   grim + slurp + satty                                     → cosmic-screenshot
  # (cosmic-screenshot has no annotation tool. If arrows/blur turn out to be
  #  worth keeping, `satty` is the piece to bring back, fed from a saved capture.)

  services.gvfs.enable = true;  # trash, mounting, network browsing for cosmic-files

  environment.systemPackages = with pkgs; [
    # ── media ──────────────────────────────────────────────────────
    mpv                # video/audio player — ffmpeg bundles the codecs; HW-accel on t480
                       # (cosmic-player is excluded in cosmic.nix in favour of this)
    yt-dlp             # stream/download from URLs (`mpv <url>`)

    # ── images / documents ─────────────────────────────────────────
    qimgv              # fast image viewer — COSMIC epoch 1 has no image viewer
    papers             # GTK PDF viewer (evince successor). COSMIC ships
                       # cosmic-reader; keep this until that one proves itself,
                       # then drop it and repoint the pdf mime in home/xdg.nix.
    pavucontrol        # GUI audio mixer (per-app volume) — finer-grained than the applet
    keepassxc          # password manager (Firefox integration via native messaging)
  ];

  # ── run apps that aren't in nixpkgs ──────────────────────────────
  programs.appimage = {
    enable = true;
    binfmt = true;   # execute .AppImage files directly (./foo.AppImage)
  };
  services.flatpak.enable = true;   # Flathub apps (uses the xdg portals COSMIC sets up).
                                    # Also what makes the COSMIC module install
                                    # cosmic-store — it only ships the store when
                                    # flatpak is enabled. Add the remote once:
                                    #   flatpak remote-add --if-not-exists flathub \
                                    #     https://flathub.org/repo/flathub.flatpakrepo
}
