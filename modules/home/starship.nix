{ config, repoDir, ... }:
{
  # starship is enabled at the NixOS level (modules/nixos/shell.nix) for the
  # package + shell init. That module only exports STARSHIP_CONFIG to its own
  # generated file when ~/.config/starship.toml is missing — so by placing the
  # repo's config here as a live-editable, out-of-store symlink, starship reads it
  # directly and noctalia can inject its palette without a read-only conflict.
  xdg.configFile."starship.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${repoDir}/config/starship.toml";
}
