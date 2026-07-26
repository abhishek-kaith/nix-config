{ config, repoDir, ... }:
{
  # neovim itself is installed system-wide (modules/nixos/packages.nix) because it
  # is the system EDITOR — sudoedit and `systemctl edit` need it on root's PATH too.
  # This wires the editable config from the working tree — exactly like niri — so
  # nvim reads it live.
  #
  # Plugins are managed imperatively by vim.pack (Neovim 0.12's built-in manager,
  # `:help vim.pack`), NOT by nixpkgs. It clones into stdpath("data") and writes its
  # lockfile to $XDG_CONFIG_HOME/nvim/nvim-pack-lock.json — which resolves through
  # this symlink back into the repo, so committing that file pins plugin revisions
  # across hosts. Update with `:lua vim.pack.update()`, then commit the lockfile.
  #
  # vim.pack needs `git`; nvim-treesitter additionally needs `tree-sitter` and `cc`,
  # and mason needs `node`/`npm` — all in packages.nix / dev.nix, not here.
  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${repoDir}/config/nvim";
}
