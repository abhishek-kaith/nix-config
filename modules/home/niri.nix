{ config, repoDir, ... }:
{
  # editable + hot-reloading: symlink points at the working tree, not the store.
  # niri watches this file and applies changes on save.
  xdg.configFile."niri/config.kdl".source =
    config.lib.file.mkOutOfStoreSymlink "${repoDir}/config/niri/config.kdl";

  # login shell: exec niri only on TTY1
  programs.zsh.profileExtra = ''
    [ "$(tty)" = "/dev/tty1" ] && exec niri --session
  '';
}
