{ inputs, pkgs, ... }:
{
  # Package only, like brave-origin.nix: Zen owns its profile, extensions and
  # settings. Saved passwords live in Zen's own NSS store (key4.db + logins.json
  # in the profile), not in the desktop keyring, so a keyring or DE swap never
  # touches them.
  home.packages = [ inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default ];

  # The default browser wherever this module is imported — see brave-origin.nix
  # for why these live with the browser and what importing both does.
  # `zen-beta.desktop` is the id the flake's default package ships.
  xdg.mimeApps.defaultApplications = {
    "text/html"              = "zen-beta.desktop";
    "x-scheme-handler/http"  = "zen-beta.desktop";
    "x-scheme-handler/https" = "zen-beta.desktop";
    "image/svg+xml"          = "zen-beta.desktop";
  };
}
