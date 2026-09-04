# inputs comes from specialArgs set in lib/default.nix
{ pkgs, inputs, user, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t14-amd-gen1  # amdgpu, AMD microcode, SSD, backlight+touchpad kernel params
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

  networking.hostName = "t14";   # networkmanager lives in modules/nixos/network.nix

  # systemd-boot: simple UEFI bootloader
  boot.loader = {
    systemd-boot.enable      = true;
    efi.canTouchEfiVariables = true;
  };

  users.users.${user} = {
    isNormalUser = true;
    extraGroups  = [ "wheel" "networkmanager" ];
    shell        = pkgs.zsh;
  };

  security.sudo.wheelNeedsPassword = true;

  # ── T14 Gen 1 (AMD) quirks ───────────────────────────────────────
  # Suspend: UEFI setup → Config → Power → Sleep State must stay on "Linux" so
  # the firmware exposes S3. /sys/power/mem_sleep then reads `s2idle [deep]`;
  # select deep explicitly because Renoir's s2idle runs warm in a closed bag.
  # A real S3 suspend/resume cycle has been verified on this machine.
  boot.kernelParams = [ "mem_sleep_default=deep" ];

  # Activate ALSA's state service and sound-card restore rule for the codec's
  # microphone-mute LED. PipeWire remains the sound server.
  hardware.alsa.enablePersistence = true;

  # Fingerprint reader (Synaptics 06cb:00bd, "Prometheus"): supported by
  # libfprint, but it needs the LVFS firmware first (`fwupdmgr update` — fwupd
  # comes from laptop.nix). Not enabled here: fprintd's PAM hook makes every
  # `sudo` wait for a finger before it accepts a password, and cosmic-greeter
  # does not yet drive it. When wanted:
  #   services.fprintd.enable = true;
  #   then `fprintd-enroll` once as ${user}.

  # ── no sshd ──────────────────────────────────────────────────────
  # Deliberately absent, where the VMs do run one. This machine joins networks it
  # does not control (cafe, hotel, conference wifi), and openFirewall puts :22 on
  # every interface — so an sshd with PasswordAuthentication gives the same
  # subnet a password-guessing path to a `wheel` account. Nothing here connects
  # *in*; outbound ssh needs no daemon.
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
