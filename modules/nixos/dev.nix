{ pkgs, inputs, ... }:
let
  # The AI coding agents, from the llm-agents flake input instead of nixpkgs —
  # rationale at the package list below.
  agents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  caches = import ../../lib/caches.nix;
in
{
  imports = [ inputs.nix-index-database.nixosModules.default ];

  # Developer environment: the FHS/dynamic-linker shim, containers, Android tools,
  # a scraper-ready Chromium, AI coding agents, and nix ergonomics.
  #
  # The dividing line is "do I build WITH this, or are my tools built ON it?"
  # Project toolchains (a pinned node, a go/rust/java version, project deps) go in
  # per-project devShells via direnv — NOT here. What lives here is what nvim and
  # the agents need in order to start working at all, plus the global agent
  # binaries themselves. For genuine one-offs, reach for
  # `nix shell nixpkgs#<pkg>` instead of adding a package.

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
  # comma (`,`) is deliberately NOT enabled: `nix shell nixpkgs#<pkg>` is the one
  # command it wrapped, and nix-index is wanted here for nix-locate and the
  # command-not-found hook either way.
  programs.nix-index.enable = true;                # nix-locate + command-not-found hook
  programs.command-not-found.enable = false;       # nix-index replaces the (flake-broken) default

  # ── open-file limit ──────────────────────────────────────────────
  # systemd's default soft limit is 1024 fds per process (hard: 524288). Vite,
  # esbuild, tsserver and the agents' file watchers each hold one fd per
  # watched file, and a large monorepo blows past 1024 as EMFILE / "too many
  # open files" — browsers survive only because they raise their own limit.
  # This lifts the soft limit to the hard one for every service and, through
  # user@.service → the user manager → the session, for everything you launch.
  # inotify watches are a separate limit and already default high (base.nix).
  systemd.settings.Manager.DefaultLimitNOFILE = "524288:524288";

  # ── binary cache for the AI agents ───────────────────────────────
  # llm-agents.nix builds against its own nixpkgs pin, not this system's, so
  # cache.nixos.org has none of its outputs — without this an agent bump means
  # ~560 MB of build inputs and a local build instead of a plain download.
  # `extra-` appends to the defaults, so cache.nixos.org is still consulted
  # first for everything else. A path that is unsigned, or signed by a key not
  # listed here, is rejected and built from source — a rotated or dead key
  # costs time, never correctness.
  #
  # The pair lives in lib/caches.nix because the installer needs the same one:
  # the live ISO's daemon cannot read the config it is installing.
  nix.settings = {
    extra-substituters        = caches.urls;
    extra-trusted-public-keys = caches.keys;
  };

  environment.systemPackages = with pkgs; [
    chromium              # scraper/automation browser (env below points tools at it)
    android-tools scrcpy  # adb + fastboot; scrcpy mirrors/controls a USB-connected phone
    docker-compose lazydocker dive   # container helpers

    # ── AI coding agents ───────────────────────────────────────────
    # Each authenticates itself on first run and keeps its own state in $HOME
    # (~/.claude, ~/.codex, ~/.config/pi) — nothing to configure here. None of them
    # self-update: the store is read-only, so they are wrapped with the updater
    # and version-nag checks off. They move with `nix flake update`.
    #
    # These come from the `llm-agents` input, not nixpkgs. nixpkgs is not slow at
    # packaging them, but the nixos-unstable *channel* only advances every 1-3
    # days behind Hydra, and that lag compounds with the packaging one: on the day
    # this was wired up nixpkgs was 3 claude releases and 2 codex minors behind
    # upstream (and pi was 9 minors behind, still coming from stable). llm-agents
    # tracks releases within hours and ships prebuilt binaries from
    # cache.numtide.com (substituter above).
    #
    # The other half of the reason is decoupling: `nix flake update llm-agents`
    # bumps the agents on their own. Taking them from `pkgs-unstable` meant every
    # agent bump also dragged in a new COSMIC (modules/nixos/cosmic.nix).
    agents.claude-code  # `claude` — Anthropic (unfree)
    agents.codex        # `codex`  — OpenAI, Rust binary, sandboxes via landlock/seccomp
    agents.pi           # `pi`     — model-agnostic, MIT
    agents.opencode     #

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
