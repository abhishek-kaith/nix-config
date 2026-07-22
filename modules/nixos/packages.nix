{ pkgs, ... }:
{
  # System-wide CLI toolbox, shared by every host (incl. the dev VMs).
  # Grouped by purpose; graphical/Wayland tools live in desktop.nix / noctalia.nix.
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

    # ── files & search ────────────────────────────────────────────
    ripgrep fd fzf bat eza zoxide tree
    sd                      # intuitive find-and-replace (sed alt)
    yazi                    # fast TUI file manager

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
    dig dnsutils            # dig + nslookup + host
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
    nh nvd                  # nicer rebuild wrapper / diff generations
    nix-tree                # explore a closure's dependencies
    nil nixfmt              # Nix LSP + formatter (for editing this repo)
    tealdeer                # `tldr` — quick command examples
  ];
}
