{ pkgs-unstable, ... }:
{
  # Home Manager only installs the browser. Origin owns its writable profile,
  # extensions, settings and policies so they can all be managed in the UI.
  home.packages = [ pkgs-unstable.brave-origin ];

  # The default browser wherever this module is imported. Kept here, not in
  # xdg.nix, so a host picks its browser with one import line. A host importing
  # two browser modules gets a "conflicting definition values" eval error for
  # these keys — on purpose: choose one, or mkForce in the host.
  xdg.mimeApps.defaultApplications = {
    "text/html"              = "brave-origin.desktop";
    "x-scheme-handler/http"  = "brave-origin.desktop";
    "x-scheme-handler/https" = "brave-origin.desktop";
    # SVG is markup, not a raster: qimgv renders it poorly or not at all, and
    # the browser is the best renderer already on the machine.
    "image/svg+xml"          = "brave-origin.desktop";
  };
}
