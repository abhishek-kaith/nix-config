{ pkgs, ... }:
{
  # Developer environment: the FHS/dynamic-linker shim, containers, Android tools,
  # a scraper-ready Chromium, and nix ergonomics. Language toolchains (node/python/
  # go/…) belong in per-project devShells via direnv — NOT here.

  # ── nix-ld: run prebuilt, dynamically-linked binaries on NixOS ────
  # Without this, non-Nix binaries fail with "No such file or directory" even
  # though they exist: Puppeteer's downloaded Chrome, editor-installed language
  # servers, bun, prebuilt npm native modules, random downloaded CLIs.
  programs.nix-ld.enable = true;

  # ── containers (Podman, docker-compatible) ───────────────────────
  virtualisation.podman = {
    enable       = true;
    dockerCompat = true;                          # `docker` command → podman
    dockerSocket.enable = true;                   # docker.sock compat (docker-compose, testcontainers)
    defaultNetwork.settings.dns_enabled = true;   # DNS between containers (needed by compose)
  };

  # ── nix ergonomics ───────────────────────────────────────────────
  programs.nix-index.enable = true;               # nix-locate <file> → which package ships it
  programs.command-not-found.enable = false;      # nix-index replaces the (flake-broken) default

  environment.systemPackages = with pkgs; [
    chromium              # scraper/automation browser (env below points tools at it)
    android-tools scrcpy  # adb + fastboot; scrcpy mirrors/controls a USB-connected phone
    docker-compose lazydocker dive   # container helpers
    comma                 # `, <program>` runs any nixpkgs program without installing
  ];

  # ── environment ──────────────────────────────────────────────────
  environment.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    PAGER  = "less";

    # Scrapers: use the Nix chromium instead of a downloaded Chrome that can't run
    # under NixOS (no /lib). adb needs no setup here — systemd 258 auto-handles USB perms.
    PUPPETEER_EXECUTABLE_PATH = "${pkgs.chromium}/bin/chromium";
    PUPPETEER_SKIP_DOWNLOAD   = "true";
    CHROME_BIN                = "${pkgs.chromium}/bin/chromium";
    # Playwright (uncomment — pulls playwright-driver.browsers, which is large):
    # PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
    # PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
  };
}
