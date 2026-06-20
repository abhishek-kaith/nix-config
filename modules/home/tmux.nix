{ repoDir, ... }:
{
  programs.tmux = {
    enable = true;
    # source the editable repo file instead of inlining it at eval time;
    # apply edits with `prefix + R` or `tmux source-file ~/.config/tmux/tmux.conf`
    extraConfig = "source-file ${repoDir}/config/tmux.conf";
  };
}
