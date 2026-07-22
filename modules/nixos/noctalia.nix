{ inputs, pkgs, ... }:
{
  # Everything the noctalia shell needs at the SYSTEM level lives here, so the
  # third-party themer stays quarantined and is easy to rip out in one place.
  # (The home-manager side — enable + theme-file seeding — is modules/home/noctalia.nix,
  #  and the per-app theming quirks live with each app in modules/home/{alacritty,niri}.nix.)

  # makes pkgs.noctalia available system-wide (home-manager uses useGlobalPkgs)
  nixpkgs.overlays = [ inputs.noctalia.overlays.default ];

  # Binary cache — pull prebuilt noctalia instead of compiling the Qt/QML shell.
  # These MUST match the flags `nix run .#install` passes to nixos-install, and
  # they work together with tracking noctalia's `cachix` branch (see flake.nix).
  nix.settings = {
    extra-substituters = [ "https://noctalia.cachix.org" ];
    extra-trusted-public-keys = [
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];
  };

  # noctalia shells out to these at runtime; they are NOT in its closure, so a
  # fresh install without them has silently-broken brightness keys and theming.
  environment.systemPackages = with pkgs; [
    matugen        # wallpaper → Material-You palette (drives the app-theming)
    imagemagick    # image processing for theming / wallpaper
    brightnessctl  # backlight control for the brightness keys / OSD
    cliphist       # clipboard-history backend
    wl-clipboard   # wl-copy / wl-paste
  ];
}
