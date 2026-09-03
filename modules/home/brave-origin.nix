{ pkgs-unstable, ... }:
{
  # Home Manager only installs the browser. Origin owns its writable profile,
  # extensions, settings and policies so they can all be managed in the UI.
  home.packages = [ pkgs-unstable.brave-origin ];
}
