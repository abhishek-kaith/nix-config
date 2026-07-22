# inputs comes from specialArgs set in lib/default.nix
{ pkgs, inputs, user, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t480  # CPU/gfx/SSD/TrackPoint/throttled
    inputs.disko.nixosModules.disko
    ./disko.nix
    ./hardware-configuration.nix
    ../../modules/nixos/base.nix      # nix settings, locale, console/tty, zram, sysctl
    ../../modules/nixos/packages.nix  # system CLI toolbox
    ../../modules/nixos/network.nix   # networkmanager, DNS (Quad9/Cloudflare), firewall
    ../../modules/nixos/shell.nix     # zsh, starship, fzf, zoxide
    ../../modules/nixos/desktop.nix   # audio, fonts, polkit, portals, keyring
    ../../modules/nixos/niri.nix      # compositor + session entry (autologin)
    ../../modules/nixos/noctalia.nix  # noctalia overlay + binary cache + runtime deps
    ../../modules/nixos/laptop.nix    # upower, bluetooth, power-profiles
  ];

  networking.hostName = "t480";  # networkmanager lives in modules/nixos/network.nix

  # systemd-boot: simple UEFI bootloader
  boot.loader = {
    systemd-boot.enable      = true;
    efi.canTouchEfiVariables = true;
  };

  users.users.${user} = {
    isNormalUser = true;
    extraGroups  = [ "wheel" "networkmanager" ];
    shell        = pkgs.zsh;
    initialPassword = "password"; # bootstrap login/sudo; change with `passwd` after first boot
  };

  security.sudo.wheelNeedsPassword = true;

  # SSH — optional on a laptop; disable PasswordAuthentication if exposed to untrusted networks
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };

  system.stateVersion = "26.05";
}
