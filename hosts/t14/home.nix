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
    ../../modules/home/cosmic.nix     # the DE, user half: COSMIC mime defaults + GTK3 light/dark sync
    ../../modules/home/starship.nix   # prompt config (out-of-store)
    ../../modules/home/easyeffects.nix # mic denoise/AGC chain (laptop mic)
  ];

  home.username      = user;
  home.homeDirectory = "/home/${user}";

  # must match system.stateVersion in hosts/t14/default.nix
  home.stateVersion  = "26.05";
}
