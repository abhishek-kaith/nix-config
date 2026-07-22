{ config, user, repoDir, ... }:
{
  imports = [
    ../../modules/home/git.nix
    ../../modules/home/zsh.nix
    ../../modules/home/tmux.nix
    ../../modules/home/scripts.nix
    ../../modules/home/xdg.nix        # user dirs, mime defaults
    ../../modules/home/direnv.nix     # direnv + nix-direnv
    ../../modules/home/neovim.nix     # editable nvim config (out-of-store)
    ../../modules/home/firefox.nix    # hardened firefox + uBlock + keepassxc
    ../../modules/home/theme.nix      # gtk/qt theme + icons + cursor (noctalia colours)
    ../../modules/home/niri.nix       # kdl config (out-of-store), TTY1 exec
    ../../modules/home/noctalia.nix   # noctalia shell
    ../../modules/home/alacritty.nix  # terminal
    ../../modules/home/starship.nix   # prompt config (out-of-store, noctalia-themeable)
  ];

  # t480-only: editable noctalia base config (laptop-specific — eDP-1, location).
  # Safe as an out-of-store symlink: noctalia reads config.toml and only ever writes
  # to ~/.local/state/noctalia/settings.toml.
  xdg.configFile."noctalia/config.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${repoDir}/config/noctalia/config.toml";

  home.username      = user;
  home.homeDirectory = "/home/${user}";

  # must match system.stateVersion in hosts/t480/default.nix
  home.stateVersion  = "26.05";
}
