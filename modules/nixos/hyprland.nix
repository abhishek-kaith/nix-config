{ pkgs-unstable, ... }:
{
  programs.hyprland = {
    enable  = true;
    package = pkgs-unstable.hyprland;
    portalPackage = pkgs-unstable.xdg-desktop-portal-hyprland;
  };

  # TTY1 autologin — zprofile in home/hyprland.nix execs Hyprland
  services.getty.autologinUser = "k";

  environment.sessionVariables = {
    NIXOS_OZONE_WL          = "1";  # electron apps use Wayland
    WLR_NO_HARDWARE_CURSORS = "1";  # required in QEMU VM
  };
}
