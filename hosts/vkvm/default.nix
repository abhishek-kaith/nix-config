# inputs comes from specialArgs set in lib/default.nix
{ pkgs, inputs, user, ... }:
{
  imports = [
    inputs.disko.nixosModules.disko  # registers disko's NixOS options
    ./disko.nix                      # our disk layout — disko reads this at boot too
    ./hardware-configuration.nix     # kernel modules, CPU microcode (generated)
    ../../modules/nixos/common.nix  # timezone, nix settings, base packages
    ../../modules/nixos/shell.nix   # zsh, starship, fzf, zoxide
    ../../modules/nixos/niri.nix      # compositor, portals, autologin
    ../../modules/nixos/desktop.nix   # audio, fonts, polkit, overlay
  ];

  networking = {
    hostName = "vkvm";
    networkmanager.enable = true;
  };

  # systemd-boot: simple UEFI bootloader, no config file needed
  boot.loader = {
    systemd-boot.enable      = true;
    efi.canTouchEfiVariables = true;
  };

  # software cursors — required under QEMU; real hardware uses HW cursors
  environment.sessionVariables.WLR_NO_HARDWARE_CURSORS = "1";

  users.users.${user} = {
    isNormalUser = true;
    extraGroups  = [ "wheel" "networkmanager" ];
    shell        = pkgs.zsh;
    initialPassword = "password"; # bootstrap login/sudo; change with `passwd` after first boot
  };

  security.sudo.wheelNeedsPassword = true;

  # SSH — connect from Arch host with: ssh kvm@<vm-ip>
  # password auth is fine here — local dev VM only, not network-exposed
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };

  # QEMU guest agent: graceful shutdown, host↔VM clipboard
  services.qemuGuest.enable = true;

  system.stateVersion = "26.05";
}
