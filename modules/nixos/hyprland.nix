{ pkgs-unstable, user, ... }:
{
  programs.hyprland = {
    enable  = true;
    package = pkgs-unstable.hyprland;
    portalPackage = pkgs-unstable.xdg-desktop-portal-hyprland;
  };

  # TTY1 autologin — zprofile in home/hyprland.nix execs Hyprland
  services.getty.autologinUser = user;

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";  # electron apps use Wayland
  };
}
