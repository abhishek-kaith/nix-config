{ pkgs, inputs, ... }:
{
  imports = [ inputs.nix-index-database.nixosModules.default ];

  # Developer environment: the FHS/dynamic-linker shim, containers, Android tools,
  # a scraper-ready Chromium, AI coding agents, and nix ergonomics.
  #
  # The dividing line is "do I build WITH this, or are my tools built ON it?"
  # Project toolchains (a pinned node, a go/rust/java version, project deps) go in
  # per-project devShells via direnv — NOT here. What lives here is what nvim and
  # the agents need in order to start working at all, plus the global agent
  # binaries themselves. For genuine one-offs, reach for `,` (see nix ergonomics
  # below) instead of adding a package.

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
  # nix-index-database.nixosModules.default (imported above) feeds nix-index a
  # prebuilt, daily-updated DB, so `nix-index` never runs locally — it refreshes
  # with `nix flake update`.
  programs.nix-index.enable = true;                # nix-locate + command-not-found hook
  programs.nix-index-database.comma.enable = true; # `,` runs any program, backed by that DB
  programs.command-not-found.enable = false;       # nix-index replaces the (flake-broken) default

  environment.systemPackages = with pkgs; [
    chromium              # scraper/automation browser (env below points tools at it)
    android-tools scrcpy  # adb + fastboot; scrcpy mirrors/controls a USB-connected phone
    docker-compose lazydocker dive   # container helpers

    # ── AI coding agents ───────────────────────────────────────────
    # Each authenticates itself on first run and keeps its own state in $HOME
    # (~/.claude, ~/.codex, ~/.config/pi) — nothing to configure here. None of them
    # self-update: the store is read-only, so nixpkgs wraps them with the updater
    # and version-nag checks off. They move with `nix flake update` like the rest.
    claude-code      # `claude` — Anthropic (unfree; allowUnfree is set in base.nix)
    codex            # `codex`  — OpenAI, Rust binary, sandboxes via landlock/seccomp
    pi-coding-agent  # `pi`     — model-agnostic, MIT; wrapper bundles fd + ripgrep

    # ── runtimes nvim + the agents are built on ────────────────────
    # Not project toolchains — these are what the editor and the agents shell out
    # to at runtime, so they can't live in a devShell (nvim and the agents start
    # outside any project dir). Pin real versions per project in a devShell; these
    # are only ever the fallback.
    nodejs   # mason installs ts_ls/tailwindcss via npm; agents run MCP servers via npx
    gcc      # `cc` — nvim-treesitter compiles each parser from source; also node-gyp
    uv       # python without a system python: `uv run x.py`, `uvx ruff` — brings
             # its own interpreters (they're prebuilt, hence the nix-ld above)
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
