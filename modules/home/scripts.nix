{ ... }:
{
  home.file.".scripts/tmux-sessionizer" = {
    source     = ../../config/scripts/tmux-sessionizer;
    executable = true;  # home-manager sets chmod +x on activation
  };
}
