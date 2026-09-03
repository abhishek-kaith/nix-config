# inputs comes from specialArgs set in lib/default.nix
{ pkgs, inputs, user, ... }:
{
  imports = [
    inputs.disko.nixosModules.disko  # registers disko's NixOS options
    ./disko.nix                      # our disk layout — disko reads this at boot too
    ./hardware-configuration.nix     # kernel modules, CPU microcode (generated)
    ../../modules/nixos/base.nix      # nix settings, locale, console/tty, zram, sysctl
    ../../modules/nixos/packages.nix  # system CLI toolbox
    ../../modules/nixos/dev.nix       # nix-ld, podman, adb, chromium + scraper env
    ../../modules/nixos/network.nix   # networkmanager, DNS (Quad9/Cloudflare), firewall
    ../../modules/nixos/shell.nix     # zsh, starship, fzf, zoxide
    ../../modules/nixos/desktop.nix   # audio, fonts, polkit, portals, keyring
    ../../modules/nixos/apps.nix      # GUI apps: mpv, thunar, qimgv, satty, pdf
    ../../modules/nixos/cosmic.nix    # the desktop environment (COSMIC, from unstable)
    ../../modules/nixos/syncthing.nix # file sync (opens 22000/tcp + 21027/udp)
  ];

  networking.hostName = "vkvm";  # networkmanager lives in modules/nixos/network.nix

  # systemd-boot: simple UEFI bootloader, no config file needed
  boot.loader = {
    systemd-boot.enable      = true;
    efi.canTouchEfiVariables = true;
  };

  # NOTE: no WLR_NO_HARDWARE_CURSORS here. That is a wlroots variable and
  # cosmic-comp is Smithay-based, so setting it does nothing. If the pointer is
  # missing or the session won't start under QEMU, fix it on the host side
  # instead: `-vga virtio` / virtio-gpu-gl with `-display gtk,gl=on` (COSMIC
  # needs a working GL stack, it has no software-only fallback worth using).

  users.users.${user} = {
    isNormalUser = true;
    extraGroups  = [ "wheel" "networkmanager" ];
    shell        = pkgs.zsh;
  };

  security.sudo.wheelNeedsPassword = true;

  # SSH — connect from Arch host with: ssh kvm@<vm-ip>
  # password auth is fine here — local dev VM only, not network-exposed
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };

  # QEMU guest agent: graceful shutdown/reboot from the host, and IP reporting to
  # virsh. It does NOT do clipboard or display resize — that is the SPICE agent
  # below, and the comment here used to claim otherwise.
  services.qemuGuest.enable = true;

  # SPICE guest agent: shared clipboard and guest display auto-resize when the VM
  # runs on a SPICE display (virt-manager's default). Needs `-device virtio-serial`
  # plus the org.spice-space.webdav/vdagent channel on the host side — virt-manager
  # wires that up itself; a hand-rolled qemu command line has to add it.
  # Under Wayland the clipboard half works through wlr-data-control, which
  # cosmic-comp implements; the resize half goes through the agent either way.
  services.spice-vdagentd.enable = true;

  system.stateVersion = "26.05";
}
