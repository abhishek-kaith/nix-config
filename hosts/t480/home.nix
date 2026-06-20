{ user, ... }:
{
  imports = [
    ../../modules/home/git.nix
    ../../modules/home/zsh.nix
    ../../modules/home/tmux.nix
    ../../modules/home/scripts.nix
    ../../modules/home/niri.nix       # kdl config (out-of-store), TTY1 exec
    ../../modules/home/noctalia.nix   # noctalia shell
    ../../modules/home/alacritty.nix  # terminal
  ];

  home.username      = user;
  home.homeDirectory = "/home/${user}";

  # must match system.stateVersion in hosts/t480/default.nix
  home.stateVersion  = "26.05";
}
