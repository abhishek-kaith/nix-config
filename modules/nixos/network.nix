{ ... }:
{
  networking.networkmanager.enable = true;

  # Do not hold the boot for the network. NetworkManager-wait-online blocks
  # network-online.target (and everything ordered after it) until a connection
  # is up — on wifi that is routinely 5-30s of a black screen for nothing the
  # desktop needs. The optional Flatpak theme job is the only unit here ordered
  # after network-online; it skips an absent Flathub remote and retries transient
  # install failures itself. Nothing else waits for a link.
  systemd.services.NetworkManager-wait-online.enable = false;

  # ── DNS: Cloudflare, then Quad9, encrypted where possible ─────────────
  # NetworkManager ignores `networking.nameservers` on its own, so hand DNS to
  # systemd-resolved and let it apply our resolvers globally.
  networking.networkmanager.dns = "systemd-resolved";

  # All of them go in one list because resolved treats `DNS=` as an ordered set it
  # fails over through — NOT as "primary + backup". FallbackDNS is deliberately
  # not used for the second provider: resolved consults FallbackDNS only when it
  # knows no DNS servers at all, so with a global DNS= set it can never be
  # reached, and a "fallback" put there is dead config that silently never runs.
  networking.nameservers = [
    "1.1.1.1" "1.0.0.1"                             # Cloudflare v4
    "2606:4700:4700::1111" "2606:4700:4700::1001"   # Cloudflare v6
    "9.9.9.9" "149.112.112.112"                     # Quad9 v4, if Cloudflare is unreachable
    "2620:fe::fe"                                   # Quad9 v6
  ];

  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNSOverTLS  = "opportunistic";           # DoT when the network allows it (captive-portal safe)
      # "~." routes ALL otherwise-unmatched lookups through our global resolvers,
      # so a connection's DHCP-supplied DNS can't silently override them.
      Domains = [ "~." ];
    };
  };

  # ── firewall ──────────────────────────────────────────────────────────
  # On by default and default-deny inbound (this IS the ufw equivalent). Nothing
  # is opened here; every open port comes from a module that asked for one, so
  # the real inbound surface on a laptop is:
  #
  #   22000/tcp + 22000,21027/udp  syncthing.nix, openDefaultPorts (sync + discovery)
  #   5353/udp                     mDNS — services.avahi, which the upstream COSMIC
  #                                module turns on with openFirewall for itself.
  #                                Browse-only: publish.* is all false, so this host
  #                                answers nothing, it only listens. Close it with
  #                                `services.avahi.openFirewall = false;` if no
  #                                printer/cast discovery is wanted on foreign wifi.
  #   22/tcp                       ONLY on the vbx/vkvm VMs (openssh.openFirewall).
  #                                t14/t480 run no sshd on purpose — see their
  #                                default.nix.
  #
  # Verify the live set rather than trusting this list:
  #   nix eval .#nixosConfigurations.t14.config.networking.firewall.allowedTCPPorts
  # Add extra inbound ports here, e.g. networking.firewall.allowedTCPPorts = [ 8080 ];
  networking.firewall.enable = true;
}
