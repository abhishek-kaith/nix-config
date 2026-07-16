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
    hostName = "vbx";
    networkmanager.enable = true;
  };

  # systemd-boot: simple UEFI bootloader, no config file needed.
  # NOTE: enable EFI in the VirtualBox VM settings (System → Enable EFI),
  # otherwise the GPT/ESP layout in disko.nix won't boot.
  boot.loader = {
    systemd-boot.enable      = true;
    efi.canTouchEfiVariables = true;
  };

  # software cursors — required under the VirtualBox virtual GPU; real hardware
  # uses HW cursors
  environment.sessionVariables.WLR_NO_HARDWARE_CURSORS = "1";

  users.users.${user} = {
    isNormalUser = true;
    extraGroups  = [ "wheel" "networkmanager" ];
    shell        = pkgs.zsh;
    initialPassword = "password"; # bootstrap login/sudo; change with `passwd` after first boot
  };

  security.sudo.wheelNeedsPassword = true;

  # SSH — connect from the host with: ssh vbox@<vm-ip>
  # (forward a port in VirtualBox NAT settings, or use a bridged/host-only adapter)
  # password auth is fine here — local dev VM only, not network-exposed
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };

  # VirtualBox Guest Additions: clipboard sharing, dynamic resize, vboxsf shares,
  # graceful shutdown. Analogous to services.qemuGuest on the vkvm host.
  virtualisation.virtualbox.guest.enable = true;

  system.stateVersion = "26.05";
}
