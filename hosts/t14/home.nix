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
    ../../modules/home/zen-browser.nix  # Zen browser (flake input), the default browser here
    ../../modules/home/plasma.nix     # the DE, user half: plasma-manager (keys, sleep), Qt pinentry, mime defaults
    ../../modules/home/starship.nix   # prompt config (out-of-store)
    ../../modules/home/easyeffects.nix # mic denoise/AGC chain (laptop mic)
    ../../modules/home/pass.nix       # gpg + gpg-agent (Qt pinentry via plasma.nix), pass + pass-otp
  ];

  home.username      = user;
  home.homeDirectory = "/home/${user}";

  # must match system.stateVersion in hosts/t14/default.nix
  home.stateVersion  = "26.05";
}
