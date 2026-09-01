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
    ../../modules/nixos/dev.nix       # nix-ld, podman, adb, chromium + scraper env
    ../../modules/nixos/network.nix   # networkmanager, DNS (Quad9/Cloudflare), firewall
    ../../modules/nixos/shell.nix     # zsh, starship, fzf, zoxide
    ../../modules/nixos/desktop.nix   # audio, fonts, polkit, portals, keyring
    ../../modules/nixos/apps.nix      # GUI apps: mpv, thunar, qimgv, satty, pdf
    ../../modules/nixos/cosmic.nix    # the desktop environment (COSMIC, from unstable)
    ../../modules/nixos/syncthing.nix # file sync (opens 22000/tcp + 21027/udp)
    ../../modules/nixos/laptop.nix    # fwupd, lid->hibernate, battery thresholds
    ../../modules/nixos/storage.nix   # btrfs scrub, smartd, snapper snapshots
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

  # ── no sshd ──────────────────────────────────────────────────────
  # Deliberately absent, where the VMs do run one. This machine joins networks it
  # does not control (cafe, hotel, conference wifi), and openFirewall puts :22 on
  # every interface — so an sshd with PasswordAuthentication and a `wheel` account
  # still on its bootstrap password is a guessable path to root from the same
  # subnet. Nothing here connects *in*; outbound ssh needs no daemon.
  #
  # To turn it back on, do it key-only — never with the password path open:
  #   users.users.${user}.openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAA..." ];
  #   services.openssh = {
  #     enable = true;
  #     settings.PasswordAuthentication = false;
  #     settings.KbdInteractiveAuthentication = false;
  #   };

  system.stateVersion = "26.05";
}
