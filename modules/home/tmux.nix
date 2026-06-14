{ ... }:
{
  programs.tmux = {
    enable      = true;
    # reads config/tmux.conf at eval time and inlines it — file stays in native tmux syntax
    extraConfig = builtins.readFile ../../config/tmux.conf;
  };
}
