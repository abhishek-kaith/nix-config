{ config, repoDir, ... }:
{
  # editable: symlink to the working tree so script edits take effect immediately
  home.file.".scripts/tmux-sessionizer".source =
    config.lib.file.mkOutOfStoreSymlink "${repoDir}/config/scripts/tmux-sessionizer";
}
