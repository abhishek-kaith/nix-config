{ config, pkgs, repoDir, ... }:
{
  # Ghostty: GPU-rendered, native-Wayland terminal, the Meta+Return one on
  # hosts that import this. tmux runs inside it, so Ghostty's own tabs and
  # splits are switched off in its config.
  home.packages = [ pkgs.ghostty ];

  # Out-of-store, like nvim and starship: ~/.config/ghostty/config IS
  # config/ghostty/config in this repo, so an edit is one Ctrl+Shift+, away
  # from live with no rebuild.
  xdg.configFile."ghostty/config".source =
    config.lib.file.mkOutOfStoreSymlink "${repoDir}/config/ghostty/config";
  # The light half of the config's light/dark theme pair (Ghostty ships no
  # light Breeze), linked the same way so it is editable in place.
  xdg.configFile."ghostty/themes/Breeze Light".source =
    config.lib.file.mkOutOfStoreSymlink "${repoDir}/config/ghostty/themes/Breeze Light";

  # Apps that ask for "a terminal" (x-scheme-handler/terminal) get Ghostty.
  xdg.mimeApps.defaultApplications."x-scheme-handler/terminal" = "com.mitchellh.ghostty.desktop";
}
