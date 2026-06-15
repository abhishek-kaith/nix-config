# inputs comes from specialArgs set in lib/default.nix
{ pkgs, inputs, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t480  # CPU/gfx/SSD/TrackPoint/throttled
    inputs.disko.nixosModules.disko
    ./disko.nix
    ./hardware-configuration.nix
    ../../modules/nixos/common.nix    # timezone, nix settings, zram, base packages
    ../../modules/nixos/shell.nix     # zsh, starship, fzf, zoxide
    ../../modules/nixos/hyprland.nix  # compositor, portals, autologin
    ../../modules/nixos/desktop.nix   # audio, fonts, polkit, noctalia overlay
    ../../modules/nixos/laptop.nix    # upower, bluetooth, power-profiles (noctalia prereqs)
  ];

  networking = {
    hostName = "t480";
    networkmanager.enable = true;
  };

  # systemd-boot: simple UEFI bootloader
  boot.loader = {
    systemd-boot.enable      = true;
    efi.canTouchEfiVariables = true;
  };

  users.users.k = {
    isNormalUser = true;
    extraGroups  = [ "wheel" "networkmanager" ];
    shell        = pkgs.zsh;
    # set password on first boot: passwd k
  };

  security.sudo.wheelNeedsPassword = true;

  # SSH — optional on a laptop; disable PasswordAuthentication if exposed to untrusted networks
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };

  system.stateVersion = "26.05";
}
