{ config, lib, repoDir, ... }:
{
  # editable + hot-reloading: symlink points at the working tree, not the store.
  # niri watches this file and applies changes on save.
  xdg.configFile."niri/config.kdl".source =
    config.lib.file.mkOutOfStoreSymlink "${repoDir}/config/niri/config.kdl";

  # config.kdl does `include "noctalia.kdl"`; noctalia overwrites that file with
  # generated theme colors when it themes niri. Seed a blank one so the include
  # always resolves (niri rejects a config whose include target is missing) — even
  # on a fresh boot before noctalia has applied a theme. Never clobber a real theme
  # noctalia has already written.
  home.activation.seedNoctaliaNiriTheme =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      dir="${config.xdg.configHome}/niri"
      run mkdir -p "$dir"
      [ -e "$dir/noctalia.kdl" ] || run touch "$dir/noctalia.kdl"
    '';

  # login shell: exec niri only on TTY1
  programs.zsh.profileExtra = ''
    [ "$(tty)" = "/dev/tty1" ] && exec niri --session
  '';
}
