{ pkgs, pkgs-unstable, user, ... }:
{
  programs.niri = {
    enable  = true;
    package = pkgs-unstable.niri;  # >= 26.04 for blur
  };

  # TTY1 autologin — zprofile in home/niri.nix execs niri-session
  services.getty.autologinUser = user;

  environment.sessionVariables.NIXOS_OZONE_WL = "1";  # electron apps use Wayland

  # niri has no built-in wallpaper renderer; swaybg sets one (spawn-at-startup in config.kdl)
  environment.systemPackages = [ pkgs.swaybg ];
}
