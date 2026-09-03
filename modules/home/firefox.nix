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

      # Keep these defaults consistent across Firefox-managed profiles without
      # making Home Manager own profiles.ini or the individual profile folders.
      Preferences = {
        "dom.security.https_only_mode" = {
          Value = true;
          Status = "default";
        };
        "browser.contentblocking.category" = {
          Value = "strict";
          Status = "default";
        };
        "toolkit.telemetry.enabled" = {
          Value = false;
          Status = "default";
        };
        "datareporting.healthreport.uploadEnabled" = {
          Value = false;
          Status = "default";
        };
        "extensions.pocket.enabled" = {
          Value = false;
          Status = "default";
        };
        "browser.newtabpage.activity-stream.showSponsored" = {
          Value = false;
          Status = "default";
        };
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = {
          Value = false;
          Status = "default";
        };
        "browser.aboutConfig.showWarning" = {
          Value = false;
          Status = "default";
        };
        "browser.urlbar.suggest.quicksuggest.sponsored" = {
          Value = false;
          Status = "default";
        };
        "browser.urlbar.suggest.quicksuggest.nonsponsored" = {
          Value = false;
          Status = "default";
        };
        "browser.discovery.enabled" = {
          Value = false;
          Status = "default";
        };
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

      # KeePassXC is the password store — leaving Firefox's own manager on means
      # credentials get saved in two places and the save-password prompt competes
      # with the KeePassXC one.
      PasswordManagerEnabled = false;
      OfferToSaveLogins = false;
    };
  };
}
