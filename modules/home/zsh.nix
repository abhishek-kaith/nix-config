{ ... }:
{
  programs.zsh = {
    enable    = true;   # tells home-manager to create and manage ~/.zshrc
    initContent = ''
      bindkey -v
      bindkey '^p' history-search-backward
      bindkey '^n' history-search-forward
      bindkey -s '^f' '~/.scripts/tmux-sessionizer\n'
    '';
  };
}
