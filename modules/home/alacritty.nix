{ config, lib, repoDir, ... }:
{
  programs.alacritty = {
    enable = true;
    # The real, live-editable config is the repo file; alacritty imports it and
    # live-reloads on save (live_config_reload is on by default).
    #
    # We ALSO pre-declare noctalia's generated theme file here. noctalia's
    # alacritty apply.sh corrupts a single-element import array: it inserts a
    # second path *before the closing `]` with no comma*, producing invalid TOML
    # so alacritty refuses the config. By already referencing noctalia.toml, its
    # script takes the idempotent path-rewrite branch instead of the array-insert
    # branch — so noctalia can theme the terminal without breaking it.
    settings.general.import = [
      "${repoDir}/config/alacritty/alacritty.toml"
      "~/.config/alacritty/themes/noctalia.toml"
    ];
  };

  # Seed an empty, writable theme file so the import above always resolves (even
  # before noctalia has applied a theme) and so noctalia can freely overwrite it.
  # noctalia owns this file's contents from here on; nix must not manage it as a
  # read-only store symlink.
  home.activation.seedNoctaliaAlacrittyTheme =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      themes="${config.xdg.configHome}/alacritty/themes"
      run mkdir -p "$themes"
      [ -e "$themes/noctalia.toml" ] || run touch "$themes/noctalia.toml"
    '';
}
