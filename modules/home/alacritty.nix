{ repoDir, ... }:
{
  programs.alacritty = {
    enable = true;
    # The real, live-editable config is the repo file; alacritty imports it and
    # live-reloads on save (live_config_reload is on by default). Colours live
    # there too now — with noctalia gone nothing generates a palette at runtime,
    # so the theme is a plain static block in config/alacritty/alacritty.toml.
    settings.general.import = [ "${repoDir}/config/alacritty/alacritty.toml" ];
  };
}
