{ config, pkgs, ... }:
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
  # Two jobs, and the second is not obvious: it lets you install apps that are not
  # in nixpkgs (through the xdg portals COSMIC already sets up), AND it is the gate
  # that makes the COSMIC module ship `cosmic-store` — upstream only adds the store
  # when `services.flatpak.enable` is set. Turning this off silently removes the
  # Store from the machine.
  services.flatpak.enable = true;

  # Enabling flatpak gives you the machinery but NO source of apps: a fresh install
  # comes up with zero remotes, so the Store shows an empty catalogue and every
  # `flatpak install` fails to resolve. NixOS has no option for remotes, so this
  # adds Flathub itself — the same `flatpak remote-add` you would otherwise have to
  # remember to type by hand after every reinstall.
  systemd.services.flatpak-flathub-remote = {
    description = "Register the Flathub remote with flatpak";
    # Needs the network only on the FIRST successful run: --if-not-exists checks
    # for the remote before fetching anything, so once Flathub is registered this
    # is a no-op that never touches the network again.
    #
    # network-online.target is NOT a guarantee of a link here: network.nix turns
    # NetworkManager-wait-online off so the boot does not stall on wifi, which
    # means this can (and on a fresh install's first boot, will) run before there
    # is a connection. So instead of failing once and waiting for the next boot,
    # it retries every 30s until it succeeds — Restart= on a oneshot is allowed
    # for exactly this, and RemainAfterExit stops the retries once it has worked.
    after    = [ "network-online.target" "flatpak-system-helper.service" ];
    wants    = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    startLimitIntervalSec = 0;   # never trip the 5-starts-in-10s rate limit
    # config.services.flatpak.package, not pkgs.flatpak, so this cannot drift from
    # whatever version the module above is actually running.
    path = [ config.services.flatpak.package ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = "30s";
    };
    script = ''
      flatpak remote-add --if-not-exists flathub \
        https://flathub.org/repo/flathub.flatpakrepo
    '';
  };
}
