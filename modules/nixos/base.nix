{ pkgs, user, ... }:
{
  # ── locale / time ────────────────────────────────────────────────
  time.timeZone      = "Asia/Kolkata";
  i18n.defaultLocale = "en_US.UTF-8";

  # The interface language stays en_US (that is what upstream software is written
  # and tested in), but the machine lives in India — so the formats that describe
  # the *place* come from en_IN: dates as dd/mm/yyyy, ₹ for money, metric units,
  # A4 paper.
  #
  # NixOS builds the locale archive from defaultLocale + every locale named here
  # (+ i18n.extraLocales for anything else), as "<name>/UTF-8". So the name used
  # here has to be one glibc's SUPPORTED list actually carries — and it is
  # `en_IN/UTF-8`, NOT `en_IN.UTF-8/UTF-8`: unlike en_US, en_IN has no
  # codeset-suffixed variant. Writing "en_IN.UTF-8" below therefore fails the
  # glibc-locales build with "you should choose from the list", and `nix eval`
  # will NOT catch it because evaluating a config never builds the archive.
  # Plain "en_IN" is the UTF-8 locale (the archive holds it as en_IN + en_IN.utf8).
  i18n.extraLocaleSettings = {
    LC_TIME        = "en_IN";
    LC_MONETARY    = "en_IN";
    LC_MEASUREMENT = "en_IN";
    LC_PAPER       = "en_IN";
    LC_ADDRESS     = "en_IN";
    LC_TELEPHONE   = "en_IN";
    # LC_NUMERIC is deliberately NOT switched. en_IN groups digits the Indian way
    # (1,00,000 rather than 100,000), and that grouping leaks into the output of
    # sort, awk, printf and anything else that formats numbers for a human —
    # which is a surprising thing to hit inside a shell pipeline.
  };

  # ── console / TTY (the pre-graphical layer) ──────────────────────
  console = {
    font       = "ter-128b";              # large HiDPI console font (bold)
    packages   = [ pkgs.terminus_font ];  # ships ter-128b
    earlySetup = true;                    # apply the big font before stage-1, so the
                                          # LUKS passphrase prompt isn't tiny
    keyMap     = "us";
  };

  # ── boot ─────────────────────────────────────────────────────────
  # skip the systemd-boot menu and boot straight in. Hold Space (or any key)
  # during boot to bring the menu up when you need to pick an older generation
  # to roll back. Per-host bootloader enable lives in hosts/*/default.nix.
  boot.loader.timeout = 0;

  # systemd in stage 1. Starts units in parallel instead of running one shell
  # script top-to-bottom, and unlocks LUKS via systemd-cryptsetup — which is the
  # slowest part of this boot. disko already emits boot.initrd.luks.devices, and
  # it turns this on itself when FIDO2 unlock is used, so the pairing is supported.
  # If a boot ever fails here: hold Space at power-on for the systemd-boot menu and
  # pick the previous generation.
  boot.initrd.systemd.enable = true;

  # Empty /tmp on every boot. It is a real directory on the btrfs root here, NOT a
  # tmpfs — deliberately, because that is what lets a large `nix build` spill to
  # disk instead of eating RAM (the same reason the installer sets TMPDIR=/mnt/tmp).
  # The cost of that choice is that anything left behind by a killed build persists
  # forever; this sweeps it at the one moment nothing can be using it.
  boot.tmp.cleanOnBoot = true;

  # ── nix ──────────────────────────────────────────────────────────
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      trusted-users         = [ "root" user ];
      # Per-host build parallelism is NOT capped here — core counts differ between
      # the laptop and the VMs. If a big rebuild ever starves the machine, set
      # `nix.settings.max-jobs` / `cores` in that host's default.nix.
    };
    gc = {
      automatic = true;
      dates     = "weekly";
      options   = "--delete-older-than 30d";
    };
    channel.enable = false; # flakes handle pinning; channels are redundant

    # A rebuild should not make the desktop, the browser or a running agent
    # stutter. `batch` tells the scheduler the daemon's work is throughput, not
    # latency — it still gets its fair share of CPU, just never at the expense of
    # something interactive. Deliberately NOT `idle`: that gives builds zero CPU
    # whenever anything else wants some, and with agents busy in the background
    # a rebuild could then crawl for an hour. I/O likewise: lowest best-effort
    # priority rather than idle, so a build progresses while a browser thrashes.
    daemonCPUSchedPolicy  = "batch";
    daemonIOSchedClass    = "best-effort";
    daemonIOSchedPriority = 7;
  };

  # Store deduplication, moved OFF the build path. `auto-optimise-store = true`
  # hardlinks identical files after EVERY build and every `nix copy`, adding an
  # I/O pass to work you are waiting on. This does the same job on a timer
  # instead; `persistent` defaults true, so a laptop that was asleep at 03:45
  # catches up on the next boot rather than skipping the run.
  nix.optimise = {
    automatic = true;
    # Daytime, and deliberately NOT persistent. The default 03:45 never fires on a
    # laptop that is off overnight, and `persistent` (default true) would then dump
    # a store-wide hardlink pass on you moments after the next boot — the worst
    # possible moment. Skipping a missed run is fine: this is disk housekeeping,
    # not something that has to happen every day.
    dates      = [ "13:00" ];
    persistent = false;
  };

  nixpkgs.config.allowUnfree = true;

  # compressed RAM swap — eases memory pressure; coexists with disk hibernation swap.
  # Defaults: 50% of RAM, zstd, priority 5 — above the disk swap, so pages go to
  # compressed RAM first and only spill to the LUKS swap LV when zram is full.
  zramSwap.enable = true;

  # ── staying responsive under load ────────────────────────────────
  # The failure this prevents: enough parallel work (agents spinning worktrees,
  # a big rebuild) to exhaust RAM, at which point the kernel thrashes swap and the
  # desktop stops responding without ever invoking the OOM killer. earlyoom acts
  # while there is still headroom, killing ONE process instead of freezing.
  # No --avoid / --prefer on purpose. earlyoom picks the highest oom_score, which
  # is essentially the largest memory consumer — already the runaway agent or
  # build, never sshd or dbus-daemon at a few MB. The session processes are the
  # only plausible false target, and if cosmic-comp ever IS the biggest thing on
  # the machine then it is leaking and killing it is the correct outcome; an
  # --avoid there converts one clean kill into a death spiral that takes the
  # browser, then the terminal, then the agents, while the leak survives.
  # Both flags also match /proc/<pid>/comm, which the kernel truncates to 15
  # chars, so long names silently never match (`node` is `node-MainThread` here).
  # If it ever kills the wrong thing, `journalctl -u earlyoom` names it — add the
  # regex then, from evidence. Self-protection needs nothing either: the shipped
  # unit already sets Nice=-20, OOMScoreAdjust=-100 and Restart=always.
  services.earlyoom.enable = true;   # SIGTERM under 10% free, SIGKILL under 5%

  # systemd-oomd is enabled by default but monitors NOTHING unless a slice opts in
  # (enableRootSlice / enableUserSlices are all off), so it is dead weight here.
  # Turned off explicitly rather than left running: with earlyoom above, two OOM
  # killers with different policies would be racing over the same pressure.
  systemd.oomd.enable = false;

  # Weekly SSD TRIM. Kept as a backstop even though the btrfs mounts now use
  # `discard=async` (hosts/*/disko.nix), which trims continuously in the
  # background instead of in one weekly burst — a weekly pass over already-trimmed
  # blocks is close to free, and it still covers the ESP.
  services.fstrim.enable = true;

  # ── light hardening (no desktop impact) ──────────────────────────
  boot.kernel.sysctl = {
    "kernel.kptr_restrict"               = 2;   # hide kernel pointers from userspace
    "net.ipv4.conf.all.rp_filter"        = 1;   # drop spoofed / martian source packets
    "net.ipv4.conf.all.accept_redirects" = 0;   # ignore ICMP redirects
    "net.ipv4.conf.all.log_martians"     = 1;   # log impossible-address packets

    # ── memory + I/O responsiveness ────────────────────────────────
    # Tuned for zram, not for a disk swap. Swapping to compressed RAM is cheap, so
    # prefer it over evicting page cache (which is what you actually want kept —
    # the file cache is why a re-read is instant).
    "vm.swappiness"            = 180;  # 0-200 since 5.8; the zram-tuned value
    "vm.page-cluster"          = 0;    # no read-ahead: zram reads are single-page
    "vm.watermark_scale_factor" = 125; # start reclaiming earlier, in smaller steps,
                                       # instead of one large stall at the cliff

    # NOT set here: vm.dirty_bytes / vm.dirty_background_bytes. Capping dirty
    # pages by bytes instead of the default % of RAM does smooth the stall at the
    # end of a large copy, but it costs peak write throughput on NVMe and no such
    # stall has actually been observed on this machine. If one shows up, that is
    # the knob (start at 256MB / 64MB) — measured, not guessed.

    # NOTE: fs.inotify.max_user_watches / max_user_instances are NOT set here.
    # NixOS already defaults both to 524288 (nixos/modules/config/sysctl.nix),
    # which is well above what file watchers and worktree-spinning agents need.
  };
}
