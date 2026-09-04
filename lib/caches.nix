# Extra binary caches — ONE source of truth, because two places need them and a
# mismatch is silent: `modules/nixos/dev.nix` feeds them to `nix.settings` for
# the installed system, and the installer in `flake.nix` passes the same pair to
# `nixos-install`. The live ISO's daemon has never heard of these, so without the
# second one a fresh install fetches ~560 MB of build inputs and compiles the
# agents locally instead of downloading the finished binaries.
#
# A cache is only ever an optimisation. If a key is rotated or a URL dies, Nix
# logs "ignoring substitute … signature is not valid" and builds from source —
# slower, never wrong. Fix it by editing the pair here (and see README).
rec {
  caches = [
    {
      # numtide's cache, built from the `llm-agents` input (claude, codex, pi).
      # Key published at https://github.com/numtide/llm-agents.nix (flake.nix
      # nixConfig) — verify it there before changing it here.
      url = "https://cache.numtide.com";
      key = "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=";
    }
  ];

  urls = builtins.map (c: c.url) caches;
  keys = builtins.map (c: c.key) caches;

  # space-separated, for the `--option` flags nixos-install forwards to nix
  urlsArg = builtins.concatStringsSep " " urls;
  keysArg = builtins.concatStringsSep " " keys;
}
