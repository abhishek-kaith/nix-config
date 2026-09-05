{ pkgs, ... }:
{
  # System-wide CLI toolbox, shared by every host (incl. the dev VMs).
  # Grouped by purpose; GUI apps live in apps.nix, the desktop itself in cosmic.nix.
  environment.systemPackages = with pkgs; [
    # ── system basics (identify hardware, poke at processes) ──────
    pciutils usbutils      # lspci / lsusb
    file lsof psmisc        # file-type / open-files / killall + pstree
    which

    # ── monitoring ────────────────────────────────────────────────
    btop lm_sensors iotop htop
    procs                   # modern `ps` (tree, colour, search)
    duf ncdu                # disk usage: duf = df, ncdu = interactive du
    bandwhich               # live per-process network bandwidth
    pfetch fastfetch        # system info fetch (fastfetch = fast, modern)
    acpi                    # battery / thermal / AC status

    # ── editors ───────────────────────────────────────────────────
    neovim vim
    tree-sitter             # nvim-treesitter's `main` branch shells out to this CLI
                            # to fetch + generate each parser (it explicitly refuses
                            # the npm build). Needs >= 0.26.1; a C compiler comes
                            # from `gcc` in dev.nix.

    # ── files & search ────────────────────────────────────────────
    ripgrep fd fzf bat eza zoxide tree
    sd                      # intuitive find-and-replace (sed alt)
    yazi                    # fast TUI file manager

    # ── wayland / desktop CLI ─────────────────────────────────────
    wl-clipboard            # wl-copy / wl-paste — piping to and from the clipboard

    # ── media / documents from the shell ──────────────────────────
    # The GUI side of this (mpv, qimgv, papers) is apps.nix; these are the tools
    # for doing something *to* a file rather than looking at it.
    ffmpeg                  # transcode/cut/concat A/V. Note yt-dlp does NOT need
                            # this — nixpkgs already wraps ffmpeg-headless into its
                            # PATH — this is for calling ffmpeg/ffprobe yourself.
    imagemagick             # convert/mogrify/identify for image work from the shell
    exiftool                # read/strip image + video metadata (EXIF, GPS, …)
    poppler-utils           # pdftotext / pdfimages / pdfunite — the CLI half of PDF
    mediainfo               # what codec/bitrate/profile is actually in this file
    libva-utils             # `vainfo`: prove the Intel HW decode path really works
                            # (nixos-hardware installs the driver; nothing verified it)

    # ── archives ──────────────────────────────────────────────────
    unzip zip p7zip rsync
    zstd xz                 # modern .zst / .xz (de)compression
    libarchive              # bsdtar — reads most formats
    unrar                   # .rar (unfree)
    ouch                    # one command to (un)pack any archive

    # ── network diagnostics ───────────────────────────────────────
    curl wget nmap netcat-openbsd   # nmap = the port/IP scanner
    mtr whois               # live traceroute+ping / ownership lookup
    arp-scan                # discover every device on the LAN
    iperf3 tcpdump          # bandwidth test / packet capture
    gping speedtest-cli iftop   # ping-graph / ISP speed / live iface usage

    # ── DNS ───────────────────────────────────────────────────────
    # `dnsutils` alone, NOT `dnsutils` + `dig`. In nixpkgs those are two separate
    # derivations of the same bind output (`dig` re-wraps it only to set
    # meta.mainProgram), so asking for both pulls two copies into the closure and
    # collides on bin/dig, bin/host and bin/nslookup — buildEnv then prints a
    # collision warning on every rebuild and picks one arbitrarily.
    dnsutils                # dig + nslookup + host
    doggo                   # modern, colourful dig (DoH/DoT aware)

    # ── HTTP / API ────────────────────────────────────────────────
    xh                      # friendly HTTP client (httpie-compatible, fast)
    grpcurl websocat        # gRPC / websocket poking

    # ── data / json ───────────────────────────────────────────────
    jq yq
    jless fx                # interactive JSON/YAML viewers

    # ── dev / git ─────────────────────────────────────────────────
    git gh                  # GitHub CLI (PRs, issues, gists)
    delta                   # syntax-highlighted git diffs
    lazygit                 # TUI git
    git-lfs difftastic      # large files / structural diff
    just                    # project task runner
    watchexec hyperfine tokei   # run-on-change / benchmark / count LOC

    # ── file transfer ─────────────────────────────────────────────
    rclone                  # sync to cloud remotes
    croc                    # painless device→device transfer
    sshfs                   # mount a remote dir over ssh

    # ── nix workflow ──────────────────────────────────────────────
    # Deliberately no rebuild wrapper (nh) and no generation-differ (nvd): plain
    # `nixos-rebuild` and the built-in `nix store diff-closures` do both jobs, and
    # neither is another moving part to keep current.
    nix-tree                # explore a closure's dependencies
    nil nixfmt              # Nix LSP + formatter (for editing this repo)
    tealdeer                # `tldr` — quick command examples
  ];
}
