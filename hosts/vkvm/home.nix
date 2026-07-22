{ user, ... }:
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
    ../../modules/home/niri.nix       # kdl config (out-of-store), TTY1 exec
    ../../modules/home/noctalia.nix   # noctalia shell
    ../../modules/home/alacritty.nix  # terminal
    ../../modules/home/starship.nix   # prompt config (out-of-store, noctalia-themeable)
  ];

  home.username      = user;
  home.homeDirectory = "/home/${user}";

  # must match the NixOS release — same as system.stateVersion in hosts/vkvm/default.nix
  home.stateVersion  = "26.05";
}
