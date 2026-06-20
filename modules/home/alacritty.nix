{ repoDir, ... }:
{
  programs.alacritty = {
    enable = true;
    # the real config is the editable repo file; alacritty imports it and
    # live-reloads on save (live_config_reload is on by default)
    settings.general.import = [ "${repoDir}/config/alacritty/alacritty.toml" ];
  };
}
