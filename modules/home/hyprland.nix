{ pkgs-unstable, ... }:
{
  wayland.windowManager.hyprland = {
    enable         = true;
    package        = pkgs-unstable.hyprland;
    systemd.enable = false; # config is a raw Lua file, not home-manager settings
  };

  # hybrid: Lua config stays in native format, home-manager places it
  xdg.configFile."hypr/hyprland.lua".source = ../../config/hypr/hyprland.lua;

  # login shell: exec Hyprland only on TTY1
  programs.zsh.profileExtra = ''
    [ "$(tty)" = "/dev/tty1" ] && exec start-hyprland
  '';
}
