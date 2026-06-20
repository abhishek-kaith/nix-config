{ pkgs-unstable, user, ... }:
{
  programs.niri = {
    enable  = true;
    package = pkgs-unstable.niri;  # >= 26.04 for blur
  };

  # TTY1 autologin — zprofile in home/niri.nix execs niri-session
  services.getty.autologinUser = user;

  environment.sessionVariables.NIXOS_OZONE_WL = "1";  # electron apps use Wayland
  # wallpaper is managed by noctalia (the shell), not swaybg
}
