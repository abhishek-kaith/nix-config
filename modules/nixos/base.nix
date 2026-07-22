{ pkgs, user, ... }:
{
  # ── locale / time ────────────────────────────────────────────────
  time.timeZone      = "Asia/Kolkata";
  i18n.defaultLocale = "en_US.UTF-8";

  # ── console / TTY (the pre-graphical layer) ──────────────────────
  console = {
    font       = "ter-128b";              # large HiDPI console font (bold)
    packages   = [ pkgs.terminus_font ];  # ships ter-128b
    earlySetup = true;                    # apply the big font before stage-1, so the
                                          # LUKS passphrase prompt isn't tiny
    keyMap     = "us";
  };

  # ── nix ──────────────────────────────────────────────────────────
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store   = true;
      trusted-users         = [ "root" user ];
      # noctalia's binary cache lives in modules/nixos/noctalia.nix, not here.
    };
    gc = {
      automatic = true;
      dates     = "weekly";
      options   = "--delete-older-than 30d";
    };
    channel.enable = false; # flakes handle pinning; channels are redundant
  };

  nixpkgs.config.allowUnfree = true;

  # compressed RAM swap — eases memory pressure; coexists with disk hibernation swap
  zramSwap.enable = true;

  # ── light hardening (no desktop impact) ──────────────────────────
  boot.kernel.sysctl = {
    "kernel.kptr_restrict"               = 2;   # hide kernel pointers from userspace
    "net.ipv4.conf.all.rp_filter"        = 1;   # drop spoofed / martian source packets
    "net.ipv4.conf.all.accept_redirects" = 0;   # ignore ICMP redirects
    "net.ipv4.conf.all.log_martians"     = 1;   # log impossible-address packets
  };
}
