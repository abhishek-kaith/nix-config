{ config, repoDir, ... }:
{
  # neovim itself is installed system-wide (modules/nixos/packages.nix). This wires
  # the editable config from the working tree — exactly like niri — so nvim reads it
  # live, and lazy.nvim (bootstrapped inside init.lua) manages plugins imperatively,
  # writing lazy-lock.json back into the repo.
  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${repoDir}/config/nvim";
}
