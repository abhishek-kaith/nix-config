{ ... }:
{
  networking.networkmanager.enable = true;

  # ── DNS: Quad9 primary, Cloudflare fallback, encrypted where possible ──
  # NetworkManager ignores `networking.nameservers` on its own, so hand DNS to
  # systemd-resolved and let it apply our resolvers globally.
  networking.networkmanager.dns = "systemd-resolved";
  networking.nameservers = [ "9.9.9.9" "149.112.112.112" "2620:fe::fe" ]; # Quad9
  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNSOverTLS  = "opportunistic";           # DoT when the network allows it (captive-portal safe)
      FallbackDNS = [ "1.1.1.1" "1.0.0.1" ];   # Cloudflare
      # "~." routes ALL otherwise-unmatched lookups through our global resolvers,
      # so a connection's DHCP-supplied DNS can't silently override Quad9.
      Domains = [ "~." ];
    };
  };

  # ── firewall ──────────────────────────────────────────────────────────
  # On by default and default-deny inbound (this IS the ufw equivalent). sshd
  # opens :22 itself via services.openssh.openFirewall in each host. Add extra
  # inbound ports here, e.g. networking.firewall.allowedTCPPorts = [ 8080 ];
  networking.firewall.enable = true;
}
