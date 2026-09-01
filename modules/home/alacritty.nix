{ config, repoDir, ... }:
{
  programs.alacritty = {
    enable = true;
    # The real, live-editable config is the repo file; alacritty imports it and
    # live-reloads on save (live_config_reload is on by default).
    #
    # Order matters and is the whole trick. Alacritty applies imports in sequence
    # with a later one replacing an earlier one, and silently skips any that are
    # missing. So:
    #
    #   alacritty.toml     — settings, no colours
    #   colors-dark.toml   — the palette, committed; this is the FALLBACK
    #   colors-active.toml — written by cosmic-theme-sync from the COSMIC theme
    #
    # If the sync service is disabled, fails, or has simply never run, the third
    # file does not exist and the terminal is exactly what colors-dark.toml says —
    # the static behaviour this repo had before. Nothing to undo.
    settings.general.import = [
      "${repoDir}/config/alacritty/alacritty.toml"
      "${repoDir}/config/alacritty/colors-dark.toml"
      "${config.xdg.configHome}/alacritty/colors-active.toml"
    ];
  };
}
