{ ... }:
{
  imports = [
    ../../modules/home/git.nix
    ../../modules/home/zsh.nix
    ../../modules/home/tmux.nix
    ../../modules/home/scripts.nix
    ../../modules/home/hyprland.nix   # lua config, TTY1 exec
    ../../modules/home/noctalia.nix   # noctalia shell
    ../../modules/home/alacritty.nix  # terminal
  ];

  home.username      = "k";
  home.homeDirectory = "/home/k";

  # must match the NixOS release — same as system.stateVersion in hosts/vm/default.nix
  home.stateVersion  = "26.05";
}
