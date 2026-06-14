{ inputs, pkgs, ... }:
{
  # makes pkgs.noctalia available system-wide (needed for home-manager with useGlobalPkgs)
  nixpkgs.overlays = [ inputs.noctalia.overlays.default ];

  services.pipewire = {
    enable       = true;
    alsa.enable  = true;
    pulse.enable = true;
  };
  services.pulseaudio.enable = false;

  fonts.packages = with pkgs; [
    nerd-fonts.iosevka
    nerd-fonts.jetbrains-mono
  ];

  security.polkit.enable = true;
}
