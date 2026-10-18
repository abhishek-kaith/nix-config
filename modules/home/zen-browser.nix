{ inputs, pkgs, ... }:
let
  zen = inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system};
  # The flake's own wrapper, as its `default` package uses it.
  wrapZen = import "${inputs.zen-browser}/wrap-zen.nix" pkgs.wrapFirefox;
in
{
  # Package only, like brave-origin.nix: Zen owns its profile, extensions and
  # settings. Saved passwords live in Zen's own NSS store (key4.db + logins.json
  # in the profile), not in the desktop keyring, so a keyring or DE swap never
  # touches them.
  #
  # The one exception is a policy baked into the package, built here the way
  # the flake builds its `default` (beta): no AV1 video. Neither laptop's GPU
  # decodes AV1 (Renoir and Kaby Lake stop at VP9/HEVC), and YouTube serves
  # AV1 to any browser that accepts it, so every video was decoded on the CPU.
  # Measured on t14, 1080p60: AV1 83% of a core in software, VP9 32% through
  # VA-API even with a copy back to RAM, which the browser skips. With AV1 off
  # YouTube serves VP9 instead (about a third more bandwidth). "default"
  # leaves media.av1.enabled changeable in about:config. It goes to the
  # wrapper: wrapFirefox replaces the browser's distribution/policies.json
  # with one built from its own extraPolicies.
  home.packages = [
    (wrapZen zen.beta-unwrapped {
      icon = "zen-browser";
      extraPolicies.Preferences."media.av1.enabled" = { Value = false; Status = "default"; };
    })
  ];

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
