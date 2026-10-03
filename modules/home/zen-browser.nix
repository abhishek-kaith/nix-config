{ inputs, pkgs, ... }:
{
  # Package only, like brave-origin.nix: Zen owns its profile, extensions and
  # settings. Brave Origin stays the default browser (modules/home/xdg.nix).
  home.packages = [ inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default ];
}
