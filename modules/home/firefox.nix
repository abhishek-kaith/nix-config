{ pkgs, ... }:
{
  programs.firefox = {
    enable = true;

    # KeePassXC browser integration needs its native-messaging host registered
    # with Firefox. (Also flip on "Browser Integration" in KeePassXC's settings.)
    nativeMessagingHosts = [ pkgs.keepassxc ];

    # Enterprise policies (apply to every profile) — a sensible privacy baseline
    # that doesn't break sites. Extensions are force-installed straight from AMO,
    # so no NUR input is needed.
    policies = {
      DisableTelemetry = true;
      DisablePocket = true;
      DisableFirefoxStudies = true;
      DisableFeedbackCommands = true;
      DontCheckDefaultBrowser = true;
      EnableTrackingProtection = {
        Value = true;
        Locked = false;
        Cryptomining = true;
        Fingerprinting = true;
      };
      # the system already does DNS-over-TLS via systemd-resolved — don't double up
      DNSOverHTTPS.Enabled = false;
      ExtensionSettings = {
        "uBlock0@raymondhill.net" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
          installation_mode = "force_installed";
        };
        "keepassxc-browser@keepassxc.org" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/keepassxc-browser/latest.xpi";
          installation_mode = "force_installed";
        };
      };
    };

    profiles.default = {
      id = 0;
      isDefault = true;
      settings = {
        "dom.security.https_only_mode" = true;          # HTTPS-only
        "browser.contentblocking.category" = "strict";  # strict tracking protection
        "toolkit.telemetry.enabled" = false;
        "datareporting.healthreport.uploadEnabled" = false;
        "extensions.pocket.enabled" = false;
        "browser.newtabpage.activity-stream.showSponsored" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "browser.aboutConfig.showWarning" = false;
      };
    };
  };
}
